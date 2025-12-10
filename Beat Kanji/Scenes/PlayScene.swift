//
//  PlayScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit
import UIKit

class PlayScene: SKScene {
    
    // MARK: - Game State
    var gameEngine: GameEngine!
    var currentKanjiNode: SKNode?
    var currentStrokeNode: SKNode? // Container for Glow + Core
    var drawingPath: CGMutablePath?
    var currentStrokeNodePath: SKShapeNode? // Keep ref if needed, or just iterate children
    var currentDrawnPoints: [CGPoint] = []
    var strokeResults: [Int: ScoreType] = [:]
    var strokeEarnedPoints: [Int: Int] = [:]
    
    // MARK: - HUD
    var hudLayer: SKNode?
    var heartsContainer: SKNode?
    var heartNodes: [SKSpriteNode] = []
    var pauseButtonNode: SKNode?
    var pauseMenuNode: SKNode?
    var pauseDimNode: SKShapeNode?
    var isPauseMenuVisible = false
    var isGamePaused = false
    var didRecordSessionResult = false
    
    // MARK: - Stroke Timing Window
    var isDrawingStartedInWindow: Bool = false // Tracks if current drawing started during valid window
    var strokeWindowIndicator: SKShapeNode?    // Visual indicator for active stroke window
    var pendingTimeoutStrokeIndex: Int? = nil  // Track if we need to evaluate a partial stroke on timeout
    
    // MARK: - Touch State Tracking (for button press validation)
    private var pauseButtonTouchBegan = false
    private var resumeButtonTouchBegan = false
    private var exitButtonTouchBegan = false
    #if DEBUG
    private var skipButtonTouchBegan = false
    private var debugHeartButtonTouchBegan = false
    #endif
    
    // MARK: - iPad Mode Switcher
    var modeSwitcherControl: iPadModeSwitcher?
    
    // MARK: - Beatmap Integration
    var selectedDifficulty: DifficultyLevel = .easy
    var beatmap: Beatmap?
    var selectedSongId: String = "debug"
    var selectedSongFilename: String = "debug"
    var selectedSongTitle: String = "Debug"
    var enabledTags: Set<String> = KanjiCategory.allTags
    // Optional debug filter: force a specific set of kanji (by char or id) regardless of tags.
    var debugForcedKanjiIds: [String]? = nil
    
    // MARK: - Effects
    var sparkEmitter: SKEmitterNode?
    var strokeTrailEmitter: SKEmitterNode?
    
    // MARK: - Flying Strokes
    struct FlyingStroke {
        let index: Int
        let bgNode: SKShapeNode // The faint full stroke
        let fillNode: SKNode // Container for Glow + Core
        let arrivalTime: TimeInterval
        var depth: CGFloat = 10.0 // Starts far away
        let kanjiIndex: Int // Which kanji this stroke belongs to
        let isNextKanji: Bool // Whether this is a look-ahead stroke from the next kanji
        let isRainbow: Bool // Rainbow strokes restore health on perfect completion
    }
    
    var flyingStrokes: [FlyingStroke] = []
    var nextSpawnIndex: Int = 0
    let perspectiveFactor: CGFloat = 0.5
    let spawnDepth: CGFloat = 10.0
    
    // MARK: - Conveyor (BPM-synced)
    struct ConveyorLine {
        let node: SKShapeNode
        let spawnTime: TimeInterval
    }
    
    var conveyorLines: [ConveyorLine] = []
    var nextConveyorSpawnTime: TimeInterval = 0
    
    // Conveyor spawn interval will be calculated from BPM
    var conveyorSpawnInterval: TimeInterval {
        guard let bpm = beatmap?.meta.bpm, bpm > 0 else { return 0.5 }
        // Spawn a line every beat (quarter note)
        return 60.0 / bpm
    }
    
    var lastUpdateTime: TimeInterval = 0
    
    // MARK: - Look-ahead state
    var nextKanjiNode: SKNode? // Preview node for next kanji during look-ahead
    
