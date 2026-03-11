package com.pinglo.tracker.service

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.pinglo.tracker.BuildConfig
import com.pinglo.tracker.config.ConfigurationDefaults
import com.pinglo.tracker.config.ConfigurationKeys
import com.pinglo.tracker.model.MotionType
import com.pinglo.tracker.model.RequestPayload
import com.squareup.moshi.JsonClass
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/** Legacy model kept for one-time migration of pending pings from SharedPreferences to WorkManager. */
@JsonClass(generateAdapter = true)
data class PendingPing(
    val payload: RequestPayload,
    val retryIndex: Int,
)

@Singleton
class NetworkingService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val api: SupabaseApi,
    private val secureStore: SecureStore,
    private val moshi: Moshi,
    private val prefs: SharedPreferences,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val throttleMutex = Mutex()
    private val lastPingTimes = mutableMapOf<String, Long>()

    var uid: String?
        get() = prefs.getString(ConfigurationKeys.UID, null)
        set(value) {
            if (value.isNullOrEmpty()) {
                prefs.edit().remove(ConfigurationKeys.UID).apply()
            } else {
                prefs.edit().putString(ConfigurationKeys.UID, value).apply()
            }
        }

    init {
        val defaultUid = prefs.getString(ConfigurationKeys.UID, null)
        val legacyUid = prefs.getString(ConfigurationKeys.LEGACY_UID, null)

        if (defaultUid == null) {
            val secureUid = secureStore.getString(SecureStoreKey.UID)
            val resolved = secureUid ?: legacyUid
            if (resolved != null) {
                uid = resolved
                prefs.edit().remove(ConfigurationKeys.LEGACY_UID).apply()
            }
        }
        migratePendingPingsToWorkManager()
    }

    companion object {
        private const val TAG = "NetworkingService"
        private const val PENDING_PINGS_KEY = "pendingPings"

        fun throttleIntervalMs(activity: String): Long = when (activity) {
            "WALKING"    -> 120_000L
            "RUNNING"    -> 120_000L
            "CYCLING"    -> 240_000L
            "AUTOMOTIVE" -> 600_000L
            "STILL"      -> 1_200_000L
            else         -> 300_000L
        }
    }

    fun sendLocation(
        lat: Double,
        long: Double,
        accuracy: Double,
        activity: String,
        confidence: String,
        force: Boolean = false,
    ) {
        val capturedAt = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        scope.launch {
            if (BuildConfig.DEBUG) {
                Log.d(TAG, "Sending location. Activity: $activity ($confidence)${if (force) " [FORCED]" else ""}")
            }

            val shouldSend = throttleMutex.withLock {
                if (!force) {
                    val interval = throttleIntervalMs(activity)
                    val last = lastPingTimes[activity]
                    if (last != null && System.currentTimeMillis() - last < interval) {
                        if (BuildConfig.DEBUG) {
                            Log.d(TAG, "Throttled: ${interval / 60_000}min limit for $activity not reached")
                        }
                        return@withLock false
                    }
                }
                lastPingTimes[activity] = System.currentTimeMillis()
                true
            }
            if (!shouldSend) return@launch

            val isHomeSet = prefs.getBoolean(ConfigurationKeys.IS_HOME_SET, false)
            val homeLat = if (isHomeSet) secureStore.getDouble(SecureStoreKey.HOME_LATITUDE) else null
            val homeLong = if (isHomeSet) secureStore.getDouble(SecureStoreKey.HOME_LONGITUDE) else null

            val payload = RequestPayload(
                uid = uid ?: ConfigurationDefaults.ANONYMOUS_UID,
                lat = lat,
                long = long,
                homeLat = homeLat,
                homeLong = homeLong,
                motion = MotionType(motion = activity, confidence = confidence),
                horizontalAccuracy = accuracy,
                capturedAt = capturedAt,
            )

            sendPing(payload)
        }
    }

    suspend fun callBackfillReframeHome(homeLat: Double, homeLong: Double): Result<Int> =
        try {
            val body = mapOf<String, Any>(
                "deviceId" to (uid ?: ConfigurationDefaults.ANONYMOUS_UID),
                "user_home_lat" to homeLat,
                "user_home_long" to homeLong,
            )
            val response = api.backfillReframeHome(body)
            if (response.isSuccessful) {
                val jsonStr = response.body()?.string()
                val updated = jsonStr?.let {
                    try {
                        val type = Types.newParameterizedType(
                            Map::class.java, String::class.java, Any::class.java,
                        )
                        val map = moshi.adapter<Map<String, Any>>(type).fromJson(it)
                        (map?.get("updated") as? Double)?.toInt() ?: 0
                    } catch (_: Exception) { 0 }
                } ?: 0
                Result.success(updated)
            } else {
                Result.failure(Exception("Backfill returned status ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }

    // -- Ping with WorkManager retry -------------------------------------------------

    private suspend fun sendPing(payload: RequestPayload) {
        try {
            val response = api.ping(payload)
            if (response.isSuccessful) {
                if (BuildConfig.DEBUG) Log.d(TAG, "Ping success")
            } else if (response.code() >= 500) {
                enqueueRetry(payload)
            } else {
                if (BuildConfig.DEBUG) Log.w(TAG, "Ping rejected: status ${response.code()}")
            }
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Ping failed: ${e.message}")
            enqueueRetry(payload)
        }
    }

    private fun enqueueRetry(payload: RequestPayload) {
        val json = moshi.adapter(RequestPayload::class.java).toJson(payload)
        val workRequest = OneTimeWorkRequestBuilder<PingRetryWorker>()
            .setInputData(workDataOf(PingRetryWorker.KEY_PAYLOAD to json))
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)
        if (BuildConfig.DEBUG) Log.d(TAG, "Ping retry enqueued via WorkManager")
    }

    // -- One-time migration from legacy SharedPreferences pending pings ---------------

    private fun migratePendingPingsToWorkManager() {
        val json = prefs.getString(PENDING_PINGS_KEY, null) ?: return
        try {
            val type = Types.newParameterizedType(List::class.java, PendingPing::class.java)
            val pings = moshi.adapter<List<PendingPing>>(type).fromJson(json) ?: return
            if (pings.isEmpty()) return
            if (BuildConfig.DEBUG) Log.d(TAG, "Migrating ${pings.size} pending ping(s) to WorkManager")
            for (ping in pings) {
                enqueueRetry(ping.payload)
            }
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Failed to migrate pending pings: ${e.message}")
        } finally {
            prefs.edit().remove(PENDING_PINGS_KEY).apply()
        }
    }
}
