//
//  DiaryDayDetailView.swift
//  location tracker
//
//  Shows all entries for a diary day with inline questionnaire and submit button.
//

import SwiftUI

struct DiaryDayDetailView: View {
    @EnvironmentObject var diaryService: DiaryService
    @State var diaryDay: DiaryDay
    @State private var submitSuccess = false
    @State private var showingSubmitAlert = false

    var body: some View {
        VStack(spacing: 0) {
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
                .padding(.bottom, 100) // space for submit button
            }

            // MARK: Submit Button
            VStack {
                Divider()
                Button(action: { showingSubmitAlert = true }) {
                    HStack {
                        if diaryService.isLoading {
                            ProgressView().tint(.white)
                        }
                        Image(systemName: "arrow.up.circle.fill")
                        Text("SUBMIT DIARY")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .background(diaryDay.isCompleted ? Color.green : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!diaryDay.isCompleted || diaryService.isLoading)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
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
            Button("OK") {}
        } message: {
            Text("Your diary for \(diaryDay.date) has been submitted successfully.")
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
    private var timeString: String {
        if let tIndex = entry.createdAt.firstIndex(of: "T") {
            let timeStart = entry.createdAt.index(after: tIndex)
            let timePart = String(entry.createdAt[timeStart...].prefix(5))
            return timePart
        }
        return entry.createdAt
    }

    private var displayType: String {
        entry.primaryType.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // MARK: Header
            HStack {
                Text(timeString)
                    .font(.system(.subheadline, design: .monospaced))
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
