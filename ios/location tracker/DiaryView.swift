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

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        defaults.string(forKey: ConfigurationKeys.uid) ?? "anonymous"
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // MARK: Date Picker & Build Button
                VStack(spacing: 12) {
                    DatePicker("Diary Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.horizontal)

                    Button(action: {
                        Task {
                            await diaryService.fetchDiary(deviceId: deviceId, date: dateString)
                        }
                    }) {
                        HStack {
                            if diaryService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Image(systemName: "book.fill")
                            Text("BUILD DIARY")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .background(Color.indigo)
                        .cornerRadius(12)
                    }
                    .disabled(diaryService.isLoading)
                    .padding(.horizontal)
                }
                .padding(.top)

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
                        Text("Select a date and tap Build Diary to get started.")
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
