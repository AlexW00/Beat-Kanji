//
//  HapticManager.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import UIKit
import CoreHaptics

/// Manages haptic feedback for stroke drawing
class HapticManager {
    static let shared = HapticManager()
    
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var isHapticsSupported: Bool = false
    
    // Timing for warning haptics
    private var lastWarningTime: TimeInterval = 0
    private let minWarningInterval: TimeInterval = 0.08 // Slightly slower for warnings
    
    // Track zone state for edge detection
    private var wasInGoodZone: Bool = true
    
    // Fallback generators for devices without CoreHaptics
    private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private init() {
        setupHaptics()
    }
    
    private func setupHaptics() {
        // Check if device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            isHapticsSupported = false
            // Pre-warm fallback generators
            impactGenerator.prepare()
            softImpactGenerator.prepare()
            mediumImpactGenerator.prepare()
            return
        }
        
        isHapticsSupported = true
        
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.playsHapticsOnly = true
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            // Handle engine stopped
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
            
            try hapticEngine?.start()
            
            // Pre-warm fallback generators as backup
            impactGenerator.prepare()
            softImpactGenerator.prepare()
            mediumImpactGenerator.prepare()
            
        } catch {
            print("Failed to create haptic engine: \(error)")
            isHapticsSupported = false
        }
    }
    
    /// Trigger warning haptics when drifting OFF the stroke path
    /// - Parameters:
    ///   - isInGoodZone: Whether the touch is currently in the good/perfect zone
    ///   - distanceFromPath: How far from the path (0 = on path, higher = further away)
    ///   - currentTime: Current time to throttle warnings
    func triggerStrokeWarning(isInGoodZone: Bool, distanceFromPath: CGFloat, currentTime: TimeInterval) {
        // Check for zone transition (edge detection)
        if wasInGoodZone && !isInGoodZone {
            // Just left the good zone - single warning tap
            triggerZoneExitWarning()
        }
        wasInGoodZone = isInGoodZone
        
        // If in good zone, no continuous warning needed (silence = success)
        guard !isInGoodZone else { return }
        
        // Throttle continuous warnings
        guard currentTime - lastWarningTime >= minWarningInterval else { return }
        lastWarningTime = currentTime
        
        // Further from path = stronger warning
        // distanceFromPath typically ranges from 0.10 (just outside) to 0.30+ (way off)
        let warningIntensity = min((distanceFromPath - 0.10) / 0.15, 1.0) // 0 to 1 based on distance
        
        if warningIntensity > 0.1 {
            if isHapticsSupported, let engine = hapticEngine {
                playWarningHaptic(engine: engine, intensity: warningIntensity)
            } else {
                playFallbackWarning(intensity: warningIntensity)
            }
        }
    }
    
    /// Reset zone tracking when starting a new stroke
    func resetZoneTracking() {
        wasInGoodZone = true
    }
    
    /// Trigger a single tap when starting to draw on the stroke path
    func triggerStrokeStart() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                let hapticEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Fallback silently
            }
        } else {
            softImpactGenerator.impactOccurred(intensity: 0.6)
        }
    }
    
    private func triggerZoneExitWarning() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                // Sharp tap when leaving good zone
                let hapticEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Fallback
            }
        } else {
            mediumImpactGenerator.impactOccurred(intensity: 0.8)
        }
    }
    
    private func playWarningHaptic(engine: CHHapticEngine, intensity: CGFloat) {
        let clampedIntensity = Float(min(max(intensity * 0.6, 0.2), 0.7)) // Keep warnings moderate
        
        do {
            // Rough, scratchy haptic for being off-path
            let hapticEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3) // Low sharpness = rough
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            // Fallback silently
        }
    }
    
    private func playFallbackWarning(intensity: CGFloat) {
        if intensity > 0.5 {
            impactGenerator.impactOccurred(intensity: intensity * 0.7)
        } else {
            softImpactGenerator.impactOccurred(intensity: intensity * 0.5)
        }
    }
    
    /// Trigger a success haptic for completing a stroke
    /// - Parameter type: The score type (perfect, acceptable, miss)
    func triggerStrokeComplete(type: ScoreType) {
        switch type {
        case .perfect:
            triggerPerfectPattern()
        case .acceptable:
            triggerGoodPattern()
        case .miss:
            triggerFailurePattern()
        }
    }
    
    private func triggerPerfectPattern() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                // Single crisp, strong tap for perfect - feels decisive and clean
                let hapticEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0) // Max sharpness = crisp
                    ],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred(intensity: 1.0)
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred(intensity: 1.0)
        }
    }
    
    private func triggerGoodPattern() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                // Very soft, subtle tap for good - noticeably different from perfect
                let hapticEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3) // Soft and muted
                    ],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.impactOccurred(intensity: 0.3)
            }
        } else {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred(intensity: 0.3)
        }
    }
    
    private func triggerFailurePattern() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                // Softer, gentler buzz for miss — distinct but not jarring
                let events = [
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25) // Softer, less harsh
                        ],
                        relativeTime: 0,
                        duration: 0.07
                    )
                ]
                
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                // Fallback: subtle warning notification when complex haptics fail
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }
        } else {
            // Fallback for older devices: small soft impact
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred(intensity: 0.25)
        }
    }

    /// Subtle celebratory pulse when a kanji is fully completed (shown with meaning)
    func triggerKanjiCompleteMeaning() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                let first = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                    ],
                    relativeTime: 0
                )
                let second = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: 0.12
                )
                let pattern = try CHHapticPattern(events: [first, second], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                mediumImpactGenerator.impactOccurred(intensity: 0.7)
            }
        } else {
            mediumImpactGenerator.impactOccurred(intensity: 0.7)
        }
    }
    
    /// Prepare haptics before starting a game session
    func prepareForGameplay() {
        impactGenerator.prepare()
        softImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        resetZoneTracking()
        
        if isHapticsSupported {
            do {
                try hapticEngine?.start()
            } catch {
                print("Failed to start haptic engine: \(error)")
            }
        }
    }
    
    /// Trigger a firework burst haptic with ripple effects for victory screen
    /// Creates a burst with progressively slowing ripples that fade out like a real explosion
    func triggerFirework() {
        if isHapticsSupported, let engine = hapticEngine {
            do {
                // Strong initial pop + ripples with progressively INCREASING intervals
                // to simulate the explosion fading away (ripples slow down as energy dissipates)
                var events: [CHHapticEvent] = []
                
                // Main explosion - strong and sharp
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0
                ))
                
                // Ripple parameters: each ripple has increasing delay and decreasing intensity
                // Times: 0.05, 0.12, 0.22, 0.35, 0.52, 0.73, 0.98 (progressively slower)
                let rippleData: [(delay: Double, intensity: Float, sharpness: Float)] = [
                    (0.05, 0.75, 0.7),   // 1st ripple - very close, still strong
                    (0.12, 0.55, 0.55),  // 2nd ripple - 70ms later
                    (0.22, 0.42, 0.45),  // 3rd ripple - 100ms later
                    (0.35, 0.32, 0.35),  // 4th ripple - 130ms later
                    (0.52, 0.22, 0.28),  // 5th ripple - 170ms later
                    (0.73, 0.15, 0.22),  // 6th ripple - 210ms later
                    (0.98, 0.10, 0.18),  // 7th ripple - 250ms later (fading)
                    (1.28, 0.06, 0.12),  // 8th ripple - 300ms later (nearly gone)
                ]
                
                for ripple in rippleData {
                    events.append(CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: ripple.intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: ripple.sharpness)
                        ],
                        relativeTime: ripple.delay
                    ))
                }
                
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Fallback: schedule multiple impacts with GCD for fading effect
                triggerFireworkFallback()
            }
        } else {
            triggerFireworkFallback()
        }
    }
    
    /// Fallback firework haptics for devices without CoreHaptics
    private func triggerFireworkFallback() {
        // Initial strong impact
        mediumImpactGenerator.impactOccurred(intensity: 1.0)
        
        // Schedule fading ripples with increasing delays
        let ripples: [(delay: Double, intensity: Double)] = [
            (0.08, 0.6),
            (0.18, 0.4),
            (0.32, 0.25),
            (0.50, 0.15),
        ]
        
        for ripple in ripples {
            DispatchQueue.main.asyncAfter(deadline: .now() + ripple.delay) { [weak self] in
                self?.softImpactGenerator.impactOccurred(intensity: ripple.intensity)
            }
        }
    }
    
    /// Stop haptic engine when not needed
    func stopHaptics() {
        hapticEngine?.stop()
    }
}
