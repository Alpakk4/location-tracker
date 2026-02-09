//
//  LocationService.swift
//  location tracker
//
//  Created by Alex Skondras on 04/02/2026.
//

import Foundation
import CoreLocation

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentState: String = "STILL"
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
    }
    
    func stop() {
        print("Stopping location service")
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.lastLocation = loc
        }
        NetworkingService.shared.sendLocation(loc, activity: self.currentState)
    }
}
