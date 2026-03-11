package com.pinglo.tracker.model

import com.squareup.moshi.Json
import com.squareup.moshi.JsonClass

// ---------------------------------------------------------------------------
// Supabase diary-maker response (transport-only; mapped to local models)
// ---------------------------------------------------------------------------

/** Top-level response from the `diary-maker` edge function. */
@JsonClass(generateAdapter = true)
data class DiaryMakerResponse(
    val visits: List<DiaryMakerEntry>,
    val journeys: List<DiaryMakerJourney>
)

/** Raw visit cluster returned by `diary-maker`. Snake_case matches the API contract. */
@JsonClass(generateAdapter = true)
data class DiaryMakerEntry(
    val entryid: String,
    @Json(name = "entry_ids") val entryIds: List<String>,
    @Json(name = "created_at") val createdAt: String,
    @Json(name = "ended_at") val endedAt: String,
    @Json(name = "cluster_duration_s") val clusterDurationS: Int,
    @Json(name = "primary_type") val primaryType: String,
    @Json(name = "place_category") val placeCategory: String,
    @Json(name = "activity_label") val activityLabel: String,
    @Json(name = "other_types") val otherTypes: List<String>,
    @Json(name = "motion_type") val motionType: MotionType,
    @Json(name = "visit_confidence") val visitConfidence: String,
    @Json(name = "visit_type") val visitType: String?,
    @Json(name = "ping_count") val pingCount: Int
)

/** Raw journey segment returned by `diary-maker`. */
@JsonClass(generateAdapter = true)
data class DiaryMakerJourney(
    @Json(name = "journey_id") val journeyId: String,
    @Json(name = "entry_ids") val entryIds: List<String>,
    @Json(name = "from_visit_id") val fromVisitId: String?,
    @Json(name = "to_visit_id") val toVisitId: String?,
    @Json(name = "primary_transport") val primaryTransport: String,
    @Json(name = "transport_proportions") val transportProportions: Map<String, Double>,
    @Json(name = "started_at") val startedAt: String,
    @Json(name = "ended_at") val endedAt: String,
    @Json(name = "journey_duration_s") val journeyDurationS: Int,
    @Json(name = "ping_count") val pingCount: Int,
    @Json(name = "journey_confidence") val journeyConfidence: String?
)

// ---------------------------------------------------------------------------
// Local diary models (persisted on device, displayed in UI)
// ---------------------------------------------------------------------------

/**
 * Local visit model shown in the diary UI and persisted on device until submission.
 * Generated fields come from the server; answer fields come from user interaction.
 *
 * JSON keys are camelCase (local storage format, not the server API).
 */
@JsonClass(generateAdapter = true)
data class DiaryEntry(
    val id: String,
    val entryIds: List<String>,
    val createdAt: String,
    val endedAt: String,
    val clusterDurationSeconds: Int,
    val primaryType: String,
    val placeCategory: String = "Unknown",
    val otherTypes: List<String>,
    val motionType: MotionType,
    val visitConfidence: String,
    val visitType: String? = null,
    val pingCount: Int,
    var confirmedCategory: Boolean? = null,
    var confirmedPlace: Boolean? = null,
    var confirmedActivity: Boolean? = null,
    var activityLabel: String,
    var userContext: String? = null
) {
    /** All three confirmations answered; context mandatory when any is false. */
    val isCompleted: Boolean
        get() {
            val cc = confirmedCategory ?: return false
            val cp = confirmedPlace ?: return false
            val ca = confirmedActivity ?: return false
            if (!cc || !cp || !ca) {
                return !userContext.isNullOrBlank()
            }
            return true
        }

    /** Human-readable duration, e.g. "12 min", "1h 30min", "< 1 min". */
    val formattedDuration: String
        get() {
            if (clusterDurationSeconds < 60) return "< 1 min"
            val hours = clusterDurationSeconds / 3600
            val minutes = (clusterDurationSeconds % 3600) / 60
            return when {
                hours > 0 && minutes > 0 -> "${hours}h ${minutes}min"
                hours > 0 -> "${hours}h"
                else -> "$minutes min"
            }
        }
}

