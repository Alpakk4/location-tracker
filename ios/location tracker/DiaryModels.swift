//
//  DiaryModels.swift
//  location tracker
//

import Foundation

// MARK: - Supabase diary-maker Response

/// Response from `diary-maker`.
/// This is a transport-only wrapper used before mapping to local app models.
struct DiaryMakerResponse: Codable {
    let visits: [DiaryMakerEntry]
    let journeys: [DiaryMakerJourney]
}

/// Raw visit cluster returned by `diary-maker`.
/// Ownership: server-side shape and naming (snake_case) to match API contracts.
struct DiaryMakerEntry: Codable {
    let entryid: String
    let entry_ids: [String]
    let created_at: String
    let ended_at: String
    let cluster_duration_s: Int
    let primary_type: String
    let other_types: [String]
    let motion_type: MotionType
    let visit_confidence: String   // "high", "medium", or "low"
    let ping_count: Int
}

/// Raw journey segment returned by `diary-maker`.
/// Relationship hint: optional links point to adjacent visits when they can be inferred.
struct DiaryMakerJourney: Codable {
    let journey_id: String
    let entry_ids: [String]
    let from_visit_id: String?
    let to_visit_id: String?
    let primary_transport: String
    let transport_proportions: [String: Double]
    let started_at: String
    let ended_at: String
    let journey_duration_s: Int
    let ping_count: Int
}

// MARK: - Local Diary Models

/// Local visit model shown in diary UI and persisted on device until submission.
/// Ownership: generated fields come from server, answer fields come from user interaction.
struct DiaryEntry: Codable, Identifiable {
    let id: String              // entryid from Supabase (first ping in cluster)
    let entryIds: [String]      // all ping entryids in this visit cluster
    let createdAt: String
    let endedAt: String
    let clusterDurationSeconds: Int
    let primaryType: String
    let otherTypes: [String]
    let motionType: MotionType
    let visitConfidence: String     // "high", "medium", or "low"
    let pingCount: Int
    var confirmedPlace: Bool?       // nil = unanswered
    var confirmedActivity: Bool?    // nil = unanswered
    var activityLabel: String       // derived from PlaceActivityMapping
    var userContext: String?         // required if either answer is "no"

    /// Invariant: if either confirmation is false, non-empty `userContext` is required.
    var isCompleted: Bool {
        guard let cp = confirmedPlace, let ca = confirmedActivity else { return false }
        if !cp || !ca {
            return userContext != nil && !userContext!.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    /// Human-readable duration string, e.g. "12 min", "1h 30min", "< 1 min"
    var formattedDuration: String {
        if clusterDurationSeconds < 60 { return "< 1 min" }
        let hours = clusterDurationSeconds / 3600
        let minutes = (clusterDurationSeconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(minutes) min"
    }
}

/// Local journey model shown in diary UI and persisted until submission.
/// Relationship: `fromVisitId` and `toVisitId` may point to surrounding `DiaryEntry` ids.
struct DiaryJourney: Codable, Identifiable {
    let id: String              // journey_id (first ping's entryid)
    let entryIds: [String]
    let fromVisitId: String?
    let toVisitId: String?
    let primaryTransport: String    // walking, running, cycling, automotive
    let transportProportions: [String: Double]
    let startedAt: String
    let endedAt: String
    let journeyDurationSeconds: Int
    let pingCount: Int
    var confirmedTransport: Bool?   // nil = unanswered
    var travelReason: String?       // optional free text, nullable

    /// Invariant: a journey is complete once transport confirmation is provided.
    var isCompleted: Bool {
        confirmedTransport != nil
    }

    /// Human-readable duration string, e.g. "12 min", "1h 30min", "< 1 min"
    var formattedDuration: String {
        if journeyDurationSeconds < 60 { return "< 1 min" }
        let hours = journeyDurationSeconds / 3600
        let minutes = (journeyDurationSeconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
        return "\(minutes) min"
    }

    /// SF Symbol name for the primary transport mode.
    var transportIcon: String {
        switch primaryTransport.lowercased() {
        case "walking":     return "figure.walk"
        case "running":     return "figure.run"
        case "cycling":     return "bicycle"
        case "automotive":  return "car.fill"
        default:            return "arrow.right"
        }
    }

    /// Human-readable transport label.
    var transportLabel: String {
        switch primaryTransport.lowercased() {
        case "walking":     return "Walking"
        case "running":     return "Running"
        case "cycling":     return "Cycling"
        case "automotive":  return "Driving"
        default:            return primaryTransport.capitalized
        }
    }
}

/// Aggregate local state for one calendar day and one device.
/// `DiaryDay` is the unit persisted, loaded, and submitted by `DiaryService`.
struct DiaryDay: Codable, Identifiable {
    let id: String              // "deviceId_YYYY-MM-DD"
    let deviceId: String
    let date: String            // "YYYY-MM-DD"
    var entries: [DiaryEntry]
    var journeys: [DiaryJourney]

    /// Invariant: at least one visit must exist to consider a day submit-ready.
    var isCompleted: Bool {
        let entriesDone = entries.isEmpty || entries.allSatisfy { $0.isCompleted }
        let journeysDone = journeys.isEmpty || journeys.allSatisfy { $0.isCompleted }
        return !entries.isEmpty && entriesDone && journeysDone
    }

    var completedCount: Int {
        entries.filter { $0.isCompleted }.count + journeys.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        entries.count + journeys.count
    }

    // Backward compatibility with older cached payloads that predate journey support.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        deviceId = try container.decode(String.self, forKey: .deviceId)
        date = try container.decode(String.self, forKey: .date)
        entries = try container.decode([DiaryEntry].self, forKey: .entries)
        journeys = try container.decodeIfPresent([DiaryJourney].self, forKey: .journeys) ?? []
    }

    init(id: String, deviceId: String, date: String, entries: [DiaryEntry], journeys: [DiaryJourney]) {
        self.id = id
        self.deviceId = deviceId
        self.date = date
        self.entries = entries
        self.journeys = journeys
    }
}

// MARK: - DiaryDay Hashable (needed for NavigationStack path)

extension DiaryDay: Hashable {
    static func == (lhs: DiaryDay, rhs: DiaryDay) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Submission Payload

/// Submission wrapper sent to `diary-submit`.
/// Contract: references source ids from generated visits/journeys plus user answers.
struct DiarySubmitPayload: Codable {
    let deviceId: String
    let date: String
    let entries: [DiarySubmitEntry]
    let journeys: [DiarySubmitJourney]
}

/// User-confirmed answers for one visit cluster.
struct DiarySubmitEntry: Codable {
    let source_entryid: String
    let activity_label: String
    let confirmed_place: Bool
    let confirmed_activity: Bool
    let user_context: String?
}

/// User-confirmed answers for one journey segment.
struct DiarySubmitJourney: Codable {
    let source_journey_id: String
    let confirmed_transport: Bool
    let travel_reason: String?
}
