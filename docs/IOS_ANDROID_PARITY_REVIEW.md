# iOS vs Android parity review

Review date: 2026-03-13.  
Scope: location and networking logic, battery behaviour, background processes and permissions, precision of variables.  
Server-side data processing is assumed identical for both platforms.

---

## 1. Location and networking logic

### 1.1 Payload and API contract

| Aspect | iOS | Android | Parity |
|--------|-----|---------|--------|
| Endpoint | `POST {endpoint}/ping` | `POST ping` (base from config) | ✓ Same |
| Fields | `uid`, `lat`, `long`, `home_lat`, `home_long`, `motion`, `horizontal_accuracy`, `capturedAt` | Same (snake_case via `@Json(name)` where needed) | ✓ Same |
| Motion shape | `MotionType(motion, confidence)` | Same | ✓ Same |
| Auth | `Authorization: Bearer {apikey}`, `apikey` header | Via Supabase client | ✓ Same |

Payload structure is aligned; both send the same logical data to the server.

### 1.2 Throttling (per-activity minimum interval between pings)

| Activity   | Interval (seconds) | iOS | Android |
|-----------|---------------------|-----|---------|
| WALKING   | 120                 | ✓   | ✓       |
| RUNNING   | 120                 | ✓   | ✓       |
| CYCLING   | 240                 | ✓   | ✓       |
| AUTOMOTIVE| 600                 | ✓   | ✓       |
| STILL     | 1200                | ✓   | ✓       |
| UNKNOWN   | 300                 | ✓   | ✓       |

**Parity: ✓** Intervals are identical.

### 1.3 When a ping is sent

- **Accuracy gate:** both only send when horizontal accuracy is “good enough”:
  - iOS: `horizontalAccuracy >= 0 && horizontalAccuracy <= 50` (meters).
  - Android: `loc.accuracy` in same range (50 m).
- **Distance gate:** both use the same per-mode minimum distance since last ping:

| Mode      | Min distance (m) |
|-----------|-------------------|
| STILL     | 50                |
| WALKING   | 20                |
| RUNNING   | 20                |
| CYCLING   | 30                |
| AUTOMOTIVE| 100               |
| UNKNOWN   | 30                |

- **Forced pings:** motion commit and geofence exit send with `force: true` on both, bypassing the throttle (but not accuracy/distance where applicable).

**Parity: ✓** Logic is aligned.

### 1.4 Retry behaviour (failed or 5xx pings)

| Aspect | iOS | Android |
|--------|-----|---------|
| Trigger | Network error or HTTP status ≥ 500 | Exception or response code ≥ 500 |
| Strategy | Fixed delays: 60 s, 300 s, 900 s (3 retries) | WorkManager: exponential backoff, 1 minute initial, up to 3 run attempts |
| Persistence | Pending pings stored in UserDefaults; replayed on next app launch | One WorkManager work enqueued per failure; WorkManager persists and retries across process death/reboot |
| After max retries | Ping dropped | Worker returns `Result.failure()`; ping not re-enqueued |

**Parity: ✗** Behaviour differs:

- **Schedule:** iOS uses fixed 1 min → 5 min → 15 min. Android uses exponential backoff (e.g. 1 min, 2 min, 4 min), so the second and third attempts happen at different times.
- **Survival:** Android retries survive app kill and device reboot; iOS retries only run while the app is running (or when it next launches and replays from UserDefaults). So after a reboot, iOS may never retry; Android will.

If you want parity, you could either align on fixed delays on Android or move iOS to a more WorkManager-like strategy (or document that “best effort” differs by platform).

---

## 2. Battery usage

### 2.1 Location updates

| Aspect | iOS | Android |
|--------|-----|---------|
| API | `CLLocationManager`, `startUpdatingLocation()` | Fused Location Provider, `LocationRequest` |
| Accuracy | `kCLLocationAccuracyBest` | `Priority.PRIORITY_HIGH_ACCURACY` |
| Minimum distance | 20 / 10 / 15 / 50 / 15 m by mode (same as ping thresholds) | Same values via `setMinUpdateDistanceMeters()` |
| Time / interval | No explicit interval; OS-driven | `LocationRequest` built with `10_000` ms (10 s) max interval |
| Pause when still | `pausesLocationUpdatesAutomatically = true` | Not set; service runs continuously while tracking |

**Parity: ~**  
Logic is similar. The only notable difference is the explicit 10 s cap on Android; iOS relies on the system. Both use the same distance filters, so update frequency in motion should be comparable. Android does not enable “pause when still” in the same way as iOS; if you want closer behaviour, you could consider a similar optimisation on Android (e.g. reduce frequency or switch to a lower-power mode when motion is STILL).

### 2.2 Activity recognition

| Aspect | iOS | Android |
|--------|-----|---------|
| Source | `CMMotionActivityManager` | Google Play Services `ActivityRecognition` |
| Requested frequency | System-determined | `requestActivityUpdates(5_000, ...)` → every 5 s |

**Parity: ✓** Functionally equivalent; Android explicitly asks for 5 s updates.

### 2.3 Geofence (visit boundary)

- Both use a single circular region, radius **75 m**, **exit-only**, to trigger a boundary ping when leaving a visit.
- iOS: `CLCircularRegion`, `notifyOnExit = true`.
- Android: `Geofence.GEOFENCE_TRANSITION_EXIT`, same radius.

