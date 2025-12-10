//
//  GameOverScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit
import CoreMotion

class GameOverScene: SKScene {
    
    var score: Int = 0
    var percentage: Double = 0
    var isVictory: Bool = false
    
    // MARK: - Play Again Parameters
    var selectedDifficulty: DifficultyLevel = .easy
    var selectedSongId: String = "debug"
    var selectedSongFilename: String = "debug"
    var selectedSongTitle: String = "Debug"
    var enabledTags: Set<String> = KanjiCategory.allTags
    
    // MARK: - Conveyor Belt (matching PlayScene)
    private var conveyorBeltManager: ConveyorBeltManager?
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // Layout constants (shared)
    private let conveyorHorizonY: CGFloat = SharedBackground.conveyorHorizonY
    
    // MARK: - UI Elements
    private var logoNode: SKSpriteNode?
    private var playAgainButton: SKNode?
    private var backButton: SKNode?
    private var tierIcon: SKSpriteNode?
    private var tierParticleContainer: SKNode?
    private var percentLabel: SKLabelNode?
    
    // MARK: - Touch State Tracking
    private var playAgainButtonTouchBegan = false
    private var backButtonTouchBegan = false
    
    #if DEBUG
    private var debugTierOverride: TierRank? = nil
    #endif
    
    // MARK: - Broken Glass (Game Over only)
    private var shatterLeft: SKSpriteNode?
    private var shatterRight: SKSpriteNode?
    private var shatterTop: SKSpriteNode?
    private var shatterBottom: SKSpriteNode?
    
    // MARK: - Motion for Parallax (Game Over only)
    private var motionManager: CMMotionManager?
    private var initialPitch: Double = 0
    private var initialRoll: Double = 0
    
    // MARK: - Fireworks (Win only)
    private var lastFireworkBeat: Int = -1
    private var beatsPerFirework: Int = 2  // Spawn firework every N beats (2 = every other beat for less overwhelming sound)
    private var isSceneActive: Bool = true
    
    override func didMove(to view: SKView) {
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        setupBackground()
        
        // Create grid node for conveyor belt (needed before setupWinScene for victory)
        let gridNode = SharedBackground.addPerspectiveGrid(to: self, lineAlpha: isVictory ? 0.3 : 0.15)
        
        if isVictory {
            // Firework sounds will play during the firework animation
            setupWinScene()
            // Start conveyor belt for victory
            conveyorBeltManager = ConveyorBeltManager(scene: self, gridNode: gridNode, horizonY: conveyorHorizonY)
            conveyorBeltManager?.start()
        } else {
            // Play glass shatter sound on game over
            AudioManager.shared.playUISound(.glassShatter)
            setupGameOverScene()
            // No conveyor belt update for game over (stopped)
        }
        
        setupButtons()
        
        #if DEBUG
        setupDebugTierButton()
        #endif
    }
    
