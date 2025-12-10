//
//  DifficultySelectScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

class DifficultySelectScene: SKScene {
    
    private var buttons: [SKNode] = []
    
    // MARK: - Touch State Tracking
    
    private var backButtonTouchBegan = false
    private var activeDifficultyButton: DifficultyLevel? = nil
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        setupUI()
    }
    
    private func setupUI() {
        // Title
        let titleLabel = SKLabelNode(text: "Select Difficulty")
        titleLabel.fontSize = 48
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        addChild(titleLabel)
        
        // Difficulty buttons
        let difficulties = DifficultyLevel.allCases
        let buttonSpacing: CGFloat = 120
        let startY = size.height * 0.55
        
        for (index, difficulty) in difficulties.enumerated() {
            let buttonNode = createDifficultyButton(difficulty: difficulty)
            buttonNode.position = CGPoint(
                x: size.width / 2,
                y: startY - CGFloat(index) * buttonSpacing
            )
            addChild(buttonNode)
            buttons.append(buttonNode)
        }
        
        // Back button
        let backButton = SKLabelNode(text: "← Back")
        backButton.name = "backButton"
        backButton.fontSize = 28
        backButton.fontColor = .gray
        backButton.position = CGPoint(x: size.width / 2, y: size.height * 0.1)
        addChild(backButton)
    }
    
    private func createDifficultyButton(difficulty: DifficultyLevel) -> SKNode {
        let container = SKNode()
        container.name = "difficulty_\(difficulty.rawValue)"
        
        // Background using button asset with hue shift via shader
        let buttonBg = SKSpriteNode(imageNamed: "button")
        let buttonScale: CGFloat = 280 / buttonBg.size.width
        buttonBg.setScale(buttonScale)
        
        // Apply color tint using shader for proper hue shift
        let shader = ShaderFactory.createHueShiftShader(for: difficulty)
        buttonBg.shader = shader
        
        container.addChild(buttonBg)
        
        // Title
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = difficulty.displayName
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 8)
        titleLabel.zPosition = 1
        container.addChild(titleLabel)
        
        // Description
        let descLabel = SKLabelNode(fontNamed: FontConfig.regular)
        descLabel.text = difficulty.description
        descLabel.fontSize = 14
        descLabel.fontColor = SKColor(white: 0.9, alpha: 0.8)
        descLabel.verticalAlignmentMode = .center
        descLabel.position = CGPoint(x: 0, y: -14)
        descLabel.zPosition = 1
        container.addChild(descLabel)
        
        return container
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check for back button
        if nodes.contains(where: { $0.name == "backButton" }) {
            backButtonTouchBegan = true
            return
        }
        
        // Check for difficulty buttons
        for node in nodes {
            if let name = node.name, name.hasPrefix("difficulty_") {
                if let levelStr = name.split(separator: "_").last,
                   let level = Int(levelStr),
                   let difficulty = DifficultyLevel(rawValue: level) {
                    activeDifficultyButton = difficulty
                    node.run(SKAction.scale(to: 0.95, duration: 0.1))
                    return
                }
            }
            
            // Also check parent (in case we hit a child node)
            if let parentName = node.parent?.name, parentName.hasPrefix("difficulty_") {
                if let levelStr = parentName.split(separator: "_").last,
                   let level = Int(levelStr),
                   let difficulty = DifficultyLevel(rawValue: level) {
                    activeDifficultyButton = difficulty
                    node.parent?.run(SKAction.scale(to: 0.95, duration: 0.1))
                    return
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Reset button scales
        for button in buttons {
            button.run(SKAction.scale(to: 1.0, duration: 0.1))
        }
        
        // Check for back button - only trigger if touch began on it
        if backButtonTouchBegan && nodes.contains(where: { $0.name == "backButton" }) {
            backButtonTouchBegan = false
            activeDifficultyButton = nil
            AudioManager.shared.playUISound(.buttonBack)
            transitionToStartScene()
            return
        }
        backButtonTouchBegan = false
        
        // Check for difficulty buttons - only trigger if touch began on same button
        if let targetDifficulty = activeDifficultyButton {
            for node in nodes {
                if let name = node.name, name.hasPrefix("difficulty_") {
                    if let levelStr = name.split(separator: "_").last,
                       let level = Int(levelStr),
                       let difficulty = DifficultyLevel(rawValue: level),
                       difficulty == targetDifficulty {
                        activeDifficultyButton = nil
                        AudioManager.shared.playUISound(.button)
                        startGame(with: difficulty)
                        return
                    }
                }
                
                // Also check parent (in case we hit a child node)
                if let parentName = node.parent?.name, parentName.hasPrefix("difficulty_") {
                    if let levelStr = parentName.split(separator: "_").last,
                       let level = Int(levelStr),
                       let difficulty = DifficultyLevel(rawValue: level),
                       difficulty == targetDifficulty {
                        activeDifficultyButton = nil
                        AudioManager.shared.playUISound(.button)
                        startGame(with: difficulty)
                        return
                    }
                }
            }
        }
        activeDifficultyButton = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for button in buttons {
            button.run(SKAction.scale(to: 1.0, duration: 0.1))
        }
        backButtonTouchBegan = false
        activeDifficultyButton = nil
    }
    
    private func transitionToStartScene() {
        let startScene = StartScene(size: size)
        startScene.scaleMode = scaleMode
        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(startScene, transition: transition)
    }
    
    private func startGame(with difficulty: DifficultyLevel) {
        let playScene = PlayScene(size: size)
        playScene.scaleMode = scaleMode
        playScene.selectedDifficulty = difficulty
        let transition = SKTransition.fade(withDuration: 1.0)
        view?.presentScene(playScene, transition: transition)
    }
}
