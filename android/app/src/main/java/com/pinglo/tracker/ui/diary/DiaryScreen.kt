package com.pinglo.tracker.ui.diary

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pinglo.tracker.BuildConfig
import com.pinglo.tracker.model.DiaryDay
import kotlinx.coroutines.delay
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiaryScreen(
    onDaySelected: (date: String) -> Unit,
    viewModel: DiaryViewModel = hiltViewModel(),
) {
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()
    val inProgressDays by viewModel.inProgressDays.collectAsStateWithLifecycle()
    val navigateToDayDate by viewModel.navigateToDayDate.collectAsStateWithLifecycle()
    val toastMessage by viewModel.toastMessage.collectAsStateWithLifecycle()

    var showDatePicker by remember { mutableStateOf(false) }
    var showToast by remember { mutableStateOf(false) }
    var currentToastMessage by remember { mutableStateOf("") }
    var toastColor by remember { mutableStateOf(Color(0xFFFFF3E0)) }

    LaunchedEffect(Unit) {
        viewModel.onAppear()
    }

    LaunchedEffect(navigateToDayDate) {
        navigateToDayDate?.let { date ->
            viewModel.onNavigated()
            onDaySelected(date)
        }
    }

    LaunchedEffect(toastMessage) {
        toastMessage?.let { info ->
            currentToastMessage = info.message
            toastColor = when (info.type) {
                ToastType.WARNING -> Color(0xFFFFF3E0)
                ToastType.INFO -> Color(0xFFE8EAF6)
            }
            showToast = true
            viewModel.dismissToast()
            delay(2_500)
            showToast = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 16.dp),
    ) {
        // Day selection header
        Text(
            text = "What day shall we complete the diary for?",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        Spacer(Modifier.height(12.dp))

        // Day selection buttons
        Row(
            modifier = Modifier.padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Button(
                onClick = { viewModel.buildDiaryForYesterday() },
                enabled = !isLoading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Text("Yesterday")
            }

            if (BuildConfig.DEBUG) {
                OutlinedButton(
                    onClick = { viewModel.buildDiaryForToday() },
                    enabled = !isLoading,
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color(0xFFFF9800),
                    ),
                ) {
                    Text("Today (Debug)")
                }
            }

            OutlinedButton(
                onClick = { showDatePicker = true },
                enabled = !isLoading,
            ) {
                Text("Another date")
            }
        }

        // Error banner
        AnimatedVisibility(visible = errorMessage != null) {
            errorMessage?.let { error ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.errorContainer,
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Filled.Warning,
                            contentDescription = null,
                            tint = Color(0xFFFF9800),
                            modifier = Modifier.size(18.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = error,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { viewModel.dismissError() }) {
                            Text("Dismiss", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
        }

        // Toast messages
        AnimatedVisibility(
            visible = showToast,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                shape = RoundedCornerShape(10.dp),
                color = toastColor,
            ) {
                Text(
                    text = currentToastMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(12.dp),
                )
            }
        }

        // Loading indicator
        if (isLoading) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Spacer(Modifier.width(12.dp))
                Text("Loading diary...", style = MaterialTheme.typography.bodyMedium)
            }
        }

        Spacer(Modifier.height(8.dp))
        HorizontalDivider()

        // In-progress diaries list
        if (inProgressDays.isEmpty()) {
            Spacer(Modifier.weight(1f))
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Filled.DateRange,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "No diary entries yet",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Choose Yesterday or pick another date to get started.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.weight(1f))
        } else {
            Text(
                text = "In Progress",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            )
            LazyColumn(modifier = Modifier.weight(1f)) {
                items(inProgressDays, key = { it.id }) { day ->
                    DiaryDayRow(
                        day = day,
                        onClick = { viewModel.navigateToDay(day.date) },
                    )
                }
            }
        }
    }

    // Date picker dialog
    if (showDatePicker) {
        val yesterday = LocalDate.now().minusDays(1)
        val yesterdayMillis = yesterday
            .atStartOfDay(ZoneId.of("UTC"))
            .toInstant()
            .toEpochMilli()
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = yesterdayMillis,
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                    val date = Instant.ofEpochMilli(utcTimeMillis)
                        .atZone(ZoneId.of("UTC"))
                        .toLocalDate()
                    return !date.isAfter(yesterday)
                }
            },
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    showDatePicker = false
                    datePickerState.selectedDateMillis?.let { millis ->
                        val selected = Instant.ofEpochMilli(millis)
                            .atZone(ZoneId.of("UTC"))
                            .toLocalDate()
                        viewModel.buildDiary(selected)
                    }
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(
                state = datePickerState,
            )
        }
    }
}

@Composable
private fun DiaryDayRow(day: DiaryDay, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = formatDateLabel(day.date),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(Modifier.height(2.dp))
                when {
                    day.entries.isEmpty() && day.journeys.isEmpty() -> {
                        Text(
                            text = "No diary entries on the selected day",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    day.isCompleted -> {
                        Text(
                            text = "Ready to submit",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFF4CAF50),
                        )
                    }
                    else -> {
                        Text(
                            text = "${day.completedCount}/${day.totalCount} items completed",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            when {
                day.entries.isEmpty() && day.journeys.isEmpty() -> {
                    Icon(
                        Icons.Filled.DateRange,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                day.isCompleted -> {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = Color(0xFF4CAF50),
                    )
                }
                else -> {
                    CircularProgressIndicator(
                        progress = {
                            if (day.totalCount > 0) day.completedCount.toFloat() / day.totalCount
                            else 0f
                        },
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 3.dp,
                        color = Color(0xFFFF9800),
                        trackColor = MaterialTheme.colorScheme.surfaceVariant,
                    )
                }
            }
        }
    }
    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
}

private fun formatDateLabel(dateStr: String): String {
    return try {
        val date = LocalDate.parse(dateStr, DateTimeFormatter.ISO_LOCAL_DATE)
        val today = LocalDate.now()
        val yesterday = today.minusDays(1)
        when (date) {
            today -> "Today – $dateStr"
            yesterday -> "Yesterday – $dateStr"
            else -> dateStr
        }
    } catch (_: Exception) {
        dateStr
    }
}
