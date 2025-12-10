//
//  StartScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

class StartScene: SKScene {
    
    // MARK: - Conveyor Belt
    
    private var conveyorManager: ConveyorBeltManager?
    
    // Use shared timer for seamless transitions between scenes
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // UI Elements
    private var logoNode: SKSpriteNode?
    private var playButton: SKNode?
    private var playButtonBackground: SKSpriteNode?
    private var settingsButton: SKNode?
    
    // Touch tracking to prevent swipe-triggered taps
    private var playButtonTouchBegan = false
    private var settingsButtonTouchBegan = false
    
    override func didMove(to view: SKView) {
        setupBackground()
        setupUI()
        
        // Start conveyor belt
        if let gridNode = children.first(where: { $0.zPosition == -98 }) {
            conveyorManager = ConveyorBeltManager(scene: self, gridNode: gridNode)
            conveyorManager?.start()
        }
        
        // Play menu music
        AudioManager.shared.playMenuMusic()
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Update shared global timer
        globalTimer.update(systemTime: currentTime)
        
        // Update conveyor belt
        conveyorManager?.update()
    }
    
    // MARK: - Background Setup
    
    private func setupBackground() {
        SharedBackground.setupComplete(for: self)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupSettingsButton()
        setupLogo()
        setupPlayButton()
    }
    
    private func setupSettingsButton() {
        let button = SKNode()
        button.name = "settingsButton"
        button.position = CGPoint(x: 60, y: size.height - 75)
        button.zPosition = 100
        
        let bg = SKSpriteNode(imageNamed: "button-square")
        let scale: CGFloat = 85 / max(bg.size.width, bg.size.height)
        bg.setScale(scale)
        button.addChild(bg)
        
        // Gear icon
        let gear = SKSpriteNode(imageNamed: "gear-six")
        let gearScale: CGFloat = 32 / max(gear.size.width, gear.size.height)
        gear.setScale(gearScale)
        gear.zPosition = 1
        button.addChild(gear)
        
        settingsButton = button
        addChild(button)
    }
    
    private func setupLogo() {
        logoNode = SKSpriteNode(imageNamed: "start-screen-logo")
        guard let logo = logoNode else { return }
        
        // Scale logo to be larger and more prominent
        let maxWidth = size.width * 0.95
        let maxHeight = size.height * 0.35
        let scale = min(maxWidth / logo.size.width, maxHeight / logo.size.height, 1.0)
        logo.setScale(scale)
        
        // Position at center of screen (above the horizon vanishing point)
        logo.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        logo.zPosition = 100
        addChild(logo)
        
        // Add subtle breathing animation
        let breathe = SKAction.sequence([
            SKAction.scale(to: scale * 1.03, duration: 2.0),
            SKAction.scale(to: scale, duration: 2.0)
        ])
        logo.run(SKAction.repeatForever(breathe))
        
        // Add particle effects around logo
        let particleContainer = SKNode()
        particleContainer.position = logo.position
        particleContainer.zPosition = logo.zPosition + 1
        addChild(particleContainer)
        
        let logoSize = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
        ParticleFactory.addLogoSparkles(to: particleContainer, logoSize: logoSize)
    }
    
    private func setupPlayButton() {
        let buttonContainer = SKNode()
        buttonContainer.name = "playButton"
        buttonContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        buttonContainer.zPosition = 100
        
        // Background button image
        playButtonBackground = SKSpriteNode(imageNamed: "button")
        if let bg = playButtonBackground {
            let targetWidth: CGFloat = 250
            let scale = targetWidth / bg.size.width
            bg.setScale(scale)
            bg.zPosition = 0
            buttonContainer.addChild(bg)
            
            // Add particle effects
            let buttonSize = CGSize(width: bg.size.width * scale, height: bg.size.height * scale)
            ParticleFactory.addButtonSparkles(to: buttonContainer, buttonSize: buttonSize)
        }
        
        // Localized "Play" text
        let playText = SKLabelNode(fontNamed: FontConfig.bold)
        playText.text = NSLocalizedString("start.play", comment: "Play button text")
        playText.fontSize = 28
        playText.fontColor = .white
        playText.verticalAlignmentMode = .center
        playText.horizontalAlignmentMode = .center
        playText.zPosition = 10
        buttonContainer.addChild(playText)
        
        playButton = buttonContainer
        addChild(buttonContainer)
        
        // Add subtle idle animation
        ButtonFactory.addPulseAnimation(to: buttonContainer, scale: 1.02, duration: 2.0)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Settings button
        if let settings = settingsButton {
            let settingsLocation = touch.location(in: settings)
            if abs(settingsLocation.x) < 50 && abs(settingsLocation.y) < 50 {
                settingsButtonTouchBegan = true
                settings.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
        
        if let button = playButton, let bg = playButtonBackground {
            // Convert touch into the button's local space so we use the correct frame
            let locationInButton = button.convert(location, from: self)
            let expandedFrame = bg.frame.insetBy(dx: -20, dy: -20)
            
            if expandedFrame.contains(locationInButton) {
                playButtonTouchBegan = true
                button.removeAllActions()
                ButtonFactory.animatePress(button)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Settings button - only trigger if touch began on it
        if let settings = settingsButton {
            let settingsLocation = touch.location(in: settings)
            settings.run(SKAction.scale(to: 1.0, duration: 0.1))
            if settingsButtonTouchBegan && abs(settingsLocation.x) < 50 && abs(settingsLocation.y) < 50 {
                settingsButtonTouchBegan = false
                AudioManager.shared.playUISound(.button)
                transitionToSettingsScene()
                return
            }
            settingsButtonTouchBegan = false
        }
        
        if let button = playButton, let bg = playButtonBackground {
            let locationInButton = button.convert(location, from: self)
            let expandedFrame = bg.frame.insetBy(dx: -20, dy: -20)
            
            // Reset scale and restart pulse
            ButtonFactory.animateRelease(button)
            button.run(SKAction.wait(forDuration: 0.1)) { [weak button] in
                if let btn = button {
                    ButtonFactory.addPulseAnimation(to: btn, scale: 1.02, duration: 2.0)
                }
            }
            
            // Only trigger if touch began on the button
            if playButtonTouchBegan && expandedFrame.contains(locationInButton) {
                playButtonTouchBegan = false
                AudioManager.shared.playUISound(.button)
                transitionToPlayScene()
            }
            playButtonTouchBegan = false
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        settingsButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        settingsButtonTouchBegan = false
        playButtonTouchBegan = false
        
        if let button = playButton {
            ButtonFactory.animateRelease(button)
            button.run(SKAction.wait(forDuration: 0.1)) { [weak button] in
                if let btn = button {
                    ButtonFactory.addPulseAnimation(to: btn, scale: 1.02, duration: 2.0)
                }
            }
        }
    }
    
    // MARK: - Navigation
    
    private func transitionToSettingsScene() {
        globalTimer.prepareForSceneTransition()
        let settingsScene = SettingsScene(size: size)
        settingsScene.scaleMode = scaleMode
        view?.presentScene(settingsScene)
    }
    
    func transitionToPlayScene() {
        globalTimer.prepareForSceneTransition()
        
        let songSelectScene = SongSelectScene(size: size)
        songSelectScene.scaleMode = scaleMode
        view?.presentScene(songSelectScene)
    }
}
