//
//  KanjiModels.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import Foundation
import CoreGraphics

/// Keyword data for a kanji character
struct Keyword {
    let uniq: String?
}

struct KanjiEntry {
    let id: String
    let char: String
    let strokeCount: Int
    let tags: [String]
    let keyword: Keyword?
    
    /// Lazily load stroke geometry from the SQLite dataset when needed.
    /// Results are cached inside KanjiDataLoader.
    var strokes: [Stroke] {
        KanjiDataLoader.shared.loadStrokes(for: id, expectedCount: strokeCount)
    }
    
    /// Check if this kanji has any of the specified tags
    func hasAnyTag(from enabledTags: Set<String>) -> Bool {
        return tags.contains { enabledTags.contains($0) }
    }
    
    /// Get keyword for the specified display option
    func getKeyword(for option: PostKanjiDisplayOption) -> String? {
        switch option {
        case .meaning:
            return keyword?.uniq
        case .nothing:
            return nil
        }
    }
}

/// Available category tags for filtering kanji
enum KanjiCategory: String, CaseIterable {
    case n5, n4, n3, n2, n1
    case hiragana, katakana
    
    var displayName: String {
        switch self {
        case .n5: return "N5"
        case .n4: return "N4"
        case .n3: return "N3"
        case .n2: return "N2"
        case .n1: return "N1"
        case .hiragana: return "Hiragana"
        case .katakana: return "Katakana"
        }
    }
    
    static var kanjiCategories: [KanjiCategory] {
        [.n5, .n4, .n3, .n2, .n1]
    }
    
    static var kanaCategories: [KanjiCategory] {
        [.hiragana, .katakana]
    }
    
    static var allTags: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
}

struct Stroke {
    let id: String
    let points: [[Double]] // JSON is array of arrays [x, y]
    
    // Helper to convert to CGPoints
    var cgPoints: [CGPoint] {
        return points.map { CGPoint(x: $0[0], y: $0[1]) }
    }
    
    // Calculate total length of the stroke
    func length() -> Double {
        let pts = cgPoints
        guard pts.count > 1 else { return 0 }
        var total: Double = 0
        for i in 0..<pts.count-1 {
            let p1 = pts[i]
            let p2 = pts[i+1]
            total += hypot(p2.x - p1.x, p2.y - p1.y)
        }
        return total
    }
    
    // Resample points to a fixed count (equidistant)
    func resample(count: Int) -> [CGPoint] {
        let pts = cgPoints
        guard pts.count > 1 else { return Array(repeating: pts.first ?? .zero, count: count) }
        
        let totalLength = length()
        let interval = totalLength / Double(count - 1)
        
        var newPoints: [CGPoint] = [pts[0]]
        var currentDist: Double = 0
        var nextDist: Double = interval
        
        var i = 0
        
        // Walk along the path
        while newPoints.count < count {
            if i >= pts.count - 1 {
                newPoints.append(pts.last!)
                continue
            }
            
            let p1 = pts[i]
            let p2 = pts[i+1]
            let dist = hypot(p2.x - p1.x, p2.y - p1.y)
            
            if currentDist + dist >= nextDist {
                // The next point is on this segment
                let t = (nextDist - currentDist) / dist
                let newX = p1.x + (p2.x - p1.x) * CGFloat(t)
                let newY = p1.y + (p2.y - p1.y) * CGFloat(t)
                let newPoint = CGPoint(x: newX, y: newY)
                newPoints.append(newPoint)
                
                nextDist += interval
                // Don't advance i, we might find another point on this segment
            } else {
                currentDist += dist
                i += 1
            }
        }
        
        return newPoints
    }
}
