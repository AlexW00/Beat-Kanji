//
//  BeatmapLoader.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import Foundation

// MARK: - Difficulty Level

enum DifficultyLevel: Int, CaseIterable {
    case easy = 1
    case medium = 2
    case hard = 3
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "Quarter notes, relaxed pace"
        case .medium: return "Eighth notes, moderate pace"
        case .hard: return "All notes, intense pace"
        }
    }
}

// MARK: - Beatmap Models

struct BeatmapMeta: Codable {
    let version: String
    let filename: String
    let title: String?
    let category: String?
    let priority: Int?
    let bpm: Double
    let total_duration: Double
    
    /// Display title, falls back to filename without extension
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return (filename as NSString).deletingPathExtension
    }
    
    /// Display category, defaults to "Uncategorized"
    var displayCategory: String {
        if let category = category, !category.isEmpty {
            return category
        }
        return "Uncategorized"
    }

    /// Display priority, defaults to 0
    var displayPriority: Int {
        return priority ?? 0
    }
}

struct BeatNote: Codable {
    let time: Double
    let level: Int
    let type: String
}

struct Beatmap: Codable {
    let meta: BeatmapMeta
    let notes: [BeatNote]
    
    /// Time in seconds to skip at the beginning for player preparation
    static let introSkipTime: Double = 3.0
    
    /// Filter notes based on difficulty level
    /// - Easy: level == 1 only
    /// - Medium: level <= 2
    /// - Hard: level <= 3 (all notes)
    /// Also filters out notes in the first 3 seconds to give players time to prepare
    func notesForDifficulty(_ difficulty: DifficultyLevel) -> [BeatNote] {
        let filteredByLevel: [BeatNote]
        switch difficulty {
        case .easy:
            filteredByLevel = notes.filter { $0.level == 1 }
        case .medium:
            filteredByLevel = notes.filter { $0.level <= 2 }
        case .hard:
            filteredByLevel = notes.filter { $0.level <= 3 }
        }
        
        // Skip notes in the first few seconds to give player time to prepare
        return filteredByLevel.filter { $0.time >= Beatmap.introSkipTime }
    }
    
    
    /// Get the interval between beats based on BPM
    var beatInterval: TimeInterval {
        return 60.0 / meta.bpm
    }
    
    /// Get quarter note interval
    var quarterNoteInterval: TimeInterval {
        return beatInterval
    }
    
    /// Get eighth note interval
    var eighthNoteInterval: TimeInterval {
        return beatInterval / 2.0
    }
}

// MARK: - Beatmap Loader

/// Represents a song with its metadata (without loading the full beatmap)
struct SongInfo {
    let beatmapName: String  // JSON file name without extension
    let title: String
    let category: String
    let audioFilename: String
    let bpm: Double
    let duration: Double
    let priority: Int
    
    /// Unique identifier for the song (used for high scores, etc.)
    var id: String {
        let raw = "\(category)-\(title)".lowercased()
        let parts = raw.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return parts.joined(separator: "-")
    }
}

/// Groups songs by category for display
struct SongCategory {
    let name: String
    var songs: [SongInfo]
}

class BeatmapLoader {
    static let shared = BeatmapLoader()

    /// Cached song categories (loaded once)
    private var cachedCategories: [SongCategory]?

    /// Beatmap names to exclude from song discovery (non-playable/debug files)
    private let excludedBeatmaps: Set<String> = ["debug", "short", "categories"]

    /// Categories list file
    private let categoriesFileName = "categories"

    /// Simple category model for decoding categories.json
    private struct CategoryDefinition: Decodable {
        let name: String
    }
    
    private init() {}
    
