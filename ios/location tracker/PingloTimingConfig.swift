//
//  PingloTimingConfig.swift
//  location tracker
//
//  Single source of truth for all ping, heartbeat, location-update, and retry timing
//  parameters. Both iOS and Android maintain a mirrored version of this file — keep
//  values identical across platforms unless there is a platform-specific reason to diverge.
//
//  See docs/pinglo-timing-policy.md for the human-readable parity table.
//

import CoreLocation

enum PingloTimingConfig {

    // MARK: - Ping throttle (minimum interval between non-forced pings per activity)

    static func throttleInterval(for activity: String) -> TimeInterval {
        switch activity {
        case "WALKING":    return 120    // 2 min
        case "RUNNING":    return 120    // 2 min
        case "CYCLING":    return 240    // 4 min
        case "AUTOMOTIVE": return 600    // 10 min
        case "STILL":      return 1200   // 20 min
        default:           return 300    // 5 min (UNKNOWN / fallback)
        }
    }

    // MARK: - Heartbeat interval (repeating timer that fires sendLocation with force=false)
    // Defined to equal the throttle interval per activity.

    static func heartbeatInterval(for activity: String) -> TimeInterval {
        throttleInterval(for: activity)
    }

    // MARK: - Ping distance gate (min movement since last ping before a new one is sent)

    static let pingDistanceThresholds: [String: CLLocationDistance] = [
        "STILL": 50, "WALKING": 20, "RUNNING": 20,
        "CYCLING": 30, "AUTOMOTIVE": 100, "UNKNOWN": 30
    ]

    // MARK: - Accuracy gate (pings are dropped when horizontal accuracy exceeds this)

    static let maxHorizontalAccuracy: CLLocationAccuracy = 50

    // MARK: - Geofence (visit boundary detection)

    static let geofenceRadius: CLLocationDistance = 75

    // MARK: - CLLocationManager distance filter per motion (iOS-specific)

    static func distanceFilter(for motion: String) -> CLLocationDistance {
        switch motion {
        case "STILL":              return 20
        case "WALKING", "RUNNING": return 10
        case "CYCLING":            return 15
        case "AUTOMOTIVE":         return 50
        default:                   return 15
        }
    }

    // MARK: - Retry / backoff (failed or 5xx pings)

    static let retryDelays: [TimeInterval] = [60, 120, 240]

    // MARK: - Motion debouncer

    static let motionWindowDuration: TimeInterval     = 40
    static let motionSmoothingAlpha: Double            = 0.3
    static let motionHysteresisThreshold: Double       = 0.15
    static let motionStabilityDuration: TimeInterval   = 5.0
    static let motionDecayTimeout: TimeInterval        = 75

    // MARK: - Pause duration (UI "pause tracking" countdown)

    static let pauseDuration: TimeInterval = 25 * 60  // 25 minutes
}
