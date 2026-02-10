//
//  DiaryModels.swift
//  location tracker
//

import Foundation

// MARK: - Supabase diary-maker Response

/// Raw entry returned by the diary-maker Supabase function (now represents a visit cluster).
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

// MARK: - Local Diary Models

/// Represents a single diary entry (a visit cluster) with user questionnaire answers.
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

/// Groups diary entries for a single day.
struct DiaryDay: Codable, Identifiable {
    let id: String              // "deviceId_YYYY-MM-DD"
    let deviceId: String
    let date: String            // "YYYY-MM-DD"
    var entries: [DiaryEntry]

    var isCompleted: Bool {
        !entries.isEmpty && entries.allSatisfy { $0.isCompleted }
    }

    var completedCount: Int {
        entries.filter { $0.isCompleted }.count
    }
}

// MARK: - Submission Payload

/// Payload sent to the diary-submit Supabase function.
struct DiarySubmitPayload: Codable {
    let deviceId: String
    let date: String
    let entries: [DiarySubmitEntry]
}

struct DiarySubmitEntry: Codable {
    let source_entryid: String
    let entry_ids: [String]
    let primary_type: String
    let activity_label: String
    let confirmed_place: Bool
    let confirmed_activity: Bool
    let user_context: String?
    let motion_type: MotionType
    let visit_confidence: String
    let ping_count: Int
    let cluster_duration_s: Int
}