/**
 * Local journey model shown in the diary UI and persisted until submission.
 * `fromVisitId` / `toVisitId` may reference surrounding [DiaryEntry] ids.
 */
@JsonClass(generateAdapter = true)
data class DiaryJourney(
    val id: String,
    val entryIds: List<String>,
    val fromVisitId: String? = null,
    val toVisitId: String? = null,
    val primaryTransport: String,
    val transportProportions: Map<String, Double>,
    val startedAt: String,
    val endedAt: String,
    val journeyDurationSeconds: Int,
    val pingCount: Int,
    val journeyConfidence: String? = null,
    var confirmedTransport: Boolean? = null,
    var travelReason: String? = null
) {
    /** A journey is complete once transport confirmation is provided. */
    val isCompleted: Boolean
        get() = confirmedTransport != null

    /** Human-readable duration, e.g. "12 min", "1h 30min", "< 1 min". */
    val formattedDuration: String
        get() {
            if (journeyDurationSeconds < 60) return "< 1 min"
            val hours = journeyDurationSeconds / 3600
            val minutes = (journeyDurationSeconds % 3600) / 60
            return when {
                hours > 0 && minutes > 0 -> "${hours}h ${minutes}min"
                hours > 0 -> "${hours}h"
                else -> "$minutes min"
            }
        }

    /** Human-readable transport label. */
    val transportLabel: String
        get() = when (primaryTransport.lowercase()) {
            "walking" -> "Walking"
            "running" -> "Running"
            "cycling" -> "Cycling"
            "automotive" -> "Driving"
            else -> primaryTransport.replaceFirstChar { it.uppercase() }
        }
}

/**
 * Aggregate local state for one calendar day and one device.
 * This is the unit persisted, loaded, and submitted by DiaryService.
 */
@JsonClass(generateAdapter = true)
data class DiaryDay(
    val id: String,
    val deviceId: String,
    val date: String,
    var entries: List<DiaryEntry>,
    var journeys: List<DiaryJourney> = emptyList()
) {
    /** At least one visit must exist to consider a day submit-ready. */
    val isCompleted: Boolean
        get() {
            val entriesDone = entries.isEmpty() || entries.all { it.isCompleted }
            val journeysDone = journeys.isEmpty() || journeys.all { it.isCompleted }
            return entries.isNotEmpty() && entriesDone && journeysDone
        }

    val completedCount: Int
        get() = entries.count { it.isCompleted } + journeys.count { it.isCompleted }

    val totalCount: Int
        get() = entries.size + journeys.size
}

// ---------------------------------------------------------------------------
// Submission payloads (sent to diary-submit edge function)
// ---------------------------------------------------------------------------

/** Wrapper sent to the `diary-submit` edge function. */
@JsonClass(generateAdapter = true)
data class DiarySubmitPayload(
    val deviceId: String,
    val date: String,
    val entries: List<DiarySubmitEntry>,
    val journeys: List<DiarySubmitJourney>
)

/** User-confirmed answers for one visit cluster. Snake_case matches the API contract. */
@JsonClass(generateAdapter = true)
data class DiarySubmitEntry(
    @Json(name = "source_entryid") val sourceEntryId: String,
    @Json(name = "place_category") val placeCategory: String,
    @Json(name = "activity_label") val activityLabel: String,
    @Json(name = "confirmed_category") val confirmedCategory: Boolean,
    @Json(name = "confirmed_place") val confirmedPlace: Boolean,
    @Json(name = "confirmed_activity") val confirmedActivity: Boolean,
    @Json(name = "user_context") val userContext: String?
)

/** User-confirmed answers for one journey segment. Snake_case matches the API contract. */
@JsonClass(generateAdapter = true)
data class DiarySubmitJourney(
    @Json(name = "source_journey_id") val sourceJourneyId: String,
    @Json(name = "confirmed_transport") val confirmedTransport: Boolean,
    @Json(name = "travel_reason") val travelReason: String?
)
