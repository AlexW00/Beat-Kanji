//
//  PlayScene+Layout.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

extension PlayScene {
    func setupBackground() {
        // Reuse shared background + grid so offsets/horizon stay consistent across scenes
        SharedBackground.setupComplete(for: self)

        // Red flash overlay
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = .red
        flash.strokeColor = .clear
        flash.alpha = 0.0
        flash.zPosition = 200
        flash.name = "redFlash"
        addChild(flash)

        // Debug skip button (bottom left corner)
        #if DEBUG
        setupSkipButton()
        #endif
    }
    
    #if DEBUG
    func setupSkipButton() {
        let skipButton = SKNode()
        skipButton.name = "skipButton"
        skipButton.position = CGPoint(x: 60, y: 50)
        skipButton.zPosition = 250
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        skipButton.addChild(bg)
        
        // Label
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "SKIP ⏭"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        skipButton.addChild(label)
        
        addChild(skipButton)
        
        // Debug heart restore button (next to skip button)
        let heartButton = SKNode()
        heartButton.name = "debugHeartButton"
        heartButton.position = CGPoint(x: 150, y: 50)
        heartButton.zPosition = 250
        
        let heartBg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        heartBg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        heartBg.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 0.5)
        heartBg.lineWidth = 1
        heartButton.addChild(heartBg)
        
        let heartLabel = SKLabelNode(fontNamed: FontConfig.bold)
        heartLabel.text = "+1 ❤️"
        heartLabel.fontSize = 14
        heartLabel.fontColor = .white
        heartLabel.verticalAlignmentMode = .center
        heartLabel.horizontalAlignmentMode = .center
        heartButton.addChild(heartLabel)
        
        addChild(heartButton)
    }
    #endif
}
