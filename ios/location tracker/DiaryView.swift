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

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        defaults.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    private func buildDiary(for date: Date) {
        selectedDate = date

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let ds = formatter.string(from: date)
        selectedDateString = ds

        Task {
            await diaryService.loadOrFetchDiary(deviceId: deviceId, date: ds)
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
                        Button("Today") {
                            isSelectingAnotherDate = false
                            buildDiary(for: Date())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .disabled(diaryService.isLoading)

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
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .disabled(diaryService.isLoading)
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { newValue in
                            buildDiary(for: newValue)
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

                Divider()

                // MARK: Selected Day
                if let selected = diaryService.selectedDiaryDay, selectedDateString != nil {
                    if selected.entries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No diary entries on the selected day")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List {
                            Section(header: Text("Selected Day")) {
                                NavigationLink(destination: DiaryDayDetailView(diaryDay: selected)) {
                                    DiaryDayRow(day: selected)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .frame(maxHeight: 120)
                    }
                } else if diaryService.isLoading {
                    ProgressView("Loading diary...")
                        .padding()
                }

                // MARK: In Progress Diaries
                if diaryService.diaryDays.isEmpty && selectedDateString == nil {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No diary entries yet")
                            .foregroundColor(.secondary)
                        Text("Choose Today, Yesterday, or pick another date to get started.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if !diaryService.diaryDays.isEmpty {
                    List {
                        Section(header: Text("In Progress")) {
                            ForEach(diaryService.diaryDays) { day in
                                NavigationLink(destination: DiaryDayDetailView(diaryDay: day)) {
                                    DiaryDayRow(day: day)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Diary")
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
                Image(systemName: "checkmark.circle.fill")
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
