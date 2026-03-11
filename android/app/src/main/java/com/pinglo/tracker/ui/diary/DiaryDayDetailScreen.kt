package com.pinglo.tracker.ui.diary

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pinglo.tracker.model.DiaryDay
import com.pinglo.tracker.model.DiaryEntry
import com.pinglo.tracker.model.DiaryJourney
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiaryDayDetailScreen(
    date: String,
    onBack: () -> Unit,
    viewModel: DiaryDayDetailViewModel = hiltViewModel(),
) {
    val diaryDay by viewModel.diaryDay.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val submitSuccess by viewModel.submitSuccess.collectAsStateWithLifecycle()
    val alreadySubmitted by viewModel.alreadySubmitted.collectAsStateWithLifecycle()
    val errorMessage by viewModel.errorMessage.collectAsStateWithLifecycle()

    var showSubmitAlert by remember { mutableStateOf(false) }
    var showRefreshAlert by remember { mutableStateOf(false) }

    LaunchedEffect(submitSuccess) {
        if (submitSuccess) onBack()
    }

    LaunchedEffect(alreadySubmitted) {
        if (alreadySubmitted) onBack()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(date) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        val day = diaryDay

        if (day == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                if (isLoading) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        CircularProgressIndicator()
                        Spacer(Modifier.height(12.dp))
                        Text("Loading diary...")
                    }
                } else {
                    Text("No diary data available.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            return@Scaffold
        }

        if (day.entries.isEmpty() && day.journeys.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = null,
                        modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "No diary entries on the selected day",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            return@Scaffold
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            // Progress header
            ProgressHeader(day)

            // Error banner
            errorMessage?.let { error ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.errorContainer,
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = error,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.weight(1f),
                        )
                        TextButton(onClick = { viewModel.dismissError() }) {
                            Text("Dismiss", style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }

            // Timeline
            val timelineItems = buildTimeline(day)
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { Spacer(Modifier.height(4.dp)) }
                items(timelineItems, key = { it.id }) { item ->
                    when (item) {
                        is TimelineItem.Visit -> {
                            DiaryEntryCard(
                                entry = item.entry,
                                onConfirmedCategoryChanged = { value ->
                                    viewModel.updateEntry(item.index) { it.copy(confirmedCategory = value) }
                                },
                                onConfirmedPlaceChanged = { value ->
                                    viewModel.updateEntry(item.index) { it.copy(confirmedPlace = value) }
                                },
                                onConfirmedActivityChanged = { value ->
                                    viewModel.updateEntry(item.index) { it.copy(confirmedActivity = value) }
                                },
                                onUserContextChanged = { value ->
                                    viewModel.updateEntry(item.index) {
                                        it.copy(userContext = value.ifBlank { null })
                                    }
                                },
                            )
                        }
                        is TimelineItem.Journey -> {
                            DiaryJourneyCard(
                                journey = item.journey,
                                entries = day.entries,
                                onConfirmedTransportChanged = { value ->
                                    viewModel.updateJourney(item.index) { it.copy(confirmedTransport = value) }
                                },
                                onTravelReasonChanged = { value ->
                                    viewModel.updateJourney(item.index) {
                                        it.copy(travelReason = value.ifBlank { null })
                                    }
                                },
                            )
                        }
                    }
                }
                item { Spacer(Modifier.height(80.dp)) }
            }

            // Bottom buttons
            HorizontalDivider()
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedButton(
                    onClick = { showRefreshAlert = true },
                    enabled = !isLoading,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFFF9800)),
                ) {
                    Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("REFRESH", fontWeight = FontWeight.Bold)
                }

                Button(
                    onClick = { showSubmitAlert = true },
                    enabled = day.isCompleted && !isLoading && !viewModel.isSubmitted(),
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (day.isCompleted) Color(0xFF4CAF50) else Color.Gray,
                    ),
                ) {
                    if (isLoading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = Color.White,
                        )
                        Spacer(Modifier.width(6.dp))
                    }
                    Text("SUBMIT", fontWeight = FontWeight.Bold)
                }
            }
        }
    }

    // Submit alert
    if (showSubmitAlert) {
        val day = diaryDay
        AlertDialog(
            onDismissRequest = { showSubmitAlert = false },
            title = { Text("Submit Diary") },
            text = {
                Text("Submit all ${day?.totalCount ?: 0} completed items for $date? Once submitted, you cannot edit the diary.")
            },
            confirmButton = {
                TextButton(onClick = {
                    showSubmitAlert = false
                    viewModel.submit()
                }) { Text("Submit") }
            },
            dismissButton = {
                TextButton(onClick = { showSubmitAlert = false }) { Text("Cancel") }
            },
        )
    }

    // Refresh alert
    if (showRefreshAlert) {
        AlertDialog(
            onDismissRequest = { showRefreshAlert = false },
            title = { Text("Refresh Diary") },
            text = {
                Text("This will re-fetch your diary from the server and reset your answers. Continue?")
            },
            confirmButton = {
                TextButton(onClick = {
                    showRefreshAlert = false
                    viewModel.refresh()
                }) { Text("Refresh") }
            },
            dismissButton = {
                TextButton(onClick = { showRefreshAlert = false }) { Text("Cancel") }
            },
        )
    }
}