    /// Discover all available songs from beatmap JSON files in the bundle
    /// Returns songs grouped by category
    func discoverSongs() -> [SongCategory] {
        if let cached = cachedCategories {
            return cached
        }

        var categoryMap: [String: [SongInfo]] = [:]
        let configuredCategories = loadConfiguredCategories()

        // Find all JSON files in the bundle
        guard let resourcePath = Bundle.main.resourcePath else {
            print("Error: Could not access bundle resource path")
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            let jsonFiles = files.filter { $0.hasSuffix(".json") }
            
            for file in jsonFiles {
                let baseName = (file as NSString).deletingPathExtension
                
                // Skip excluded files
                if excludedBeatmaps.contains(baseName) {
                    continue
                }
                
                // Skip kanji data files
                if baseName.contains("kanji") {
                    continue
                }
                
                // Try to load beatmap metadata
                if let beatmap = loadBeatmap(named: baseName) {
                    let songInfo = SongInfo(
                        beatmapName: baseName,
                        title: beatmap.meta.displayTitle,
                        category: beatmap.meta.displayCategory,
                        audioFilename: beatmap.meta.filename,
                        bpm: beatmap.meta.bpm,
                        duration: beatmap.meta.total_duration,
                        priority: beatmap.meta.displayPriority
                    )
                    
                    categoryMap[songInfo.category, default: []].append(songInfo)
                }
            }
        } catch {
            print("Error discovering beatmaps: \(error)")
        }

        let categories = buildCategories(from: categoryMap, orderedBy: configuredCategories)
        cachedCategories = categories
        print("Discovered \(categories.count) categories with \(categories.flatMap { $0.songs }.count) songs total")

        return categories
    }
    
    /// Load beatmap from a JSON file in the bundle
    func loadBeatmap(named filename: String) -> Beatmap? {
        let baseName = (filename as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: baseName, withExtension: "json") else {
            print("Error: \(baseName).json not found in Bundle")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let beatmap = try decoder.decode(Beatmap.self, from: data)
            print("Loaded beatmap: \(beatmap.meta.filename), BPM: \(beatmap.meta.bpm), Notes: \(beatmap.notes.count)")
            return beatmap
        } catch {
            print("Error loading beatmap: \(error)")
            return nil
        }
    }
    
    /// Load the debug beatmap
    func loadDebugBeatmap() -> Beatmap? {
        return loadBeatmap(named: "debug")
    }

    // MARK: - Private helpers

    private func sortedSongs(_ songs: [SongInfo]) -> [SongInfo] {
        return songs.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title < rhs.title
            }
            return lhs.priority > rhs.priority
        }
    }

    private func loadConfiguredCategories() -> [String] {
        guard let url = categoriesFileURL() else {
            print("Warning: categories.json not found in bundle; using discovered categories")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let categories = try decoder.decode([CategoryDefinition].self, from: data)
            return categories.map { $0.name }
        } catch {
            print("Error loading categories.json: \(error)")
            return []
        }
    }

    private func categoriesFileURL() -> URL? {
        if let direct = Bundle.main.url(forResource: categoriesFileName, withExtension: "json") {
            return direct
        }

        if let matches = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            return matches.first(where: { $0.lastPathComponent == "\(categoriesFileName).json" })
        }

        return nil
    }

    private func buildCategories(from map: [String: [SongInfo]], orderedBy configured: [String]) -> [SongCategory] {
        var categories: [SongCategory] = []

        // First, add categories in the configured order
        if !configured.isEmpty {
            for name in configured {
                let songs = sortedSongs(map[name] ?? [])
                categories.append(SongCategory(name: name, songs: songs))
            }

            // Warn about any songs whose categories are not in the configured list
            let remaining = map.keys.filter { !configured.contains($0) }
            if !remaining.isEmpty {
                print("Warning: categories.json missing entries for categories: \(remaining.joined(separator: ", "))")
            }

            return categories
        }

        // Add any remaining categories not listed in categories.json (sorted alphabetically)
        let remaining = map.keys.sorted()
        for name in remaining {
            let songs = sortedSongs(map[name] ?? [])
            categories.append(SongCategory(name: name, songs: songs))
        }

        return categories
    }
}
