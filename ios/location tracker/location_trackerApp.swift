//
//  location_trackerApp.swift
//  location tracker
//
//  Created by Joel on 01/09/2025.
//

import SwiftUI
import CoreLocation

struct MotionType: Codable {
    var motion: String
    var confidence: String
}

struct RequestPayload: Codable {
    var uid: String
    var lat: Double
    var long: Double
    var home_lat: Double?
    var home_long: Double?
    var motion: MotionType
}

@main
struct location_trackerApp: App {
    @StateObject private var locService = LocationService()
    @StateObject private var diaryService = DiaryService()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(locService)
                .environmentObject(diaryService)
                .onAppear {
                    print("hello world!!!!!")
                }
        }
    }
}

// MARK: - Tab Navigation

struct MainTabView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @EnvironmentObject var loc: LocationService

    var body: some View {
        if hasCompletedOnboarding {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Tracker", systemImage: "location.fill")
                    }
                DiaryView()
                    .tabItem {
                        Label("Diary", systemImage: "book.fill")
                    }
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

