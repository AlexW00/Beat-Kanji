//
//  TierRank.swift
//  Beat Kanji
//
//  Created by Codex on 05.12.25.
//

import Foundation

/// Represents a tier rank based on completion percentage
enum TierRank: String, CaseIterable {
    case S = "S"
    case A = "A"
    case B = "B"
    case C = "C"
    case D = "D"
    
    /// Returns the tier rank for a given percentage (0-100)
    static func from(percentage: Double) -> TierRank {
        switch percentage {
        case 90...100:
            return .S
        case 80..<90:
            return .A
        case 60..<80:
            return .B
        case 30..<60:
            return .C
        default:
            return .D
        }
    }
    
    /// The asset name for the tier icon
    var iconName: String {
        switch self {
        case .S: return "tier-s"
        case .A: return "tier-a"
        case .B: return "tier-b"
        case .C: return "tier-c"
        case .D: return "tier-d"
        }
    }
}
