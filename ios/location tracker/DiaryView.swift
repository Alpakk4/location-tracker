//
//  DiaryView.swift
//  location tracker
//
//  Main diary tab: choose a day to build, then list local diary days.
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var diaryService: DiaryService

    @State private var selectedDate = Date()
    @State private var isSelectingAnotherDate = false
    @State private var selectedDateString: String?
    @State private var showNoEntriesMessage = false

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        defaults.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    /// In Progress list excludes the currently selected day to avoid duplication
    private var inProgressDays: [DiaryDay] {
        diaryService.diaryDays.filter { $0.date != selectedDateString }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func buildDiary(for date: Date) {
        selectedDate = date
        let ds = dateString(from: date)

        // Dedup guard
        guard selectedDateString != ds else { return }
        selectedDateString = ds
        isSelectingAnotherDate = false  // collapse calendar

        // Check if this date was already submitted
        if diaryService.hasBeenSubmitted(date: ds) {
            diaryService.selectedDiaryDay = nil
            return
        }

        performFetch(for: ds)
    }

    private func performFetch(for ds: String) {
        Task {
            await diaryService.loadOrFetchDiary(deviceId: deviceId, date: ds)
            if let selected = diaryService.selectedDiaryDay, selected.entries.isEmpty {
                diaryService.selectedDiaryDay = nil
                withAnimation { showNoEntriesMessage = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showNoEntriesMessage = false }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // MARK: Day Selection (Auto-build)
                VStack(alignment: .leading, spacing: 12) {
                    Text("What day shall we complete the diary for?")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    HStack(spacing: 10) {
                        Button("Yesterday") {
                            isSelectingAnotherDate = false
                            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            buildDiary(for: yesterday)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(diaryService.isLoading)

                        Button("Another date") {
                            isSelectingAnotherDate.toggle()
                        }
                        .buttonStyle(.bordered)
                        .tint(.indigo)
                        .disabled(diaryService.isLoading)
                    }
                    .padding(.horizontal)

                    if isSelectingAnotherDate {
                        DatePicker(
                            "Select a date",
                            selection: $selectedDate,
                            in: ...Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .disabled(diaryService.isLoading)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) {
                            buildDiary(for: selectedDate)
                        }
                    }
                }

                // MARK: Error Banner
                if let error = diaryService.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            diaryService.errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }

                // MARK: No Entries Toast
                if showNoEntriesMessage {
                    Text("Selected day has no entries, try another")
                        .font(.subheadline)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .padding(.horizontal)
                }

                Divider()

                // MARK: Selected Day
                if let ds = selectedDateString {
                    let isSubmitted = diaryService.hasBeenSubmitted(date: ds) && diaryService.selectedDiaryDay == nil
                    if let selected = diaryService.selectedDiaryDay, !selected.entries.isEmpty {
                        NavigationLink(destination: DiaryDayDetailView(diaryDay: selected)) {
                            SelectedDayCard(day: selected, dateString: ds, isSubmitted: false)
                        }
                        .buttonStyle(.plain)
                    } else if isSubmitted {
                        SelectedDayCard(day: nil, dateString: ds, isSubmitted: true)
                    } else if diaryService.isLoading {
                        ProgressView("Loading diary...")
                            .padding()
                    } else if diaryService.selectedDiaryDay != nil {
                        // Empty diary (e.g. today waiting for entries)
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No diary entries on the selected day")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                } else if diaryService.isLoading {
                    ProgressView("Loading diary...")
                        .padding()
                }

                // MARK: In Progress Diaries
                if inProgressDays.isEmpty && selectedDateString == nil {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No diary entries yet")
                            .foregroundColor(.secondary)
                        Text("Choose Yesterday or pick another date to get started.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if !inProgressDays.isEmpty {
                    List {
                        Section(header: Text("In Progress")) {
                            ForEach(inProgressDays) { day in
                                Button {
                                    diaryService.selectedDiaryDay = day
                                    selectedDateString = day.date
                                } label: {
                                    DiaryDayRow(day: day)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Diary")
            .onAppear {
                diaryService.loadLocalDiaries()
                if let ds = selectedDateString {
                    if let fresh = DiaryStorage.shared.loadDiaryDay(date: ds) {
                        diaryService.selectedDiaryDay = fresh
                    } else if diaryService.hasBeenSubmitted(date: ds) {
                        // Diary was submitted -- keep selectedDateString so card shows "Submitted" badge
                        diaryService.selectedDiaryDay = nil
                    } else {
                        // Diary doesn't exist and wasn't submitted -- clear
                        diaryService.selectedDiaryDay = nil
                        selectedDateString = nil
                    }
                }
            }
        }
    }
}

// MARK: - Diary Day Row

struct DiaryDayRow: View {
    let day: DiaryDay

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.date)
                    .font(.headline)
                if day.entries.isEmpty {
                    Text("No diary entries on the selected day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if day.isCompleted {
                    Text("Ready to submit")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("\(day.completedCount)/\(day.entries.count) entries completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if day.entries.isEmpty {
                Image(systemName: "minus.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            } else if day.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Image(systemName: "circle.dotted")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Selected Day Card

struct SelectedDayCard: View {
    let day: DiaryDay?
    let dateString: String
    let isSubmitted: Bool

    private var statusText: String {
        if isSubmitted { return "Submitted" }
        guard let day else { return "Loading..." }
        if day.entries.isEmpty { return "No Entries" }
        if day.isCompleted { return "Ready to Submit" }
        if day.completedCount == 0 { return "New" }
        return "In Progress (\(day.completedCount)/\(day.entries.count))"
    }

    private var statusColor: Color {
        if isSubmitted { return .indigo }
        guard let day else { return .secondary }
        if day.isCompleted { return .green }
        if day.completedCount > 0 { return .orange }
        return .secondary
    }

    private var statusIcon: String {
        if isSubmitted { return "checkmark.seal.fill" }
        guard let day else { return "circle" }
        if day.isCompleted { return "checkmark.seal.fill" }
        if day.completedCount > 0 { return "circle.dotted" }
        return "circle"
    }

    private var progress: Double {
        guard let day, !day.entries.isEmpty else { return isSubmitted ? 1.0 : 0.0 }
        return Double(day.completedCount) / Double(day.entries.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateString)
                    .font(.title3)
                    .bold()
                Spacer()
                Label(statusText, systemImage: statusIcon)
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(statusColor)
                    .cornerRadius(8)
            }
            ProgressView(value: progress)
                .tint(statusColor)
            Text(isSubmitted
                 ? "Diary already submitted successfully"
                 : "\(day?.completedCount ?? 0)/\(day?.entries.count ?? 0) entries completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}
