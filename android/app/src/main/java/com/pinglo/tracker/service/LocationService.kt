package com.pinglo.tracker.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.pinglo.tracker.BuildConfig
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject

@AndroidEntryPoint
class LocationService : Service() {

    @Inject lateinit var networkingService: NetworkingService

    companion object {
        private const val TAG = "LocationService"

        const val ACTION_START = "com.pinglo.tracker.action.START"
        const val ACTION_STOP = "com.pinglo.tracker.action.STOP"
        private const val ACTION_ACTIVITY = "com.pinglo.tracker.action.ACTIVITY"
        private const val ACTION_GEOFENCE = "com.pinglo.tracker.action.GEOFENCE"

        private const val NOTIFICATION_CHANNEL_ID = "location_tracking"
        private const val NOTIFICATION_ID = 1
        private const val REQUEST_CODE_ACTIVITY = 100
        private const val REQUEST_CODE_GEOFENCE = 101
        private const val GEOFENCE_ID = "current-visit"
        private const val GEOFENCE_RADIUS_M = 75f

        private val _currentMotion = MutableStateFlow("STILL")
        val currentMotion = _currentMotion.asStateFlow()

        private val _currentConfidence = MutableStateFlow("unknown")
        val currentConfidence = _currentConfidence.asStateFlow()

        private val _lastLocation = MutableStateFlow<Location?>(null)
        val lastLocation = _lastLocation.asStateFlow()

        private val _isRunning = MutableStateFlow(false)
        val isRunning = _isRunning.asStateFlow()

        private val pingDistanceThresholds = mapOf(
            "STILL" to 50f, "WALKING" to 20f, "RUNNING" to 20f,
            "CYCLING" to 30f, "AUTOMOTIVE" to 100f, "UNKNOWN" to 30f,
        )
    }

    // -- Clients -------------------------------------------------------------------

    private val fusedLocationClient by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val geofencingClient by lazy { LocationServices.getGeofencingClient(this) }
    private lateinit var locationCallback: LocationCallback
    private var activityPendingIntent: PendingIntent? = null
    private var geofencePendingIntent: PendingIntent? = null

    // -- Timers --------------------------------------------------------------------

    private val handler = Handler(Looper.getMainLooper())
    private var stabilityRunnable: Runnable? = null
    private var decayRunnable: Runnable? = null
    private var heartbeatRunnable: Runnable? = null

    // -- Motion debouncer ----------------------------------------------------------

    private data class MotionSample(
        val motion: String,
        val confidenceValue: Double,
        val timestamp: Long,
    )

    private val motionWindow = mutableListOf<MotionSample>()
    private val windowDuration = 40_000L
    private val smoothedScores = mutableMapOf<String, Double>("STILL" to 1.0)
    private val smoothingAlpha = 0.3
    private val hysteresisThreshold = 0.15

    private var stabilityCandidate: String? = null
    private var stabilityCandidateStart = 0L
    private val stabilityDuration = 5_000L
    private val decayTimeout = 75_000L

    // -- Tracking state ------------------------------------------------------------

    private var wasStationary = false
    private var lastPingLocation: Location? = null
    private val maxHorizontalAccuracy = 50f
    private var hasActiveGeofence = false
    private var isTracking = false

