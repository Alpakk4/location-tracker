package com.pinglo.tracker.ui.tracker

import android.location.Location
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.pinglo.tracker.BuildConfig
import kotlinx.coroutines.delay

@Composable
fun TrackerScreen(viewModel: TrackerViewModel = hiltViewModel()) {
    val lastLocation by viewModel.lastLocation.collectAsStateWithLifecycle()
    val enableReporting by viewModel.enableReporting.collectAsStateWithLifecycle()
    val isPaused by viewModel.isPaused.collectAsStateWithLifecycle()
    val pauseEndTimeMs by viewModel.pauseEndTimeMs.collectAsStateWithLifecycle()
    val uid by viewModel.uid.collectAsStateWithLifecycle()
    val isUidLocked by viewModel.isUidLocked.collectAsStateWithLifecycle()
    val homeLat by viewModel.homeLat.collectAsStateWithLifecycle()
    val homeLong by viewModel.homeLong.collectAsStateWithLifecycle()
    val isHomeSet by viewModel.isHomeSet.collectAsStateWithLifecycle()
    val isBackfilling by viewModel.isBackfilling.collectAsStateWithLifecycle()
    val backfillMessage by viewModel.backfillMessage.collectAsStateWithLifecycle()

    var showSetHomeDialog by remember { mutableStateOf(false) }
    var showAdminPasswordDialog by remember { mutableStateOf(false) }
    var showUidPasswordDialog by remember { mutableStateOf(false) }
    var showDeviceIdRequiredDialog by remember { mutableStateOf(false) }
    var showBackfillDialog by remember { mutableStateOf(false) }

    var homeShakeTrigger by remember { mutableIntStateOf(0) }
    val homeShakeOffset = remember { Animatable(0f) }
    var uidShakeTrigger by remember { mutableIntStateOf(0) }
    val uidShakeOffset = remember { Animatable(0f) }

    LaunchedEffect(homeShakeTrigger) {
        if (homeShakeTrigger > 0) {
            for (v in listOf(-10f, 10f, -10f, 10f, -5f, 5f, 0f)) {
                homeShakeOffset.animateTo(v, tween(50))
            }
        }
    }

    LaunchedEffect(uidShakeTrigger) {
        if (uidShakeTrigger > 0) {
            for (v in listOf(-10f, 10f, -10f, 10f, -5f, 5f, 0f)) {
                uidShakeOffset.animateTo(v, tween(50))
            }
        }
    }

    LaunchedEffect(backfillMessage) {
        if (backfillMessage != null) showBackfillDialog = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
    ) {
        // Top banner
        LocationBanner(lastLocation)

        if (BuildConfig.DEBUG) {
            Spacer(Modifier.height(12.dp))
            OutlinedButton(
                onClick = { viewModel.sendDebugPing() },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
                enabled = lastLocation != null,
                border = BorderStroke(2.dp, MaterialTheme.colorScheme.primary),
            ) {
                Icon(
                    Icons.Filled.Send,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text("SEND PING", fontWeight = FontWeight.Bold)
            }
        }

        Spacer(Modifier.height(12.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Location sharing toggle
            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Location Sharing is ${
                            when {
                                isPaused -> "PAUSED"
                                enableReporting -> "ON"
                                else -> "OFF"
                            }
                        }",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f),
                    )
                    Switch(
                        checked = enableReporting,
                        onCheckedChange = { enabled ->
                            if (!viewModel.setReporting(enabled)) {
                                showDeviceIdRequiredDialog = true
                            }
                        },
                        enabled = !isPaused,
                    )
                }
            }

            // Pause countdown + resume
            if (isPaused && pauseEndTimeMs != null) {
                PauseSection(
                    pauseEndTimeMs = pauseEndTimeMs!!,
                    onResume = { viewModel.cancelPause() },
                )
            }

            // Device ID row
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset(x = uidShakeOffset.value.dp)
                    .pointerInput(isUidLocked) {
                        if (isUidLocked) {
                            detectTapGestures(
                                onLongPress = { showUidPasswordDialog = true },
                            )
                        }
                    },
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(
                        imageVector = if (isUidLocked) Icons.Filled.Lock else Icons.Filled.Person,
                        contentDescription = null,
                        tint = if (isUidLocked) {
                            Color(0xFFFF9800)
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                        modifier = Modifier.size(20.dp),
                    )

                    if (isUidLocked) {
                        Text(
                            text = uid,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f),
                        )
                    } else {
                        var localUid by remember(uid) { mutableStateOf(uid) }
                        OutlinedTextField(
                            value = localUid,
                            onValueChange = {
                                localUid = it
                                viewModel.updateUid(it)
                            },
                            label = { Text("Device ID") },
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                            keyboardActions = KeyboardActions(
                                onDone = { viewModel.lockUid() },
                            ),
                        )
                    }
                }
            }

            Spacer(Modifier.height(4.dp))

            // Home Location card
            OutlinedCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .offset(x = homeShakeOffset.value.dp),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            Icons.Filled.Home,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = "Home Location",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.weight(1f),
                        )
                        if (isHomeSet) {
                            HomeLockMenu(
                                onUnlockRequest = { showAdminPasswordDialog = true },
                            )
                        }
                    }

                    if (homeLat != null && homeLong != null) {
                        Text(
                            text = "%.4f, %.4f".format(homeLat, homeLong),
                            style = MaterialTheme.typography.bodyMedium.copy(
                                fontFamily = FontFamily.Monospace,
                            ),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    } else {
                        Text(
                            text = "No home set",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                    }

                    Button(
                        onClick = { showSetHomeDialog = true },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = lastLocation != null && !isHomeSet && !isBackfilling,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isHomeSet) {
                                Color(0xFF4CAF50)
                            } else {
                                MaterialTheme.colorScheme.primary
                            },
                        ),
                    ) {
                        Text(
                            text = if (isHomeSet) "Home Locked" else "Set Current as Home",
                            fontWeight = FontWeight.Medium,
                        )
                    }

                    if (isBackfilling) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp,
                            )
                            Text(
                                text = "Updating historical records...",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }

    // -- Dialogs --

    if (showSetHomeDialog) {
        AlertDialog(
            onDismissRequest = { showSetHomeDialog = false },
            title = { Text("Set Home Location?") },
            text = { Text("This action can only be performed once. Are you sure?") },
            confirmButton = {
                TextButton(onClick = {
                    showSetHomeDialog = false
                    viewModel.setHome()
                }) { Text("Confirm") }
            },
            dismissButton = {
                TextButton(onClick = { showSetHomeDialog = false }) { Text("Cancel") }
            },
        )
    }

    if (showAdminPasswordDialog) {
        PasswordDialog(
            title = "Admin Access",
            message = "Enter admin password to reset home coordinates.",
            onDismiss = { showAdminPasswordDialog = false },
            onSubmit = { password ->
                showAdminPasswordDialog = false
                if (!viewModel.unlockHome(password)) {
                    homeShakeTrigger++
                }
            },
        )
    }

    if (showUidPasswordDialog) {
        PasswordDialog(
            title = "Unlock Device ID",
            message = "Enter admin password to unlock Device ID.",
            onDismiss = { showUidPasswordDialog = false },
            onSubmit = { password ->
                showUidPasswordDialog = false
                if (!viewModel.unlockUid(password)) {
                    uidShakeTrigger++
                }
            },
        )
    }

    if (showDeviceIdRequiredDialog) {
        AlertDialog(
            onDismissRequest = { showDeviceIdRequiredDialog = false },
            title = { Text("Device ID Required") },
            text = {
                Text("Must set Device ID before starting location services for the first time.")
            },
            confirmButton = {
                TextButton(onClick = { showDeviceIdRequiredDialog = false }) { Text("OK") }
            },
        )
    }

    if (showBackfillDialog && backfillMessage != null) {
        AlertDialog(
            onDismissRequest = {
                showBackfillDialog = false
                viewModel.dismissBackfillMessage()
            },
            title = { Text("Home Backfill") },
            text = { Text(backfillMessage ?: "") },
            confirmButton = {
                TextButton(onClick = {
                    showBackfillDialog = false
                    viewModel.dismissBackfillMessage()
                }) { Text("OK") }
            },
        )
    }
}

