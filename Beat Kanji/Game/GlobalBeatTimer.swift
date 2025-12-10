//
//  GlobalBeatTimer.swift
//  Beat Kanji
//
//  Created for seamless conveyor belt transitions between scenes.
//

import Foundation

/// A singleton that provides a continuous time reference for BPM-synced animations.
/// This ensures the conveyor belt stays in phase across scene transitions.
class GlobalBeatTimer {
    static let shared = GlobalBeatTimer()
    
    /// The BPM used for menu animations
    let menuBPM: Double = 100.0
    
    /// Continuous time that persists across scene transitions
    private(set) var globalTime: TimeInterval = 0
    
    /// Last update timestamp from the scene
    private var lastSystemTime: TimeInterval = 0
    
    /// Whether the timer has been initialized with a system time
    private var isInitialized: Bool = false
    
    private init() {}
    
    /// Update the global time based on the scene's current update time.
    /// Call this from each scene's `update(_:)` method.
    /// - Parameter systemTime: The `currentTime` parameter from SKScene's update method
    /// - Returns: The delta time since last update
    @discardableResult
    func update(systemTime: TimeInterval) -> TimeInterval {
        if !isInitialized || lastSystemTime == 0 {
            lastSystemTime = systemTime
            isInitialized = true
            return 0
        }
        
        let dt = systemTime - lastSystemTime
        lastSystemTime = systemTime
        
        // Cap delta time to prevent large jumps during scene transitions
        // This keeps the belt moving smoothly even if there's a gap in updates
        let cappedDt = min(dt, 0.1)  // Max 100ms per frame
        globalTime += cappedDt
        
        return cappedDt
    }
    
    /// Notify the timer that a scene transition is about to happen.
    /// This helps maintain smooth timing across transitions.
    func prepareForSceneTransition() {
        // Reset lastSystemTime so next update doesn't see a huge delta
        lastSystemTime = 0
    }
    
    /// The interval between conveyor line spawns (in seconds)
    var conveyorSpawnInterval: TimeInterval {
        60.0 / menuBPM
    }
    
    /// The duration for a line to travel from spawn to end (4 beats)
    var flightDuration: TimeInterval {
        60.0 / menuBPM * 4.0
    }
    
    /// Calculate the next spawn time that's aligned with the beat
    /// - Parameter afterTime: The time after which to find the next spawn
    /// - Returns: The next beat-aligned spawn time
    func nextAlignedSpawnTime(after afterTime: TimeInterval) -> TimeInterval {
        let interval = conveyorSpawnInterval
        let beatNumber = ceil(afterTime / interval)
        return beatNumber * interval
    }
    
    /// Reset the timer (e.g., when returning to a fresh start)
    func reset() {
        globalTime = 0
        lastSystemTime = 0
        isInitialized = false
    }
}
