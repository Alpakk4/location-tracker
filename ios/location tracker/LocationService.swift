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
    private let geofenceRadius: CLLocationDistance = 75.0
    private static let geofenceIdentifier = "current-visit"
    /// Tracks whether the previous motion update was STILL, to detect transitions.
    private var wasStationary = false
    
    /// Only send pings when horizontal accuracy is within this threshold (meters).
    private let maxHorizontalAccuracyForPing: CLLocationAccuracy = 50

    // MARK: - Motion debouncing properties
    private var debounceTimer: Timer?
    private var pendingMotion: String?
    private var pendingConfidence: String?
    private let debounceInterval: TimeInterval = 5.0

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        // Limit callback frequency so capture is useful without excessive upload churn.
        manager.distanceFilter = 30
        // Keep high accuracy because diary clustering benefits from precise coordinates.
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

    /// Starts both location callbacks and motion activity updates.
    /// If motion is unavailable, location still continues.
    func start() {
        #if DEBUG
        print("Starting location service")
        #endif
        manager.startUpdatingLocation()

        guard CMMotionActivityManager.isActivityAvailable() else {
            #if DEBUG
            print("Motion activity not available on this device")
            #endif
            return
        }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            let newMotion = self.mapActivity(activity)
            let newConfidence = self.mapConfidence(activity.confidence)

            self.updateDistanceFilter(for: newMotion)

            // Geofence lifecycle: register when becoming STILL, tear down when leaving STILL.
            // Use raw motion value (not debounced) for responsive geofence management.
            let isNowStationary = (newMotion == "STILL")
            if isNowStationary && !self.wasStationary {
                // Transition into STILL — register a geofence at current location
                if let loc = self.lastLocation {
                    self.registerVisitGeofence(at: loc)
                }
            } else if !isNowStationary && self.wasStationary {
                // Transition out of STILL — tear down any active geofence
                self.tearDownGeofence()
            }
            self.wasStationary = isNowStationary

            // Debounce motion status updates for smooth UI and reduced networking churn.
            // Allow immediate update on first state (when still in initial state).
            let isInitialState = (self.currentMotion == "STILL" && self.currentConfidence == "unknown")
            
            if isInitialState {
                // First update: apply immediately without debouncing
                DispatchQueue.main.async {
                    self.currentMotion = newMotion
                    self.currentConfidence = newConfidence
                }
                #if DEBUG
                print("Activity updated (initial): \(newMotion) (\(newConfidence))")
                #endif
            } else {
                // Subsequent updates: debounce
                self.pendingMotion = newMotion
                self.pendingConfidence = newConfidence
                
                // Cancel existing timer
                self.debounceTimer?.invalidate()
                
                // Create new timer on main queue
                DispatchQueue.main.async {
                    self.debounceTimer = Timer.scheduledTimer(withTimeInterval: self.debounceInterval, repeats: false) { [weak self] _ in
                        guard let self = self,
                              let motion = self.pendingMotion,
                              let confidence = self.pendingConfidence else { return }
                        
                        self.currentMotion = motion
                        self.currentConfidence = confidence
                        self.pendingMotion = nil
                        self.pendingConfidence = nil
                        
                        if let loc = self.lastLocation {
                            NetworkingService.shared.sendLocation(loc, activity: motion, confidence: confidence, force: true)
                        }
                        
                        #if DEBUG
                        print("Activity updated (debounced): \(motion) (\(confidence))")
                        #endif
                    }
                }
            }
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
        
        // Cancel debounce timer and apply any pending updates
        debounceTimer?.invalidate()
        debounceTimer = nil
        if let pendingMotion = pendingMotion, let pendingConfidence = pendingConfidence {
            DispatchQueue.main.async {
                self.currentMotion = pendingMotion
                self.currentConfidence = pendingConfidence
                self.pendingMotion = nil
                self.pendingConfidence = nil
            }
        }
    }

    // MARK: - Geofence (visit boundary detection)

    /// Registers a circular geofence at the given location to detect when the user leaves a visit.
    /// iOS region monitoring is battery-efficient (cell/WiFi, not continuous GPS) and supports up to 20 regions.
    private func registerVisitGeofence(at location: CLLocation) {
        // Only one visit geofence at a time
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
    private func updateDistanceFilter(for motion: String) {
        switch motion {
        case "STILL":       manager.distanceFilter = 50
        case "WALKING", "RUNNING": manager.distanceFilter = 20
        case "AUTOMOTIVE":  manager.distanceFilter = 100
        case "CYCLING", "UNKNOWN": fallthrough
        default:            manager.distanceFilter = 30
        }
    }

    /// Maps confidence enum to lowercase labels expected by downstream services.
    private func mapConfidence(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low:    return "low"
        case .medium: return "medium"
        case .high:   return "high"
        @unknown default: return "unknown"
        }
    }

    // MARK: - CLLocationManagerDelegate

    /// Forwards the latest location together with current motion context.
    /// Contract: `lastLocation` updates on main queue for UI observation.
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc
        }
        let accuracyOk = loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy <= maxHorizontalAccuracyForPing
        if accuracyOk {
            NetworkingService.shared.sendLocation(loc, activity: self.currentMotion, confidence: self.currentConfidence)
        }
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

        // Force an immediate ping to mark the visit exit boundary.
        if let loc = manager.location {
            #if DEBUG
            print("Geofence exit detected — sending forced boundary ping")
            #endif
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
