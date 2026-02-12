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
    private let submittedDatesKey = "diary_submitted_dates"

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

    // MARK: - Submission Tracking

    func recordSubmission(date: String) {
        var dates = submittedDates()
        dates.insert(date)
        UserDefaults.standard.set(Array(dates), forKey: submittedDatesKey)
    }

    func submittedDates() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: submittedDatesKey) ?? []
        return Set(arr)
    }

    func hasBeenSubmitted(date: String) -> Bool {
        submittedDates().contains(date)
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
        // After fetch, set selectedDiaryDay from storage if available.
        // If fetchDiary already set a transient empty selectedDiaryDay, don't overwrite it.
        if let saved = storage.loadDiaryDay(date: date) {
            selectedDiaryDay = saved
        }
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

            // Check if the server says this diary was already submitted
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alreadySubmitted = json["already_submitted"] as? Bool,
               alreadySubmitted {
                // Record locally so we don't ask again
                recordSubmission(date: date)
                isLoading = false
                selectedDiaryDay = nil
                return
            }

            let makerResponse = try JSONDecoder().decode(DiaryMakerResponse.self, from: data)

            // Transform raw entries (visit clusters) into DiaryEntry with activity labels
            let entries: [DiaryEntry] = makerResponse.visits.map { raw in
                DiaryEntry(
                    id: raw.entryid,
                    entryIds: raw.entry_ids,
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

            // Transform raw journeys into DiaryJourney
            let journeys: [DiaryJourney] = makerResponse.journeys.map { raw in
                DiaryJourney(
                    id: raw.journey_id,
                    entryIds: raw.entry_ids,
                    fromVisitId: raw.from_visit_id,
                    toVisitId: raw.to_visit_id,
                    primaryTransport: raw.primary_transport,
                    transportProportions: raw.transport_proportions,
                    startedAt: raw.started_at,
                    endedAt: raw.ended_at,
                    journeyDurationSeconds: raw.journey_duration_s,
                    pingCount: raw.ping_count,
                    confirmedTransport: nil,
                    travelReason: nil
                )
            }

            let dayId = "\(deviceId)_\(date)"

            // Don't persist empty diaries — set transient selectedDiaryDay for the view to inspect
            if entries.isEmpty && journeys.isEmpty {
                let emptyDay = DiaryDay(id: dayId, deviceId: deviceId, date: date, entries: [], journeys: [])
                selectedDiaryDay = emptyDay
                loadLocalDiaries()
                isLoading = false
                return
            }

            // If a local diary already exists for this date, merge: keep answered entries and journeys
            if var existing = storage.loadDiaryDay(date: date), existing.deviceId == deviceId {
                // Merge visits
                let existingById = Dictionary(uniqueKeysWithValues: existing.entries.map { ($0.id, $0) })
                let mergedEntries = entries.map { entry -> DiaryEntry in
                    if let prev = existingById[entry.id] {
                        return prev  // keep previous answers
                    }
                    return entry
                }
                existing.entries = mergedEntries

                // Merge journeys
                let existingJourneysById = Dictionary(uniqueKeysWithValues: existing.journeys.map { ($0.id, $0) })
                let mergedJourneys = journeys.map { journey -> DiaryJourney in
                    if let prev = existingJourneysById[journey.id] {
                        return prev  // keep previous answers
                    }
                    return journey
                }
                existing.journeys = mergedJourneys

                storage.saveDiaryDay(existing)
            } else {
                let diaryDay = DiaryDay(id: dayId, deviceId: deviceId, date: date, entries: entries, journeys: journeys)
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
                activity_label: entry.activityLabel,
                confirmed_place: entry.confirmedPlace ?? false,
                confirmed_activity: entry.confirmedActivity ?? false,
                user_context: entry.userContext
            )
        }

        let submitJourneys = diaryDay.journeys.map { journey in
            DiarySubmitJourney(
                source_journey_id: journey.id,
                confirmed_transport: journey.confirmedTransport ?? false,
                travel_reason: journey.travelReason
            )
        }

        let payload = DiarySubmitPayload(
            deviceId: diaryDay.deviceId,
            date: diaryDay.date,
            entries: submitEntries,
            journeys: submitJourneys
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

            if http.statusCode == 200 {
                // Success – record submission and delete local data
                recordSubmission(date: diaryDay.date)
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
