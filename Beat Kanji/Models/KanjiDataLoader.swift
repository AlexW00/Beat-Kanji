//
//  KanjiDataLoader.swift
//  Beat Kanji
//
//  SQLite-backed loader for kanji metadata and stroke geometry.
//

import Foundation
import SQLite

final class KanjiDataLoader {
    
    static let shared = KanjiDataLoader()
    
    private var cachedKanjiData: [KanjiEntry] = []
    private var strokeCache: [String: [Stroke]] = [:]
    private var hasLoadedKanjiData = false
    private var connection: Connection?
    private let queue = DispatchQueue(label: "com.beatkanji.kanjidataloader", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Public API
    
    @discardableResult
    func preloadPrototypeData() -> [KanjiEntry] {
        if hasLoadedKanjiData {
            return cachedKanjiData
        }
        cachedKanjiData = loadPrototypeData()
        return cachedKanjiData
    }
    
    var preloadedKanji: [KanjiEntry] {
        if hasLoadedKanjiData {
            return cachedKanjiData
        }
        return preloadPrototypeData()
    }
    
    /// Load kanji metadata (id, char, stroke_count, tags, keyword) from the bundled SQLite DB.
    func loadPrototypeData() -> [KanjiEntry] {
        if hasLoadedKanjiData {
            return cachedKanjiData
        }
        
        do {
            let result = try queue.sync {
                try self.fetchKanjiMetadata()
            }
            cachedKanjiData = result
            hasLoadedKanjiData = true
            print("Loaded \(cachedKanjiData.count) kanji entries (metadata only).")
            return cachedKanjiData
        } catch {
            print("Error loading kanji metadata: \(error)")
            return []
        }
    }
    
    /// Load strokes lazily for a given kanji id. Results are cached per kanji.
    func loadStrokes(for kanjiId: String, expectedCount: Int? = nil) -> [Stroke] {
        do {
            return try queue.sync {
                if let cached = strokeCache[kanjiId] {
#if DEBUG
                    if let expected = expectedCount, cached.count != expected {
                        assertionFailure("Kanji \(kanjiId): expected \(expected) strokes, cached \(cached.count)")
                    }
#endif
                    return cached
                }
                let strokes = try self.fetchStrokes(for: kanjiId)
#if DEBUG
                if let expected = expectedCount, strokes.count != expected {
                    assertionFailure("Kanji \(kanjiId): expected \(expected) strokes, loaded \(strokes.count)")
                }
#endif
                strokeCache[kanjiId] = strokes
                return strokes
            }
        } catch {
            print("Error loading strokes for \(kanjiId): \(error)")
            return []
        }
    }
    
    // MARK: - Private helpers
    
    private enum KanjiLoadError: Error {
        case missingDatabase
    }
    
    private func openDatabase() throws -> Connection {
        if let connection {
            return connection
        }
        
        guard let url = Bundle.main.url(forResource: "kanji", withExtension: "sqlite") else {
            throw KanjiLoadError.missingDatabase
        }
        let conn = try Connection(url.path, readonly: true)
        connection = conn
        return conn
    }
    
    private func fetchKanjiMetadata() throws -> [KanjiEntry] {
        let db = try openDatabase()
        
        let kanjiTable = Table("kanji")
        let tagsTable = Table("kanji_tags")
        
        let idCol = Expression<String>("id")
        let charCol = Expression<String>("char")
        let strokeCountCol = Expression<Int>("stroke_count")
        let keywordCol = Expression<String?>("keyword")
        
        let tagKanjiIdCol = Expression<String>("kanji_id")
        let tagCol = Expression<String>("tag")
        
        // Build tag lookup
        var tagsLookup: [String: [String]] = [:]
        for row in try db.prepare(tagsTable) {
            let kanjiId = row[tagKanjiIdCol]
            tagsLookup[kanjiId, default: []].append(row[tagCol])
        }
        
        var results: [KanjiEntry] = []
        for row in try db.prepare(kanjiTable) {
            let kanjiId = row[idCol]
            let keywordValue: String? = row[keywordCol]
            let keyword = keywordValue.map { Keyword(uniq: $0) }
            let tags = tagsLookup[kanjiId] ?? []
            let entry = KanjiEntry(
                id: kanjiId,
                char: row[charCol],
                strokeCount: row[strokeCountCol],
                tags: tags,
                keyword: keyword
            )
            results.append(entry)
        }
        
        return results
    }
    
    private func fetchStrokes(for kanjiId: String) throws -> [Stroke] {
        let db = try openDatabase()
        let strokesTable = Table("strokes").filter(Expression<String>("kanji_id") == kanjiId).order(Expression<Int>("stroke_index"))
        
        let strokeIdCol = Expression<String?>("stroke_id")
        let pointsCol = Expression<Blob>("points")
        
        var strokes: [Stroke] = []
        for row in try db.prepare(strokesTable) {
            let blob = row[pointsCol]
            let points = decodePoints(from: blob)
            let strokeId = row[strokeIdCol] ?? "\(kanjiId)-\(strokes.count)"
            let stroke = Stroke(id: strokeId, points: points)
            strokes.append(stroke)
        }
        return strokes
    }
    
    private func decodePoints(from blob: Blob) -> [[Double]] {
        let data = Data(blob.bytes)
        let floatCount = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0, count: floatCount)
        _ = floats.withUnsafeMutableBytes { buffer in
            data.copyBytes(to: buffer)
        }
        
        var points: [[Double]] = []
        points.reserveCapacity(floatCount / 2)
        var idx = 0
        while idx + 1 < floats.count {
            points.append([Double(floats[idx]), Double(floats[idx + 1])])
            idx += 2
        }
        return points
    }
}