// -- Progress Header --

@Composable
private fun ProgressHeader(day: DiaryDay) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "${day.completedCount}/${day.totalCount} completed",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.weight(1f))
        if (day.isCompleted) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF4CAF50),
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = "Ready to submit",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color(0xFF4CAF50),
                )
            }
        }
    }
}

// -- Timeline Model --

private sealed class TimelineItem(val id: String, val sortMillis: Long) {
    class Visit(val index: Int, val entry: DiaryEntry) :
        TimelineItem("visit_${entry.id}", parseIsoMillis(entry.createdAt))

    class Journey(val index: Int, val journey: DiaryJourney) :
        TimelineItem("journey_${journey.id}", parseIsoMillis(journey.startedAt))
}

private fun buildTimeline(day: DiaryDay): List<TimelineItem> {
    val items = mutableListOf<TimelineItem>()
    day.entries.forEachIndexed { i, entry -> items.add(TimelineItem.Visit(i, entry)) }
    day.journeys.forEachIndexed { i, journey -> items.add(TimelineItem.Journey(i, journey)) }
    items.sortBy { it.sortMillis }
    return items
}

private val ISO_PARSERS = listOf(
    DateTimeFormatter.ISO_OFFSET_DATE_TIME,
    DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"),
    DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"),
    DateTimeFormatter.ISO_INSTANT,
)

private fun parseIsoMillis(iso: String): Long {
    for (fmt in ISO_PARSERS) {
        try {
            return OffsetDateTime.parse(iso, fmt).toInstant().toEpochMilli()
        } catch (_: DateTimeParseException) { /* try next */ }
    }
    return 0L
}

private fun shortTime(iso: String): String {
    val tIdx = iso.indexOf('T')
    if (tIdx >= 0 && tIdx + 6 <= iso.length) {
        return iso.substring(tIdx + 1, tIdx + 6)
    }
    return iso
}

private fun timeRange(start: String, end: String): String {
    val s = shortTime(start)
    val e = shortTime(end)
    return if (s == e) s else "$s – $e"
}

// -- Diary Entry Card --

