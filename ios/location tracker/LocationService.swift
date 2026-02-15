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

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        // Limit callback frequency so capture is useful without excessive upload churn.
        manager.distanceFilter = 10
        // Keep high accuracy because diary clustering benefits from precise coordinates.
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

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
            self.currentMotion = self.mapActivity(activity)
            self.currentConfidence = self.mapConfidence(activity.confidence)
            #if DEBUG
            print("Activity updated: \(self.currentMotion) (\(self.currentConfidence))")
            #endif
        }
    }

    /// Stops all active sensors owned by this service.
    func stop() {
        #if DEBUG
        print("Stopping location service")
        #endif
        manager.stopUpdatingLocation()
        activityManager.stopActivityUpdates()
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
        NetworkingService.shared.sendLocation(loc, activity: self.currentMotion, confidence: self.currentConfidence)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
