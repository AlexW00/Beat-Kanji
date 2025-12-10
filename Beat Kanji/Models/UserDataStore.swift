//
//  UserDataStore.swift
//  Beat Kanji
//
//  Created by Codex on 05.03.25.
//

import Foundation

// MARK: - Song Score Tracking

struct SongScoreEntry: Codable {
    let score: Int
    let percentage: Double
    let recordedAt: Date
}

struct SongScoreRecord: Codable {
    var last: SongScoreEntry
    var best: SongScoreEntry
}

final class SongScoreStore {
    static let shared = SongScoreStore()
    private let defaultsKey = "songScoreStore.v1"
    private var storage: [String: SongScoreRecord] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private init() {
        load()
    }
    private func key(songId: String, difficulty: DifficultyLevel) -> String {
        return "\(songId)|\(difficulty.rawValue)"
    }
    private func clampPercentage(_ percentage: Double) -> Double {
        return min(100.0, max(0.0, percentage))
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? decoder.decode([String: SongScoreRecord].self, from: data) {
            storage = decoded
        }
    }
    private func persist() {
        if let data = try? encoder.encode(storage) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    @discardableResult
    func record(songId: String, difficulty: DifficultyLevel, score: Int, maxPossibleScore: Int) -> SongScoreRecord {
        let denominator = max(1, maxPossibleScore)
        let percentage = clampPercentage((Double(score) / Double(denominator)) * 100.0)
        let entry = SongScoreEntry(score: score, percentage: percentage, recordedAt: Date())
        let key = key(songId: songId, difficulty: difficulty)
        if var existing = storage[key] {
            existing.last = entry
            if entry.percentage > existing.best.percentage {
                existing.best = entry
            }
            storage[key] = existing
        } else {
            storage[key] = SongScoreRecord(last: entry, best: entry)
        }
        persist()
        return storage[key]!
    }
    func record(songId: String, difficulty: DifficultyLevel, result: SongScoreEntry) {
        let key = key(songId: songId, difficulty: difficulty)
        if var existing = storage[key] {
            existing.last = result
            if result.percentage > existing.best.percentage {
                existing.best = result
            }
            storage[key] = existing
        } else {
            storage[key] = SongScoreRecord(last: result, best: result)
        }
        persist()
    }
    func record(songId: String, difficulty: DifficultyLevel, score: Int, percentage: Double) {
        let entry = SongScoreEntry(score: score, percentage: clampPercentage(percentage), recordedAt: Date())
        record(songId: songId, difficulty: difficulty, result: entry)
    }
    func record(songId: String, difficulty: DifficultyLevel, score: Int, percentage: Double, recordedAt: Date) {
        let entry = SongScoreEntry(score: score, percentage: clampPercentage(percentage), recordedAt: recordedAt)
        record(songId: songId, difficulty: difficulty, result: entry)
    }
    func result(for songId: String, difficulty: DifficultyLevel) -> SongScoreRecord? {
        return storage[key(songId: songId, difficulty: difficulty)]
    }
    func bestPercentage(for songId: String, difficulty: DifficultyLevel) -> Double? {
        return result(for: songId, difficulty: difficulty)?.best.percentage
    }
}

// MARK: - Kanji User Data

struct KanjiUserData: Codable {
    var timesSeen: Int
    var scores: [Int]
}

final class KanjiUserStore {
    static let shared = KanjiUserStore()
    private let defaultsKey = "kanjiUserStore.v1"
    private let maxScoresStored = 20
    private var storage: [String: KanjiUserData] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private init() {
        load()
    }
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? decoder.decode([String: KanjiUserData].self, from: data) {
            storage = decoded
        }
    }
    private func persist() {
        if let data = try? encoder.encode(storage) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    private func updateEntry(for kanjiId: String, mutate: (inout KanjiUserData) -> Void) {
        var entry = storage[kanjiId] ?? KanjiUserData(timesSeen: 0, scores: [])
        mutate(&entry)
        storage[kanjiId] = entry
        persist()
    }
    func markSeen(kanjiId: String) {
        updateEntry(for: kanjiId) { entry in
            entry.timesSeen += 1
        }
    }
    func recordScore(kanjiId: String, score: Int) {
        updateEntry(for: kanjiId) { entry in
            entry.scores.append(score)
            if entry.scores.count > maxScoresStored {
                entry.scores = Array(entry.scores.suffix(maxScoresStored))
            }
        }
    }
    func data(for kanjiId: String) -> KanjiUserData? {
        return storage[kanjiId]
    }
}

// MARK: - Category Preference Store

/// Stores user's enabled kanji/kana category preferences
final class CategoryPreferenceStore {
    static let shared = CategoryPreferenceStore()
    private let defaultsKey = "categoryPreferences.v1"
    private var storage: Set<String> = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        load()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode(Set<String>.self, from: data) else {
            // Default: all categories enabled
            storage = KanjiCategory.allTags
            return
        }
        storage = decoded
    }
    