**Parity: ✓** Same role and parameters.

### 2.4 Summary (battery)

- Throttling, distance filters, and geofence are aligned; both apps avoid unnecessary pings in similar ways.
- Difference: iOS can pause location updates when the system thinks the device is still; Android does not. Retry behaviour (see above) also affects how often network is used after failures.

---

## 3. Background processes and permissions

### 3.1 Permissions

| Capability | iOS | Android |
|------------|-----|---------|
| Location (foreground) | NSLocationWhenInUseUsageDescription | ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION |
| Location (background) | NSLocationAlwaysAndWhenInUseUsageDescription; `requestAlwaysAuthorization()` | ACCESS_BACKGROUND_LOCATION |
| Motion / activity | NSMotionUsageDescription; `CMMotionActivityManager` | ACTIVITY_RECOGNITION |
| Background execution | UIBackgroundModes: `location`, `fetch` | Foreground service (location) with notification |
| Notifications | — | POST_NOTIFICATIONS (API 33+) |
| Boot | — | RECEIVE_BOOT_COMPLETED declared |

**Parity: ✓** Both platforms declare and use the right capabilities for always-on tracking and activity.

### 3.2 How tracking runs in background

- **iOS:** App process runs with background location and fetch modes; `LocationService` sets `allowsBackgroundLocationUpdates = true`. Location and activity updates can be delivered in background; pings are sent immediately (or after throttle). No foreground service.
- **Android:** Tracking runs inside a **foreground service** with a persistent notification and `FOREGROUND_SERVICE_LOCATION`. Service is started from the UI (e.g. `TrackerViewModel`); no `BroadcastReceiver` is registered in the manifest for `BOOT_COMPLETED`, so tracking does **not** auto-restart after reboot.

So: both can track in background; Android is explicit (foreground service); iOS uses background modes. The only gap is that **RECEIVE_BOOT_COMPLETED** is declared but unused—either register a boot receiver to start the service after reboot (for parity with “resume tracking after reboot”) or remove the permission to match current behaviour.

---

## 4. Precision of variables

### 4.1 Coordinates and accuracy

| Variable | iOS | Android | Parity |
|----------|-----|---------|--------|
| Latitude / longitude | `CLLocationCoordinate2D` (Double) → payload `lat`, `long` (Double) | `Location.latitude`, `.longitude` (double) → payload `lat`, `long` (Double) | ✓ |
| Horizontal accuracy | `CLLocation.horizontalAccuracy` (CLLocationAccuracy = Double) → `horizontal_accuracy` | `Location.accuracy` (float) → `.toDouble()` → `horizontalAccuracy` | ✓ |

Both send **Double** in the payload; server sees the same type and sufficient precision.

### 4.2 Timestamps

| Platform | Format | Example |
|----------|--------|--------|
| iOS | ISO 8601 with fractional seconds (`ISO8601DateFormatter`, `.withFractionalSeconds`) | `2026-03-13T12:00:00.123Z` |
| Android | `DateTimeFormatter.ISO_INSTANT.format(Instant.now())` | `2026-03-13T12:00:00.123456789Z` |

Both are ISO 8601 and suitable for server processing. Sub-second precision can differ (e.g. milliseconds vs nanoseconds). If the server normalises or truncates, this is a non-issue; otherwise it’s a small format/precision difference only.

### 4.3 Motion and confidence

- **Motion:** Same string set on both: `WALKING`, `RUNNING`, `CYCLING`, `AUTOMOTIVE`, `STILL`, `UNKNOWN`.
- **Confidence:** Same labels: `high`, `medium`, `low`, derived from the same thresholds (e.g. score &gt; 0.6 → high, &gt; 0.3 → medium).
- **Debouncer:** Same parameters (e.g. 40 s window, 0.3 smoothing, 0.15 hysteresis, 5 s stability, 75 s decay).

**Parity: ✓** Variables and logic match.

---

## 5. Summary table

| Area | Parity | Notes |
|------|--------|--------|
| Payload shape and fields | ✓ | Same contract and types. |
| Throttle intervals | ✓ | Identical per activity. |
| Accuracy and distance gating | ✓ | Same thresholds and logic. |
| Retry strategy | ✗ | iOS: fixed 60/300/900 s, in-process + UserDefaults; Android: WorkManager exponential, survives reboot. |
| Location request (distance, accuracy) | ✓ | Same distance filters; Android adds 10 s max interval. |
| Pause when still | ~ | iOS uses it; Android does not. |
| Activity recognition | ✓ | Same semantics; Android requests 5 s explicitly. |
| Geofence (75 m, exit) | ✓ | Same. |
| Background / permissions | ✓ | Correct capabilities on both; RECEIVE_BOOT_COMPLETED unused on Android. |
| Numeric precision (lat, long, accuracy) | ✓ | Double everywhere in payload. |
| Timestamp format | ~ | Both ISO 8601; sub-second precision may differ. |
| Motion and confidence | ✓ | Same strings and thresholds. |

Overall, location logic, networking behaviour (except retries), and variable precision are at parity. The main differences are **retry behaviour** (schedule and persistence across process/reboot) and **battery** (iOS pausing location when still; Android not). Optionally, either use the boot permission on Android (with a receiver) or remove it to match current behaviour.
