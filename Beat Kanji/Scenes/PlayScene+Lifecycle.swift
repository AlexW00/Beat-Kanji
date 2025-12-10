//
//  PlayScene+Lifecycle.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit
import UIKit

extension PlayScene {
    
    func configureScene() {
        setupBackground()
        setupSparkEmitter()
        setupStrokeTrailEmitter()
        setupHUD()
        setupGameEngineCallbacks()
        setupAppLifecycleObservers()
        isPauseMenuVisible = false
        isGamePaused = false
        didRecordSessionResult = false
        
        // Prepare haptics for gameplay
        HapticManager.shared.prepareForGameplay()
        
        // Use provided song selection or default to debug assets
        let songAssetName = sanitizedSongAssetName()
        if selectedSongId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            selectedSongId = songAssetName
        }
        
        // Use kanji data preloaded at startup, filtered by enabled tags
        let allKanji = KanjiDataLoader.shared.preloadedKanji
        var kanjiList = allKanji.filter { $0.hasAnyTag(from: enabledTags) }
        
        if let forcedIds = debugForcedKanjiIds, !forcedIds.isEmpty {
            let forcedSet = Set(forcedIds)
            kanjiList = kanjiList.filter { forcedSet.contains($0.char) || forcedSet.contains($0.id) }
            print("Debug filter active: forcing \(kanjiList.count) kanji from \(forcedIds)")
        }
        
        if kanjiList.isEmpty {
            print("No kanji data matching enabled tags!")
            let errorLabel = SKLabelNode(text: "Error: No Kanji Data")
            errorLabel.fontColor = .red
            errorLabel.position = CGPoint(x: size.width/2, y: size.height/2)
            addChild(errorLabel)
            return
        }
        
        print("Loaded \(kanjiList.count) kanji entries (filtered from \(allKanji.count) total)")
        
        // Load beatmap
        beatmap = BeatmapLoader.shared.loadBeatmap(named: songAssetName)
            ?? BeatmapLoader.shared.loadDebugBeatmap()
        
        if let beatmap = beatmap {
            // Start game with beatmap
            gameEngine.startGameWithBeatmap(kanjiList: kanjiList, beatmap: beatmap, difficulty: selectedDifficulty)
            print("Starting with difficulty: \(selectedDifficulty.displayName), BPM: \(beatmap.meta.bpm)")
            
            // Play audio using filename from beatmap metadata
            AudioManager.shared.playSong(named: beatmap.meta.filename)
        } else {
            // Fallback to legacy mode
            print("Warning: No beatmap found, using legacy mode")
            gameEngine.startGame(with: kanjiList)
            AudioManager.shared.playSong(named: songAssetName)
        }
        
        updateScoreLabel()
        updateLivesLabel()
        