@Composable
private fun DiaryEntryCard(
    entry: DiaryEntry,
    onConfirmedCategoryChanged: (Boolean) -> Unit,
    onConfirmedPlaceChanged: (Boolean) -> Unit,
    onConfirmedActivityChanged: (Boolean) -> Unit,
    onUserContextChanged: (String) -> Unit,
) {
    val displayType = entry.primaryType.replace("_", " ")
        .replaceFirstChar { it.uppercase() }

    val anyAnswerIsNo = entry.confirmedCategory == false ||
            entry.confirmedPlace == false ||
            entry.confirmedActivity == false

    var showContext by remember(entry.id) { mutableStateOf(anyAnswerIsNo || !entry.userContext.isNullOrBlank()) }
    val contextIsVisible = showContext || anyAnswerIsNo

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Header: time range + completion icon
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = timeRange(entry.createdAt, entry.endedAt),
                    style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = entry.formattedDuration,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                if (entry.isCompleted) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "Completed",
                        tint = Color(0xFF4CAF50),
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    CircularProgressIndicator(
                        progress = { 0f },
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = Color(0xFFFF9800),
                        trackColor = Color(0xFFFF9800).copy(alpha = 0.3f),
                    )
                }
            }

            // Confidence badge row
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ConfidenceBadge(entry.visitConfidence)
                Text(
                    text = entry.formattedDuration,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "${entry.pingCount} ping${if (entry.pingCount != 1) "s" else ""}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Place type + category + activity
            Text(
                text = displayType,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = buildAnnotatedString {
                    append("Category: ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(entry.placeCategory) }
                    append(" · Activity: ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(entry.activityLabel) }
                },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            HorizontalDivider()

            // Q1: Category
            QuestionRow(
                question = buildAnnotatedString {
                    append("Were you at a ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(entry.placeCategory) }
                    append(" place?")
                },
                selectedYes = entry.confirmedCategory == true,
                selectedNo = entry.confirmedCategory == false,
                onYes = { onConfirmedCategoryChanged(true) },
                onNo = { onConfirmedCategoryChanged(false) },
            )

            // Q2: Place
            QuestionRow(
                question = buildAnnotatedString {
                    append("Was that place ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(displayType) }
                    append("?")
                },
                selectedYes = entry.confirmedPlace == true,
                selectedNo = entry.confirmedPlace == false,
                onYes = { onConfirmedPlaceChanged(true) },
                onNo = { onConfirmedPlaceChanged(false) },
            )

            // Q3: Activity
            QuestionRow(
                question = buildAnnotatedString {
                    append("Were you doing ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(entry.activityLabel) }
                    append("?")
                },
                selectedYes = entry.confirmedActivity == true,
                selectedNo = entry.confirmedActivity == false,
                onYes = { onConfirmedActivityChanged(true) },
                onNo = { onConfirmedActivityChanged(false) },
            )

            // Context field
            if (contextIsVisible) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = if (anyAnswerIsNo) "Please provide context (required):" else "Additional context (optional):",
                            style = MaterialTheme.typography.bodySmall,
                            color = if (anyAnswerIsNo) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        if (!anyAnswerIsNo) {
                            IconButton(
                                onClick = { showContext = false },
                                modifier = Modifier.size(24.dp),
                            ) {
                                Icon(
                                    Icons.Filled.Close,
                                    contentDescription = "Close",
                                    modifier = Modifier.size(16.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                    OutlinedTextField(
                        value = entry.userContext ?: "",
                        onValueChange = onUserContextChanged,
                        placeholder = { Text("What were you actually doing?") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        textStyle = MaterialTheme.typography.bodyMedium,
                    )
                }
            } else {
                TextButton(onClick = { showContext = true }) {
                    Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Add context", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

// -- Diary Journey Card --

@Composable
private fun DiaryJourneyCard(
    journey: DiaryJourney,
    entries: List<DiaryEntry>,
    onConfirmedTransportChanged: (Boolean) -> Unit,
    onTravelReasonChanged: (String) -> Unit,
) {
    val fromPlace = entries.firstOrNull { it.id == journey.fromVisitId }
        ?.primaryType?.replace("_", " ")?.replaceFirstChar { it.uppercase() }
    val toPlace = entries.firstOrNull { it.id == journey.toVisitId }
        ?.primaryType?.replace("_", " ")?.replaceFirstChar { it.uppercase() }

    val sortedProportions = journey.transportProportions.entries
        .sortedByDescending { it.value }
        .map { it.key to it.value }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF2196F3).copy(alpha = 0.3f)),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = transportEmoji(journey.primaryTransport),
                    style = MaterialTheme.typography.titleMedium,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = timeRange(journey.startedAt, journey.endedAt),
                    style = MaterialTheme.typography.bodyMedium.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = journey.formattedDuration,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.weight(1f))
                if (journey.isCompleted) {
                    Icon(
                        Icons.Filled.CheckCircle,
                        contentDescription = "Completed",
                        tint = Color(0xFF4CAF50),
                        modifier = Modifier.size(20.dp),
                    )
                } else {
                    CircularProgressIndicator(
                        progress = { 0f },
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = Color(0xFFFF9800),
                        trackColor = Color(0xFFFF9800).copy(alpha = 0.3f),
                    )
                }
            }

            // Badge row
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Badge(text = "JOURNEY", color = Color(0xFF2196F3))
                journey.journeyConfidence?.let { conf ->
                    ConfidenceBadge(conf)
                }
                Text(
                    text = journey.formattedDuration,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = "${journey.pingCount} ping${if (journey.pingCount != 1) "s" else ""}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // From / To
            if (fromPlace != null && toPlace != null) {
                Text(
                    text = buildAnnotatedString {
                        append("From ")
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(fromPlace) }
                        append(" to ")
                        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(toPlace) }
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Transport proportions bar
            if (sortedProportions.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(4.dp)),
                    ) {
                        sortedProportions.forEach { (mode, ratio) ->
                            Box(
                                modifier = Modifier
                                    .weight(ratio.toFloat().coerceAtLeast(0.01f))
                                    .height(8.dp)
                                    .background(transportColor(mode)),
                            )
                        }
                    }
                    // Legend
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        sortedProportions.forEach { (mode, ratio) ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .background(transportColor(mode), CircleShape),
                                )
                                Text(
                                    text = "${mode.replaceFirstChar { it.uppercase() }} ${(ratio * 100).toInt()}%",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            HorizontalDivider()

            // Transport confirmation question
            QuestionRow(
                question = buildAnnotatedString {
                    append("Did you travel by ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(journey.transportLabel) }
                    append("?")
                },
                selectedYes = journey.confirmedTransport == true,
                selectedNo = journey.confirmedTransport == false,
                onYes = { onConfirmedTransportChanged(true) },
                onNo = { onConfirmedTransportChanged(false) },
            )

            // Travel reason
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "Why did you travel this way? (optional)",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = journey.travelReason ?: "",
                    onValueChange = onTravelReasonChanged,
                    placeholder = { Text("e.g. commute, errand, exercise...") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

// -- Shared Components --

@Composable
private fun QuestionRow(
    question: androidx.compose.ui.text.AnnotatedString,
    selectedYes: Boolean,
    selectedNo: Boolean,
    onYes: () -> Unit,
    onNo: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(text = question, style = MaterialTheme.typography.bodyMedium)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            AnswerButton(label = "Yes", isSelected = selectedYes, color = Color(0xFF4CAF50), onClick = onYes)
            AnswerButton(label = "No", isSelected = selectedNo, color = Color(0xFFF44336), onClick = onNo)
        }
    }
}

@Composable
private fun AnswerButton(label: String, isSelected: Boolean, color: Color, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isSelected) color else MaterialTheme.colorScheme.surfaceVariant,
            contentColor = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface,
        ),
        shape = RoundedCornerShape(8.dp),
    ) {
        Text(label, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun ConfidenceBadge(confidence: String) {
    val color = when (confidence.lowercase()) {
        "high" -> Color(0xFF4CAF50)
        "medium" -> Color(0xFFFF9800)
        else -> Color(0xFFF44336)
    }
    Badge(text = confidence.uppercase(), color = color)
}

@Composable
private fun Badge(text: String, color: Color) {
    Surface(
        shape = RoundedCornerShape(6.dp),
        color = color,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
        )
    }
}

private fun transportColor(mode: String): Color = when (mode.lowercase()) {
    "walking" -> Color(0xFF2196F3)
    "running" -> Color(0xFF9C27B0)
    "cycling" -> Color(0xFFFF9800)
    "automotive" -> Color(0xFFF44336)
    else -> Color.Gray
}

private fun transportEmoji(mode: String): String = when (mode.lowercase()) {
    "walking" -> "\uD83D\uDEB6"
    "running" -> "\uD83C\uDFC3"
    "cycling" -> "\uD83D\uDEB2"
    "automotive" -> "\uD83D\uDE97"
    else -> "\uD83D\uDEA9"
}
