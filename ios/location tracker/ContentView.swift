import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    // Persistent state to track if onboarding is done
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    @EnvironmentObject var loc: LocationService
    let defaults = UserDefaults.standard
    
    // --- Configuration State ---
    @State private var enableReporting: Bool = {
        if UserDefaults.standard.object(forKey: ConfigurationKeys.enableReporting) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: ConfigurationKeys.enableReporting)
    }()
    @State private var uid = UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
        ?? ""
    
    // --- Pause Timer State ---
    @State private var isPaused: Bool = false
    @State private var pauseEndTime: Date?
    @State private var pauseTask: Task<Void, Never>?
    
    // --- Home Location State ---
    @State private var homeLat: Double? = SecureStore.getDouble(for: .homeLatitude)
    @State private var homeLong: Double? = SecureStore.getDouble(for: .homeLongitude)
    @State private var isHomeSet: Bool = UserDefaults.standard.bool(forKey: ConfigurationKeys.isHomeSet)
    
    // --- User ID Lock State ---
    @State private var isUidLocked: Bool = !(UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
        ?? "").isEmpty
    @State private var showingUidPasswordAlert = false
    @State private var uidEnteredPassword = ""
    
    // --- Alert States ---
    @State private var showingPasswordAlert = false
    @State private var showingSetHomeAlert = false
    @State private var showingDeviceIdRequiredAlert = false
    @State private var enteredPassword = ""
    
    // --- Backfill State ---
    @State private var isBackfilling = false
    @State private var showingBackfillAlert = false
    @State private var backfillMessage = ""
    
    // --- Wobble State ---
    @State private var homeWobble = false
    @State private var uidWobble = false
    
    // --- Refresh State ---
    @State private var isRefreshingFromDefaults = false
    
    // MARK: - Refresh Function
    private func refreshFromUserDefaults() {
        isRefreshingFromDefaults = true
        defer { isRefreshingFromDefaults = false }
        
        if UserDefaults.standard.object(forKey: ConfigurationKeys.enableReporting) == nil {
            enableReporting = false
        } else {
            enableReporting = UserDefaults.standard.bool(forKey: ConfigurationKeys.enableReporting)
        }
        
        // Refresh uid
        let refreshedUid = UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
            ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
            ?? ""
        if refreshedUid != uid {
            uid = refreshedUid
        }
        
        // Refresh home location
        homeLat = SecureStore.getDouble(for: .homeLatitude)
        homeLong = SecureStore.getDouble(for: .homeLongitude)
        isHomeSet = UserDefaults.standard.bool(forKey: ConfigurationKeys.isHomeSet)
        
        // Refresh uid lock state
        isUidLocked = !refreshedUid.isEmpty
    }
    
    // MARK: - Pause Countdown Formatting

    private func formatCountdown(until endTime: Date, now: Date) -> String {
        let remaining = max(0, endTime.timeIntervalSince(now))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Pause Timer Functions
    private func startPauseTimer() {
        // Cancel any existing task
        pauseTask?.cancel()
        
        // Set pause end time to 25 minutes from now
        let endTime = Date().addingTimeInterval(25 * 60) // 25 minutes = 1500 seconds
        pauseEndTime = endTime
        
        // Store pause end time in UserDefaults for persistence
        defaults.set(endTime, forKey: ConfigurationKeys.pauseEndTime)
        
        // Set paused state
        isPaused = true
        
        // Stop location services
        loc.stop()
        
        // Create async task to auto-resume after 25 minutes
        pauseTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(25 * 60 * 1_000_000_000))
                // Check if task was cancelled
                if !Task.isCancelled {
                    cancelPause()
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
        
        #if DEBUG
        print("Started 25-minute pause timer, will resume at \(endTime)")
        #endif
    }
    
    private func cancelPause() {
        // Cancel task
        pauseTask?.cancel()
        pauseTask = nil
        
        // Clear pause state
        isPaused = false
        pauseEndTime = nil
        
        // Clear stored pause end time
        defaults.removeObject(forKey: ConfigurationKeys.pauseEndTime)
        
        // Resume location services (onChange will handle loc.start() when enableReporting is set)
        enableReporting = true
        defaults.set(true, forKey: ConfigurationKeys.enableReporting)
        
        #if DEBUG
        print("Pause cancelled, location services resumed")
        #endif
    }
    
    private func restorePauseIfNeeded() {
        // Check if there's a stored pause end time
        if let storedEndTime = defaults.object(forKey: ConfigurationKeys.pauseEndTime) as? Date {
            let now = Date()
            if storedEndTime > now {
                // Pause is still active, restore it
                pauseEndTime = storedEndTime
                isPaused = true
                
                // Ensure enableReporting reflects paused state
                enableReporting = false
                
                // Calculate remaining time
                let remainingTime = storedEndTime.timeIntervalSince(now)
                
                // Create async task for remaining time
                pauseTask = Task { @MainActor in
                    do {
                        try await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
                        // Check if task was cancelled
                        if !Task.isCancelled {
                            cancelPause()
                        }
                    } catch {
                        // Task was cancelled, do nothing
                    }
                }
                
                // Ensure location services are stopped
                loc.stop()
                
                #if DEBUG
                print("Restored pause timer, will resume in \(remainingTime) seconds")
                #endif
            } else {
                // Pause time has passed, clear it
                defaults.removeObject(forKey: ConfigurationKeys.pauseEndTime)
                isPaused = false
                pauseEndTime = nil
                
                // Ensure location services are running
                enableReporting = true
                defaults.set(true, forKey: ConfigurationKeys.enableReporting)
                
                #if DEBUG
                print("Pause time expired, location services resumed")
                #endif
            }
        }
    }

    var body: some View {
        mainAppContent
    }

    // MARK: - Main App UI
    var mainAppContent: some View {
        VStack(spacing: 20) {
            
            // MARK: 1. Top Banner (Live Location)
            HStack {
                Image("PingloIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                
                if let last = loc.lastLocation {
                    VStack(alignment: .leading) {
                        Text("LAT: \(last.coordinate.latitude, specifier: "%.6f")")
                        Text("LON: \(last.coordinate.longitude, specifier: "%.6f")")
                    }
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                } else {
                    Text("Acquiring GPS Signal...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ProgressView().scaleEffect(0.8)
                }
                Spacer()
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: 2. Styled "Send Ping" Button
            #if DEBUG
            Button(action: {
                if let last = loc.lastLocation {
                    NetworkingService.shared.sendLocation(last, activity: loc.currentMotion, confidence: loc.currentConfidence, force: true)
                }
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("SEND PING")
                        .fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .foregroundColor(.purple)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.purple, lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 40)
            .disabled(loc.lastLocation == nil)
            .opacity(loc.lastLocation == nil ? 0.6 : 1.0)
            #endif
            Divider()
            
            // MARK: 3. Configuration Area
            ScrollView {
                VStack(spacing: 15) {
                    Toggle(isOn: $enableReporting) {
                        Label("Location Sharing is \(isPaused ? "PAUSED" : (enableReporting ? "ON" : "OFF"))", systemImage: "timer")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .disabled(isPaused)
                    .tint(.mint)
                    .opacity(isPaused ? 0.6 : 1.0)
                    .onChange(of: enableReporting) {
                        guard !isRefreshingFromDefaults else { return }
                        if enableReporting {
                            if uid.trimmingCharacters(in: .whitespaces).isEmpty {
                                enableReporting = false
                                showingDeviceIdRequiredAlert = true
                                return
                            }
                            if isPaused {
                                cancelPause()
                            } else {
                                loc.start()
                                defaults.set(true, forKey: ConfigurationKeys.enableReporting)
                            }
                        } else {
                            startPauseTimer()
                            defaults.set(false, forKey: ConfigurationKeys.enableReporting)
                        }
                    }
                    
                    if isPaused {
                        VStack(spacing: 6) {
                            if let endTime = pauseEndTime {
                                TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                                    Label(
                                        "Resuming in \(formatCountdown(until: endTime, now: context.date))",
                                        systemImage: "clock"
                                    )
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                            }

                            Button(action: {
                                cancelPause()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Resume Now")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                        }
                        .padding(.top, -10)
                    }
                    
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: isUidLocked ? "lock.fill" : "person")
                                .foregroundColor(isUidLocked ? .orange : .gray)
                                .frame(width: 20)
                            if isUidLocked {
                                Text(uid)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                TextField("Device ID", text: $uid)
                                    .onChange(of: uid) {
                                        guard !isRefreshingFromDefaults else { return }
                                        NetworkingService.shared.uid = uid
                                        defaults.set(uid, forKey: ConfigurationKeys.uid)
                                    }
                                    .onSubmit {
                                        if !uid.isEmpty {
                                            isUidLocked = true
                                        }
                                    }
                            }
                        }
                        .padding()
                        .onLongPressGesture {
                            if isUidLocked {
                                showingUidPasswordAlert = true
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .offset(x: uidWobble ? -10 : 0)
                    .animation(
                        uidWobble
                            ? .default.repeatCount(5, autoreverses: true).speed(6)
                            : .default,
                        value: uidWobble
                    )
                    .padding(.bottom)
                    
                    // MARK: 4. Home Location Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Home Location", systemImage: "house")
                                .font(.headline)
                            Spacer()
                            if isHomeSet {
                                Menu {
                                    Button(role: .destructive) { showingPasswordAlert = true } label: {
                                        Label("Unlock Settings", systemImage: "lock.open")
                                    }
                                } label: {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                        .padding(6)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        
                        if let hLat = homeLat, let hLong = homeLong {
                            Text("\(hLat, specifier: "%.4f"), \(hLong, specifier: "%.4f")")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No home set").font(.caption).foregroundColor(.red)
                        }
                        
                        Button(action: { showingSetHomeAlert = true }) {
                            Text(isHomeSet ? "Home Locked" : "Set Current as Home")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(loc.lastLocation == nil || isHomeSet || isBackfilling)
                        .tint(isHomeSet ? .green : .purple)
                        
                        if isBackfilling {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Updating historical records...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .offset(x: homeWobble ? -10 : 0)
                    .animation(
                        homeWobble
                            ? .default.repeatCount(5, autoreverses: true).speed(6)
                            : .default,
                        value: homeWobble
                    )
                }
            }
        }
        .padding()
        .onAppear {
            // Refresh all state from User Defaults first
            refreshFromUserDefaults()
            
            // Keep reporting behavior consistent across cold launch and toggle changes.
            if let legacyUid = defaults.string(forKey: ConfigurationKeys.legacyUid),
               defaults.string(forKey: ConfigurationKeys.uid) == nil {
                uid = legacyUid
                defaults.set(legacyUid, forKey: ConfigurationKeys.uid)
                defaults.removeObject(forKey: ConfigurationKeys.legacyUid)
            }
            NetworkingService.shared.uid = uid.isEmpty ? nil : uid
            
            // Restore pause state if needed (checks stored pause end time)
            restorePauseIfNeeded()
            
            if enableReporting && !isPaused {
                loc.start()
            } else {
                loc.stop()
            }
        }
        .onDisappear {
            // Clean up task when view disappears
            pauseTask?.cancel()
            pauseTask = nil
        }
        .alert("Set Home Location?", isPresented: $showingSetHomeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                if let last = loc.lastLocation {
                    let lat = last.coordinate.latitude
                    let lng = last.coordinate.longitude
                    homeLat = lat
                    homeLong = lng
                    isHomeSet = true
                    isBackfilling = true
                    _ = SecureStore.setDouble(lat, for: .homeLatitude)
                    _ = SecureStore.setDouble(lng, for: .homeLongitude)
                    defaults.set(true, forKey: ConfigurationKeys.isHomeSet)

                    NetworkingService.shared.callBackfillReframeHome(homeLat: lat, homeLong: lng) { result in
                        DispatchQueue.main.async {
                            isBackfilling = false
                            switch result {
                            case .success(let count):
                                backfillMessage = "Updated \(count) historical records with new home."
                            case .failure(let error):
                                backfillMessage = "Backfill failed: \(error.localizedDescription)"
                            }
                            showingBackfillAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("This action can only be performed once. Are you sure?")
        }
        .alert("Home Backfill", isPresented: $showingBackfillAlert) {
            Button("OK") { }
        } message: {
            Text(backfillMessage)
        }
        .alert("Admin Access", isPresented: $showingPasswordAlert) {
            SecureField("Enter Password", text: $enteredPassword)
            Button("Cancel", role: .cancel) { enteredPassword = "" }
            Button("Unlock") {
                if enteredPassword == Environment.adminPassword {
                    isHomeSet = false
                    homeLat = nil
                    homeLong = nil
                    _ = SecureStore.remove(.homeLatitude)
                    _ = SecureStore.remove(.homeLongitude)
                    defaults.set(false, forKey: ConfigurationKeys.isHomeSet)
                } else {
                    // Wrong password – trigger wobble
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        homeWobble = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            homeWobble = false
                        }
                    }
                }
                enteredPassword = ""
            }
        } message: {
            Text("Enter admin password to reset home coordinates.")
        }
        .alert("Device ID Required", isPresented: $showingDeviceIdRequiredAlert) {
            Button("OK") { }
        } message: {
            Text("Must set Device ID before starting location services for the first time.")
        }
        .alert("Unlock Device ID", isPresented: $showingUidPasswordAlert) {
            SecureField("Enter Password", text: $uidEnteredPassword)
            Button("Cancel", role: .cancel) { uidEnteredPassword = "" }
            Button("Unlock") {
                if uidEnteredPassword == Environment.adminPassword {
                    isUidLocked = false
                } else {
                    // Wrong password – trigger wobble
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        uidWobble = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            uidWobble = false
                        }
                    }
                }
                uidEnteredPassword = ""
            }
        } message: {
            Text("Enter admin password to unlock Device ID.")
        }
    }
}

// MARK: - Onboarding

enum OnboardingStep {
    case location
    case motion
    case deviceId
}

struct OnboardingFlowView: View {
    @EnvironmentObject var loc: LocationService
    @Binding var hasCompletedOnboarding: Bool
    @State private var step: OnboardingStep = .location

    var body: some View {
        switch step {
        case .location:
            locationStep
        case .motion:
            motionStep
        case .deviceId:
            deviceIdStep
        }
    }

    // Step 1: Location permission — advance to motion when authorized.
    private var locationStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image("PingloIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)

            Text("Enable Background Tracking")
                .font(.title).bold()

            Text("This app maps your activity diary. To work correctly, it needs access to your location even when the app is closed.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Image(systemName: "1.circle.fill").foregroundColor(.purple)
                    Text("Select **'Allow While Using App'** when prompted.")
                }
                HStack(alignment: .top) {
                    Image(systemName: "2.circle.fill").foregroundColor(.purple)
                    Text("Then, go to **Settings > Apps > pingLo > Location** and set it to **'Always'**.")
                }
            }
            .font(.subheadline)
            .padding(.horizontal)

            Spacer()

            Button(action: {
                loc.requestAuth()
            }) {
                Text("Enable Always Access")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onChange(of: loc.authorizationStatus) {
            if loc.authorizationStatus == .authorizedAlways || loc.authorizationStatus == .authorizedWhenInUse {
                step = .motion
            }
        }
    }

    // Step 2: Motion permission — set hasCompletedOnboarding when done (or Continue if unavailable).
    private var motionStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "figure.walk.motion")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.purple)

            Text("Enable Activity Detection")
                .font(.title).bold()

            if loc.isMotionAvailable {
                Text("Knowing whether you're walking, driving, or still helps build a better activity diary. Allow access when prompted.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .foregroundColor(.secondary)
            } else {
                Text("Activity detection is not available on this device.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                loc.ensureMotionPermission {
                    step = .deviceId
                }
            }) {
                Text(loc.isMotionAvailable ? "Enable Motion & Fitness" : "Continue")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // Step 3: Device ID — must be set before accessing the main app.
    @State private var onboardingDeviceId: String = ""

    private var deviceIdStep: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "person.text.rectangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.purple)

            Text("What is this device id?")
                .font(.title).bold()

            Text("Enter the identifier for this device. This is required before you can start using the app.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)

            HStack {
                TextField("Device ID", text: $onboardingDeviceId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button(action: {
                    let trimmed = onboardingDeviceId.trimmingCharacters(in: .whitespaces)
                    UserDefaults.standard.set(trimmed, forKey: ConfigurationKeys.uid)
                    NetworkingService.shared.uid = trimmed
                    hasCompletedOnboarding = true
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .foregroundColor(onboardingDeviceId.trimmingCharacters(in: .whitespaces).isEmpty ? .purple : .green)
                }
                .disabled(onboardingDeviceId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Helper Views
struct ConfigRow: View {
    let title: String
    let icon: String
    @Binding var text: String
    var onCommit: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            TextField(title, text: $text)
                .onChange(of: text) { _, _ in onCommit() }
        }
        .padding()
    }
}
#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(DiaryService())
}

