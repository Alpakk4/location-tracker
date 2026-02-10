//
//  DiaryService.swift
//  location tracker
//
//  Manages diary lifecycle: fetch from Supabase, local persistence, and submission.
//

import Foundation
import SwiftUI

@MainActor
class DiaryService: ObservableObject {

    @Published var diaryDays: [DiaryDay] = []
    @Published var selectedDiaryDay: DiaryDay?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let storage = DiaryStorage.shared

    init() {
        loadLocalDiaries()
    }

    // MARK: - Local Data

    func loadLocalDiaries() {
        diaryDays = storage.loadAllDiaryDays()
    }

    func saveDiaryDay(_ day: DiaryDay) {
        storage.saveDiaryDay(day)
        loadLocalDiaries()
    }

    // MARK: - Local-First Loading

    /// Loads diary from local storage if available; fetches from Supabase only if no local copy exists.
    func loadOrFetchDiary(deviceId: String, date: String) async {
        // Check local storage first
        if let local = storage.loadDiaryDay(date: date), local.deviceId == deviceId {
            selectedDiaryDay = local
            return
        }
        // No local diary – fetch from server
        await fetchDiary(deviceId: deviceId, date: date)
        // After fetch, set selectedDiaryDay from whatever was saved locally
        selectedDiaryDay = storage.loadDiaryDay(date: date)
    }

    // MARK: - Environment Helpers

    /// Base URL for Supabase edge functions, e.g. "https://xxx.supabase.co/functions/v1/"
    private func functionsBaseURL() -> String {
        return Environment.endpoint
    }

    private func apiKey() -> String {
        return Environment.apikey
    }

    // MARK: - Fetch Diary (calls diary-maker)

    func fetchDiary(deviceId: String, date: String) async {
        let base = functionsBaseURL()
        let urlString = "\(base)diary-maker"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid diary-maker URL"
            return
        }

        isLoading = true
        errorMessage = nil

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey()
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue(key, forHTTPHeaderField: "apikey")

        let body: [String: String] = ["deviceId": deviceId, "date": date]
        do {
            req.httpBody = try JSONEncoder().encode(body)
        } catch {
            isLoading = false
            errorMessage = "Failed to encode request"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                isLoading = false
                errorMessage = "Invalid response"
                return
            }

            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                isLoading = false
                errorMessage = "Server error \(http.statusCode): \(body)"
                return
            }

            let rawEntries = try JSONDecoder().decode([DiaryMakerEntry].self, from: data)

            // Transform raw entries (visit clusters) into DiaryEntry with activity labels
            let entries: [DiaryEntry] = rawEntries.map { raw in
                DiaryEntry(
                    id: raw.entryid,
                    createdAt: raw.created_at,
                    endedAt: raw.ended_at,
                    clusterDurationSeconds: raw.cluster_duration_s,
                    primaryType: raw.primary_type,
                    otherTypes: raw.other_types,
                    motionType: raw.motion_type,
                    visitConfidence: raw.visit_confidence,
                    pingCount: raw.ping_count,
                    confirmedPlace: nil,
                    confirmedActivity: nil,
                    activityLabel: PlaceActivityMapping.activityLabel(for: raw.primary_type),
                    userContext: nil
                )
            }

            let dayId = "\(deviceId)_\(date)"

            // If a local diary already exists for this date, merge: keep answered entries
            if var existing = storage.loadDiaryDay(date: date), existing.deviceId == deviceId {
                let existingById = Dictionary(uniqueKeysWithValues: existing.entries.map { ($0.id, $0) })
                let merged = entries.map { entry -> DiaryEntry in
                    if let prev = existingById[entry.id] {
                        return prev  // keep previous answers
                    }
                    return entry
                }
                existing.entries = merged
                storage.saveDiaryDay(existing)
            } else {
                let diaryDay = DiaryDay(id: dayId, deviceId: deviceId, date: date, entries: entries)
                storage.saveDiaryDay(diaryDay)
            }

            loadLocalDiaries()
            selectedDiaryDay = storage.loadDiaryDay(date: date)
            isLoading = false

        } catch {
            isLoading = false
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }

    // MARK: - Submit Completed Diary (calls diary-submit)

    func submitCompletedDiary(_ diaryDay: DiaryDay) async -> Bool {
        guard diaryDay.isCompleted else {
            errorMessage = "Diary is not fully completed"
            return false
        }

        let base = functionsBaseURL()
        let urlString = "\(base)diary-submit"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid diary-submit URL"
            return false
        }

        isLoading = true
        errorMessage = nil

        let submitEntries = diaryDay.entries.map { entry in
            DiarySubmitEntry(
                source_entryid: entry.id,
                primary_type: entry.primaryType,
                activity_label: entry.activityLabel,
                confirmed_place: entry.confirmedPlace ?? false,
                confirmed_activity: entry.confirmedActivity ?? false,
                user_context: entry.userContext,
                motion_type: entry.motionType,
                visit_confidence: entry.visitConfidence,
                ping_count: entry.pingCount,
                cluster_duration_s: entry.clusterDurationSeconds
            )
        }

        let payload = DiarySubmitPayload(
            deviceId: diaryDay.deviceId,
            date: diaryDay.date,
            entries: submitEntries
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey()
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue(key, forHTTPHeaderField: "apikey")

        do {
            req.httpBody = try JSONEncoder().encode(payload)
        } catch {
            isLoading = false
            errorMessage = "Failed to encode submission"
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                isLoading = false
                errorMessage = "Invalid response"
                return false
            }

            if http.statusCode == 201 {
                // Success – delete local data
                storage.deleteDiaryDay(date: diaryDay.date)
                loadLocalDiaries()
                isLoading = false
                return true
            } else {
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                isLoading = false
                errorMessage = "Submit failed \(http.statusCode): \(body)"
                return false
            }
        } catch {
            isLoading = false
            errorMessage = "Network error: \(error.localizedDescription)"
            return false
        }
    }
}
