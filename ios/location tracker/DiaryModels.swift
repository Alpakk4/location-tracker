//
//  DiaryModels.swift
//  location tracker
//

import Foundation

// MARK: - Supabase diary-maker Response

/// Raw entry returned by the diary-maker Supabase function.
struct DiaryMakerEntry: Codable {
    let entryid: String
    let created_at: String
    let primary_type: String
    let other_types: [String]
    let motion_type: MotionType
}

// MARK: - Local Diary Models

/// Represents a single diary entry (one location ping) with user questionnaire answers.
struct DiaryEntry: Codable, Identifiable {
    let id: String              // entryid from Supabase
    let createdAt: String
    let primaryType: String
    let otherTypes: [String]
    let motionType: MotionType
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
    let primary_type: String
    let activity_label: String
    let confirmed_place: Bool
    let confirmed_activity: Bool
    let user_context: String?
    let motion_type: MotionType
}
