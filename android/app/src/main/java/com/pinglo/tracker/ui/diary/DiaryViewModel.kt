package com.pinglo.tracker.ui.diary

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pinglo.tracker.config.ConfigurationDefaults
import com.pinglo.tracker.config.ConfigurationKeys
import com.pinglo.tracker.model.DiaryDay
import com.pinglo.tracker.service.DiaryService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject

@HiltViewModel
class DiaryViewModel @Inject constructor(
    private val diaryService: DiaryService,
    private val prefs: SharedPreferences,
) : ViewModel() {

    val isLoading: StateFlow<Boolean> = diaryService.isLoading
    val errorMessage: StateFlow<String?> = diaryService.errorMessage

    val inProgressDays: StateFlow<List<DiaryDay>> = diaryService.diaryDays
        .map { days -> days.filter { !diaryService.hasBeenSubmitted(it.date) } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _navigateToDayDate = MutableStateFlow<String?>(null)
    val navigateToDayDate: StateFlow<String?> = _navigateToDayDate.asStateFlow()

    private val _toastMessage = MutableStateFlow<ToastInfo?>(null)
    val toastMessage: StateFlow<ToastInfo?> = _toastMessage.asStateFlow()

    private val deviceId: String
        get() = prefs.getString(ConfigurationKeys.UID, null)
            ?: prefs.getString(ConfigurationKeys.LEGACY_UID, null)
            ?: ConfigurationDefaults.ANONYMOUS_UID

    fun onAppear() {
        diaryService.loadLocalDiaries()
    }

    fun buildDiaryForYesterday() {
        val yesterday = LocalDate.now().minusDays(1)
        buildDiary(yesterday)
    }

    fun buildDiaryForToday() {
        buildDiary(LocalDate.now())
    }

    fun buildDiary(date: LocalDate) {
        val ds = date.format(DateTimeFormatter.ISO_LOCAL_DATE)

        if (diaryService.hasBeenSubmitted(ds)) {
            _toastMessage.value = ToastInfo("Diary for this date has already been submitted", ToastType.INFO)
            return
        }

        viewModelScope.launch {
            diaryService.loadOrFetchDiary(deviceId, ds)

            val selected = diaryService.selectedDiaryDay.value
            if (selected != null && (selected.entries.isNotEmpty() || selected.journeys.isNotEmpty())) {
                _navigateToDayDate.value = ds
            } else {
                _toastMessage.value = ToastInfo("Selected day has no entries, try another", ToastType.WARNING)
            }
        }
    }

    fun onNavigated() {
        _navigateToDayDate.value = null
    }

    fun dismissError() {
        diaryService.clearError()
    }

    fun dismissToast() {
        _toastMessage.value = null
    }

    fun navigateToDay(date: String) {
        viewModelScope.launch {
            diaryService.loadOrFetchDiary(deviceId, date)
            _navigateToDayDate.value = date
        }
    }
}

data class ToastInfo(val message: String, val type: ToastType)

enum class ToastType { WARNING, INFO }
