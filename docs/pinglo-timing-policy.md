# Pinglo Timing Policy

Single-view reference for every timing parameter that controls when the app pings,
updates location, and heartbeats. Both platforms read from their respective
`PingloTimingConfig` file, which should be kept in sync.

| Source file (Android) | Source file (iOS) |
|---|---|
| `android/.../config/PingloTimingConfig.kt` | `ios/location tracker/PingloTimingConfig.swift` |

---

## Ping throttle (per-activity minimum interval)

| Activity   | Interval | Android (ms) | iOS (s) |
|------------|----------|--------------|---------|
| WALKING    | 2 min    | 120 000      | 120     |
| RUNNING    | 2 min    | 120 000      | 120     |
| CYCLING    | 4 min    | 240 000      | 240     |
| AUTOMOTIVE | 10 min   | 600 000      | 600     |
| STILL      | 20 min   | 1 200 000    | 1200    |
| UNKNOWN    | 5 min    | 300 000      | 300     |

Non-forced pings are dropped if the last ping for the same activity was sent
less than the interval ago.

## Heartbeat interval

Equals the throttle interval per activity. A repeating timer fires
`sendLocation(force: false)` at this cadence so the server receives at least
one update per window even when the device hasn't moved enough to trigger the
distance gate.

## Ping distance gate

| Activity   | Min distance (m) |
|------------|-------------------|
| STILL      | 50                |
| WALKING    | 20                |
| RUNNING    | 20                |
| CYCLING    | 30                |
| AUTOMOTIVE | 100               |
| UNKNOWN    | 30                |

A location-triggered ping is suppressed if the device hasn't moved at least
this far from the location of the last successful ping.

## Accuracy gate

| Threshold | Value |
|-----------|-------|
| Max horizontal accuracy | 50 m |

Pings with horizontal accuracy worse than this are dropped.

## Geofence (visit boundary)

| Parameter | Value |
|-----------|-------|
| Radius    | 75 m  |
| Trigger   | Exit only |

Registered when motion goes STILL; torn down when motion leaves STILL.
Exit fires a forced boundary ping.

## Location update settings

### Android (Fused Location Provider)

| Motion          | Priority          | Interval | Min distance |
|-----------------|-------------------|----------|-------------|
| STILL           | LOW_POWER         | 60 s     | 20 m        |
| WALKING/RUNNING | HIGH_ACCURACY     | 10 s     | 10 m        |
| CYCLING         | HIGH_ACCURACY     | 10 s     | 15 m        |
| AUTOMOTIVE      | HIGH_ACCURACY     | 10 s     | 50 m        |
| Other           | HIGH_ACCURACY     | 10 s     | 15 m        |

### iOS (CLLocationManager)

| Motion          | distanceFilter |
|-----------------|---------------|
| STILL           | 20 m          |
| WALKING/RUNNING | 10 m          |
| CYCLING         | 15 m          |
| AUTOMOTIVE      | 50 m          |
| Other           | 15 m          |

iOS additionally uses `pausesLocationUpdatesAutomatically = true`.

## Retry / backoff

| Platform | Strategy | Delays | Max retries |
|----------|----------|--------|------------|
| Android  | WorkManager exponential backoff | Initial 1 min | 3 |
| iOS      | Fixed delays | 60 s, 120 s, 240 s | 3 |

## Motion debouncer

| Parameter | Value |
|-----------|-------|
| Window duration | 40 s |
| Smoothing alpha | 0.3 |
| Hysteresis threshold | 0.15 |
| Stability duration | 5 s |
| Decay timeout | 75 s |

## Activity recognition polling

| Platform | Interval |
|----------|----------|
| Android  | 5 s (explicit `requestActivityUpdates`) |
| iOS      | System-determined (`CMMotionActivityManager`) |

## Pause duration

| Parameter | Value |
|-----------|-------|
| Pause timer | 25 min |

---

## Parity expectations

All values in this document should be identical across platforms unless marked
with a platform-specific note. When changing a value, update both
`PingloTimingConfig` files and this document.
