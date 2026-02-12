//
//  DiaryDayDetailView.swift
//  location tracker
//
//  Shows all entries and journeys for a diary day with inline questionnaire and submit button.
//

import SwiftUI

// MARK: - Timeline Item

/// Unified timeline item that sorts visits and journeys chronologically.
enum DiaryTimelineItem: Identifiable {
    case visit(index: Int, entry: DiaryEntry)
    case journey(index: Int, journey: DiaryJourney)

    var id: String {
        switch self {
        case .visit(_, let entry): return "visit_\(entry.id)"
        case .journey(_, let journey): return "journey_\(journey.id)"
        }
    }

    var sortDate: Date {
        let iso: String
        switch self {
        case .visit(_, let entry): iso = entry.createdAt
        case .journey(_, let journey): iso = journey.startedAt
        }
        return ISO8601DateFormatter().date(from: iso)
            ?? DateFormatter.iso8601Fallback.date(from: iso)
            ?? .distantPast
    }
}

private extension DateFormatter {
    static let iso8601Fallback: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

struct DiaryDayDetailView: View {
    @EnvironmentObject var diaryService: DiaryService
    @SwiftUI.Environment(\.dismiss) var dismiss
    @State var diaryDay: DiaryDay
    @State private var submitSuccess = false
    @State private var showingSubmitAlert = false
    @State private var showingRefreshAlert = false
    @State private var showingAlreadySubmittedAlert = false

    private var deviceId: String {
        SecureStore.getString(for: .uid)
            ?? UserDefaults.standard.string(forKey: ConfigurationKeys.uid)
            ?? UserDefaults.standard.string(forKey: ConfigurationKeys.legacyUid)
            ?? ConfigurationDefaults.anonymousUid
    }

