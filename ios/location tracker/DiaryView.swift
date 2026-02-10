//
//  DiaryView.swift
//  location tracker
//
//  Main diary tab: date picker, build diary button, and list of local diary days.
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var diaryService: DiaryService

    @State private var selectedDate = Date()
    @State private var showingDetail: DiaryDay?
    @State private var isSelectingAnotherDate = false
    @State private var lastBuiltDateString: String?

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        defaults.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
    
    private func buildDiary(for date: Date) {
        selectedDate = date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let ds = formatter.string(from: date)
        
        // Guard against duplicate calls (e.g., multiple SwiftUI change events)
        guard lastBuiltDateString != ds else { return }
        lastBuiltDateString = ds
        
        Task {
            await diaryService.fetchDiary(deviceId: deviceId, date: ds)
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
                        .onChange(of: selectedDate) { _, newValue in
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

                // MARK: Diary Days List
                if diaryService.diaryDays.isEmpty {
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
                } else {
                    List {
                        ForEach(diaryService.diaryDays) { day in
                            NavigationLink(destination: DiaryDayDetailView(diaryDay: day)) {
                                DiaryDayRow(day: day)
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
                Text("\(day.completedCount)/\(day.entries.count) entries completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if day.isCompleted {
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