    override func didMove(to view: SKView) {
        configureScene()
    }
    
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        removeAppLifecycleObservers()
    }
    
    override func update(_ currentTime: TimeInterval) {
        guard gameEngine != nil else { return }
        
        if isGamePaused {
            lastUpdateTime = currentTime
            return
        }
        
        lastUpdateTime = currentTime
        
        // Check if we need to force-evaluate a partial stroke (user is drawing but window closed)
        checkPartialStrokeTimeout()
        
        // Sync game time directly to audio playback for accurate beat timing
        gameEngine.update(audioTime: AudioManager.shared.currentTime)
        
        spawnIncomingStrokes()
        updateFlyingStrokes()
        updateConveyorBelt()
        updateKanjiVisuals()
    }
    
    /// Check if user is drawing but window has fully closed - evaluate partial stroke
    private func checkPartialStrokeTimeout() {
        guard isDrawingStartedInWindow,
              gameEngine.isUserDrawing,
              currentDrawnPoints.count >= 3,
              let kanji = gameEngine.currentKanji,
              gameEngine.currentStrokeIndex < kanji.strokes.count,
              gameEngine.currentStrokeIndex < gameEngine.strokeArrivalTimes.count else { return }
        
        let arrivalTime = gameEngine.strokeArrivalTimes[gameEngine.currentStrokeIndex]
        let windowEnd = arrivalTime + gameEngine.windowAfterArrival
        
        // If window has closed while user is drawing, force evaluate the partial stroke
        if gameEngine.currentTime > windowEnd {
            let targetIndex = gameEngine.currentStrokeIndex
            let targetStroke = kanji.strokes[targetIndex]
            
            // Normalize drawn points
            guard let node = currentKanjiNode,
                  let scale = node.userData?["scale"] as? CGFloat,
                  let offsetX = node.userData?["offsetX"] as? CGFloat,
                  let offsetY = node.userData?["offsetY"] as? CGFloat else { return }
            
            let normalizedPoints = currentDrawnPoints.map { p -> CGPoint in
                let x = (p.x - offsetX) / scale
                let y = 1.0 - (p.y - offsetY) / scale
                return CGPoint(x: x, y: y)
            }
            
            // Evaluate partial stroke
            let result = gameEngine.evaluatePartialStroke(drawnPoints: normalizedPoints, targetStroke: targetStroke)
            
            // Reset drawing state
            isDrawingStartedInWindow = false
            gameEngine.isUserDrawing = false
            
            // Hide spark
            sparkEmitter?.particleBirthRate = 0
            sparkEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
            strokeTrailEmitter?.particleBirthRate = 0
            strokeTrailEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
            
            // Trigger haptic feedback
            HapticManager.shared.triggerStrokeComplete(type: result)
            
            if result == .miss {
                gameEngine.handleMiss()
                updateLivesLabel()
                strokeResults[targetIndex] = .miss
                strokeEarnedPoints[targetIndex] = ScoreType.miss.points
                showFeedback(type: .miss)

                currentStrokeNode?.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.2),
                    SKAction.removeFromParent()
                ]))
            } else {
                // Partial stroke accepted (acceptable)
                gameEngine.score += result.points
                updateScoreLabel()
                strokeResults[targetIndex] = result
                strokeEarnedPoints[targetIndex] = result.points
                showFeedback(type: result)
                
                createStrokePathParticles(for: targetStroke, color: UIColor.yellow, intensity: 0.15)
                currentStrokeNode?.removeFromParent()
            }
            
            currentStrokeNode = nil
            drawingPath = nil
            currentDrawnPoints = []
            
            let kanjiCompleted = gameEngine.advanceStroke()
            updateKanjiVisuals()
            
            if kanjiCompleted {
                handleKanjiCompleted()
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check for skip button tap (debug only)
        #if DEBUG
        let debugNodes = self.nodes(at: location)
        if debugNodes.contains(where: { $0.name == "skipButton" || $0.parent?.name == "skipButton" }) {
            skipButtonTouchBegan = true
            return
        }
        if debugNodes.contains(where: { $0.name == "debugHeartButton" || $0.parent?.name == "debugHeartButton" }) {
            debugHeartButtonTouchBegan = true
            return
        }
        #endif
        
        let tappedNodes = self.nodes(at: location)
        
        // Pause toggle button (top right)
        if tappedNodes.contains(where: { $0.name == "pauseButton" || $0.parent?.name == "pauseButton" }) {
            pauseButtonTouchBegan = true
            return
        }

        // iPad mode switcher should swallow touches so they don't reach gameplay canvas.
        if let switcher = modeSwitcherControl,
           switcher.shouldConsumeTouch(location: location, nodes: tappedNodes) {
            return
        }
        
        // Pause menu buttons - track touch began state
        if isPauseMenuVisible {
            if tappedNodes.contains(where: { $0.name == "resumeButton" || $0.parent?.name == "resumeButton" }) {
                resumeButtonTouchBegan = true
            } else if tappedNodes.contains(where: { $0.name == "exitButton" || $0.parent?.name == "exitButton" }) {
                exitButtonTouchBegan = true
            }
            return
        }
        
        // In Apple Pencil mode on iPad, ignore non-pencil touches for stroke drawing
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let pencilModeActive = isIPad && SettingsStore.shared.iPadInputMode == .applePencil
        if pencilModeActive && touch.type != .pencil {
            return // Ignore finger/palm touches for stroke drawing
        }
        
        // Check if we're within the stroke timing window
        let windowState = gameEngine.isStrokeWindowActive()
        
        // If not in a valid window, show feedback and ignore the touch
        guard windowState.isActive else {
            isDrawingStartedInWindow = false
            AudioManager.shared.playUISound(.strokeTooEarly)
            showTooEarlyToast(at: location)
            return
        }
        
        // Mark that drawing started within a valid window
        isDrawingStartedInWindow = true
        gameEngine.isUserDrawing = true
        
        // Reset haptic zone tracking for new stroke
        HapticManager.shared.resetZoneTracking()
        
        // Stroke start haptic disabled - felt too noisy
        // triggerStrokeStartHapticIfOnPath(at: location)
        
        drawingPath = CGMutablePath()
        drawingPath?.move(to: location)
        currentDrawnPoints = [location]
        
        currentStrokeNode = SKNode()
        
        // Use device-appropriate stroke widths
        let drawLayout = LayoutConstants.shared
        
        // 1. Glow Node
        let glowNode = SKShapeNode()
        glowNode.strokeColor = .cyan
        glowNode.lineWidth = drawLayout.drawingGlowWidth
        glowNode.lineCap = .round
        glowNode.glowWidth = 0.0
        glowNode.blendMode = .add
        glowNode.alpha = 0.65
        glowNode.zPosition = 0
        currentStrokeNode?.addChild(glowNode)
        
        // 2. Core Node
        let coreNode = SKShapeNode()
        coreNode.strokeColor = .white
        coreNode.lineWidth = drawLayout.drawingCoreWidth
        coreNode.lineCap = .round
        coreNode.glowWidth = 0.0
        coreNode.alpha = 1.0
        coreNode.zPosition = 1
        currentStrokeNode?.addChild(coreNode)
        
        addChild(currentStrokeNode!)
        
        // Activate spark
        sparkEmitter?.position = location
        sparkEmitter?.alpha = 1.0
        sparkEmitter?.particleBirthRate = 100 // Reset birth rate
        sparkEmitter?.resetSimulation()
        
        // Activate trailing stars
        strokeTrailEmitter?.position = location
        strokeTrailEmitter?.alpha = 1.0
        strokeTrailEmitter?.particleBirthRate = 140
        strokeTrailEmitter?.resetSimulation()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isPauseMenuVisible else { return }
        // Only process if drawing started within a valid window
        guard isDrawingStartedInWindow else { return }
        guard let touch = touches.first, let path = drawingPath, let node = currentStrokeNode else { return }
        
        // In Apple Pencil mode on iPad, ignore non-pencil touches for stroke drawing
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let pencilModeActive = isIPad && SettingsStore.shared.iPadInputMode == .applePencil
        if pencilModeActive && touch.type != .pencil {
            return // Ignore finger/palm touches for stroke drawing
        }
        
        let location = touch.location(in: self)
        path.addLine(to: location)
        currentDrawnPoints.append(location)
        
        for child in node.children {
            if let shape = child as? SKShapeNode {
                shape.path = path
            }
        }
        
        // Move spark
        sparkEmitter?.position = location
        if sparkEmitter?.alpha == 0 {
            sparkEmitter?.alpha = 1.0
            sparkEmitter?.resetSimulation()
        }
        
        // Move trailing stars
        strokeTrailEmitter?.position = location
        if strokeTrailEmitter?.alpha == 0 {
            strokeTrailEmitter?.alpha = 1.0
            strokeTrailEmitter?.resetSimulation()
        }
        
        // Real-time haptic feedback disabled - only completion haptics now
        // triggerHapticForStrokeAccuracy(at: location)
    }
    
    /// Calculate and trigger haptic feedback based on how close the touch is to the target stroke
    /// Uses INVERTED logic: haptics warn when OFF the path, silence when ON the path
    private func triggerHapticForStrokeAccuracy(at location: CGPoint) {
        // Get the target stroke
        let targetIndex = gameEngine.currentStrokeIndex
        guard let kanji = gameEngine.currentKanji, targetIndex < kanji.strokes.count else { return }
        let targetStroke = kanji.strokes[targetIndex]
        
        // Normalize the touch location to stroke coordinates
        guard let node = currentKanjiNode,
              let scale = node.userData?["scale"] as? CGFloat,
              let offsetX = node.userData?["offsetX"] as? CGFloat,
              let offsetY = node.userData?["offsetY"] as? CGFloat else { return }
        
        let normalizedX = (location.x - offsetX) / scale
        let normalizedY = 1.0 - (location.y - offsetY) / scale
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Find the minimum distance to the target stroke path
        let distance = minimumDistanceToStroke(point: normalizedPoint, stroke: targetStroke)
        
        // Thresholds match the evaluation thresholds in GameEngine
        let goodThreshold: CGFloat = 0.05
        
        // Determine if in good zone
        let isInGoodZone = distance < goodThreshold
        
        // Trigger warning haptics (vibrates when OFF path, silent when ON path)
        HapticManager.shared.triggerStrokeWarning(
            isInGoodZone: isInGoodZone,
            distanceFromPath: distance,
            currentTime: gameEngine.currentTime
        )
    }
    
    /// Check if touch started on the stroke path and trigger start haptic
    private func triggerStrokeStartHapticIfOnPath(at location: CGPoint) {
        // Get the target stroke
        let targetIndex = gameEngine.currentStrokeIndex
        guard let kanji = gameEngine.currentKanji, targetIndex < kanji.strokes.count else { return }
        let targetStroke = kanji.strokes[targetIndex]
        
        // Normalize the touch location to stroke coordinates
        guard let node = currentKanjiNode,
              let scale = node.userData?["scale"] as? CGFloat,
              let offsetX = node.userData?["offsetX"] as? CGFloat,
              let offsetY = node.userData?["offsetY"] as? CGFloat else { return }
        
        let normalizedX = (location.x - offsetX) / scale
        let normalizedY = 1.0 - (location.y - offsetY) / scale
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Find the minimum distance to the target stroke path
        let distance = minimumDistanceToStroke(point: normalizedPoint, stroke: targetStroke)
        
        // If starting on or near the path, give a satisfying start tap
        let goodThreshold: CGFloat = 0.05
        if distance < goodThreshold {
            HapticManager.shared.triggerStrokeStart()
        }
    }
    
    
    /// Calculate the minimum distance from a point to any point on the stroke path
    private func minimumDistanceToStroke(point: CGPoint, stroke: Stroke) -> CGFloat {
        let strokePoints = stroke.cgPoints
        guard strokePoints.count > 1 else {
            if let first = strokePoints.first {
                return hypot(point.x - first.x, point.y - first.y)
            }
            return CGFloat.greatestFiniteMagnitude
        }
        
        var minDistance: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // Check distance to each segment of the stroke 
        for i in 0..<(strokePoints.count - 1) {
            let p1 = strokePoints[i]
            let p2 = strokePoints[i + 1]
            let dist = distanceToLineSegment(point: point, lineStart: p1, lineEnd: p2)
            minDistance = min(minDistance, dist)
        }
        
        return minDistance
    }
    
    /// Calculate the shortest distance from a point to a line segment
    private func distanceToLineSegment(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        
        if lengthSquared == 0 {
            // Line segment is a point
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        // Calculate projection of point onto line segment
        var t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSquared
        t = max(0, min(1, t)) // Clamp to segment
        
        // Find the closest point on the segment
        let closestX = lineStart.x + t * dx
        let closestY = lineStart.y + t * dy
        
        return hypot(point.x - closestX, point.y - closestY)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNodes = self.nodes(at: location)
        
        // Handle debug buttons (only trigger if touch began on them)
        #if DEBUG
        if skipButtonTouchBegan && tappedNodes.contains(where: { $0.name == "skipButton" || $0.parent?.name == "skipButton" }) {
            resetPauseMenuTouchState()
            skipToWinScreen()
            return
        }
        skipButtonTouchBegan = false
        
        if debugHeartButtonTouchBegan && tappedNodes.contains(where: { $0.name == "debugHeartButton" || $0.parent?.name == "debugHeartButton" }) {
            resetPauseMenuTouchState()
            debugRestoreHealth()
            return
        }
        debugHeartButtonTouchBegan = false
        #endif
        
        // Handle pause button (only trigger if touch began on it)
        if pauseButtonTouchBegan && tappedNodes.contains(where: { $0.name == "pauseButton" || $0.parent?.name == "pauseButton" }) {
            pauseButtonTouchBegan = false
            AudioManager.shared.playUISound(.button)
            isPauseMenuVisible ? resumeGameFromPause() : showPauseMenu()
            return
        }
        pauseButtonTouchBegan = false
        
        // Handle iPad mode switcher (uses dropdown pattern like DifficultySwitcher)
        if let switcher = modeSwitcherControl, switcher.handleTouchEnded(location: location, nodes: tappedNodes) {
            return
        }
        
        // Handle pause menu buttons (only trigger if touch began on them)
        if isPauseMenuVisible {
            if resumeButtonTouchBegan && tappedNodes.contains(where: { $0.name == "resumeButton" || $0.parent?.name == "resumeButton" }) {
                resetPauseMenuTouchState()
                AudioManager.shared.playUISound(.button)
                resumeGameFromPause()
            } else if exitButtonTouchBegan && tappedNodes.contains(where: { $0.name == "exitButton" || $0.parent?.name == "exitButton" }) {
                resetPauseMenuTouchState()
                AudioManager.shared.playUISound(.buttonBack)
                exitToMenu()
            } else {
                resetPauseMenuTouchState()
            }
            return
        }
        
        // Hide spark
        sparkEmitter?.particleBirthRate = 0 // Stop emitting immediately
        sparkEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
        strokeTrailEmitter?.particleBirthRate = 0
        strokeTrailEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
        
        // Clear drawing state
        gameEngine.isUserDrawing = false
        
        // If drawing didn't start in a valid window, just clean up without evaluation
        guard isDrawingStartedInWindow else {
            currentStrokeNode?.removeFromParent()
            currentStrokeNode = nil
            drawingPath = nil
            currentDrawnPoints = []
            return
        }
        
        // Reset the flag
        isDrawingStartedInWindow = false
        
        // Get the target stroke
        let targetIndex = gameEngine.currentStrokeIndex
        guard let kanji = gameEngine.currentKanji, targetIndex < kanji.strokes.count else { return }
        let targetStroke = kanji.strokes[targetIndex]
        
        // Normalize drawn points
        guard let node = currentKanjiNode,
              let scale = node.userData?["scale"] as? CGFloat,
              let offsetX = node.userData?["offsetX"] as? CGFloat,
              let offsetY = node.userData?["offsetY"] as? CGFloat else { return }
        
        let normalizedPoints = currentDrawnPoints.map { p -> CGPoint in
            let x = (p.x - offsetX) / scale
            let y = 1.0 - (p.y - offsetY) / scale
            return CGPoint(x: x, y: y)
        }
        
        // Evaluate
        let result = gameEngine.evaluateStroke(drawnPoints: normalizedPoints, targetStroke: targetStroke)
        
        // Trigger haptic feedback for stroke completion
        HapticManager.shared.triggerStrokeComplete(type: result)
        
        if result == .miss {
            gameEngine.handleMiss()
            updateLivesLabel()

            // Store result
            strokeResults[targetIndex] = .miss
            strokeEarnedPoints[targetIndex] = ScoreType.miss.points
            
            showFeedback(type: .miss)
            
            // Clear drawing
            currentStrokeNode?.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.removeFromParent()
            ]))
            
            // Advance stroke so it turns red
            let kanjiCompleted = gameEngine.advanceStroke()
            updateKanjiVisuals()
            
            if kanjiCompleted {
                handleKanjiCompleted()
            }
        } else {
            // Success (Perfect or Acceptable)
            let wasRainbowStroke = gameEngine.isCurrentStrokeRainbow()
            let earnedPoints = result.points
            gameEngine.score += earnedPoints
            updateScoreLabel()

            // Check for rainbow stroke health restoration (before advancing stroke)
            if wasRainbowStroke && result == .perfect {
                gameEngine.handleRainbowStrokePerfect()
                updateLivesLabel()
            }

            // Store result
            strokeResults[targetIndex] = result
            strokeEarnedPoints[targetIndex] = earnedPoints
            
            // Determine feedback color - rainbow for rainbow stroke perfects
            let feedbackColor: UIColor = (wasRainbowStroke && result == .perfect) ? .magenta : (result == .perfect ? .green : .yellow)
            
            showFeedback(type: result)
            
            // Lock-in animation (Particle Burst)
            if let touch = touches.first {
                let location = touch.location(in: self)
                let intensity: CGFloat = result == .perfect ? 1.0 : 0.15 // Reduced intensity for Good
                createLockInBurst(at: location, color: feedbackColor, intensity: intensity)
            }
            
            // Stroke Path Particles
            let intensity: CGFloat = result == .perfect ? 1.0 : 0.15
            createStrokePathParticles(for: targetStroke, color: feedbackColor, intensity: intensity)
            
            // Clear drawing immediately
            currentStrokeNode?.removeFromParent()
            
            // Advance
            let kanjiCompleted = gameEngine.advanceStroke()
            updateKanjiVisuals()
            
            if kanjiCompleted {
                handleKanjiCompleted()
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetPauseMenuTouchState()
        guard !isPauseMenuVisible else { return }
        // Reset drawing state when touch is cancelled
        isDrawingStartedInWindow = false
        gameEngine.isUserDrawing = false
        sparkEmitter?.particleBirthRate = 0
        sparkEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
        strokeTrailEmitter?.particleBirthRate = 0
        strokeTrailEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
        currentStrokeNode?.removeFromParent()
        currentStrokeNode = nil
        drawingPath = nil
        currentDrawnPoints = []
    }
    
    private func resetPauseMenuTouchState() {
        pauseButtonTouchBegan = false
        resumeButtonTouchBegan = false
        exitButtonTouchBegan = false
        #if DEBUG
        skipButtonTouchBegan = false
        debugHeartButtonTouchBegan = false
        #endif
    }
    
    // MARK: - iPad Mode Switcher
    
    func rebuildKanjiForModeChange() {
        // Rebuild the current kanji with new size without resetting game state
        if gameEngine.currentKanji != nil {
            rebuildCurrentKanjiNode()
        }
    }
    
    func finalizeCurrentKanjiScore() {
        guard let kanji = gameEngine.currentKanji else { return }
        let totalScore = kanji.strokes.enumerated().reduce(0) { partial, item in
            if let earned = strokeEarnedPoints[item.offset] {
                return partial + earned
            }
            let scoreTypePoints = strokeResults[item.offset]?.points ?? ScoreType.miss.points
            return partial + scoreTypePoints
        }
        KanjiUserStore.shared.recordScore(kanjiId: kanji.id, score: totalScore)
    }
    
    /// Handle kanji completion: show meaning toast if enabled (non-blocking), then transition to next kanji
    func handleKanjiCompleted() {
        // Play kanji complete sound
        AudioManager.shared.playUISound(.kanjiComplete)
        
        finalizeCurrentKanjiScore()
        
        let displayOption = SettingsStore.shared.postKanjiDisplay
        
        // Show meaning toast if enabled (non-blocking - appears in corner)
        if displayOption != .nothing {
            let kanjiChar = gameEngine.currentKanji?.char ?? ""
            let keyword = gameEngine.currentKanji?.getKeyword(for: displayOption) ?? ""
            if !keyword.isEmpty {
                HapticManager.shared.triggerKanjiCompleteMeaning()
                showMeaningToast(kanji: kanjiChar, meaning: keyword)
            }
        }
        
        // Always transition to next kanji immediately (gap is handled by beatmap scheduling)
        gameEngine.nextKanjiInSequence()
        showNextKanji()
    }
    
    func sanitizedSongAssetName() -> String {
        let nameObj = selectedSongFilename as NSString
        let base = nameObj.deletingPathExtension
        return base.isEmpty ? selectedSongFilename : base
    }
}
