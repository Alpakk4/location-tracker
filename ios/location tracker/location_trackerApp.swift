//
//  location_trackerApp.swift
//  location tracker
//
//  Created by Joel on 01/09/2025.
//

import SwiftUI
import CoreLocation

struct RequestPayload: Codable {
    var uid: String
    var lat: Double
    var long: Double
    var home_lat: Double? // new
    var home_long: Double? // new
}

@main
struct location_trackerApp: App {
    @StateObject private var locService = LocationService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locService)
                .onAppear {
                    print("hello world!!!!!")
                }
        }
    }
}

