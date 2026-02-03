//
//  ContentView.swift
//  location tracker
//
//  Created by Joel on 01/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let defaults = UserDefaults.standard
    @EnvironmentObject var loc: LocationService
    
    // --- Configuration State ---
    @State private var enableReporting = UserDefaults.standard.bool(forKey: ConfigurationKeys.enableReporting)
    @State private var endpoint = UserDefaults.standard.string(forKey: ConfigurationKeys.endpoint) ?? ""
    @State private var apikey = UserDefaults.standard.string(forKey: ConfigurationKeys.apikey) ?? ""
    @State private var uid = UserDefaults.standard.string(forKey: ConfigurationKeys.uid) ?? ""
    
    // --- Home Location State ---
    @State private var homeLat: Double? = UserDefaults.standard.object(forKey: "home_lat") as? Double
    @State private var homeLong: Double? = UserDefaults.standard.object(forKey: "home_long") as? Double
    @State private var isHomeSet: Bool = UserDefaults.standard.bool(forKey: "is_home_set")
    
    // --- Alert States ---
    @State private var showingPasswordAlert = false
    @State private var showingSetHomeAlert = false
    @State private var enteredPassword = ""
    
    var body: some View {
        VStack(spacing: 20) { // Added spacing for better flow
            
            // MARK: 1. Top Banner (Live Location)
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                
                if let last = loc.lastLocation {
                    VStack(alignment: .leading) {
                        Text("LAT: \(last.coordinate.latitude, specifier: "%.6f")")
                        Text("LON: \(last.coordinate.longitude, specifier: "%.6f")")
                    }
                    .font(.system(.subheadline, design: .monospaced)) // Monospaced prevents jitter
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
            .background(Color.blue.opacity(0.1)) // Subtle background
            .cornerRadius(12)
            
            // MARK: 2. Styled "Send Ping" Button
            Button(action: {
                if let last = loc.lastLocation {
                    NetworkingService.shared.sendLocation(last)
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
                // The Border Logic:
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 40) // Indent the button slightly
            .disabled(loc.lastLocation == nil)
            .opacity(loc.lastLocation == nil ? 0.6 : 1.0)
            
            Divider()
            
            // MARK: 3. Configuration Area
            ScrollView {
                VStack(spacing: 15) {
                    Toggle(isOn: $enableReporting) {
                        Label("Enable Background Reporting", systemImage: "timer")
                            .font(.headline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: enableReporting, initial: true) {
                        if enableReporting {
                            loc.start()
                            defaults.set(true, forKey: ConfigurationKeys.enableReporting)
                        } else {
                            loc.stop()
                            defaults.set(false, forKey: ConfigurationKeys.enableReporting)
                        }
                    }
                    
                    // Grouped Text Fields
                    VStack(spacing: 0) {
                        ConfigRow(title: "Endpoint", icon: "network", text: $endpoint) {
                            NetworkingService.shared.endpoint = endpoint
                            defaults.set(endpoint, forKey: ConfigurationKeys.endpoint)
                        }
                        Divider().padding(.leading)
                        ConfigRow(title: "API Key", icon: "key", text: $apikey) {
                            NetworkingService.shared.apikey = apikey
                            defaults.set(apikey, forKey: ConfigurationKeys.apikey)
                        }
                        Divider().padding(.leading)
                        ConfigRow(title: "User ID", icon: "person", text: $uid) {
                            NetworkingService.shared.uid = uid
                            defaults.set(uid, forKey: ConfigurationKeys.uid)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
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
                }
            }
        }
        .padding()
        // --- Alerts remain exactly the same ---
        .alert("Set Home Location?", isPresented: $showingSetHomeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                if let last = loc.lastLocation {
                    homeLat = last.coordinate.latitude
                    homeLong = last.coordinate.longitude
                    isHomeSet = true
                    defaults.set(homeLat, forKey: "home_lat")
                    defaults.set(homeLong, forKey: "home_long")
                    defaults.set(true, forKey: "is_home_set")
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
                    defaults.set(false, forKey: "is_home_set")
                }
                enteredPassword = ""
            }
        } message: {
            Text("Enter admin password to reset home coordinates.")
        }
    }
}

// Helper View to clean up the TextFields
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
                .onChange(of: text, initial: false) { onCommit() }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
