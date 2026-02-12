import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    // Persistent state to track if onboarding is done
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    @EnvironmentObject var loc: LocationService
    let defaults = UserDefaults.standard
    
    // --- Configuration State ---
    @State private var enableReporting = UserDefaults.standard.bool(forKey: ConfigurationKeys.enableReporting)
    @State private var uid = SecureStore.getString(for: .uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
        ?? ""
    
    // --- Home Location State ---
    @State private var homeLat: Double? = SecureStore.getDouble(for: .homeLatitude)
    @State private var homeLong: Double? = SecureStore.getDouble(for: .homeLongitude)
    @State private var isHomeSet: Bool = UserDefaults.standard.bool(forKey: ConfigurationKeys.isHomeSet)
    
    // --- User ID Lock State ---
    @State private var isUidLocked: Bool = !(SecureStore.getString(for: .uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
        ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
        ?? "").isEmpty
    @State private var showingUidPasswordAlert = false
    @State private var uidEnteredPassword = ""
    
    // --- Alert States ---
    @State private var showingPasswordAlert = false
    @State private var showingSetHomeAlert = false
    @State private var enteredPassword = ""
    
    // --- Wobble State ---
    @State private var homeWobble = false
    @State private var uidWobble = false

    var body: some View {
        mainAppContent
    }

    // MARK: - Main App UI
    var mainAppContent: some View {
        VStack(spacing: 20) {
            
            // MARK: 1. Top Banner (Live Location)
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                
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
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            // MARK: 2. Styled "Send Ping" Button
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
                .foregroundColor(.blue)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 40)
            .disabled(loc.lastLocation == nil)
            .opacity(loc.lastLocation == nil ? 0.6 : 1.0)
            
            Divider()
            
            // MARK: 3. Configuration Area
            ScrollView {
                VStack(spacing: 15) {
                    Toggle(isOn: $enableReporting) {
                        Label("Location Sharing is \(enableReporting ? "ON" : "OFF")", systemImage: "timer")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: enableReporting) {
                        if enableReporting {
                            loc.start()
                            defaults.set(true, forKey: ConfigurationKeys.enableReporting)
                        } else {
                            loc.stop()
                            defaults.set(false, forKey: ConfigurationKeys.enableReporting)
                        }
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
                                        NetworkingService.shared.uid = uid
                                        defaults.set(uid, forKey: ConfigurationKeys.uid)
                                        if uid.isEmpty {
                                            _ = SecureStore.remove(.uid)
                                        } else {
                                            _ = SecureStore.setString(uid, for: .uid)
                                        }
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
                        .disabled(loc.lastLocation == nil || isHomeSet)
                        .tint(isHomeSet ? .gray : .blue)
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
            // Keep reporting behavior consistent across cold launch and toggle changes.
            if let legacyUid = defaults.string(forKey: ConfigurationKeys.legacyUid),
               defaults.string(forKey: ConfigurationKeys.uid) == nil {
                uid = legacyUid
                defaults.set(legacyUid, forKey: ConfigurationKeys.uid)
                _ = SecureStore.setString(legacyUid, for: .uid)
                defaults.removeObject(forKey: ConfigurationKeys.legacyUid)
            }
            NetworkingService.shared.uid = uid.isEmpty ? nil : uid
            if enableReporting {
                loc.start()
            } else {
                loc.stop()
            }
        }
        .alert("Set Home Location?", isPresented: $showingSetHomeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                if let last = loc.lastLocation {
                    homeLat = last.coordinate.latitude
                    homeLong = last.coordinate.longitude
                    isHomeSet = true
                    _ = SecureStore.setDouble(last.coordinate.latitude, for: .homeLatitude)
                    _ = SecureStore.setDouble(last.coordinate.longitude, for: .homeLongitude)
                    defaults.set(true, forKey: ConfigurationKeys.isHomeSet)
                }
            }
        } message: {
            Text("This action can only be performed once. Are you sure?")
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

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var loc: LocationService
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "location.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("Enable Background Tracking")
                .font(.title).bold()
            
            Text("This app maps your activity diary. To work correctly, it needs access to your location even when the app is closed.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Image(systemName: "1.circle.fill").foregroundColor(.blue)
                    Text("Select **'Allow While Using App'** when prompted.")
                }
                HStack(alignment: .top) {
                    Image(systemName: "2.circle.fill").foregroundColor(.blue)
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onChange(of: loc.authorizationStatus) {
            if loc.authorizationStatus == .authorizedAlways || loc.authorizationStatus == .authorizedWhenInUse {
                hasCompletedOnboarding = true
            }
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
                .onChange(of: text) { onCommit() }
        }
        .padding()
    }
}
#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(DiaryService())
}

