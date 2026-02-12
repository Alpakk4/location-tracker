//
//  DiaryService.swift
//  location tracker
//
//  Manages diary lifecycle: fetch from Supabase, local persistence, and submission.
//

import Foundation
import SwiftUI

@MainActor
/// Coordinates diary state across network, local persistence, and submission lifecycle.
/// Source of truth:
/// - generated visit/journey data comes from Supabase
/// - in-progress questionnaire answers live in local storage until submit
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

    /// Reloads all locally saved diary days into published state.
    func loadLocalDiaries() {
        diaryDays = storage.loadAllDiaryDays()
    }

    /// Persists a day and refreshes in-memory collections used by the UI.
    func saveDiaryDay(_ day: DiaryDay) {
        storage.saveDiaryDay(day)
        loadLocalDiaries()
    }

    // MARK: - Submission Tracking

    /// Records successful submission dates to prevent duplicate prompts and posts.
    func recordSubmission(date: String) {
        var dates = submittedDates()
        dates.insert(date)
        UserDefaults.standard.set(Array(dates), forKey: submittedDatesKey)
    }

    /// Returns all locally known submitted dates.
    func submittedDates() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: submittedDatesKey) ?? []
        return Set(arr)
    }

    /// True when this day has already been accepted by the backend.
    func hasBeenSubmitted(date: String) -> Bool {
        submittedDates().contains(date)
    }

    // MARK: - Local-First Loading

    /// Local-first load policy:
    /// - skip fully submitted days
    /// - reuse local progress when available
    /// - otherwise fetch fresh generated data from `diary-maker`
    func loadOrFetchDiary(deviceId: String, date: String) async {
        // Guard: do not surface or refetch a day already confirmed as submitted.
        if hasBeenSubmitted(date: date) {
            selectedDiaryDay = nil
            return
        }

        // Local storage owns in-progress answers, so prefer it over a remote refetch.
        if let local = storage.loadDiaryDay(date: date), local.deviceId == deviceId {
            selectedDiaryDay = local
            return
        }
        // No local diary exists; bootstrap from server-generated visits and journeys.
        await fetchDiary(deviceId: deviceId, date: date)
        // If a non-empty result was persisted, select it.
        // Keep transient empty-day selection unchanged.
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

    /// Fetches generated diary data and reconciles it with any saved local answers.
    /// Merge contract: preserve prior user answers when item ids are stable across fetches.
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

            // Handle backend idempotency response: mark as submitted locally and stop.
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alreadySubmitted = json["already_submitted"] as? Bool,
               alreadySubmitted {
                // Persist this fact so future UI sessions do not prompt again.
                recordSubmission(date: date)
                isLoading = false
                selectedDiaryDay = nil
                return
            }

            let makerResponse = try JSONDecoder().decode(DiaryMakerResponse.self, from: data)

            // API DTO -> local model mapping for visits.
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

            // API DTO -> local model mapping for journeys.
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

            // Avoid caching empty days. Views can still inspect a transient empty result.
            if entries.isEmpty && journeys.isEmpty {
                let emptyDay = DiaryDay(id: dayId, deviceId: deviceId, date: date, entries: [], journeys: [])
                selectedDiaryDay = emptyDay
                loadLocalDiaries()
                isLoading = false
                return
            }

            // Merge strategy: server may regenerate clusters, but stable ids keep prior answers.
            if var existing = storage.loadDiaryDay(date: date), existing.deviceId == deviceId {
                // Merge visits by id and keep answered values when present.
                let existingById = Dictionary(uniqueKeysWithValues: existing.entries.map { ($0.id, $0) })
                let mergedEntries = entries.map { entry -> DiaryEntry in
                    if let prev = existingById[entry.id] {
                        return prev  // keep previous answers
                    }
                    return entry
                }
                existing.entries = mergedEntries

                // Merge journeys by id and keep answered values when present.
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

    /// Submits a fully answered diary day and clears local copy on success.
    /// Side effects: records date as submitted and removes local persisted day.
    func submitCompletedDiary(_ diaryDay: DiaryDay) async -> Bool {
        guard !hasBeenSubmitted(date: diaryDay.date) else {
            errorMessage = "Diary already submitted"
            return false
        }
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

        // Local model -> submission DTO mapping for visits.
        let submitEntries = diaryDay.entries.map { entry in
            DiarySubmitEntry(
                source_entryid: entry.id,
                activity_label: entry.activityLabel,
                confirmed_place: entry.confirmedPlace ?? false,
                confirmed_activity: entry.confirmedActivity ?? false,
                user_context: entry.userContext
            )
        }

        // Local model -> submission DTO mapping for journeys.
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
                // After successful submit, local data is no longer authoritative.
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
