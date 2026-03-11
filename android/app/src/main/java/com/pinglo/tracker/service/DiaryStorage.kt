package com.pinglo.tracker.service

import android.content.Context
import android.util.Log
import com.pinglo.tracker.BuildConfig
import com.pinglo.tracker.model.DiaryDay
import com.squareup.moshi.Moshi
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DiaryStorage @Inject constructor(
    @ApplicationContext private val context: Context,
    moshi: Moshi,
) {
    private val adapter = moshi.adapter(DiaryDay::class.java).indent("  ")

    var lastError: Exception? = null
        private set

    private val diaryDir: File get() = context.filesDir

    private fun fileFor(date: String) = File(diaryDir, "diary_$date.json")

    // -- Save ----------------------------------------------------------------------

    fun saveDiaryDay(day: DiaryDay): Boolean =
        try {
            saveDiaryDayOrThrow(day); true
        } catch (e: Exception) {
            lastError = e
            if (BuildConfig.DEBUG) Log.e(TAG, "Save failed for ${day.date}", e)
            false
        }

    fun saveDiaryDayOrThrow(day: DiaryDay) {
        fileFor(day.date).writeText(adapter.toJson(day))
    }

    // -- Load single ---------------------------------------------------------------

    fun loadDiaryDay(date: String): DiaryDay? {
        val file = fileFor(date)
        if (!file.exists()) return null
        return try {
            adapter.fromJson(file.readText())
        } catch (e: Exception) {
            lastError = e
            if (BuildConfig.DEBUG) Log.e(TAG, "Load failed for $date", e)
            null
        }
    }

    // -- Load all ------------------------------------------------------------------

    fun loadAllDiaryDays(): List<DiaryDay> {
        val files = diaryDir.listFiles { f ->
            f.name.startsWith("diary_") && f.extension == "json"
        } ?: return emptyList()

        return files.mapNotNull { file ->
            try {
                adapter.fromJson(file.readText())
            } catch (e: Exception) {
                lastError = e
                if (BuildConfig.DEBUG) Log.w(TAG, "Skipping ${file.name}: ${e.message}")
                null
            }
        }.sortedByDescending { it.date }
    }

    // -- Delete --------------------------------------------------------------------

    fun deleteDiaryDay(date: String): Boolean =
        try {
            deleteDiaryDayOrThrow(date); true
        } catch (e: Exception) {
            lastError = e
            if (BuildConfig.DEBUG) Log.e(TAG, "Delete failed for $date", e)
            false
        }

    fun deleteDiaryDayOrThrow(date: String) {
        val file = fileFor(date)
        if (file.exists()) file.delete()
    }

    companion object {
        private const val TAG = "DiaryStorage"
    }
}
