package com.pinglo.tracker.ui.diary

import android.content.SharedPreferences
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pinglo.tracker.config.ConfigurationDefaults
import com.pinglo.tracker.config.ConfigurationKeys
import com.pinglo.tracker.model.DiaryDay
import com.pinglo.tracker.model.DiaryEntry
import com.pinglo.tracker.model.DiaryJourney
import com.pinglo.tracker.service.DiaryService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DiaryDayDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val diaryService: DiaryService,
    private val prefs: SharedPreferences,
) : ViewModel() {

    val date: String = savedStateHandle.get<String>("date") ?: ""

    val isLoading: StateFlow<Boolean> = diaryService.isLoading

    private val _diaryDay = MutableStateFlow<DiaryDay?>(null)
    val diaryDay: StateFlow<DiaryDay?> = _diaryDay.asStateFlow()

    private val _submitSuccess = MutableStateFlow(false)
    val submitSuccess: StateFlow<Boolean> = _submitSuccess.asStateFlow()

    private val _alreadySubmitted = MutableStateFlow(false)
    val alreadySubmitted: StateFlow<Boolean> = _alreadySubmitted.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val deviceId: String
        get() = prefs.getString(ConfigurationKeys.UID, null)
            ?: prefs.getString(ConfigurationKeys.LEGACY_UID, null)
            ?: ConfigurationDefaults.ANONYMOUS_UID

    init {
        loadDay()
    }

    private fun loadDay() {
        val selected = diaryService.selectedDiaryDay.value
        if (selected != null && selected.date == date) {
            _diaryDay.value = selected
        } else {
            viewModelScope.launch {
                diaryService.loadOrFetchDiary(deviceId, date)
                _diaryDay.value = diaryService.selectedDiaryDay.value
            }
        }
    }

    fun updateEntry(index: Int, transform: (DiaryEntry) -> DiaryEntry) {
        val day = _diaryDay.value ?: return
        val updated = day.entries.toMutableList()
        updated[index] = transform(updated[index])
        val newDay = day.copy(entries = updated)
        _diaryDay.value = newDay
        diaryService.saveDiaryDay(newDay)
    }

    fun updateJourney(index: Int, transform: (DiaryJourney) -> DiaryJourney) {
        val day = _diaryDay.value ?: return
        val updated = day.journeys.toMutableList()
        updated[index] = transform(updated[index])
        val newDay = day.copy(journeys = updated)
        _diaryDay.value = newDay
        diaryService.saveDiaryDay(newDay)
    }

    fun refresh() {
        viewModelScope.launch {
            diaryService.fetchDiary(deviceId, date)
            val refreshed = diaryService.selectedDiaryDay.value
            if (refreshed != null && refreshed.date == date) {
                _diaryDay.value = refreshed
            } else if (diaryService.hasBeenSubmitted(date)) {
                _alreadySubmitted.value = true
            }
        }
    }

    fun submit() {
        val day = _diaryDay.value ?: return
        viewModelScope.launch {
            val success = diaryService.submitCompletedDiary(day)
            if (success) {
                _submitSuccess.value = true
            } else {
                _errorMessage.value = diaryService.errorMessage.value ?: "Submission failed."
            }
        }
    }

    fun isSubmitted(): Boolean = diaryService.hasBeenSubmitted(date)

    fun dismissError() {
        _errorMessage.value = null
    }
}
