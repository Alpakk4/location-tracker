package com.pinglo.tracker.service

import android.content.SharedPreferences
import android.util.Log
import com.pinglo.tracker.BuildConfig
import com.pinglo.tracker.model.DiaryDay
import com.pinglo.tracker.model.DiaryEntry
import com.pinglo.tracker.model.DiaryJourney
import com.pinglo.tracker.model.DiaryMakerResponse
import com.pinglo.tracker.model.DiarySubmitEntry
import com.pinglo.tracker.model.DiarySubmitJourney
import com.pinglo.tracker.model.DiarySubmitPayload
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DiaryService @Inject constructor(
    private val api: SupabaseApi,
    private val storage: DiaryStorage,
    private val moshi: Moshi,
    private val prefs: SharedPreferences,
) {

    private val _diaryDays = MutableStateFlow<List<DiaryDay>>(emptyList())
    val diaryDays: StateFlow<List<DiaryDay>> = _diaryDays.asStateFlow()

    private val _selectedDiaryDay = MutableStateFlow<DiaryDay?>(null)
    val selectedDiaryDay: StateFlow<DiaryDay?> = _selectedDiaryDay.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    @Volatile
    private var latestLoadRequestId: UUID = UUID.randomUUID()

    init {
        loadLocalDiaries()
    }

    fun clearError() {
        _errorMessage.value = null
    }

    // -- Local data ----------------------------------------------------------------

    fun loadLocalDiaries() {
        _diaryDays.value = storage.loadAllDiaryDays()
    }

    fun saveDiaryDay(day: DiaryDay) {
        if (!storage.saveDiaryDay(day)) {
            _errorMessage.value = "Could not save diary progress. Please try again."
            return
        }
        loadLocalDiaries()
    }

    // -- Submission tracking -------------------------------------------------------

    fun recordSubmission(date: String) {
        val dates = submittedDates().toMutableSet()
        dates += date
        prefs.edit().putStringSet(SUBMITTED_KEY, dates).apply()
    }

    fun submittedDates(): Set<String> =
        prefs.getStringSet(SUBMITTED_KEY, emptySet()) ?: emptySet()

    fun hasBeenSubmitted(date: String): Boolean = date in submittedDates()

    // -- Local-first loading -------------------------------------------------------

    suspend fun loadOrFetchDiary(deviceId: String, date: String) {
        val requestId = UUID.randomUUID()
        latestLoadRequestId = requestId

        if (!isValidDate(date)) {
            _selectedDiaryDay.value = null
            _errorMessage.value = "Invalid date format."
            return
        }

        if (hasBeenSubmitted(date)) {
            _selectedDiaryDay.value = null
            return
        }

        storage.loadDiaryDay(date)?.takeIf { it.deviceId == deviceId }?.let {
            _selectedDiaryDay.value = it
            return
        }

        fetchDiary(deviceId, date, requestId)
        if (isStale(requestId)) return

        storage.loadDiaryDay(date)?.let { _selectedDiaryDay.value = it }
    }

    // -- Fetch from diary-maker ----------------------------------------------------

    suspend fun fetchDiary(deviceId: String, date: String, requestId: UUID? = null) {
        if (!isValidDate(date)) {
            _errorMessage.value = "Invalid date format."
            return
        }

        _isLoading.value = true
        _errorMessage.value = null

        val body = mapOf("deviceId" to deviceId, "date" to date)

        try {
            val response = executeWithRetry { api.fetchDiary(body) }
            if (isStale(requestId)) { _isLoading.value = false; return }

            if (!response.isSuccessful) {
                _isLoading.value = false
                debugLog("Fetch failed: ${response.code()}")
                _errorMessage.value = "Unable to fetch diary right now. Please try again."
                return
            }

            val responseJson = response.body()?.string() ?: run {
                _isLoading.value = false
                _errorMessage.value = "Empty response from server."
                return
            }

            // Handle backend idempotency: mark as submitted and stop
            if (responseJson.contains("\"already_submitted\"")) {
                try {
                    val mapType = Types.newParameterizedType(
                        Map::class.java, String::class.java, Any::class.java,
                    )
                    val map = moshi.adapter<Map<String, Any>>(mapType).fromJson(responseJson)
                    if (map?.get("already_submitted") == true) {
                        recordSubmission(date)
                        _isLoading.value = false
                        _selectedDiaryDay.value = null
                        return
                    }
                } catch (_: Exception) { /* fall through to normal parse */ }
            }

            val makerResponse = moshi.adapter(DiaryMakerResponse::class.java)
                .fromJson(responseJson) ?: run {
                _isLoading.value = false
                _errorMessage.value = "Invalid diary response."
                return
            }

            // DTO -> local model mapping
            val entries = makerResponse.visits.map { raw ->
                DiaryEntry(
                    id = raw.entryid,
                    entryIds = raw.entryIds,
                    createdAt = raw.createdAt,
                    endedAt = raw.endedAt,
                    clusterDurationSeconds = raw.clusterDurationS,
                    primaryType = raw.primaryType,
                    placeCategory = raw.placeCategory,
                    otherTypes = raw.otherTypes,
                    motionType = raw.motionType,
                    visitConfidence = raw.visitConfidence,
                    visitType = raw.visitType,
                    pingCount = raw.pingCount,
                    activityLabel = raw.activityLabel,
                )
            }

            val journeys = makerResponse.journeys.map { raw ->
                DiaryJourney(
                    id = raw.journeyId,
                    entryIds = raw.entryIds,
                    fromVisitId = raw.fromVisitId,
                    toVisitId = raw.toVisitId,
                    primaryTransport = raw.primaryTransport,
                    transportProportions = raw.transportProportions,
                    startedAt = raw.startedAt,
                    endedAt = raw.endedAt,
                    journeyDurationSeconds = raw.journeyDurationS,
                    pingCount = raw.pingCount,
                    journeyConfidence = raw.journeyConfidence,
                )
            }

            val dayId = "${deviceId}_$date"

            // Empty days are not persisted; keep a transient selection only
            if (entries.isEmpty() && journeys.isEmpty()) {
                _selectedDiaryDay.value = DiaryDay(dayId, deviceId, date, emptyList(), emptyList())
                loadLocalDiaries()
                _isLoading.value = false
                return
            }

            // Merge: keep prior user answers for entries/journeys with stable IDs
            val existing = storage.loadDiaryDay(date)?.takeIf { it.deviceId == deviceId }
            if (existing != null) {
                val entryMap = existing.entries.associateBy { it.id }
                val mergedEntries = entries.map { entryMap[it.id] ?: it }
                val journeyMap = existing.journeys.associateBy { it.id }
                val mergedJourneys = journeys.map { journeyMap[it.id] ?: it }
                val merged = existing.copy(entries = mergedEntries, journeys = mergedJourneys)
                if (!storage.saveDiaryDay(merged)) {
                    _isLoading.value = false
                    _errorMessage.value = "Could not save refreshed diary. Please try again."
                    return
                }
            } else {
                val newDay = DiaryDay(dayId, deviceId, date, entries, journeys)
                if (!storage.saveDiaryDay(newDay)) {
                    _isLoading.value = false
                    _errorMessage.value = "Could not save fetched diary. Please try again."
                    return
                }
            }

            loadLocalDiaries()
            _selectedDiaryDay.value = storage.loadDiaryDay(date)
            _isLoading.value = false

        } catch (e: Exception) {
            _isLoading.value = false
            debugLog("Fetch network error: ${e.message}")
            _errorMessage.value = "Unable to fetch diary right now. Please try again."
        }
    }

    // -- Submit completed diary ----------------------------------------------------

    suspend fun submitCompletedDiary(diaryDay: DiaryDay): Boolean {
        if (!isValidDate(diaryDay.date)) {
            _errorMessage.value = "Invalid diary date."
            return false
        }
        if (hasBeenSubmitted(diaryDay.date)) {
            _errorMessage.value = "Diary already submitted"
            return false
        }
        if (!diaryDay.isCompleted) {
            _errorMessage.value = "Diary is not fully completed"
            return false
        }

        _isLoading.value = true
        _errorMessage.value = null

        val payload = DiarySubmitPayload(
            deviceId = diaryDay.deviceId,
            date = diaryDay.date,
            entries = diaryDay.entries.map { e ->
                DiarySubmitEntry(
                    sourceEntryId = e.id,
                    placeCategory = e.placeCategory,
                    activityLabel = e.activityLabel,
                    confirmedCategory = e.confirmedCategory ?: false,
                    confirmedPlace = e.confirmedPlace ?: false,
                    confirmedActivity = e.confirmedActivity ?: false,
                    userContext = e.userContext,
                )
            },
            journeys = diaryDay.journeys.map { j ->
                DiarySubmitJourney(
                    sourceJourneyId = j.id,
                    confirmedTransport = j.confirmedTransport ?: false,
                    travelReason = j.travelReason,
                )
            },
        )

        return try {
            val response = executeWithRetry { api.submitDiary(payload) }

            if (response.isSuccessful) {
                recordSubmission(diaryDay.date)
                if (!storage.deleteDiaryDay(diaryDay.date)) {
                    _isLoading.value = false
                    _errorMessage.value = "Submitted but failed to clear local cache."
                    return false
                }
                loadLocalDiaries()
                _selectedDiaryDay.value = null
                _isLoading.value = false
                true
            } else {
                debugLog("Submit failed: ${response.code()}")
                _isLoading.value = false
                _errorMessage.value = "Submission failed. Please try again."
                false
            }
        } catch (e: Exception) {
            debugLog("Submit error: ${e.message}")
            _isLoading.value = false
            _errorMessage.value = "Submission failed. Please try again."
            false
        }
    }

    // -- Helpers -------------------------------------------------------------------

    private fun isStale(requestId: UUID?): Boolean =
        requestId != null && requestId != latestLoadRequestId

    private fun isValidDate(raw: String): Boolean =
        try {
            val parsed = LocalDate.parse(raw, DateTimeFormatter.ISO_LOCAL_DATE)
            raw == parsed.toString()
        } catch (_: DateTimeParseException) {
            false
        }

    private suspend fun <T> executeWithRetry(
        maxAttempts: Int = 3,
        baseDelayMs: Long = 400,
        operation: suspend () -> T,
    ): T {
        var currentDelay = baseDelayMs
        var attempt = 1
        while (true) {
            try {
                return operation()
            } catch (e: Exception) {
                if (attempt >= maxAttempts) throw e
                delay(currentDelay)
                currentDelay *= 2
                attempt++
            }
        }
    }

    private fun debugLog(msg: String) {
        if (BuildConfig.DEBUG) Log.d(TAG, msg)
    }

    companion object {
        private const val TAG = "DiaryService"
        private const val SUBMITTED_KEY = "diary_submitted_dates"
    }
}
