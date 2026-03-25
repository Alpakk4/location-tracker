package com.pinglo.tracker.config

import com.google.android.gms.location.Priority

/**
 * Single source of truth for all ping, heartbeat, location-update, and retry timing
 * parameters. Both Android and iOS maintain a mirrored version of this file — keep
 * values identical across platforms unless there is a platform-specific reason to diverge.
 *
 * See docs/pinglo-timing-policy.md for the human-readable parity table.
 */
object PingloTimingConfig {

    // ── Ping throttle (minimum interval between non-forced pings per activity) ──

    fun throttleIntervalMs(activity: String): Long = when (activity) {
        "WALKING"    -> 120_000L    // 2 min
        "RUNNING"    -> 120_000L    // 2 min
        "CYCLING"    -> 240_000L    // 4 min
        "AUTOMOTIVE" -> 600_000L    // 10 min
        "STILL"      -> 300_000L    // 5 min
        else         -> 300_000L    // 5 min (UNKNOWN / fallback)
    }

    // ── Heartbeat interval (repeating timer that fires sendLocation with force=false) ──
    // Defined to equal the throttle interval per activity.

    fun heartbeatIntervalMs(activity: String): Long = throttleIntervalMs(activity)

    // ── Ping distance gate (min movement since last ping before a new one is sent) ──

    val pingDistanceThresholds: Map<String, Float> = mapOf(
        "STILL"      to 50f,
        "WALKING"    to 20f,
        "RUNNING"    to 20f,
        "CYCLING"    to 30f,
        "AUTOMOTIVE" to 100f,
        "UNKNOWN"    to 30f,
    )

    // ── Accuracy gate (pings are dropped when horizontal accuracy exceeds this) ──

    const val MAX_HORIZONTAL_ACCURACY_M = 50f

    // ── Geofence (visit boundary detection) ──

    const val GEOFENCE_RADIUS_M = 75f

    // ── Fused Location Request per motion (Android-specific) ──

    data class LocationRequestParams(
        val priority: Int,
        val intervalMs: Long,
        val minDistanceMeters: Float,
    )

    fun locationRequestParams(motion: String): LocationRequestParams = when (motion) {
        "STILL"              -> LocationRequestParams(Priority.PRIORITY_LOW_POWER,     60_000L, 20f)
        "WALKING", "RUNNING" -> LocationRequestParams(Priority.PRIORITY_HIGH_ACCURACY, 10_000L, 10f)
        "CYCLING"            -> LocationRequestParams(Priority.PRIORITY_HIGH_ACCURACY, 10_000L, 15f)
        "AUTOMOTIVE"         -> LocationRequestParams(Priority.PRIORITY_HIGH_ACCURACY, 10_000L, 50f)
        else                 -> LocationRequestParams(Priority.PRIORITY_HIGH_ACCURACY, 10_000L, 15f)
    }

    // ── Activity recognition polling (Android-specific) ──

    const val ACTIVITY_RECOGNITION_INTERVAL_MS = 5_000L

    // ── Retry / backoff (failed or 5xx pings) ──

    const val MAX_PING_RETRIES = 3
    const val RETRY_INITIAL_BACKOFF_MINUTES = 1L  // WorkManager exponential from 1 min

    // ── Motion debouncer ──

    const val MOTION_WINDOW_DURATION_MS      = 40_000L
    const val MOTION_SMOOTHING_ALPHA         = 0.3
    const val MOTION_HYSTERESIS_THRESHOLD    = 0.15
    const val MOTION_STABILITY_DURATION_MS   = 5_000L
    const val MOTION_DECAY_TIMEOUT_MS        = 75_000L

    // ── Pause duration (UI "pause tracking" countdown) ──

    const val PAUSE_DURATION_MS = 25L * 60 * 1000  // 25 minutes
}
