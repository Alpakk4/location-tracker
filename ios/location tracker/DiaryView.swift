//
//  DiaryView.swift
//  location tracker
//
//  Main diary tab: choose a day to build, then list local diary days.
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var diaryService: DiaryService

    @State private var path: [DiaryDay] = []
    @State private var selectedDate = Date()
    @State private var isSelectingAnotherDate = false
    @State private var showNoEntriesMessage = false
    @State private var showAlreadySubmittedMessage = false

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        defaults.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    /// In-progress diaries, excluding any that have already been submitted.
    private var inProgressDays: [DiaryDay] {
        diaryService.diaryDays.filter { !diaryService.hasBeenSubmitted(date: $0.date) }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func buildDiary(for date: Date) {
        selectedDate = date
        let ds = dateString(from: date)
        isSelectingAnotherDate = false  // collapse calendar

        // Check if this date was already submitted
        if diaryService.hasBeenSubmitted(date: ds) {
            withAnimation { showAlreadySubmittedMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showAlreadySubmittedMessage = false }
            }
            return
        }

        performFetch(for: ds)
    }

    private func performFetch(for ds: String) {
        Task {
            await diaryService.loadOrFetchDiary(deviceId: deviceId, date: ds)
            if let selected = diaryService.selectedDiaryDay,
               !selected.entries.isEmpty || !selected.journeys.isEmpty {
                // Navigate immediately to the detail view
                path = [selected]
            } else {
                // Empty diary or no data
                diaryService.selectedDiaryDay = nil
                withAnimation { showNoEntriesMessage = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showNoEntriesMessage = false }
                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
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

                // MARK: Already Submitted Toast
                if showAlreadySubmittedMessage {
                    Text("Diary for this date has already been submitted")
                        .font(.subheadline)
                        .padding()
                        .background(Color.indigo.opacity(0.15))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .padding(.horizontal)
                }

                // MARK: Loading Indicator
                if diaryService.isLoading {
                    ProgressView("Loading diary...")
                        .padding()
                }

                Divider()

                // MARK: In Progress Diaries
                if inProgressDays.isEmpty {
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
                } else {
                    List {
                        Section(header: Text("In Progress")) {
                            ForEach(inProgressDays) { day in
                                Button {
                                    path = [day]
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
            .navigationDestination(for: DiaryDay.self) { day in
                DiaryDayDetailView(diaryDay: day)
            }
            .onAppear {
                diaryService.loadLocalDiaries()
            }
            .onChange(of: path) {
                if path.isEmpty {
                    diaryService.loadLocalDiaries()
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
                if day.entries.isEmpty && day.journeys.isEmpty {
                    Text("No diary entries on the selected day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if day.isCompleted {
                    Text("Ready to submit")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("\(day.completedCount)/\(day.totalCount) items completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if day.entries.isEmpty && day.journeys.isEmpty {
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