    // ===========================================================================
    // Lifecycle
    // ===========================================================================

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        buildLocationCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTracking()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_ACTIVITY -> {
                if (ActivityRecognitionResult.hasResult(intent)) {
                    ActivityRecognitionResult.extractResult(intent)?.let { onActivityResult(it) }
                }
            }
            ACTION_GEOFENCE -> {
                GeofencingEvent.fromIntent(intent)?.let { onGeofenceEvent(it) }
            }
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID, buildNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, buildNotification())
                }
                if (!isTracking) startTracking()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ===========================================================================
    // Start / Stop
    // ===========================================================================

    @SuppressLint("MissingPermission")
    private fun startTracking() {
        isTracking = true
        _isRunning.value = true

        fusedLocationClient.requestLocationUpdates(
            buildLocationRequest("STILL"), locationCallback, Looper.getMainLooper(),
        )

        val arIntent = Intent(this, LocationService::class.java).apply { action = ACTION_ACTIVITY }
        activityPendingIntent = PendingIntent.getForegroundService(
            this, REQUEST_CODE_ACTIVITY, arIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        ActivityRecognition.getClient(this)
            .requestActivityUpdates(5_000, activityPendingIntent!!)

        startHeartbeat("STILL")
        resetDecayTimer()

        if (BuildConfig.DEBUG) Log.d(TAG, "Tracking started")
    }

    private fun stopTracking() {
        if (!isTracking) return
        isTracking = false
        _isRunning.value = false

        fusedLocationClient.removeLocationUpdates(locationCallback)
        activityPendingIntent?.let {
            ActivityRecognition.getClient(this).removeActivityUpdates(it)
        }
        tearDownGeofence()

        handler.removeCallbacksAndMessages(null)
        stabilityRunnable = null
        decayRunnable = null
        heartbeatRunnable = null

        if (BuildConfig.DEBUG) Log.d(TAG, "Tracking stopped")
    }

    // ===========================================================================
    // Location
    // ===========================================================================

    private fun buildLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                _lastLocation.value = loc

                if (loc.accuracy < 0 || loc.accuracy > maxHorizontalAccuracy) return

                val threshold = pingDistanceThresholds[_currentMotion.value] ?: 30f
                val prev = lastPingLocation
                if (prev != null && loc.distanceTo(prev) < threshold) return

                lastPingLocation = loc
                networkingService.sendLocation(
                    loc.latitude, loc.longitude, loc.accuracy.toDouble(),
                    _currentMotion.value, _currentConfidence.value,
                )
            }
        }
    }

    private fun buildLocationRequest(motion: String): LocationRequest {
        val minDistance = when (motion) {
            "STILL" -> 20f
            "WALKING", "RUNNING" -> 10f
            "CYCLING" -> 15f
            "AUTOMOTIVE" -> 50f
            else -> 15f
        }
        return LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000)
            .setMinUpdateDistanceMeters(minDistance)
            .build()
    }

    @SuppressLint("MissingPermission")
    private fun updateLocationRequest(motion: String) {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        fusedLocationClient.requestLocationUpdates(
            buildLocationRequest(motion), locationCallback, Looper.getMainLooper(),
        )
    }

    // ===========================================================================
    // Activity Recognition
    // ===========================================================================

    private fun onActivityResult(result: ActivityRecognitionResult) {
        val detected = result.mostProbableActivity
        val rawMotion = mapActivityType(detected.type)
        val confidence = detected.confidence

        val isNowStationary = rawMotion == "STILL"
        if (isNowStationary && !wasStationary) {
            _lastLocation.value?.let { registerVisitGeofence(it) }
        } else if (!isNowStationary && wasStationary) {
            tearDownGeofence()
        }
        wasStationary = isNowStationary

        processMotionSample(rawMotion, confidence)
    }

    private fun mapActivityType(type: Int): String = when (type) {
        DetectedActivity.WALKING -> "WALKING"
        DetectedActivity.RUNNING -> "RUNNING"
        DetectedActivity.ON_BICYCLE -> "CYCLING"
        DetectedActivity.IN_VEHICLE -> "AUTOMOTIVE"
        DetectedActivity.STILL -> "STILL"
        else -> "UNKNOWN"
    }

    // ===========================================================================
    // Motion debouncer
    // ===========================================================================

    private fun processMotionSample(motion: String, confidencePercent: Int) {
        val now = System.currentTimeMillis()
        val confValue = when {
            confidencePercent >= 67 -> 1.0
            confidencePercent >= 34 -> 0.67
            else -> 0.33
        }

        motionWindow += MotionSample(motion, confValue, now)
        motionWindow.removeAll { now - it.timestamp > windowDuration }

        // Confidence-weighted window scores
        val windowScores = mutableMapOf<String, Double>()
        var totalWeight = 0.0
        for (s in motionWindow) {
            windowScores[s.motion] = (windowScores[s.motion] ?: 0.0) + s.confidenceValue
            totalWeight += s.confidenceValue
        }
        if (totalWeight > 0) {
            for (key in windowScores.keys) windowScores[key] = windowScores[key]!! / totalWeight
        }

        // Exponential smoothing
        val allMotions = windowScores.keys + smoothedScores.keys
        for (m in allMotions) {
            val windowVal = windowScores[m] ?: 0.0
            val prev = smoothedScores[m] ?: 0.0
            smoothedScores[m] = smoothingAlpha * windowVal + (1 - smoothingAlpha) * prev
        }
        smoothedScores.entries.removeAll { it.value <= 0.01 }

        val topEntry = smoothedScores.maxByOrNull { it.value } ?: return
        val currentMotionStr = _currentMotion.value

        if (topEntry.key != currentMotionStr) {
            val currentScore = smoothedScores[currentMotionStr] ?: 0.0
            if (topEntry.value - currentScore < hysteresisThreshold) {
                resetStabilityCandidate()
                resetDecayTimer()
                return
            }

            if (stabilityCandidate == topEntry.key) {
                if (now - stabilityCandidateStart >= stabilityDuration) {
                    commitMotion(topEntry.key)
                }
            } else {
                stabilityCandidate = topEntry.key
                stabilityCandidateStart = now
                startStabilityCheckTimer()
            }
        } else {
            resetStabilityCandidate()
        }

        resetDecayTimer()
    }

    private fun commitMotion(motion: String) {
        resetStabilityCandidate()
        val score = smoothedScores[motion] ?: 0.0
        val confidence = when {
            score > 0.6 -> "high"
            score > 0.3 -> "medium"
            else -> "low"
        }

        val previousMotion = _currentMotion.value
        _currentMotion.value = motion
        _currentConfidence.value = confidence

        updateLocationRequest(motion)

        _lastLocation.value?.let { loc ->
            lastPingLocation = loc
            networkingService.sendLocation(
                loc.latitude, loc.longitude, loc.accuracy.toDouble(),
                motion, confidence, force = true,
            )
        }

        if (motion != previousMotion) startHeartbeat(motion)

        if (BuildConfig.DEBUG) Log.d(TAG, "Motion committed: $motion ($confidence)")
    }

    private fun startStabilityCheckTimer() {
        stabilityRunnable?.let { handler.removeCallbacks(it) }
        val runnable = Runnable {
            val candidate = stabilityCandidate ?: return@Runnable
            val top = smoothedScores.maxByOrNull { it.value } ?: run {
                resetStabilityCandidate(); return@Runnable
            }
            if (top.key != candidate) {
                resetStabilityCandidate(); return@Runnable
            }
            val currentScore = smoothedScores[_currentMotion.value] ?: 0.0
            if (top.value - currentScore >= hysteresisThreshold) {
                commitMotion(candidate)
            } else {
                resetStabilityCandidate()
            }
        }
        stabilityRunnable = runnable
        handler.postDelayed(runnable, stabilityDuration)
    }

    private fun resetStabilityCandidate() {
        stabilityCandidate = null
        stabilityCandidateStart = 0
        stabilityRunnable?.let { handler.removeCallbacks(it) }
        stabilityRunnable = null
    }

    private fun resetDecayTimer() {
        decayRunnable?.let { handler.removeCallbacks(it) }
        val runnable = Runnable {
            if (_currentMotion.value == "STILL") return@Runnable
            if (BuildConfig.DEBUG) Log.d(TAG, "Motion decay: no samples for ${decayTimeout / 1000}s -> STILL")
            smoothedScores.clear()
            smoothedScores["STILL"] = 1.0
            motionWindow.clear()
            commitMotion("STILL")
        }
        decayRunnable = runnable
        handler.postDelayed(runnable, decayTimeout)
    }

    // ===========================================================================
    // Heartbeat
    // ===========================================================================

    private fun startHeartbeat(motion: String) {
        stopHeartbeat()
        val intervalMs = NetworkingService.throttleIntervalMs(motion)
        val runnable = object : Runnable {
            override fun run() {
                val loc = _lastLocation.value ?: return
                lastPingLocation = loc
                networkingService.sendLocation(
                    loc.latitude, loc.longitude, loc.accuracy.toDouble(),
                    _currentMotion.value, _currentConfidence.value, force = false,
                )
                handler.postDelayed(this, intervalMs)
            }
        }
        heartbeatRunnable = runnable
        handler.postDelayed(runnable, intervalMs)
    }

    private fun stopHeartbeat() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        heartbeatRunnable = null
    }

    // ===========================================================================
    // Geofencing (visit boundary detection)
    // ===========================================================================

    @SuppressLint("MissingPermission")
    private fun registerVisitGeofence(location: Location) {
        tearDownGeofence()

        val geofence = Geofence.Builder()
            .setRequestId(GEOFENCE_ID)
            .setCircularRegion(location.latitude, location.longitude, GEOFENCE_RADIUS_M)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_EXIT)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0)
            .addGeofence(geofence)
            .build()

        val pi = getOrCreateGeofencePendingIntent()
        geofencingClient.addGeofences(request, pi)
            .addOnSuccessListener {
                hasActiveGeofence = true
                if (BuildConfig.DEBUG) {
                    Log.d(TAG, "Geofence at ${location.latitude},${location.longitude} r=${GEOFENCE_RADIUS_M}m")
                }
            }
            .addOnFailureListener { e ->
                if (BuildConfig.DEBUG) Log.w(TAG, "Geofence registration failed: ${e.message}")
            }
    }

    private fun tearDownGeofence() {
        if (!hasActiveGeofence) return
        geofencingClient.removeGeofences(listOf(GEOFENCE_ID))
        hasActiveGeofence = false
        if (BuildConfig.DEBUG) Log.d(TAG, "Geofence removed")
    }

    private fun onGeofenceEvent(event: GeofencingEvent) {
        if (event.hasError()) {
            if (BuildConfig.DEBUG) Log.w(TAG, "Geofence error: ${event.errorCode}")
            return
        }
        if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT) {
            tearDownGeofence()
            val loc = event.triggeringLocation ?: _lastLocation.value ?: return
            if (BuildConfig.DEBUG) Log.d(TAG, "Geofence exit — forced boundary ping")
            lastPingLocation = loc
            networkingService.sendLocation(
                loc.latitude, loc.longitude, loc.accuracy.toDouble(),
                _currentMotion.value, _currentConfidence.value, force = true,
            )
        }
    }

    private fun getOrCreateGeofencePendingIntent(): PendingIntent {
        geofencePendingIntent?.let { return it }
        val intent = Intent(this, LocationService::class.java).apply { action = ACTION_GEOFENCE }
        return PendingIntent.getForegroundService(
            this, REQUEST_CODE_GEOFENCE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        ).also { geofencePendingIntent = it }
    }

    // ===========================================================================
    // Notification
    // ===========================================================================

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Location Tracking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows when pingLo is tracking your location"
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("pingLo")
            .setContentText("Location tracking active")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()
}
