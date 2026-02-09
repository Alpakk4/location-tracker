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

    func saveDiaryDay(_ diaryDay: DiaryDay) {
        let url = fileURL(for: diaryDay.date)
        do {
            let data = try encoder.encode(diaryDay)
            try data.write(to: url, options: .atomic)
            print("[DiaryStorage] Saved diary for \(diaryDay.date)")
        } catch {
            print("[DiaryStorage] Failed to save diary for \(diaryDay.date): \(error)")
        }
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
            print("[DiaryStorage] Failed to load diary for \(date): \(error)")
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
                let data = try Data(contentsOf: file)
                let day = try decoder.decode(DiaryDay.self, from: data)
                days.append(day)
            }
            return days.sorted { $0.date > $1.date }  // newest first
        } catch {
            print("[DiaryStorage] Failed to load all diaries: \(error)")
            return []
        }
    }

    // MARK: - Delete

    func deleteDiaryDay(date: String) {
        let url = fileURL(for: date)
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                print("[DiaryStorage] Deleted diary for \(date)")
            }
        } catch {
            print("[DiaryStorage] Failed to delete diary for \(date): \(error)")
        }
    }
}
