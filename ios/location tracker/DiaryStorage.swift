//
//  DiaryStorage.swift
//  location tracker
//
//  Persists DiaryDay objects as JSON files in the app's Documents directory.
//

import Foundation

class DiaryStorage {

    static let shared = DiaryStorage()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private(set) var lastError: Error?

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private init() {
        encoder.outputFormatting = .prettyPrinted
    }

    // MARK: - File Naming

    private func fileURL(for date: String) -> URL {
        documentsDirectory.appendingPathComponent("diary_\(date).json")
    }

    // MARK: - Save

    @discardableResult
    func saveDiaryDay(_ diaryDay: DiaryDay) -> Bool {
        do {
            try saveDiaryDayOrThrow(diaryDay)
            return true
        } catch {
            lastError = error
            #if DEBUG
            print("[DiaryStorage] Failed to save diary for \(diaryDay.date): \(error)")
            #endif
            return false
        }
    }

    func saveDiaryDayOrThrow(_ diaryDay: DiaryDay) throws {
        let url = fileURL(for: diaryDay.date)
        let data = try encoder.encode(diaryDay)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Load Single

    func loadDiaryDay(date: String) -> DiaryDay? {
        let url = fileURL(for: date)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let diaryDay = try decoder.decode(DiaryDay.self, from: data)
            return diaryDay
        } catch {
            lastError = error
            #if DEBUG
            print("[DiaryStorage] Failed to load diary for \(date): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Load All

    func loadAllDiaryDays() -> [DiaryDay] {
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory,
                                                            includingPropertiesForKeys: nil)
            let diaryFiles = files.filter { $0.lastPathComponent.hasPrefix("diary_") && $0.pathExtension == "json" }
            var days: [DiaryDay] = []
            for file in diaryFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let day = try decoder.decode(DiaryDay.self, from: data)
                    days.append(day)
                } catch {
                    lastError = error
                    #if DEBUG
                    print("[DiaryStorage] Skipping unreadable diary file \(file.lastPathComponent): \(error)")
                    #endif
                }
            }
            return days.sorted { $0.date > $1.date }  // newest first
        } catch {
            lastError = error
            #if DEBUG
            print("[DiaryStorage] Failed to load all diaries: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Delete

    @discardableResult
    func deleteDiaryDay(date: String) -> Bool {
        do {
            try deleteDiaryDayOrThrow(date: date)
            return true
        } catch {
            lastError = error
            #if DEBUG
            print("[DiaryStorage] Failed to delete diary for \(date): \(error)")
            #endif
            return false
        }
    }

    func deleteDiaryDayOrThrow(date: String) throws {
        let url = fileURL(for: date)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
