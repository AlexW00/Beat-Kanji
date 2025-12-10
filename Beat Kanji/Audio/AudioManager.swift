//
//  AudioManager.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import AVFoundation

/// Types of UI sounds that can be played
enum UISoundType: String {
    case button = "click-button"
    case buttonBack = "click-button-back"
    case popup = "click-popup"
    case popupCollapse = "click-popup-collapse"
    case checkOn = "click-check"
    case checkOff = "click-uncheck"
    case categoryExpand = "toggle-on"
    case categoryCollapse = "toggle-off"
    case fireworkLaunch = "firework-launch"
    case fireworkBoom = "firework-explosion-boom"
    case fireworkCrackle = "firework-explosion-crackle"
    case gameOver = "game-over"
    case gameWon = "game-won"
    case glassShatter = "glass-shatter"
    case heartGained = "heart-gained"
    case heartLost = "heart-lost"
    case kanjiComplete = "kanji-stroke-perfect"
    case strokeTooEarly = "swipe-stroke-too-early"
}

class AudioManager {
    static let shared = AudioManager()
    
    private var player: AVAudioPlayer?
    private var menuPlayer: AVAudioPlayer?
    private var isMenuMusicPlaying: Bool = false
    
    // Pool of UI sound players for concurrent playback
    private var uiSoundPlayers: [AVAudioPlayer] = []
    private let maxConcurrentUISounds = 8
    
    // Cache for preloaded UI sounds
    private var uiSoundCache: [String: URL] = [:]
    
    private init() {
        preloadUISounds()
    }
    
    // MARK: - Volume
    
    /// Music volume from 0 to 1. Applied to music players.
    var musicVolume: Float {
        get { SettingsStore.shared.musicVolume }
        set {
            SettingsStore.shared.musicVolume = newValue
            applyMusicVolume()
        }
    }
    
    /// Interface volume from 0 to 1. Applied to UI sound players.
    var interfaceVolume: Float {
        get { SettingsStore.shared.interfaceVolume }
        set { SettingsStore.shared.interfaceVolume = newValue }
    }
    
    /// Apply current music volume to active music players
    private func applyMusicVolume() {
        player?.volume = musicVolume
        menuPlayer?.volume = musicVolume
    }
    
    /// Get the current playback time of the music
    var currentTime: TimeInterval {
        return player?.currentTime ?? 0
    }
    
    /// Get the duration of the currently loaded song (0 if unavailable)
    var currentSongDuration: TimeInterval {
        return player?.duration ?? 0
    }
    
    /// Check if music is currently playing
    var isPlaying: Bool {
        return player?.isPlaying ?? false
    }
    
    func playDebugMusic() {
        playSong(named: "debug")
    }
    
    func playSong(named name: String) {
        // Stop menu music when playing a song
        stopMenuMusic()
        
        let nameObj = name as NSString
        let baseName = nameObj.deletingPathExtension.isEmpty ? name : nameObj.deletingPathExtension
        let providedExtension = nameObj.pathExtension
        let primaryExtension = providedExtension.isEmpty ? "mp3" : providedExtension
        let url = Bundle.main.url(forResource: baseName, withExtension: primaryExtension)
            ?? (providedExtension.isEmpty ? nil : Bundle.main.url(forResource: baseName, withExtension: "mp3"))
        guard let songURL = url else {
            print("Error: \(baseName).\(primaryExtension) not found in Bundle. Please add the audio asset to the project.")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: songURL)
            player?.numberOfLoops = 0 // Play once (song has a defined length)
            player?.volume = musicVolume
            player?.play()
            print("Playing music: \(baseName).\(primaryExtension)")
        } catch {
            print("Error playing music: \(error)")
        }
    }
    
    func pauseMusic() {
        player?.pause()
    }
    
    func resumeMusic() {
        guard let player = player else { return }
        if !player.isPlaying {
            player.play()
        }
    }
    
    func stopMusic() {
        player?.stop()
    }
    
    /// Seek to a specific time in the music
    func seek(to time: TimeInterval) {
        player?.currentTime = time
    }
    
    // MARK: - Menu Music
    
    /// Play menu music in a loop. Does nothing if already playing.
    func playMenuMusic() {
        guard !isMenuMusicPlaying else { return }
        
        guard let menuURL = Bundle.main.url(forResource: "menu", withExtension: "mp3") else {
            print("Error: menu.mp3 not found in Bundle.")
            return
        }
        
        do {
            menuPlayer = try AVAudioPlayer(contentsOf: menuURL)
            menuPlayer?.numberOfLoops = -1 // Loop indefinitely
            menuPlayer?.volume = musicVolume
            menuPlayer?.play()
            isMenuMusicPlaying = true
            print("Playing menu music")
        } catch {
            print("Error playing menu music: \(error)")
        }
    }
    
    /// Stop menu music
    func stopMenuMusic() {
        menuPlayer?.stop()
        menuPlayer = nil
        isMenuMusicPlaying = false
    }
    
    // MARK: - UI Sounds
    
    /// Preload UI sound URLs for faster playback
    private func preloadUISounds() {
        for sound in [UISoundType.button, .buttonBack, .popup, .popupCollapse,
                      .checkOn, .checkOff, .categoryExpand, .categoryCollapse,
                      .fireworkLaunch, .fireworkBoom, .fireworkCrackle,
                      .gameOver, .gameWon, .glassShatter, .heartGained, .heartLost,
                      .kanjiComplete, .strokeTooEarly] {
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
                uiSoundCache[sound.rawValue] = url
            }
        }
    }
    
    /// Play a UI sound effect with the current interface volume
    /// - Parameters:
    ///   - sound: The type of UI sound to play
    ///   - volumeMultiplier: Optional multiplier for volume (0.0-1.0), useful for depth effects
    func playUISound(_ sound: UISoundType, volumeMultiplier: Float = 1.0) {
        guard interfaceVolume > 0 else { return }
        
        guard let url = uiSoundCache[sound.rawValue] ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
            print("Warning: UI sound \(sound.rawValue).wav not found")
            return
        }
        
        // Clean up finished players
        uiSoundPlayers.removeAll { !$0.isPlaying }
        
        // Limit concurrent sounds
        if uiSoundPlayers.count >= maxConcurrentUISounds {
            uiSoundPlayers.first?.stop()
            uiSoundPlayers.removeFirst()
        }
        
        do {
            let soundPlayer = try AVAudioPlayer(contentsOf: url)
            soundPlayer.volume = interfaceVolume * min(1.0, max(0.0, volumeMultiplier))
            soundPlayer.play()
            uiSoundPlayers.append(soundPlayer)
        } catch {
            print("Error playing UI sound \(sound.rawValue): \(error)")
        }
    }
    
    /// Play multiple UI sounds simultaneously (e.g., for game over: game-over + glass-shatter)
    /// - Parameter sounds: Array of UI sounds to play at once
    func playUISounds(_ sounds: [UISoundType]) {
        for sound in sounds {
            playUISound(sound)
        }
    }
}