    /// Build a chronologically sorted timeline of visits and journeys.
    private var timelineItems: [DiaryTimelineItem] {
        var items: [DiaryTimelineItem] = []
        for (i, entry) in diaryDay.entries.enumerated() {
            items.append(.visit(index: i, entry: entry))
        }
        for (i, journey) in diaryDay.journeys.enumerated() {
            items.append(.journey(index: i, journey: journey))
        }
        return items.sorted { $0.sortDate < $1.sortDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            if diaryDay.entries.isEmpty && diaryDay.journeys.isEmpty {
                // MARK: Empty State
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No diary entries on the selected day")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // MARK: Progress Header
                HStack {
                    Text("\(diaryDay.completedCount)/\(diaryDay.totalCount) completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if diaryDay.isCompleted {
                        Label("Ready to submit", systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding()

                // MARK: Timeline List (visits + journeys interspersed)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(timelineItems) { item in
                            switch item {
                            case .visit(let index, _):
                                DiaryEntryCard(entry: $diaryDay.entries[index], onChanged: {
                                    saveProgress()
                                })
                            case .journey(let index, _):
                                DiaryJourneyCard(
                                    journey: $diaryDay.journeys[index],
                                    entries: diaryDay.entries,
                                    onChanged: { saveProgress() }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // space for bottom buttons
                }

                // MARK: Bottom Buttons
                VStack {
                    Divider()
                    HStack(spacing: 12) {
                        // Refresh Button
                        Button(action: { showingRefreshAlert = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                Text("REFRESH")
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                        }
                        .disabled(diaryService.isLoading)

                        // Submit Button
                        Button(action: { showingSubmitAlert = true }) {
                            HStack {
                                if diaryService.isLoading {
                                    ProgressView().tint(.white)
                                }
                                Image(systemName: "arrow.up.circle.fill")
                                Text("SUBMIT")
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(diaryDay.isCompleted ? Color.green : Color.gray)
                            .cornerRadius(12)
                        }
                        .disabled(!diaryDay.isCompleted || diaryService.isLoading || diaryService.hasBeenSubmitted(date: diaryDay.date))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(diaryDay.date)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Submit Diary", isPresented: $showingSubmitAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Submit") {
                Task {
                    let success = await diaryService.submitCompletedDiary(diaryDay)
                    submitSuccess = success
                }
            }
        } message: {
            Text("Submit all \(diaryDay.totalCount) completed items for \(diaryDay.date)? Once submitted, you cannot edit the diary.")
        }
        .alert("Diary Submitted", isPresented: $submitSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your diary for \(diaryDay.date) has been submitted successfully.")
        }
        .alert("Refresh Diary", isPresented: $showingRefreshAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Refresh", role: .destructive) {
                Task {
                    await diaryService.fetchDiary(deviceId: deviceId, date: diaryDay.date)
                    // Reload the refreshed diary into local state.
                    if let refreshed = diaryService.selectedDiaryDay, refreshed.date == diaryDay.date {
                        diaryDay = refreshed
                    } else if diaryService.hasBeenSubmitted(date: diaryDay.date) {
                        showingAlreadySubmittedAlert = true
                    }
                }
            }
        } message: {
            Text("This will re-fetch your diary from the server and reset your answers. Continue?")
        }
        .alert("Diary Already Submitted", isPresented: $showingAlreadySubmittedAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("This diary was already submitted and can no longer be edited.")
        }
    }

    private func saveProgress() {
        diaryService.saveDiaryDay(diaryDay)
    }
}

// MARK: - Diary Entry Card

struct DiaryEntryCard: View {
    @Binding var entry: DiaryEntry
    var onChanged: () -> Void

    /// Format "2026-02-06T13:25:12.434339+00:00" to "13:25"
    private func shortTime(_ iso: String) -> String {
        if let tIndex = iso.firstIndex(of: "T") {
            let timeStart = iso.index(after: tIndex)
            return String(iso[timeStart...].prefix(5))
        }
        return iso
    }

    private var timeRangeString: String {
        let start = shortTime(entry.createdAt)
        let end = shortTime(entry.endedAt)
        if start == end { return start }
        return "\(start) – \(end)"
    }

    private var displayType: String {
        entry.primaryType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var confidenceColor: Color {
        switch entry.visitConfidence {
        case "high":   return .green
        case "medium": return .orange
        default:       return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Header
            HStack {
                Text(timeRangeString)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(entry.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if entry.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.orange)
                }
            }

            // MARK: Visit confidence badge and duration
            HStack(spacing: 8) {
                Text(entry.visitConfidence.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(confidenceColor)
                    .cornerRadius(6)

                Text(entry.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(entry.pingCount) ping\(entry.pingCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Place type and activity
            HStack {
                Label(displayType, systemImage: "mappin.circle.fill")
                    .font(.headline)
            }
            Text("Suggested activity: **\(entry.activityLabel)**")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // MARK: Question 1 – Place
            VStack(alignment: .leading, spacing: 6) {
                Text("Were you at **\(displayType)**?")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    AnswerButton(label: "Yes", isSelected: entry.confirmedPlace == true) {
                        entry.confirmedPlace = true
                        onChanged()
                    }
                    AnswerButton(label: "No", isSelected: entry.confirmedPlace == false) {
                        entry.confirmedPlace = false
                        onChanged()
                    }
                }
            }

            // MARK: Question 2 – Activity
            VStack(alignment: .leading, spacing: 6) {
                Text("Were you doing **\(entry.activityLabel)**?")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    AnswerButton(label: "Yes", isSelected: entry.confirmedActivity == true) {
                        entry.confirmedActivity = true
                        onChanged()
                    }
                    AnswerButton(label: "No", isSelected: entry.confirmedActivity == false) {
                        entry.confirmedActivity = false
                        onChanged()
                    }
                }
            }

            // MARK: Context field (shown if either answer is "no")
            if entry.confirmedPlace == false || entry.confirmedActivity == false {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Please provide context:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("What were you actually doing?", text: Binding(
                        get: { entry.userContext ?? "" },
                        set: { newValue in
                            entry.userContext = newValue.isEmpty ? nil : newValue
                            onChanged()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: entry.confirmedPlace)
        .animation(.easeInOut(duration: 0.2), value: entry.confirmedActivity)
    }
}

// MARK: - Diary Journey Card

struct DiaryJourneyCard: View {
    @Binding var journey: DiaryJourney
    let entries: [DiaryEntry]     // all visit entries, used to resolve from/to names
    var onChanged: () -> Void

    /// Format "2026-02-06T13:25:12.434339+00:00" to "13:25"
    private func shortTime(_ iso: String) -> String {
        if let tIndex = iso.firstIndex(of: "T") {
            let timeStart = iso.index(after: tIndex)
            return String(iso[timeStart...].prefix(5))
        }
        return iso
    }

    private var timeRangeString: String {
        let start = shortTime(journey.startedAt)
        let end = shortTime(journey.endedAt)
        if start == end { return start }
        return "\(start) – \(end)"
    }

    /// Resolve a visit_id to a human-readable place name from entries.
    private func placeName(for visitId: String?) -> String? {
        guard let vid = visitId,
              let entry = entries.first(where: { $0.id == vid }) else { return nil }
        return entry.primaryType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Transport proportion bar colors.
    private func transportColor(_ mode: String) -> Color {
        switch mode.lowercased() {
        case "walking":     return .blue
        case "running":     return .purple
        case "cycling":     return .orange
        case "automotive":  return .red
        default:            return .gray
        }
    }

    /// Sorted transport proportions for display.
    private var sortedProportions: [(mode: String, ratio: Double)] {
        journey.transportProportions
            .sorted { $0.value > $1.value }
            .map { (mode: $0.key, ratio: $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Header
            HStack {
                Image(systemName: journey.transportIcon)
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(timeRangeString)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(journey.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if journey.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.orange)
                }
            }

            // MARK: Journey badge and info
            HStack(spacing: 8) {
                Text("JOURNEY")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(6)

                Text(journey.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(journey.pingCount) ping\(journey.pingCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: From / To context
            if let from = placeName(for: journey.fromVisitId),
               let to = placeName(for: journey.toVisitId) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("From **\(from)** to **\(to)**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: Transport Proportions Bar
            if !sortedProportions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(sortedProportions, id: \.mode) { item in
                                Rectangle()
                                    .fill(transportColor(item.mode))
                                    .frame(width: geo.size.width * item.ratio)
                            }
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)

                    // Legend
                    HStack(spacing: 12) {
                        ForEach(sortedProportions, id: \.mode) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(transportColor(item.mode))
                                    .frame(width: 8, height: 8)
                                Text("\(item.mode.capitalized) \(Int(item.ratio * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Divider()

            // MARK: Question – Transport confirmation
            VStack(alignment: .leading, spacing: 6) {
                Text("Did you travel by **\(journey.transportLabel)**?")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    AnswerButton(label: "Yes", isSelected: journey.confirmedTransport == true) {
                        journey.confirmedTransport = true
                        onChanged()
                    }
                    AnswerButton(label: "No", isSelected: journey.confirmedTransport == false) {
                        journey.confirmedTransport = false
                        onChanged()
                    }
                }
            }

            // MARK: Optional – Travel reason
            VStack(alignment: .leading, spacing: 4) {
                Text("Why did you travel this way? (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. commute, errand, exercise...", text: Binding(
                    get: { journey.travelReason ?? "" },
                    set: { newValue in
                        journey.travelReason = newValue.isEmpty ? nil : newValue
                        onChanged()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: journey.confirmedTransport)
    }
}

// MARK: - Answer Button

struct AnswerButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? (label == "Yes" ? Color.green : Color.red) : Color(.systemGray5))
                .cornerRadius(8)
        }
    }
}
