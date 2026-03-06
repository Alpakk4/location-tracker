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
    var horizontal_accuracy: Double
    var capturedAt: String?
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
                .transition(.opacity)
        }
    }
}

// MARK: - Tab Navigation

/// High-level app phase for the root view.
private enum RootPhase {
    case welcome
    case onboarding
    case main
}

struct MainTabView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @EnvironmentObject var loc: LocationService
    @State private var phase: RootPhase = .welcome

    var body: some View {
        Group {
            switch phase {
            case .welcome:
                WelcomeLoadingView()
            case .onboarding:
                OnboardingFlowView(hasCompletedOnboarding: $hasCompletedOnboarding)
            case .main:
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
            }
        }
        .task {
            await handleStartupPhaseIfNeeded()
        }
        .onChange(of: hasCompletedOnboarding) {
            if hasCompletedOnboarding && phase == .onboarding {
                withAnimation {
                    phase = .main
                }
            }
        }
    }

    /// Ensures the welcome/loading screen is shown briefly, then transitions
    /// into onboarding or the main app depending on completion state.
    private func handleStartupPhaseIfNeeded() async {
        if phase != .welcome {
            // App has already moved past the welcome phase; just ensure
            // the correct destination based on the latest onboarding flag.
            phase = hasCompletedOnboarding ? .main : .onboarding
            return
        }

        // Minimum welcome display time (in nanoseconds).
        let minimumDelay: UInt64 = 1_500_000_000 // 1.5 seconds
        try? await Task.sleep(nanoseconds: minimumDelay)

        await MainActor.run {
            withAnimation {
                phase = hasCompletedOnboarding ? .main : .onboarding
            }
        }
    }
}

// MARK: - Welcome / Loading Screen

struct WelcomeLoadingView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)

                Text("Welcome to pingLo")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Preparing your activity diary experience…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(.circular)

                Text("This should only take a moment.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

