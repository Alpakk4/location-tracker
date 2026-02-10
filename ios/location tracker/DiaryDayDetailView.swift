//
//  DiaryDayDetailView.swift
//  location tracker
//
//  Shows all entries for a diary day with inline questionnaire and submit button.
//

import SwiftUI

struct DiaryDayDetailView: View {
    @EnvironmentObject var diaryService: DiaryService
    @Environment(\.dismiss) var dismiss
    @State var diaryDay: DiaryDay
    @State private var submitSuccess = false
    @State private var showingSubmitAlert = false
    @State private var showingRefreshAlert = false

    private var deviceId: String {
        UserDefaults.standard.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    var body: some View {
        VStack(spacing: 0) {
            if diaryDay.entries.isEmpty {
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
                    Text("\(diaryDay.completedCount)/\(diaryDay.entries.count) completed")
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

                // MARK: Entry List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(diaryDay.entries.indices, id: \.self) { index in
                            DiaryEntryCard(entry: $diaryDay.entries[index], onChanged: {
                                saveProgress()
                            })
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
                        .disabled(!diaryDay.isCompleted || diaryService.isLoading)
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
            Text("Submit all \(diaryDay.entries.count) completed entries for \(diaryDay.date)?")
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
                    // Reload the refreshed diary into local state
                    if let refreshed = diaryService.selectedDiaryDay, refreshed.date == diaryDay.date {
                        diaryDay = refreshed
                    }
                }
            }
        } message: {
            Text("This will re-fetch your diary from the server and reset your answers. Continue?")
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
