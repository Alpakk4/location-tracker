package com.pinglo.tracker.ui.onboarding

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.pinglo.tracker.R
import com.pinglo.tracker.config.ConfigurationKeys

private const val PREFS_NAME = "pinglo_prefs"
private const val KEY_ONBOARDING_COMPLETE = "hasCompletedOnboarding"

private fun hasForegroundLocationPermission(context: Context): Boolean {
    val fine = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_FINE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED
    val coarse = ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_COARSE_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED
    return fine || coarse
}

private fun hasBackgroundLocationPermission(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
    return ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_BACKGROUND_LOCATION,
    ) == PackageManager.PERMISSION_GRANTED
}

private fun hasActivityRecognitionPermission(context: Context): Boolean {
    return ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACTIVITY_RECOGNITION,
    ) == PackageManager.PERMISSION_GRANTED
}

private fun openAppSettings(context: Context) {
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", context.packageName, null)
    }
    context.startActivity(intent)
}

private const val LOCATION_MODE_NONE = 0
private const val LOCATION_MODE_WHILE_USING = 1
private const val LOCATION_MODE_ALWAYS = 2

@Composable
fun OnboardingScreen(onComplete: () -> Unit) {
    val context = LocalContext.current
    var step by rememberSaveable { mutableIntStateOf(0) }

    when (step) {
        0 -> LocationStep(onNext = { step = 1 })
        1 -> MotionStep(onNext = { step = 2 })
        2 -> DeviceIdStep(onComplete = {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ONBOARDING_COMPLETE, true)
                .apply()
            onComplete()
        })
    }
}

