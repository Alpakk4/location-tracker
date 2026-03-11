package com.pinglo.tracker.ui.tracker

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.os.Build
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pinglo.tracker.config.ConfigurationKeys
import com.pinglo.tracker.config.Environment
import com.pinglo.tracker.service.LocationService
import com.pinglo.tracker.service.NetworkingService
import com.pinglo.tracker.service.SecureStore
import com.pinglo.tracker.service.SecureStoreKey
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class TrackerViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val secureStore: SecureStore,
    private val networkingService: NetworkingService,
    private val prefs: SharedPreferences,
) : ViewModel() {

    val lastLocation: StateFlow<Location?> = LocationService.lastLocation
    val currentMotion: StateFlow<String> = LocationService.currentMotion
    val currentConfidence: StateFlow<String> = LocationService.currentConfidence

    private val _enableReporting = MutableStateFlow(false)
    val enableReporting = _enableReporting.asStateFlow()

    private val _isPaused = MutableStateFlow(false)
    val isPaused = _isPaused.asStateFlow()

    private val _pauseEndTimeMs = MutableStateFlow<Long?>(null)
    val pauseEndTimeMs = _pauseEndTimeMs.asStateFlow()

    private val _uid = MutableStateFlow("")
    val uid = _uid.asStateFlow()

    private val _isUidLocked = MutableStateFlow(false)
    val isUidLocked = _isUidLocked.asStateFlow()

    private val _homeLat = MutableStateFlow<Double?>(null)
    val homeLat = _homeLat.asStateFlow()

    private val _homeLong = MutableStateFlow<Double?>(null)
    val homeLong = _homeLong.asStateFlow()

    private val _isHomeSet = MutableStateFlow(false)
    val isHomeSet = _isHomeSet.asStateFlow()

    private val _isBackfilling = MutableStateFlow(false)
    val isBackfilling = _isBackfilling.asStateFlow()

    private val _backfillMessage = MutableStateFlow<String?>(null)
    val backfillMessage = _backfillMessage.asStateFlow()

    private var pauseJob: Job? = null

    init {
        loadState()
        restorePauseIfNeeded()
        if (_enableReporting.value && !_isPaused.value) {
            startLocationService()
        }
    }

    private fun loadState() {
        val legacyUid = prefs.getString(ConfigurationKeys.LEGACY_UID, null)
        val storedUid = prefs.getString(ConfigurationKeys.UID, null)

        if (storedUid == null && legacyUid != null) {
            prefs.edit()
                .putString(ConfigurationKeys.UID, legacyUid)
                .remove(ConfigurationKeys.LEGACY_UID)
                .apply()
        }

        val resolvedUid = storedUid ?: legacyUid ?: ""
        _uid.value = resolvedUid
        _isUidLocked.value = resolvedUid.isNotEmpty()
        networkingService.uid = resolvedUid.ifEmpty { null }

        _enableReporting.value = if (!prefs.contains(ConfigurationKeys.ENABLE_REPORTING)) {
            false
        } else {
            prefs.getBoolean(ConfigurationKeys.ENABLE_REPORTING, false)
        }

        _homeLat.value = secureStore.getDouble(SecureStoreKey.HOME_LATITUDE)
        _homeLong.value = secureStore.getDouble(SecureStoreKey.HOME_LONGITUDE)
        _isHomeSet.value = prefs.getBoolean(ConfigurationKeys.IS_HOME_SET, false)
    }

    /**
     * @return false if device ID is required but not set.
     */
    fun setReporting(enabled: Boolean): Boolean {
        if (enabled) {
            if (_uid.value.trim().isEmpty()) return false
            if (_isPaused.value) {
                cancelPause()
            } else {
                _enableReporting.value = true
                prefs.edit().putBoolean(ConfigurationKeys.ENABLE_REPORTING, true).apply()
                startLocationService()
            }
        } else {
            _enableReporting.value = false
            prefs.edit().putBoolean(ConfigurationKeys.ENABLE_REPORTING, false).apply()
            startPauseTimer()
        }
        return true
    }

    fun cancelPause() {
        pauseJob?.cancel()
        pauseJob = null
        _isPaused.value = false
        _pauseEndTimeMs.value = null
        prefs.edit().remove(ConfigurationKeys.PAUSE_END_TIME).apply()
        _enableReporting.value = true
        prefs.edit().putBoolean(ConfigurationKeys.ENABLE_REPORTING, true).apply()
        startLocationService()
    }

    fun updateUid(value: String) {
        _uid.value = value
        networkingService.uid = value.ifEmpty { null }
        prefs.edit().putString(ConfigurationKeys.UID, value).apply()
    }

    fun lockUid() {
        if (_uid.value.isNotEmpty()) {
            _isUidLocked.value = true
        }
    }

    fun unlockUid(password: String): Boolean {
        if (password == Environment.adminPassword) {
            _isUidLocked.value = false
            return true
        }
        return false
    }

    fun setHome() {
        val location = lastLocation.value ?: return
        val lat = location.latitude
        val lng = location.longitude

        _homeLat.value = lat
        _homeLong.value = lng
        _isHomeSet.value = true
        _isBackfilling.value = true

        secureStore.setDouble(lat, SecureStoreKey.HOME_LATITUDE)
        secureStore.setDouble(lng, SecureStoreKey.HOME_LONGITUDE)
        prefs.edit().putBoolean(ConfigurationKeys.IS_HOME_SET, true).apply()

        viewModelScope.launch {
            val result = networkingService.callBackfillReframeHome(lat, lng)
            _isBackfilling.value = false
            _backfillMessage.value = result.fold(
                onSuccess = { count -> "Updated $count historical records with new home." },
                onFailure = { error -> "Backfill failed: ${error.message}" },
            )
        }
    }

    fun unlockHome(password: String): Boolean {
        if (password == Environment.adminPassword) {
            _isHomeSet.value = false
            _homeLat.value = null
            _homeLong.value = null
            secureStore.remove(SecureStoreKey.HOME_LATITUDE)
            secureStore.remove(SecureStoreKey.HOME_LONGITUDE)
            prefs.edit().putBoolean(ConfigurationKeys.IS_HOME_SET, false).apply()
            return true
        }
        return false
    }

    fun dismissBackfillMessage() {
        _backfillMessage.value = null
    }

    fun sendDebugPing() {
        val location = lastLocation.value ?: return
        networkingService.sendLocation(
            location.latitude, location.longitude, location.accuracy.toDouble(),
            currentMotion.value, currentConfidence.value,
            force = true,
        )
    }

    private fun startPauseTimer() {
        pauseJob?.cancel()
        val endTimeMs = System.currentTimeMillis() + PAUSE_DURATION_MS
        _pauseEndTimeMs.value = endTimeMs
        _isPaused.value = true
        prefs.edit().putLong(ConfigurationKeys.PAUSE_END_TIME, endTimeMs).apply()
        stopLocationService()

        pauseJob = viewModelScope.launch {
            delay(PAUSE_DURATION_MS)
            cancelPause()
        }
    }

    private fun restorePauseIfNeeded() {
        val storedEndTime = prefs.getLong(ConfigurationKeys.PAUSE_END_TIME, 0L)
        if (storedEndTime == 0L) return

        val now = System.currentTimeMillis()
        if (storedEndTime > now) {
            _pauseEndTimeMs.value = storedEndTime
            _isPaused.value = true
            _enableReporting.value = false

            val remaining = storedEndTime - now
            pauseJob = viewModelScope.launch {
                delay(remaining)
                cancelPause()
            }
        } else {
            prefs.edit().remove(ConfigurationKeys.PAUSE_END_TIME).apply()
            _isPaused.value = false
            _pauseEndTimeMs.value = null
            _enableReporting.value = true
            prefs.edit().putBoolean(ConfigurationKeys.ENABLE_REPORTING, true).apply()
        }
    }

    private fun startLocationService() {
        val intent = Intent(context, LocationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopLocationService() {
        val intent = Intent(context, LocationService::class.java).apply {
            action = LocationService.ACTION_STOP
        }
        context.startService(intent)
    }

    override fun onCleared() {
        super.onCleared()
        pauseJob?.cancel()
    }

    companion object {
        private const val PAUSE_DURATION_MS = 25L * 60 * 1000
    }
}
