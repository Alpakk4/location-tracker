//
//  LocationService.swift
//  location tracker
//
//  Created by Alex Skondras on 04/02/2026.
//

import Foundation
import CoreLocation
import CoreMotion

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let activityManager = CMMotionActivityManager()
    @Published var currentMotion: String = "STILL"
    @Published var currentConfidence: String = "unknown"
    @Published var lastLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        // Optional: Only trigger if moved 10 meters (doesn't consider elevation)
        manager.distanceFilter = 10
        //10m & 5 minute timer limit will prevent the actual network calls from being too frequent. Despite high request for accuracy
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuth() {
        print("requesting location service auth")
        manager.requestAlwaysAuthorization()
    }
    
    func start() {
        print("Starting location service")
        manager.startUpdatingLocation()
        
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity not available on this device")
            return
        }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            self.currentMotion = self.mapActivity(activity)
            self.currentConfidence = self.mapConfidence(activity.confidence)
            print("Activity updated: \(self.currentMotion) (\(self.currentConfidence))")
        }
    }
    
    func stop() {
        print("Stopping location service")
        manager.stopUpdatingLocation()
        activityManager.stopActivityUpdates()
    }
    
    private func mapActivity(_ activity: CMMotionActivity) -> String {
        if activity.walking    { return "WALKING" }
        if activity.running    { return "RUNNING" }
        if activity.cycling    { return "CYCLING" }
        if activity.automotive { return "AUTOMOTIVE" }
        if activity.stationary { return "STILL" }
        return "UNKNOWN"
    }
    
    private func mapConfidence(_ confidence: CMMotionActivityConfidence) -> String {
        switch confidence {
        case .low:    return "low"
        case .medium: return "medium"
        case .high:   return "high"
        @unknown default: return "unknown"
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc
        }
        NetworkingService.shared.sendLocation(loc, activity: self.currentMotion, confidence: self.currentConfidence)
    }
}