    private func persist() {
        if let data = try? encoder.encode(storage) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    /// Get all currently enabled category tags
    var enabledTags: Set<String> {
        return storage
    }
    
    /// Check if a specific tag is enabled
    func isEnabled(_ tag: String) -> Bool {
        return storage.contains(tag)
    }
    
    /// Check if a category is enabled
    func isEnabled(_ category: KanjiCategory) -> Bool {
        return storage.contains(category.rawValue)
    }
    
    /// Toggle a category on/off
    func toggle(_ category: KanjiCategory) {
        if storage.contains(category.rawValue) {
            storage.remove(category.rawValue)
        } else {
            storage.insert(category.rawValue)
        }
        persist()
    }
    
    /// Set a category's enabled state
    func setEnabled(_ category: KanjiCategory, enabled: Bool) {
        if enabled {
            storage.insert(category.rawValue)
        } else {
            storage.remove(category.rawValue)
        }
        persist()
    }
    
    /// Check if at least one category is enabled
    var hasAnyEnabled: Bool {
        return !storage.isEmpty
    }
    
    /// Check if all kanji categories (N1-N5) are disabled
    var allKanjiDisabled: Bool {
        return KanjiCategory.kanjiCategories.allSatisfy { !isEnabled($0) }
    }
    
    /// Check if all kana categories are disabled
    var allKanaDisabled: Bool {
        return KanjiCategory.kanaCategories.allSatisfy { !isEnabled($0) }
    }
    
    /// Reset to default (all enabled)
    func resetToDefault() {
        storage = KanjiCategory.allTags
        persist()
    }
}

// MARK: - Menu State Store

/// Stores user's menu navigation state (difficulty, expanded packs)
final class MenuStateStore {
    static let shared = MenuStateStore()
    private let defaultsKey = "menuState.v1"
    private var storage: MenuStateData
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private struct MenuStateData: Codable {
        var selectedDifficulty: Int  // Raw value of DifficultyLevel
        var expandedPackNames: Set<String>  // Names of expanded song packs
        var currentPage: Int
        
        static let `default` = MenuStateData(selectedDifficulty: 1, expandedPackNames: [], currentPage: 0)
    }
    
    private init() {
        storage = MenuStateData.default
        load()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode(MenuStateData.self, from: data) else {
            return
        }
        storage = decoded
    }
    
    private func persist() {
        if let data = try? encoder.encode(storage) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    // MARK: - Difficulty
    
    var selectedDifficulty: DifficultyLevel {
        get { DifficultyLevel(rawValue: storage.selectedDifficulty) ?? .easy }
        set {
            storage.selectedDifficulty = newValue.rawValue
            persist()
        }
    }
    
    // MARK: - Expanded Packs
    
    func isPackExpanded(_ packName: String) -> Bool {
        return storage.expandedPackNames.contains(packName)
    }
    
    func setPackExpanded(_ packName: String, expanded: Bool) {
        if expanded {
            storage.expandedPackNames.insert(packName)
        } else {
            storage.expandedPackNames.remove(packName)
        }
        persist()
    }
    
    func togglePackExpanded(_ packName: String) {
        if storage.expandedPackNames.contains(packName) {
            storage.expandedPackNames.remove(packName)
        } else {
            storage.expandedPackNames.insert(packName)
        }
        persist()
    }
    
    // MARK: - Pagination
    
    var currentPage: Int {
        get { storage.currentPage }
        set {
            storage.currentPage = newValue
            persist()
        }
    }
}

// MARK: - Tutorial Completion Store

/// Tracks whether the onboarding tutorial has been completed.
final class TutorialStore {
    static let shared = TutorialStore()
    private let defaultsKey = "tutorialStore.v1"
    private var completed: Bool = false
    private init() {
        load()
    }
    private func load() {
        completed = UserDefaults.standard.bool(forKey: defaultsKey)
    }
    private func persist() {
        UserDefaults.standard.set(completed, forKey: defaultsKey)
    }
    var hasCompletedTutorial: Bool {
        get { completed }
        set {
            completed = newValue
            persist()
        }
    }
    func reset() {
        hasCompletedTutorial = false
    }
}
