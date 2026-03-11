package com.pinglo.tracker.service

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.pinglo.tracker.BuildConfig
import com.pinglo.tracker.model.RequestPayload
import com.squareup.moshi.Moshi
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

@HiltWorker
class PingRetryWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val api: SupabaseApi,
    private val moshi: Moshi,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        if (runAttemptCount >= MAX_RETRIES) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Max retries ($MAX_RETRIES) exhausted, dropping ping")
            return Result.failure()
        }

        val payloadJson = inputData.getString(KEY_PAYLOAD) ?: return Result.failure()
        val payload = try {
            moshi.adapter(RequestPayload::class.java).fromJson(payloadJson)
                ?: return Result.failure()
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Failed to deserialize payload: ${e.message}")
            return Result.failure()
        }

        return try {
            val response = api.ping(payload)
            when {
                response.isSuccessful -> {
                    if (BuildConfig.DEBUG) Log.d(TAG, "Retry ping succeeded (attempt $runAttemptCount)")
                    Result.success()
                }
                response.code() >= 500 -> {
                    if (BuildConfig.DEBUG) Log.d(TAG, "Server error ${response.code()}, scheduling retry")
                    Result.retry()
                }
                else -> {
                    if (BuildConfig.DEBUG) Log.w(TAG, "Ping rejected with ${response.code()}, not retrying")
                    Result.failure()
                }
            }
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Retry ping failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "PingRetryWorker"
        const val KEY_PAYLOAD = "payload_json"
        const val MAX_RETRIES = 3
    }
}
