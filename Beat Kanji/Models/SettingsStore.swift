//
//  SettingsStore.swift
//  Beat Kanji
//
//  Created by Copilot on 29.11.25.
//

import Foundation

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

/// Options for iPad input mode (affects kanji size in play scene)
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

struct SettingsData: Codable {
    var musicVolume: Float
    var interfaceVolume: Float
    var postKanjiDisplay: PostKanjiDisplayOption
    var iPadInputMode: iPadInputMode
    
    // Default volumes start at 100% so new players hear full audio by default
    static let `default` = SettingsData(musicVolume: 1.0, interfaceVolume: 1.0, postKanjiDisplay: .meaning, iPadInputMode: .default)
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
