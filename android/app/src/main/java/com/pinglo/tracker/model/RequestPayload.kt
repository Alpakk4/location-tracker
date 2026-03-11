package com.pinglo.tracker.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

/**
 * Payload sent to the Supabase `ping` edge function.
 * Field names match the server contract (mixed snake_case / camelCase).
 */
@JsonClass(generateAdapter = true)
data class RequestPayload(
    val uid: String,
    val lat: Double,
    val long: Double,
    @Json(name = "home_lat") val homeLat: Double? = null,
    @Json(name = "home_long") val homeLong: Double? = null,
    val motion: MotionType,
    @Json(name = "horizontal_accuracy") val horizontalAccuracy: Double,
    val capturedAt: String? = null
)
