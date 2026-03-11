package com.pinglo.tracker.model

import com.squareup.moshi.JsonClass

/**
 * Motion snapshot attached to pings and diary entries.
 * Serialized as `{ "motion": "WALKING", "confidence": "high" }`.
 */
@JsonClass(generateAdapter = true)
data class MotionType(
    val motion: String,
    val confidence: String
)

/**
 * Type-safe representation of the motion strings produced by
 * Activity Recognition and consumed by throttling / heartbeat logic.
 */
enum class Motion(val value: String) {
    WALKING("WALKING"),
    RUNNING("RUNNING"),
    CYCLING("CYCLING"),
    AUTOMOTIVE("AUTOMOTIVE"),
    STILL("STILL"),
    UNKNOWN("UNKNOWN");

    companion object {
        fun fromString(value: String): Motion =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: UNKNOWN
    }
}