        showNextKanji()
    }
    
    private func setupHUD() {
        // HUD layer container
        let hudLayer = SKNode()
        hudLayer.zPosition = 300
        hudLayer.name = "hudLayer"
        addChild(hudLayer)
        self.hudLayer = hudLayer
        
        // Pause button (top right, uses square button asset)
        let pauseButton = createPauseButton()
        pauseButton.position = CGPoint(x: size.width - 70, y: size.height - 70)
        pauseButton.zPosition = 2
        hudLayer.addChild(pauseButton)
        pauseButtonNode = pauseButton
        
        // iPad Mode Switcher (iPad only, top left area)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        if isIPad {
            let modeSwitcher = iPadModeSwitcher(initialMode: SettingsStore.shared.iPadInputMode)
            // Pin near the top-left corner on iPad for quick access
            modeSwitcher.position = CGPoint(x: 110, y: size.height - 70)
            modeSwitcher.zPosition = 2
            modeSwitcher.onChange = { [weak self] (newMode: iPadInputMode) in
                SettingsStore.shared.iPadInputMode = newMode
                self?.rebuildKanjiForModeChange()
            }
            hudLayer.addChild(modeSwitcher)
            modeSwitcherControl = modeSwitcher
        }
        
        // Hearts container - vertically below pause button (top right)
        let heartsContainer = SKNode()
        heartsContainer.name = "heartsContainer"
        // Position below pause button (pause is at x: size.width - 70, y: size.height - 70)
        let heartsX = size.width - 70
        let heartsStartY = size.height - 70 - 60 // Start below pause button
        heartsContainer.position = CGPoint(x: heartsX, y: heartsStartY)
        heartsContainer.zPosition = 1
        hudLayer.addChild(heartsContainer)
        self.heartsContainer = heartsContainer
        
        // Create heart sprites for max lives (4) - vertical layout
        let heartSize: CGFloat = 48
        let heartSpacing: CGFloat = 12
        let maxLives = GameEngine.defaultLives
        
        heartNodes = []
        for i in 0..<maxLives {
            let heart = SKSpriteNode(imageNamed: "heart-alive")
            let scale = heartSize / max(heart.size.width, heart.size.height)
            heart.setScale(scale)
            // Stack vertically downward
            heart.position = CGPoint(x: 0, y: -CGFloat(i) * (heartSize + heartSpacing))
            heart.name = "heart_\(i)"
            heartsContainer.addChild(heart)
            heartNodes.append(heart)
        }
        
        setupPauseMenu()
        updateLivesDisplay()
    }
    
    private func setupGameEngineCallbacks() {
        gameEngine = GameEngine()
        gameEngine.onGameOver = { [weak self] in
            self?.gameOver()
        }
        
        gameEngine.onSongCompleted = { [weak self] in
            // Song finished successfully
            self?.songCompleted()
        }
        
        gameEngine.onStrokeMiss = { [weak self] in
            guard let self = self else { return }
            
            // Clear any in-progress drawing since the window has closed
            self.isDrawingStartedInWindow = false
            self.sparkEmitter?.particleBirthRate = 0
            self.sparkEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
            self.strokeTrailEmitter?.particleBirthRate = 0
            self.strokeTrailEmitter?.run(SKAction.fadeOut(withDuration: 0.1))
            self.currentStrokeNode?.removeFromParent()
            self.currentStrokeNode = nil
            self.drawingPath = nil
            self.currentDrawnPoints = []
            
            self.updateLivesLabel()
            self.showFeedback(type: .miss)
            
            // Trigger miss haptic for timeout (same as misdrawing)
            HapticManager.shared.triggerStrokeComplete(type: .miss)
            
            let currentIndex = self.gameEngine.currentStrokeIndex
            self.strokeResults[currentIndex] = .miss
            self.strokeEarnedPoints[currentIndex] = ScoreType.miss.points
            
            self.updateKanjiVisuals()
            
            self.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.01),
                SKAction.run { [weak self] in
                    self?.updateKanjiVisuals()
                    
                    if let engine = self?.gameEngine, let kanji = engine.currentKanji {
                        if engine.currentStrokeIndex >= kanji.strokes.count {
                            // Use handleKanjiCompleted() to ensure keyword display works on timeout
                            self?.handleKanjiCompleted()
                        }
                    }
                }
            ]))
        }
        
        gameEngine.onHealthRestored = { [weak self] in
            guard let self = self else { return }
            AudioManager.shared.playUISound(.heartGained)
            self.updateLivesDisplay()
            self.showHealthRestoredFeedback()
        }
        
        gameEngine.onLifeLost = { [weak self] in
            guard self != nil else { return }
            AudioManager.shared.playUISound(.heartLost)
        }
    }
    
    private func createPauseButton() -> SKNode {
        let container = SKNode()
        container.name = "pauseButton"
        
        let bg = SKSpriteNode(imageNamed: "button-square")
        let targetSize: CGFloat = 80
        let scale = targetSize / max(bg.size.width, bg.size.height)
        bg.setScale(scale)
        bg.zPosition = 0
        container.addChild(bg)
        
        // Pause icon (two bars)
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: -10, y: -16, width: 8, height: 32), cornerWidth: 3, cornerHeight: 3)
        path.addRoundedRect(in: CGRect(x: 2, y: -16, width: 8, height: 32), cornerWidth: 3, cornerHeight: 3)
        let icon = SKShapeNode(path: path)
        icon.fillColor = .white
        icon.strokeColor = .white
        icon.lineWidth = 0
        icon.zPosition = 1
        container.addChild(icon)
        
        return container
    }
    
    private func setupPauseMenu() {
        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = SKColor.black.withAlphaComponent(0.6)
        dim.strokeColor = .clear
        dim.zPosition = 350
        dim.alpha = 0
        dim.isHidden = true
        dim.name = "pauseDim"
        addChild(dim)
        pauseDimNode = dim
        
        let menu = SKNode()
        menu.name = "pauseMenu"
        menu.position = CGPoint(x: size.width / 2, y: size.height / 2)
        menu.zPosition = 360
        menu.alpha = 0
        menu.isHidden = true
        addChild(menu)
        pauseMenuNode = menu
        
        let resumeButton = createMenuButton(text: "Resume", name: "resumeButton")
        resumeButton.position = CGPoint(x: 0, y: 20)
        menu.addChild(resumeButton)
        
        let exitButton = createMenuButton(text: "Exit", name: "exitButton")
        exitButton.position = CGPoint(x: 0, y: -60)
        menu.addChild(exitButton)
    }
    
    private func createMenuButton(text: String, name: String) -> SKNode {
        let container = SKNode()
        container.name = name
        
        let bg = SKSpriteNode(imageNamed: "button")
        let targetWidth: CGFloat = 180
        let scale = targetWidth / bg.size.width
        bg.setScale(scale)
        bg.zPosition = 0
        container.addChild(bg)
        
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = text
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        container.addChild(label)
        
        return container
    }
    
    func showPauseMenu() {
        guard !isPauseMenuVisible else { return }
        isPauseMenuVisible = true
        isGamePaused = true
        lastUpdateTime = 0
        
        AudioManager.shared.pauseMusic()
        
        pauseDimNode?.removeAllActions()
        pauseMenuNode?.removeAllActions()
        
        pauseDimNode?.isHidden = false
        pauseDimNode?.alpha = 0
        pauseDimNode?.run(SKAction.fadeAlpha(to: 1.0, duration: 0.2))
        
        pauseMenuNode?.isHidden = false
        pauseMenuNode?.alpha = 0
        pauseMenuNode?.setScale(0.96)
        let fadeIn = SKAction.group([
            SKAction.fadeAlpha(to: 1.0, duration: 0.2),
            SKAction.scale(to: 1.0, duration: 0.2)
        ])
        pauseMenuNode?.run(fadeIn)
    }
    
    func resumeGameFromPause() {
        guard isPauseMenuVisible else { return }
        isPauseMenuVisible = false
        isGamePaused = false
        lastUpdateTime = 0
        
        AudioManager.shared.resumeMusic()
        
        pauseDimNode?.run(SKAction.fadeOut(withDuration: 0.2), completion: { [weak self] in
            self?.pauseDimNode?.isHidden = true
        })
        
        pauseMenuNode?.run(SKAction.fadeOut(withDuration: 0.2), completion: { [weak self] in
            self?.pauseMenuNode?.isHidden = true
            self?.pauseMenuNode?.setScale(1.0)
        })
    }
    
    func exitToMenu() {
        isPauseMenuVisible = false
        isGamePaused = false
        hidePauseMenuImmediate()
        AudioManager.shared.stopMusic()
        HapticManager.shared.stopHaptics()
        
        let startScene = StartScene(size: size)
        startScene.scaleMode = scaleMode
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view?.presentScene(startScene, transition: transition)
    }
    
    private func hidePauseMenuImmediate() {
        pauseDimNode?.removeAllActions()
        pauseMenuNode?.removeAllActions()
        pauseDimNode?.alpha = 0
        pauseMenuNode?.alpha = 0
        pauseDimNode?.isHidden = true
        pauseMenuNode?.isHidden = true
        pauseMenuNode?.setScale(1.0)
        isPauseMenuVisible = false
        isGamePaused = false
    }
    
    func updateScoreLabel() {
        // Score is no longer displayed in HUD (removed modal)
    }
    
    func updateLivesLabel() {
        updateLivesDisplay()
    }
    
    func updateLivesDisplay() {
        let lives = gameEngine?.lives ?? GameEngine.defaultLives
        for (index, heart) in heartNodes.enumerated() {
            if index < lives {
                heart.texture = SKTexture(imageNamed: "heart-alive")
            } else {
                heart.texture = SKTexture(imageNamed: "heart-dead")
            }
        }
    }
    
    func showHealthRestoredFeedback() {
        // Find the restored heart and animate it
        let lives = gameEngine?.lives ?? GameEngine.defaultLives
        if lives > 0 && lives <= heartNodes.count {
            let restoredHeart = heartNodes[lives - 1]
            let originalScale = restoredHeart.xScale
            
            // Pulse animation for the restored heart (use relative scaling)
            let scaleUp = SKAction.scale(to: originalScale * 1.3, duration: 0.15)
            let scaleDown = SKAction.scale(to: originalScale, duration: 0.15)
            let pulse = SKAction.sequence([scaleUp, scaleDown, scaleUp, scaleDown])
            restoredHeart.run(pulse)
            
            // Add a green glow effect
            let glow = SKSpriteNode(imageNamed: "heart-alive")
            glow.setScale(originalScale)
            glow.position = restoredHeart.position
            glow.alpha = 0.8
            glow.blendMode = .add
            glow.color = .green
            glow.colorBlendFactor = 0.7
            glow.zPosition = restoredHeart.zPosition - 1
            restoredHeart.parent?.addChild(glow)
            
            let glowFade = SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: originalScale * 3.5, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4)
                ]),
                SKAction.removeFromParent()
            ])
            glow.run(glowFade)
        }
        
        // Trigger a positive haptic
        HapticManager.shared.triggerStrokeComplete(type: .perfect)
    }
    
    func gameOver() {
        // Trigger fail haptic before stopping haptics engine
        HapticManager.shared.triggerStrokeComplete(type: .miss)
        recordSongResult(isVictory: false)
        
        AudioManager.shared.stopMusic()
        HapticManager.shared.stopHaptics()
        hidePauseMenuImmediate()
        let gameOverScene = GameOverScene(size: size)
        gameOverScene.score = gameEngine.score
        gameOverScene.percentage = calculatePercentage()
        gameOverScene.scaleMode = scaleMode
        gameOverScene.selectedDifficulty = selectedDifficulty
        gameOverScene.selectedSongId = selectedSongId
        gameOverScene.selectedSongFilename = selectedSongFilename
        gameOverScene.selectedSongTitle = selectedSongTitle
        gameOverScene.enabledTags = enabledTags
        view?.presentScene(gameOverScene, transition: SKTransition.crossFade(withDuration: 1.0))
    }
    
    func songCompleted() {
        // Transition to game over with success message
        recordSongResult(isVictory: true)
        AudioManager.shared.stopMusic()
        HapticManager.shared.stopHaptics()
        hidePauseMenuImmediate()
        let gameOverScene = GameOverScene(size: size)
        gameOverScene.score = gameEngine.score
        gameOverScene.percentage = calculatePercentage()
        gameOverScene.isVictory = true
        gameOverScene.scaleMode = scaleMode
        gameOverScene.selectedDifficulty = selectedDifficulty
        gameOverScene.selectedSongId = selectedSongId
        gameOverScene.selectedSongFilename = selectedSongFilename
        gameOverScene.selectedSongTitle = selectedSongTitle
        gameOverScene.enabledTags = enabledTags
        view?.presentScene(gameOverScene, transition: SKTransition.crossFade(withDuration: 1.0))
    }
    
    #if DEBUG
    func skipToWinScreen() {
        // Debug function to skip directly to win screen
        recordSongResult(isVictory: true)
        AudioManager.shared.stopMusic()
        HapticManager.shared.stopHaptics()
        hidePauseMenuImmediate()
        let gameOverScene = GameOverScene(size: size)
        gameOverScene.score = gameEngine?.score ?? 0
        gameOverScene.percentage = calculatePercentage()
        gameOverScene.isVictory = true
        gameOverScene.scaleMode = scaleMode
        gameOverScene.selectedDifficulty = selectedDifficulty
        gameOverScene.selectedSongId = selectedSongId
        gameOverScene.selectedSongFilename = selectedSongFilename
        gameOverScene.selectedSongTitle = selectedSongTitle
        gameOverScene.enabledTags = enabledTags
        view?.presentScene(gameOverScene, transition: SKTransition.crossFade(withDuration: 0.5))
    }
    
    func debugRestoreHealth() {
        // Debug function to trigger health restoration
        guard let engine = gameEngine else { return }
        if engine.lives < engine.maxLives {
            engine.lives += 1
            updateLivesDisplay()
            showHealthRestoredFeedback()
        }
    }
    #endif

    private func recordSongResult(isVictory: Bool) {
        guard !didRecordSessionResult else { return }
        didRecordSessionResult = true
        if let kanji = gameEngine?.currentKanji {
            let strokeCount = kanji.strokeCount
            for index in 0..<strokeCount where strokeResults[index] == nil {
                strokeResults[index] = .miss
                strokeEarnedPoints[index] = ScoreType.miss.points
            }
        }
        finalizeCurrentKanjiScore()
        let maxScore = gameEngine?.maxPossibleScore ?? 0
        let currentScore = gameEngine?.score ?? 0
        SongScoreStore.shared.record(songId: selectedSongId, difficulty: selectedDifficulty, score: currentScore, maxPossibleScore: maxScore)
    }
    
    private func calculatePercentage() -> Double {
        let maxScore = gameEngine?.maxPossibleScore ?? 1
        let currentScore = gameEngine?.score ?? 0
        guard maxScore > 0 else { return 0 }
        return min(100.0, max(0.0, (Double(currentScore) / Double(maxScore)) * 100.0))
    }
    
    // MARK: - App Lifecycle Observers
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillResignActive() {
        // Only pause if we're actively playing (not already paused or game over)
        guard !isPauseMenuVisible, !isGamePaused, gameEngine != nil else { return }
        
        // Show pause menu after a very short delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.showPauseMenu()
        }
    }
}