@Composable
private fun LocationStep(onNext: () -> Unit) {
    val context = LocalContext.current

    val foregroundGranted = hasForegroundLocationPermission(context)
    val backgroundGranted = hasBackgroundLocationPermission(context)

    // iOS-like chooser:
    // - While using: require foreground only, advance once foreground is granted.
    // - Always: require foreground + background, advance only when both are granted.
    var selectedLocationMode by rememberSaveable { mutableIntStateOf(LOCATION_MODE_NONE) }
    var showDisclosureDialog by rememberSaveable { mutableStateOf(false) }
    var foregroundRequestAttempted by rememberSaveable { mutableStateOf(false) }
    var backgroundRequestAttempted by rememberSaveable { mutableStateOf(false) }

    val shouldAdvance = when (selectedLocationMode) {
        LOCATION_MODE_WHILE_USING -> foregroundGranted
        LOCATION_MODE_ALWAYS -> foregroundGranted && backgroundGranted
        else -> false
    }

    androidx.compose.runtime.LaunchedEffect(shouldAdvance) {
        if (shouldAdvance) onNext()
    }

    val showDenied = selectedLocationMode != LOCATION_MODE_NONE && (
        (foregroundRequestAttempted && !foregroundGranted) ||
            (selectedLocationMode == LOCATION_MODE_ALWAYS && backgroundRequestAttempted && !backgroundGranted)
        )

    val backgroundLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        backgroundRequestAttempted = true
        // Advancement is driven by shouldAdvance.
        if (granted) return@rememberLauncherForActivityResult
    }

    val foregroundLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { permissions ->
        foregroundRequestAttempted = true

        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        val hasForeground = fineGranted || coarseGranted

        if (!hasForeground) return@rememberLauncherForActivityResult

        if (selectedLocationMode == LOCATION_MODE_ALWAYS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            backgroundRequestAttempted = false
            backgroundLauncher.launch(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
        // On pre-Q devices, backgroundGranted is effectively true, so shouldAdvance will flip automatically.
    }

    if (showDisclosureDialog) {
        AlertDialog(
            onDismissRequest = { /* require a choice */ },
            title = { Text("Enable Background Tracking") },
            text = {
                Column(modifier = Modifier.padding(top = 8.dp)) {
                    Text(
                        text = "This app maps your activity diary. To work correctly, it needs " +
                            "access to your location even when the app is closed.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )

                    Spacer(Modifier.height(16.dp))

                    Column(
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        InstructionRow(
                            number = "1",
                            text = "Select \"Allow While Using App\" when prompted.",
                        )
                        InstructionRow(
                            number = "2",
                            text = "Then, go to Settings > Apps > pingLo > Permissions > " +
                                "Location and set it to \"Allow all the time\".",
                        )
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDisclosureDialog = false
                        foregroundRequestAttempted = false
                        backgroundRequestAttempted = false
                        selectedLocationMode = LOCATION_MODE_WHILE_USING
                        foregroundLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            ),
                        )
                    },
                ) {
                    Text("Allow While Using App")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showDisclosureDialog = false
                        foregroundRequestAttempted = false
                        backgroundRequestAttempted = false
                        selectedLocationMode = LOCATION_MODE_ALWAYS
                        foregroundLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION,
                            ),
                        )
                    },
                ) {
                    Text("Allow all the time")
                }
            },
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        Image(
            painter = painterResource(R.drawable.ic_pinglo_mascot),
            contentDescription = "Pinglo",
            modifier = Modifier.size(200.dp),
            contentScale = ContentScale.Fit,
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Enable Background Tracking",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(16.dp))

        if (showDenied) {
            Text(
                text = "Location access was denied. The app won't be able to record your travel diary without it. " +
                    "You can enable it later in Settings.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(32.dp))

            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Button(
                    onClick = { openAppSettings(context) },
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) {
                    Text(
                        text = "Open Settings",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Button(
                    onClick = onNext,
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) {
                    Text(
                        text = "Continue Without Location",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        } else {
            Text(
                text = "This app maps your activity diary. To work correctly, it needs " +
                    "access to your location even when the app is closed.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(32.dp))

            Spacer(Modifier.weight(1f))

            Button(
                onClick = { showDisclosureDialog = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
            ) {
                Text(
                    text = "Enable Location Access",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun MotionStep(onNext: () -> Unit) {
    val context = LocalContext.current
    val needsPermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    val motionPermissionGranted = !needsPermission || hasActivityRecognitionPermission(context)
    var motionRequestAttempted by rememberSaveable { mutableStateOf(false) }

    androidx.compose.runtime.LaunchedEffect(motionPermissionGranted) {
        if (motionPermissionGranted) onNext()
    }

    val showDenied = motionRequestAttempted && !motionPermissionGranted

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        motionRequestAttempted = true
        if (granted) onNext()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        Icon(
            imageVector = Icons.Filled.Info,
            contentDescription = null,
            modifier = Modifier.size(100.dp),
            tint = MaterialTheme.colorScheme.primary,
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Enable Activity Detection",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(16.dp))

        if (showDenied) {
            Text(
                text = "Motion access was denied. The app won't be able to detect how you travel (walking, driving, etc.). " +
                    "You can enable it later in Settings.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(32.dp))

            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Button(
                    onClick = { openAppSettings(context) },
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) {
                    Text(
                        text = "Open Settings",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
                Button(
                    onClick = onNext,
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) {
                    Text(
                        text = "Continue Without Motion",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        } else {
            Text(
                text = if (needsPermission) {
                    "Knowing whether you're walking, driving, or still helps build " +
                        "a better activity diary. Allow access when prompted."
                } else {
                    "Activity detection is available on this device and will be " +
                        "enabled automatically."
                },
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.weight(1f))

            Button(
                onClick = {
                    if (needsPermission) {
                        motionRequestAttempted = false
                        launcher.launch(Manifest.permission.ACTIVITY_RECOGNITION)
                    } else {
                        onNext()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
            ) {
                Text(
                    text = if (needsPermission) "Enable Activity Detection" else "Continue",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun DeviceIdStep(onComplete: () -> Unit) {
    val context = LocalContext.current
    var deviceId by rememberSaveable { mutableStateOf("") }
    val trimmed = deviceId.trim()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))

        Icon(
            imageVector = Icons.Filled.Person,
            contentDescription = null,
            modifier = Modifier.size(100.dp),
            tint = MaterialTheme.colorScheme.primary,
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "What is this device id?",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(16.dp))

        Text(
            text = "Enter the identifier for this device. This is required " +
                "before you can start using the app.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(32.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = deviceId,
                onValueChange = { deviceId = it },
                label = { Text("Device ID") },
                singleLine = true,
                modifier = Modifier.weight(1f),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(
                    onDone = {
                        if (trimmed.isNotEmpty()) {
                            saveDeviceId(context, trimmed)
                            onComplete()
                        }
                    },
                ),
            )

            IconButton(
                onClick = {
                    saveDeviceId(context, trimmed)
                    onComplete()
                },
                enabled = trimmed.isNotEmpty(),
                colors = IconButtonDefaults.iconButtonColors(
                    contentColor = if (trimmed.isNotEmpty()) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    },
                ),
            ) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = "Confirm",
                    modifier = Modifier.size(36.dp),
                )
            }
        }

        Spacer(Modifier.weight(1f))
    }
}

private fun saveDeviceId(context: Context, deviceId: String) {
    context.getSharedPreferences("pinglo_prefs", Context.MODE_PRIVATE)
        .edit()
        .putString(ConfigurationKeys.UID, deviceId)
        .apply()
}

@Composable
private fun InstructionRow(number: String, text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Surface(
            modifier = Modifier.size(28.dp),
            shape = CircleShape,
            color = MaterialTheme.colorScheme.primary,
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(
                    text = number,
                    color = MaterialTheme.colorScheme.onPrimary,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                )
            }
        }

        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
    }
}