// -- Section composables --

@Composable
private fun LocationBanner(location: Location?) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Filled.LocationOn,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(16.dp))
            if (location != null) {
                Column {
                    Text(
                        text = "LAT: ${"%.6f".format(location.latitude)}",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                    Text(
                        text = "LON: ${"%.6f".format(location.longitude)}",
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Medium,
                        ),
                    )
                }
            } else {
                Text(
                    text = "Acquiring GPS Signal...",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.width(8.dp))
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                )
            }
        }
    }
}

@Composable
private fun PauseSection(pauseEndTimeMs: Long, onResume: () -> Unit) {
    var remainingMs by remember(pauseEndTimeMs) {
        mutableLongStateOf(maxOf(0, pauseEndTimeMs - System.currentTimeMillis()))
    }

    LaunchedEffect(pauseEndTimeMs) {
        while (true) {
            remainingMs = maxOf(0, pauseEndTimeMs - System.currentTimeMillis())
            if (remainingMs <= 0) break
            delay(1000)
        }
    }

    val minutes = (remainingMs / 60_000).toInt()
    val seconds = ((remainingMs % 60_000) / 1000).toInt()

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Resuming in $minutes:${"%02d".format(seconds)}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Button(
            onClick = onResume,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                Icons.Filled.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text("Resume Now", fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun HomeLockMenu(onUnlockRequest: () -> Unit) {
    var showMenu by remember { mutableStateOf(false) }

    Box {
        Surface(
            onClick = { showMenu = true },
            shape = CircleShape,
            color = Color(0xFFFF9800).copy(alpha = 0.1f),
        ) {
            Icon(
                Icons.Filled.Lock,
                contentDescription = "Unlock settings",
                tint = Color(0xFFFF9800),
                modifier = Modifier
                    .padding(6.dp)
                    .size(20.dp),
            )
        }
        DropdownMenu(
            expanded = showMenu,
            onDismissRequest = { showMenu = false },
        ) {
            DropdownMenuItem(
                text = { Text("Unlock Settings") },
                onClick = {
                    showMenu = false
                    onUnlockRequest()
                },
            )
        }
    }
}

@Composable
private fun PasswordDialog(
    title: String,
    message: String,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    var password by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(message)
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSubmit(password) }) { Text("Unlock") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}
