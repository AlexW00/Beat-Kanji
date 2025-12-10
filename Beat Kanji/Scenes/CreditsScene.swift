//
//  CreditsScene.swift
//  Beat Kanji
//
//  Created by Copilot on 05.12.25.
//

import SpriteKit

class CreditsScene: SKScene {
    
    // MARK: - Conveyor Belt
    
    private var conveyorManager: ConveyorBeltManager?
    
    // Use shared timer for seamless transitions between scenes
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // MARK: - UI Elements
    
    private var backButton: SKNode!
    
    // MARK: - Touch State Tracking
    
    private var backButtonTouchBegan = false
    
    // MARK: - Lifecycle
    
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
        setupBackButton()
        setupTitle()
    }
    
    private func setupBackButton() {
        backButton = SKNode()
        backButton.name = "backButton"
        backButton.position = CGPoint(x: 60, y: size.height - 75)
        backButton.zPosition = 100
        
        let backBg = SKSpriteNode(imageNamed: "button-square")
        let backScale: CGFloat = 85 / max(backBg.size.width, backBg.size.height)
        backBg.setScale(backScale)
        backButton.addChild(backBg)
        
        // Arrow icon using ButtonFactory
        let arrowPath = ButtonFactory.backArrowPath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .clear
        arrow.strokeColor = .white
        arrow.lineWidth = 3.5
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.glowWidth = 0
        arrow.zPosition = 1
        backButton.addChild(arrow)
        
        addChild(backButton)
    }
    
    private func setupTitle() {
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = NSLocalizedString("credits.title", comment: "Credits title")
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 150)
        titleLabel.zPosition = 100
        addChild(titleLabel)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Check back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if abs(backLocation.x) < 50 && abs(backLocation.y) < 50 {
                backButtonTouchBegan = true
                back.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Check back button - only trigger if touch began on it
        if let back = backButton {
            let backLocation = touch.location(in: back)
            back.run(SKAction.scale(to: 1.0, duration: 0.1))
            if backButtonTouchBegan && abs(backLocation.x) < 50 && abs(backLocation.y) < 50 {
                backButtonTouchBegan = false
                AudioManager.shared.playUISound(.buttonBack)
                transitionToSettingsScene()
                return
            }
            backButtonTouchBegan = false
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        backButtonTouchBegan = false
    }
    
    // MARK: - Navigation
    
    private func transitionToSettingsScene() {
        globalTimer.prepareForSceneTransition()
        let settingsScene = SettingsScene(size: size)
        settingsScene.scaleMode = scaleMode
        view?.presentScene(settingsScene)
    }
}
