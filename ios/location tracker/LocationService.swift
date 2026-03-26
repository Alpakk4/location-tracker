//
//  LocationService.swift
//  location tracker
//
//  Created by Alex Skondras on 04/02/2026.
//

import Foundation
import CoreLocation
import CoreMotion

/// Collects location and motion activity, then forwards normalized updates to NetworkingService.
/// Ownership: this class produces capture-time metadata; persistence and upload policy live elsewhere.
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let activityManager = CMMotionActivityManager()
    @Published var currentMotion: String = "STILL"
    @Published var currentConfidence: String = "unknown"
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus

    // MARK: - Geofence properties (visit boundary detection)
    private var currentGeofence: CLCircularRegion?
    private let geofenceRadius: CLLocationDistance = PingloTimingConfig.geofenceRadius
    private static let geofenceIdentifier = "current-visit"
    /// Tracks whether the previous motion update was STILL, to detect transitions.
    private var wasStationary = false

    /// Only send pings when horizontal accuracy is within this threshold (meters).
    private let maxHorizontalAccuracyForPing: CLLocationAccuracy = PingloTimingConfig.maxHorizontalAccuracy

    // MARK: - Distance-based ping filtering
    private var lastPingLocation: CLLocation?

    private static let pingDistanceThresholds = PingloTimingConfig.pingDistanceThresholds

    // MARK: - Motion debouncer state

    private struct MotionSample {
        let motion: String
        let confidenceValue: Double
        let timestamp: Date
    }

    private var motionWindow: [MotionSample] = []
    private let windowDuration: TimeInterval = PingloTimingConfig.motionWindowDuration
    private var smoothedScores: [String: Double] = ["STILL": 1.0]
    private let smoothingAlpha: Double = PingloTimingConfig.motionSmoothingAlpha
    private let hysteresisThreshold: Double = PingloTimingConfig.motionHysteresisThreshold

    private var stabilityCandidate: String?
    private var stabilityCandidateStart: Date?
    private let stabilityDuration: TimeInterval = PingloTimingConfig.motionStabilityDuration
    private var stabilityCheckTimer: Timer?

    private var decayTimer: Timer?
    private let decayTimeout: TimeInterval = PingloTimingConfig.motionDecayTimeout

    // MARK: - Per-mode heartbeat
    private var heartbeatTimer: Timer?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.distanceFilter = PingloTimingConfig.distanceFilter(for: "STILL")
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Whether motion and fitness (activity) detection is available on this device (e.g. false in simulator).
    var isMotionAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }

    /// Requests always-on permission because tracking can continue in background.
    func requestAuth() {
        #if DEBUG
        print("requesting location service auth")
        #endif
        manager.requestAlwaysAuthorization()
    }

    /// Ensures Motion & Fitness permission has been surfaced to the user.
    /// If motion is unavailable, calls completion immediately. Otherwise performs a lightweight query
    /// so the system shows the permission dialog, then waits until the user has responded before calling completion.
    var motionAuthorizationStatus: CMAuthorizationStatus {
        CMMotionActivityManager.authorizationStatus()
    }

    func ensureMotionPermission(completion: @escaping () -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            DispatchQueue.main.async { completion() }
            return
        }
        let status = CMMotionActivityManager.authorizationStatus()
        if status == .denied || status == .restricted {
            DispatchQueue.main.async { completion() }
            return
        }
        let now = Date()
        let shortlyAfter = now.addingTimeInterval(1)
        activityManager.queryActivityStarting(from: now, to: shortlyAfter, to: .main) { [weak self] _, _ in
            self?.waitForMotionAuthorizationResponse(completion: completion)
        }
    }

    private func waitForMotionAuthorizationResponse(completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(60)
        func check() {
            let status = CMMotionActivityManager.authorizationStatus()
            if status != .notDetermined || Date() > deadline {
                DispatchQueue.main.async { completion() }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { check() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { check() }
    }

    /// Starts both location callbacks and motion activity updates.
    /// If motion is unavailable, location still continues.
    func start() {
        #if DEBUG
        print("Starting location service")
        #endif
        manager.startUpdatingLocation()
        startHeartbeat(for: "STILL")
        resetDecayTimer()

        guard CMMotionActivityManager.isActivityAvailable() else {
            #if DEBUG
            print("Motion activity not available on this device")
            #endif
            return
        }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            let rawMotion = self.mapActivity(activity)

            // Geofence lifecycle uses raw (undebounced) motion for responsiveness.
            let isNowStationary = (rawMotion == "STILL")
            if isNowStationary && !self.wasStationary {
                if let loc = self.lastLocation {
                    self.registerVisitGeofence(at: loc)
                }
            } else if !isNowStationary && self.wasStationary {
                self.tearDownGeofence()
            }
            self.wasStationary = isNowStationary

            self.processMotionSample(rawMotion, confidence: activity.confidence)
        }
    }

    /// Stops all active sensors owned by this service.
    func stop() {
        #if DEBUG
        print("Stopping location service")
        #endif
        manager.stopUpdatingLocation()
        activityManager.stopActivityUpdates()
        tearDownGeofence()

        stabilityCheckTimer?.invalidate()
        stabilityCheckTimer = nil
        decayTimer?.invalidate()
        decayTimer = nil
        resetStabilityCandidate()
        stopHeartbeat()
    }

    // MARK: - Motion Debouncer

    /// Feeds a raw motion sample into the sliding-window debouncer.
    /// The debouncer applies confidence-weighted scoring, exponential smoothing, a hysteresis gate,
    /// and a stability timer before committing a mode change.
    private func processMotionSample(_ motion: String, confidence: CMMotionActivityConfidence) {
        let now = Date()
        let confValue = confidenceWeight(confidence)

        motionWindow.append(MotionSample(motion: motion, confidenceValue: confValue, timestamp: now))
        motionWindow.removeAll { now.timeIntervalSince($0.timestamp) > windowDuration }

        var windowScores: [String: Double] = [:]
        var totalWeight = 0.0
        for sample in motionWindow {
            windowScores[sample.motion, default: 0] += sample.confidenceValue
            totalWeight += sample.confidenceValue
        }
        if totalWeight > 0 {
            for key in windowScores.keys { windowScores[key]! /= totalWeight }
        }

        let allMotions = Set(windowScores.keys).union(smoothedScores.keys)
        for m in allMotions {
            let windowVal = windowScores[m] ?? 0
            let prev = smoothedScores[m] ?? 0
            smoothedScores[m] = smoothingAlpha * windowVal + (1 - smoothingAlpha) * prev
        }
        smoothedScores = smoothedScores.filter { $0.value > 0.01 }

        guard let topMode = smoothedScores.max(by: { $0.value < $1.value }) else { return }

        if topMode.key != currentMotion {
            let currentScore = smoothedScores[currentMotion] ?? 0
            guard topMode.value - currentScore >= hysteresisThreshold else {
                resetStabilityCandidate()
                return
            }

            if stabilityCandidate == topMode.key {
                if let start = stabilityCandidateStart, now.timeIntervalSince(start) >= stabilityDuration {
                    commitMotion(topMode.key)
                }
            } else {
                stabilityCandidate = topMode.key
                stabilityCandidateStart = now
                startStabilityCheckTimer()
            }
        } else {
            resetStabilityCandidate()
        }

        resetDecayTimer()
    }

    /// Commits a new motion mode: updates published state, sends a forced boundary ping,
    /// restarts the heartbeat timer for the new mode, and updates distanceFilter.
    private func commitMotion(_ motion: String) {
        resetStabilityCandidate()
        let confidence = deriveConfidence(from: smoothedScores[motion] ?? 0)

        let previousMotion = currentMotion
        currentMotion = motion
        currentConfidence = confidence

        updateDistanceFilter(for: motion)

        if let loc = lastLocation {
            lastPingLocation = loc
            NetworkingService.shared.sendLocation(loc, activity: motion, confidence: confidence, force: true)
        }

        if motion != previousMotion {
            startHeartbeat(for: motion)
        }

        #if DEBUG
        print("Motion committed: \(motion) (\(confidence))")
        #endif
    }

    /// One-shot timer that re-evaluates the stability candidate after `stabilityDuration`.
    private func startStabilityCheckTimer() {
        stabilityCheckTimer?.invalidate()
        let timer = Timer(timeInterval: stabilityDuration, repeats: false) { [weak self] _ in
            guard let self = self,
                  let candidate = self.stabilityCandidate,
                  let topMode = self.smoothedScores.max(by: { $0.value < $1.value }),
                  topMode.key == candidate else {
                self?.resetStabilityCandidate()
                return
            }
            let currentScore = self.smoothedScores[self.currentMotion] ?? 0
            if topMode.value - currentScore >= self.hysteresisThreshold {
                self.commitMotion(candidate)
            } else {
                self.resetStabilityCandidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        stabilityCheckTimer = timer
    }

    private func resetStabilityCandidate() {
        stabilityCandidate = nil
        stabilityCandidateStart = nil
        stabilityCheckTimer?.invalidate()
        stabilityCheckTimer = nil
    }

    /// Resets the decay timer. If no motion samples arrive within `decayTimeout`, forces STILL.
    private func resetDecayTimer() {
        decayTimer?.invalidate()
        let timer = Timer(timeInterval: decayTimeout, repeats: false) { [weak self] _ in
            guard let self = self, self.currentMotion != "STILL" else { return }
            #if DEBUG
            print("Motion decay: no samples for \(self.decayTimeout)s, committing STILL")
            #endif
            self.smoothedScores = ["STILL": 1.0]
            self.motionWindow.removeAll()
            self.commitMotion("STILL")
        }
        RunLoop.main.add(timer, forMode: .common)
        decayTimer = timer
    }

    private func confidenceWeight(_ confidence: CMMotionActivityConfidence) -> Double {
        switch confidence {
        case .low:    return 0.33
        case .medium: return 0.67
        case .high:   return 1.0
        @unknown default: return 0.33
        }
    }

    /// Derives a human-readable confidence label from the smoothed score for the committed mode.
    private func deriveConfidence(from score: Double) -> String {
        if score > 0.6 { return "high" }
        if score > 0.3 { return "medium" }
        return "low"
    }

    // MARK: - Per-mode Heartbeat

    /// Starts a repeating heartbeat at the committed mode's throttle interval.
    /// Heartbeats use `force: false` so they're still subject to the NetworkingService throttle gate.
    private func startHeartbeat(for motion: String) {
        stopHeartbeat()
        let interval = PingloTimingConfig.heartbeatInterval(for: motion)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self, let loc = self.lastLocation else { return }
                self.lastPingLocation = loc
                NetworkingService.shared.sendLocation(
                    loc, activity: self.currentMotion, confidence: self.currentConfidence, force: true
                )
            }
            RunLoop.main.add(timer, forMode: .common)
            self.heartbeatTimer = timer
        }
    }

    private func stopHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = nil
        }
    }

    // MARK: - Geofence (visit boundary detection)

    /// Registers a circular geofence at the given location to detect when the user leaves a visit.
    /// iOS region monitoring is battery-efficient (cell/WiFi, not continuous GPS) and supports up to 20 regions.
    private func registerVisitGeofence(at location: CLLocation) {
        tearDownGeofence()

        let region = CLCircularRegion(
            center: location.coordinate,
            radius: geofenceRadius,
            identifier: Self.geofenceIdentifier
        )
        region.notifyOnExit = true
        region.notifyOnEntry = false
        manager.startMonitoring(for: region)
        currentGeofence = region

        #if DEBUG
        print("Registered visit geofence at \(location.coordinate) r=\(geofenceRadius)m")
        #endif
    }

    /// Removes the active visit geofence, if any.
    private func tearDownGeofence() {
        guard let geofence = currentGeofence else { return }
        manager.stopMonitoring(for: geofence)
        currentGeofence = nil
        #if DEBUG
        print("Tore down visit geofence")
        #endif
    }

    // MARK: - Mapping Helpers

    /// Maps Core Motion flags into backend-compatible motion labels.
    private func mapActivity(_ activity: CMMotionActivity) -> String {
        if activity.walking    { return "WALKING" }
        if activity.running    { return "RUNNING" }
        if activity.cycling    { return "CYCLING" }
        if activity.automotive { return "AUTOMOTIVE" }
        if activity.stationary { return "STILL" }
        return "UNKNOWN"
    }

    /// Sets CLLocationManager distance filter by activity for battery vs accuracy tradeoff.
    /// Values are set smaller than the per-mode ping-distance thresholds so the OS delivers
    /// enough callbacks for the app-level distance gate to work.
    private func updateDistanceFilter(for motion: String) {
        manager.distanceFilter = PingloTimingConfig.distanceFilter(for: motion)
    }

    // MARK: - CLLocationManagerDelegate

    /// Forwards the latest location together with current motion context.
    /// Only sends a ping when horizontal accuracy is acceptable and the device has moved
    /// at least the per-mode ping-distance threshold since the last successful ping.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc
        }
        let accuracyOk = loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy <= maxHorizontalAccuracyForPing
        guard accuracyOk else { return }

        let threshold = Self.pingDistanceThresholds[currentMotion]
            ?? Self.pingDistanceThresholds["UNKNOWN"]!
        if let lastPing = lastPingLocation, loc.distance(from: lastPing) < threshold {
            return
        }

        lastPingLocation = loc
        NetworkingService.shared.sendLocation(loc, activity: currentMotion, confidence: currentConfidence)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    /// Fires when the user exits the visit geofence -- captures a boundary ping.
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.geofenceIdentifier else { return }
        tearDownGeofence()

        if let loc = manager.location {
            #if DEBUG
            print("Geofence exit detected — sending forced boundary ping")
            #endif
            lastPingLocation = loc
            NetworkingService.shared.sendLocation(
                loc,
                activity: currentMotion,
                confidence: currentConfidence,
                force: true
            )
        }
    }

    /// Handles region monitoring failures gracefully.
    func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        #if DEBUG
        print("Region monitoring failed for \(region?.identifier ?? "nil"): \(error.localizedDescription)")
        #endif
        if region?.identifier == Self.geofenceIdentifier {
            tearDownGeofence()
        }
    }
}