    override func willMove(from view: SKView) {
        motionManager?.stopDeviceMotionUpdates()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidBecomeActive() {
        isSceneActive = true
        // Reset beat tracking to prevent burst of fireworks
        lastFireworkBeat = Int(globalTimer.globalTime / (60.0 / 120.0))
    }
    
    @objc private func appWillResignActive() {
        isSceneActive = false
    }
    
    override func update(_ currentTime: TimeInterval) {
        globalTimer.update(systemTime: currentTime)
        
        if isVictory {
            conveyorBeltManager?.update()
            updateFireworks()
        }
        
        // Update parallax for game over
        if !isVictory {
            updateParallax()
        }
    }
    
    // MARK: - Beat-Synchronized Fireworks
    
    private func updateFireworks() {
        guard isSceneActive else { return }
        
        let bpm: Double = 120
        let beatDuration = 60.0 / bpm
        let currentBeat = Int(globalTimer.globalTime / beatDuration)
        
        // Spawn firework every N beats with random timing offset
        if currentBeat != lastFireworkBeat && currentBeat % beatsPerFirework == 0 {
            lastFireworkBeat = currentBeat
            // Add random offset (0-200ms) to avoid perfectly synced sounds
            let randomOffset = Double.random(in: 0...0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + randomOffset) { [weak self] in
                self?.spawnFirework()
            }
        }
    }
    
    // MARK: - Background Setup
    
    private func setupBackground() {
        backgroundColor = .black
        let bgAlpha: CGFloat = isVictory ? 1.0 : 0.4  // Darker for game over
        SharedBackground.addBackground(to: self, alpha: bgAlpha)
        // Grid is added in didMove since we need the node reference for conveyor belt
    }
    
    // MARK: - Win Scene Setup
    
    private func setupWinScene() {
        // You Win logo
        logoNode = SKSpriteNode(imageNamed: "you-win")
        if let logo = logoNode {
            let maxWidth = size.width * 0.95
            let maxHeight = size.height * 0.40
            let scale = min(maxWidth / logo.size.width, maxHeight / logo.size.height, 1.0)
            logo.setScale(scale)
            logo.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
            logo.zPosition = 100
            addChild(logo)
            
            // Subtle floating animation
            addLogoAnimation(to: logo, baseScale: scale)
        }
        
        // Add tier icon and percentage below logo
        setupResultDisplay()
        
        // Start fireworks
        startFireworks()
    }
    
    private func startFireworks() {
        // Initialize beat tracking
        let bpm: Double = 120
        let beatDuration = 60.0 / bpm
        // Start with a delay to allow UI to settle, preventing stacked sounds at start
        lastFireworkBeat = Int(globalTimer.globalTime / beatDuration) + 2 // Skip first 2 beats
        
        // First firework after short delay instead of instant burst
        DispatchQueue.main.asyncAfter(deadline: .now() + beatDuration) { [weak self] in
            self?.spawnFirework()
        }
        // Fireworks continue via updateFireworks() in update loop
    }
    
    private func spawnFirework() {
        // Random position around the logo area (more centered)
        let x = CGFloat.random(in: size.width * 0.2...size.width * 0.8)
        let y = CGFloat.random(in: size.height * 0.45...size.height * 0.75)
        let position = CGPoint(x: x, y: y)
        
        // Create firework burst
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0), // Pink
            UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0), // Cyan
            UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0), // Yellow
            UIColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 1.0), // Purple
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0), // Orange
        ]
        
        let color = colors.randomElement() ?? .white
        createFireworkBurst(at: position, color: color)
        
        // Play firework launch sound occasionally (1 in 4 chance to avoid overwhelming)
        if Int.random(in: 0..<4) == 0 {
            AudioManager.shared.playUISound(.fireworkLaunch)
        }
        
        // Randomized volume multiplier (0.7-1.0) to fake depth
        let volumeMultiplier = Float.random(in: 0.7...1.0)
        // Randomized delay between boom and crackle (40-120ms)
        let crackleDelay = Double.random(in: 0.04...0.12)
        
        // Explosion sound and haptic feedback synced together after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Play boom with volume variation
            AudioManager.shared.playUISound(.fireworkBoom, volumeMultiplier: volumeMultiplier)
            HapticManager.shared.triggerFirework()
            DispatchQueue.main.asyncAfter(deadline: .now() + crackleDelay) {
                // Crackle with slightly different volume for natural variation
                AudioManager.shared.playUISound(.fireworkCrackle, volumeMultiplier: volumeMultiplier * Float.random(in: 0.85...1.0))
            }
        }
    }
    
    private func createFireworkBurst(at position: CGPoint, color: UIColor) {
        let particleCount = Int.random(in: 40...60)
        
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            particle.fillColor = SKColor(cgColor: color.cgColor)
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 50
            particle.alpha = 1.0
            particle.blendMode = .add
            
            // Add glow
            particle.glowWidth = 4
            
            addChild(particle)
            
            // Random direction and velocity - SLOWER
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 30...80)
            let dx = cos(angle) * speed
            let dy = sin(angle) * speed
            
            let duration = TimeInterval.random(in: 1.5...2.5)
            
            let moveAction = SKAction.moveBy(x: dx * CGFloat(duration), y: dy * CGFloat(duration) - 20, duration: duration)
            moveAction.timingMode = .easeOut
            
            let fadeAction = SKAction.fadeOut(withDuration: duration)
            let scaleAction = SKAction.scale(to: 0.4, duration: duration)
            
            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
            
            particle.run(sequence)
        }
        
        // Add center flash
        let flash = SKShapeNode(circleOfRadius: 15)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.position = position
        flash.zPosition = 51
        flash.blendMode = .add
        flash.glowWidth = 10
        addChild(flash)
        
        flash.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15)
            ]),
            SKAction.removeFromParent()
        ]))
    }
    
    // MARK: - Game Over Scene Setup
    
    private func setupGameOverScene() {
        // Game Over logo
        logoNode = SKSpriteNode(imageNamed: "game-over")
        if let logo = logoNode {
            let maxWidth = size.width * 0.95
            // Push the logo toward the upper third to free space for score display
            let maxHeight = size.height * 0.32
            let scale = min(maxWidth / logo.size.width, maxHeight / logo.size.height, 1.0)
            logo.setScale(scale)
            // Slightly lower than previous tweak to avoid crowding the top
            logo.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
            logo.zPosition = 100
            addChild(logo)
            
            // Subtle floating animation
            addLogoAnimation(to: logo, baseScale: scale)
        }
        
        // Add tier icon and percentage below logo
        setupResultDisplay()
        
        // Broken glass frame
        setupBrokenGlass()
        
        // Setup motion for parallax
        setupMotion()
    }
    
    // MARK: - Result Display (Tier Icon + Percentage)
    
    private func setupResultDisplay() {
        let centerX = size.width / 2
        // Allow a larger score/percentage block on Game Over by shifting it down and scaling up
        let resultY: CGFloat
        let tierIconSize: CGFloat
        let percentFontSize: CGFloat
        let percentOffset: CGFloat
        if isVictory {
            resultY = size.height * 0.36
            tierIconSize = 100
            percentFontSize = 28
            percentOffset = 65
        } else {
            // Center the score block between the Game Over logo and the buttons
            let buttonBaseY = size.height * 0.18
            let logoY = logoNode?.position.y ?? size.height * 0.72
            resultY = buttonBaseY + (logoY - buttonBaseY) * 0.5
            tierIconSize = 150
            percentFontSize = 36
            percentOffset = 82
        }
        
        // Determine which tier to display
        #if DEBUG
        let displayTier = debugTierOverride ?? TierRank.from(percentage: percentage)
        let displayPercentage = debugTierOverride != nil ? 95.0 : percentage
        #else
        let displayTier = TierRank.from(percentage: percentage)
        let displayPercentage = percentage
        #endif
        
        // Tier icon (larger size)
        tierIcon = SKSpriteNode(imageNamed: displayTier.iconName)
        if let icon = tierIcon {
            icon.setScale(1.0)
            let tierScale = tierIconSize / max(icon.size.width, icon.size.height)
            icon.setScale(tierScale)
            icon.position = CGPoint(x: centerX, y: resultY)
            icon.zPosition = 100
            addChild(icon)
            
            // Add subtle floating animation to tier icon
            addTierIconAnimation(to: icon, baseScale: tierScale)
        }
        
        // Add S tier particles if applicable
        if displayTier == .S {
            tierParticleContainer = SKNode()
            if let container = tierParticleContainer {
                container.position = CGPoint(x: centerX, y: resultY)
                container.zPosition = 99
                ParticleFactory.addSTierSparkles(to: container, iconSize: CGSize(width: tierIconSize, height: tierIconSize))
                addChild(container)
            }
        }
        
        // Percentage label below tier icon
        percentLabel = SKLabelNode(fontNamed: FontConfig.bold)
        if let label = percentLabel {
            label.text = "\(Int(round(displayPercentage)))%"
            label.fontSize = percentFontSize
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: centerX, y: resultY - percentOffset)
            label.zPosition = 100
            addChild(label)
            
            // Add floating animation in sync with tier icon
            addPercentLabelAnimation(to: label)
        }
    }
    
    #if DEBUG
    private func refreshResultDisplay() {
        // Remove existing tier display elements
        tierIcon?.removeFromParent()
        tierIcon = nil
        tierParticleContainer?.removeFromParent()
        tierParticleContainer = nil
        percentLabel?.removeFromParent()
        percentLabel = nil
        
        // Re-setup with current debug state
        setupResultDisplay()
    }
    #endif
    
    private func setupBrokenGlass() {
        // Dark tint color for glass (matches darkened background)
        let glassTint = SKColor(white: 0.0, alpha: 0.5)
        
        // Left shatter (use shatter-left.png)
        shatterLeft = SKSpriteNode(imageNamed: "shatter-left")
        if let left = shatterLeft {
            left.anchorPoint = CGPoint(x: 0, y: 0.5)
            // Scale to fit height while maintaining aspect
            let targetHeight = size.height * 1.1 // Slightly larger to hide cutoff
            let scale = targetHeight / left.size.height
            left.setScale(scale)
            // Position slightly off-screen to hide cutoff
            left.position = CGPoint(x: -10, y: size.height / 2)
            left.zPosition = -50
            left.color = glassTint
            left.colorBlendFactor = 0.4
            addChild(left)
        }
        
        // Right shatter (use shatter-right.png)
        shatterRight = SKSpriteNode(imageNamed: "shatter-right")
        if let right = shatterRight {
            right.anchorPoint = CGPoint(x: 1, y: 0.5)
            let targetHeight = size.height * 1.1
            let scale = targetHeight / right.size.height
            right.setScale(scale)
            right.position = CGPoint(x: size.width + 10, y: size.height / 2)
            right.zPosition = -50
            right.color = glassTint
            right.colorBlendFactor = 0.4
            addChild(right)
        }
        
        // Top shatter (use shatter-top.png)
        shatterTop = SKSpriteNode(imageNamed: "shatter-top")
        if let top = shatterTop {
            top.anchorPoint = CGPoint(x: 0.5, y: 1)
            // Scale to fit width
            let targetWidth = size.width * 1.1
            let scale = targetWidth / top.size.width
            top.setScale(scale)
            top.position = CGPoint(x: size.width / 2, y: size.height + 10)
            top.zPosition = -49
            top.color = glassTint
            top.colorBlendFactor = 0.4
            addChild(top)
        }
        
        // Bottom shatter (use shatter-bottom.png)
        shatterBottom = SKSpriteNode(imageNamed: "shatter-bottom")
        if let bottom = shatterBottom {
            bottom.anchorPoint = CGPoint(x: 0.5, y: 0)
            let targetWidth = size.width * 1.1
            let scale = targetWidth / bottom.size.width
            bottom.setScale(scale)
            bottom.position = CGPoint(x: size.width / 2, y: -10)
            bottom.zPosition = -49
            bottom.color = glassTint
            bottom.colorBlendFactor = 0.4
            addChild(bottom)
        }
    }
    
    private func setupMotion() {
        motionManager = CMMotionManager()
        
        guard let motion = motionManager, motion.isDeviceMotionAvailable else { return }
        
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates()
        
        // Capture initial orientation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if let data = self?.motionManager?.deviceMotion {
                self?.initialPitch = data.attitude.pitch
                self?.initialRoll = data.attitude.roll
            }
        }
    }
    
    private func updateParallax() {
        guard let motion = motionManager, let data = motion.deviceMotion else { return }        
        
        // Get relative tilt from initial position
        let pitch = data.attitude.pitch - initialPitch
        let roll = data.attitude.roll - initialRoll
        
        // Parallax amount - subtle but noticeable movement
        let maxOffset: CGFloat = 10
        
        // Clamp the tilt values to prevent extreme movement
        let clampedRoll = max(-0.4, min(0.4, roll))
        let clampedPitch = max(-0.4, min(0.4, pitch))
        
        let offsetX = CGFloat(clampedRoll) * maxOffset
        let offsetY = CGFloat(clampedPitch) * maxOffset
        
        // Base positions (with offset to hide cutoff)
        let leftBaseX: CGFloat = -10
        let rightBaseX: CGFloat = size.width + 10
        let topBaseY: CGFloat = size.height + 10
        let bottomBaseY: CGFloat = -10
        let centerY = size.height / 2
        let centerX = size.width / 2
        
        // Subtle parallax with some depth variation
        shatterLeft?.position = CGPoint(x: leftBaseX + offsetX * 1.2, y: centerY + offsetY * 0.4)
        shatterRight?.position = CGPoint(x: rightBaseX + offsetX * 1.2, y: centerY + offsetY * 0.4)
        shatterTop?.position = CGPoint(x: centerX + offsetX * 0.4, y: topBaseY + offsetY * 1.2)
        shatterBottom?.position = CGPoint(x: centerX + offsetX * 0.4, y: bottomBaseY + offsetY * 1.2)
    }
    
    // MARK: - Logo Animation
    
    private func addLogoAnimation(to logo: SKSpriteNode, baseScale: CGFloat) {
        // Very gentle floating motion
        let moveUp = SKAction.moveBy(x: 0, y: 3, duration: 2.5)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let float = SKAction.sequence([moveUp, moveDown])
        logo.run(SKAction.repeatForever(float))
        
        // Very subtle scale breathing
        let scaleUp = SKAction.scale(to: baseScale * 1.008, duration: 3.0)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: baseScale, duration: 3.0)
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        logo.run(SKAction.repeatForever(breathe))
    }
    
    private func addTierIconAnimation(to icon: SKSpriteNode, baseScale: CGFloat) {
        // Gentle floating motion (slightly smaller than logo)
        let moveUp = SKAction.moveBy(x: 0, y: 2, duration: 2.0)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let float = SKAction.sequence([moveUp, moveDown])
        icon.run(SKAction.repeatForever(float))
        
        // Subtle scale breathing
        let scaleUp = SKAction.scale(to: baseScale * 1.01, duration: 2.5)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: baseScale, duration: 2.5)
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        icon.run(SKAction.repeatForever(breathe))
    }
    
    private func addPercentLabelAnimation(to label: SKLabelNode) {
        // Floating motion in sync with tier icon (same parameters)
        let moveUp = SKAction.moveBy(x: 0, y: 2, duration: 2.0)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = moveUp.reversed()
        let float = SKAction.sequence([moveUp, moveDown])
        label.run(SKAction.repeatForever(float))
        
        // Subtle scale breathing in sync with tier icon
        let scaleUp = SKAction.scale(to: 1.01, duration: 2.5)
        scaleUp.timingMode = .easeInEaseOut
        let scaleDown = SKAction.scale(to: 1.0, duration: 2.5)
        scaleDown.timingMode = .easeInEaseOut
        let breathe = SKAction.sequence([scaleUp, scaleDown])
        label.run(SKAction.repeatForever(breathe))
    }

    // MARK: - Button Setup
    
    private func setupButtons() {
        let buttonSpacing: CGFloat = 180
        let centerX: CGFloat = size.width / 2
        let baseY: CGFloat = size.height * 0.18  // Lower position
        
        // Back button (left)
        backButton = ButtonFactory.createButton(text: NSLocalizedString("gameover.back", comment: "Back"), name: "backButton")
        if let btn = backButton {
            btn.position = CGPoint(x: centerX - buttonSpacing / 2, y: baseY)
            ButtonFactory.addPulseAnimation(to: btn)
            addChild(btn)
        }
        
        // Play Again button (right) - with particles
        playAgainButton = ButtonFactory.createButton(text: NSLocalizedString("gameover.playagain", comment: "Play Again"), name: "playAgainButton")
        if let btn = playAgainButton {
            btn.position = CGPoint(x: centerX + buttonSpacing / 2, y: baseY)
            ButtonFactory.addPulseAnimation(to: btn)
            addChild(btn)
            
            // Add sparkle particles for both win and game over screens
            ParticleFactory.addButtonSparkles(to: btn, buttonSize: CGSize(width: 160, height: 50))
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        if nodes.contains(where: { $0.name == "playAgainButton" || $0.parent?.name == "playAgainButton" }) {
            playAgainButtonTouchBegan = true
            if let btn = playAgainButton { ButtonFactory.animatePress(btn) }
        } else if nodes.contains(where: { $0.name == "backButton" || $0.parent?.name == "backButton" }) {
            backButtonTouchBegan = true
            if let btn = backButton { ButtonFactory.animatePress(btn) }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Reset button scales
        if let btn = playAgainButton { ButtonFactory.animateRelease(btn) }
        if let btn = backButton { ButtonFactory.animateRelease(btn) }
        
        #if DEBUG
        if nodes.contains(where: { $0.name == "debugTierButton" || $0.parent?.name == "debugTierButton" }) {
            cycleDebugTier()
            playAgainButtonTouchBegan = false
            backButtonTouchBegan = false
            return
        }
        #endif
        
        // Only trigger if touch began on same button
        if playAgainButtonTouchBegan && nodes.contains(where: { $0.name == "playAgainButton" || $0.parent?.name == "playAgainButton" }) {
            playAgainButtonTouchBegan = false
            backButtonTouchBegan = false
            AudioManager.shared.playUISound(.button)
            // Play the same song again
            let playScene = PlayScene(size: size)
            playScene.scaleMode = scaleMode
            playScene.selectedDifficulty = selectedDifficulty
            playScene.selectedSongId = selectedSongId
            playScene.selectedSongFilename = selectedSongFilename
            playScene.selectedSongTitle = selectedSongTitle
            playScene.enabledTags = enabledTags
            view?.presentScene(playScene, transition: SKTransition.fade(withDuration: 0.5))
        } else if backButtonTouchBegan && nodes.contains(where: { $0.name == "backButton" || $0.parent?.name == "backButton" }) {
            playAgainButtonTouchBegan = false
            backButtonTouchBegan = false
            AudioManager.shared.playUISound(.buttonBack)
            // Go back to song selection
            let songScene = SongSelectScene(size: size)
            songScene.scaleMode = scaleMode
            view?.presentScene(songScene, transition: SKTransition.fade(withDuration: 0.5))
        }
        
        playAgainButtonTouchBegan = false
        backButtonTouchBegan = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let btn = playAgainButton { ButtonFactory.animateRelease(btn) }
        if let btn = backButton { ButtonFactory.animateRelease(btn) }
        playAgainButtonTouchBegan = false
        backButtonTouchBegan = false
    }
    
    // MARK: - Debug Tier Cycling
    
    #if DEBUG
    private func setupDebugTierButton() {
        let tierButton = SKNode()
        tierButton.name = "debugTierButton"
        tierButton.position = CGPoint(x: 60, y: 50)
        tierButton.zPosition = 250
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        tierButton.addChild(bg)
        
        // Label
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "TIER ⏭"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "debugTierLabel"
        tierButton.addChild(label)
        
        addChild(tierButton)
    }
    
    private func cycleDebugTier() {
        let allTiers: [TierRank?] = [nil, .S, .A, .B, .C, .D]
        let currentIndex = allTiers.firstIndex(where: { $0 == debugTierOverride }) ?? 0
        let nextIndex = (currentIndex + 1) % allTiers.count
        debugTierOverride = allTiers[nextIndex]
        
        // Update button label to show current tier
        if let button = childNode(withName: "debugTierButton"),
           let label = button.childNode(withName: "debugTierLabel") as? SKLabelNode {
            if let tier = debugTierOverride {
                label.text = "TIER: \(tier.rawValue)"
            } else {
                label.text = "TIER ⏭"
            }
        }
        
        // Refresh display
        refreshResultDisplay()
    }
    #endif
}
