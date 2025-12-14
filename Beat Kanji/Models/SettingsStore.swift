//
//  SettingsStore.swift
//  Beat Kanji
//
//  Created by Copilot on 29.11.25.
//

import Foundation
import UIKit

/// Options for what to display after completing a kanji
enum PostKanjiDisplayOption: String, Codable, CaseIterable {
    case meaning = "meaning"
    case nothing = "nothing"
    
    var displayName: String {
        switch self {
        case .meaning: return NSLocalizedString("settings.display.meaning", comment: "Show meaning option")
        case .nothing: return NSLocalizedString("settings.display.nothing", comment: "No display option")
        }
    }
}

/// Options for iPad input mode
enum iPadInputMode: String, Codable, CaseIterable {
    case `default` = "default"
    case applePencil = "applePencil"

    var displayName: String {
        switch self {
        case .default: return NSLocalizedString("settings.ipad.default", comment: "Default mode")
        case .applePencil: return NSLocalizedString("settings.ipad.applePencil", comment: "Apple Pencil mode")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        if let value = iPadInputMode(rawValue: rawValue) {
            self = value
            return
        }

        // Backwards compatibility: previously stored as "bigKanji"
        if rawValue == "bigKanji" {
            self = .default
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid iPadInputMode value: \(rawValue)")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Options for kanji size in play scene
enum KanjiSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return NSLocalizedString("settings.kanjiSize.small", comment: "Small kanji size")
        case .medium: return NSLocalizedString("settings.kanjiSize.medium", comment: "Medium kanji size")
        case .large: return NSLocalizedString("settings.kanjiSize.large", comment: "Large kanji size")
        }
    }
    
    /// Returns the kanji scale (as a fraction of screen size) for iPhone
    var iPhoneScale: CGFloat {
        switch self {
        case .small: return 0.55
        case .medium: return 0.70
        case .large: return 0.85
        }
    }
    
    /// Returns the kanji scale (as a fraction of screen size) for iPad
    var iPadScale: CGFloat {
        switch self {
        case .small: return 0.25
        case .medium: return 0.40
        case .large: return 0.50
        }
    }
    
    /// Returns the bottom offset (as a fraction of screen height) for iPhone
    var iPhoneBottomOffset: CGFloat {
        switch self {
        case .small: return 0.22
        case .medium: return 0.18
        case .large: return 0.12
        }
    }
    
    /// Returns the bottom offset (as a fraction of screen height) for iPad
    var iPadBottomOffset: CGFloat {
        switch self {
        case .small: return 0.30
        case .medium: return 0.24
        case .large: return 0.18
        }
    }

    /// Multiplier for stroke widths; medium is the baseline
    var strokeWidthMultiplier: CGFloat {
        switch self {
        case .small: return 0.80
        case .medium: return 1.0
        case .large: return 1.10
        }
    }
}

struct SettingsData: Codable {
    var musicVolume: Float
    var interfaceVolume: Float
    var postKanjiDisplay: PostKanjiDisplayOption
    var iPadInputMode: iPadInputMode
    var kanjiSize: KanjiSize
    
    // Default volumes start at 100% so new players hear full audio by default
    static let `default` = SettingsData(musicVolume: 1.0, interfaceVolume: 1.0, postKanjiDisplay: .meaning, iPadInputMode: .default, kanjiSize: .medium)
}

final class SettingsStore {
    static let shared = SettingsStore()
    
    private let defaultsKey = "settingsStore.v1"
    private var settings: SettingsData
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        settings = SettingsData.default
        load()
    }
    
    // MARK: - Accessors
    
    var musicVolume: Float {
        get { settings.musicVolume }
        set {
            settings.musicVolume = max(0, min(1, newValue))
            persist()
        }
    }
    
    var interfaceVolume: Float {
        get { settings.interfaceVolume }
        set {
            settings.interfaceVolume = max(0, min(1, newValue))
            persist()
        }
    }
    
    var postKanjiDisplay: PostKanjiDisplayOption {
        get { settings.postKanjiDisplay }
        set {
            settings.postKanjiDisplay = newValue
            persist()
        }
    }
    
    var iPadInputMode: iPadInputMode {
        get { settings.iPadInputMode }
        set {
            settings.iPadInputMode = newValue
            persist()
        }
    }
    
    var kanjiSize: KanjiSize {
        get { settings.kanjiSize }
        set {
            settings.kanjiSize = newValue
            persist()
        }
    }
    
    // MARK: - Persistence
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? decoder.decode(SettingsData.self, from: data) else {
            return
        }
        settings = decoded
    }
    
    private func persist() {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
