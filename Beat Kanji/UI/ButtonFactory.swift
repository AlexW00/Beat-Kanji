//
//  ButtonFactory.swift
//  Beat Kanji
//
//  Factory for creating consistent button styles across the game.
//

import SpriteKit

/// Factory for creating reusable button components.
enum ButtonFactory {
    
    // MARK: - Standard Button
    
    /// Creates a standard button with background image and text.
    /// - Parameters:
    ///   - text: The button label text
    ///   - name: The node name for touch detection
    ///   - width: Target width for the button (default 180)
    ///   - fontSize: Font size for label (default 20)
    ///   - imageName: Background image name (default "button")
    /// - Returns: A container node with the button
    static func createButton(
        text: String,
        name: String,
        width: CGFloat = 180,
        fontSize: CGFloat = 20,
        imageName: String = "button"
    ) -> SKNode {
        let container = SKNode()
        container.name = name
        
        // Background
        let bg = SKSpriteNode(imageNamed: imageName)
        let scale = width / bg.size.width
        bg.setScale(scale)
        bg.zPosition = 0
        container.addChild(bg)
        
        // Label
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = text
        label.fontSize = fontSize
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        container.addChild(label)
        
        return container
    }
    
    // MARK: - Square Button
    
    /// Creates a square button with an icon (e.g., pause button, back button).
    /// - Parameters:
    ///   - name: The node name for touch detection
    ///   - iconPath: CGPath for the icon shape, or nil for no icon
    ///   - size: Target size (width and height) for the button (default 80)
    ///   - imageName: Background image name (default "button-square")
    /// - Returns: A container node with the button
    static func createSquareButton(
        name: String,
        iconPath: CGPath?,
        size: CGFloat = 80,
        imageName: String = "button-square"
    ) -> SKNode {
        let container = SKNode()
        container.name = name
        
        // Background
        let bg = SKSpriteNode(imageNamed: imageName)
        let scale = size / max(bg.size.width, bg.size.height)
        bg.setScale(scale)
        bg.zPosition = 0
        container.addChild(bg)
        
        // Icon
        if let iconPath = iconPath {
            let icon = SKShapeNode(path: iconPath)
            icon.fillColor = .white
            icon.strokeColor = .white
            icon.lineWidth = 0
            icon.zPosition = 1
            container.addChild(icon)
        }
        
        return container
    }
    
    // MARK: - Icon Paths
    
    /// Creates a pause icon path (two vertical bars).
    static func pauseIconPath() -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: -10, y: -16, width: 8, height: 32), cornerWidth: 3, cornerHeight: 3)
        path.addRoundedRect(in: CGRect(x: 2, y: -16, width: 8, height: 32), cornerWidth: 3, cornerHeight: 3)
        return path
    }
    
    /// Creates a back arrow icon path.
    static func backArrowPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 0))
        path.move(to: CGPoint(x: -10, y: 0))
        path.addLine(to: CGPoint(x: -2, y: 8))
        path.move(to: CGPoint(x: -10, y: 0))
        path.addLine(to: CGPoint(x: -2, y: -8))
        return path
    }
    
    /// Creates a caret (chevron) path for dropdown indicators.
    /// - Parameter pointingDown: If true, points down; if false, points up
    static func caretPath(pointingDown: Bool) -> CGPath {
        let path = CGMutablePath()
        if pointingDown {
            path.move(to: CGPoint(x: -6, y: 4))
            path.addLine(to: CGPoint(x: 0, y: -4))
            path.addLine(to: CGPoint(x: 6, y: 4))
        } else {
            path.move(to: CGPoint(x: -6, y: -4))
            path.addLine(to: CGPoint(x: 0, y: 4))
            path.addLine(to: CGPoint(x: 6, y: -4))
        }
        return path
    }
    
    // MARK: - Back Button (with stroke arrow)
    
    /// Creates a back button with a stroked arrow icon.
    /// - Parameters:
    ///   - name: The node name for touch detection
    ///   - size: Target size for the button (default 85)
    /// - Returns: A container node with the button
    static func createBackButton(name: String = "backButton", size: CGFloat = 85) -> SKNode {
        let container = SKNode()
        container.name = name
        
        // Background
        let bg = SKSpriteNode(imageNamed: "button-square")
        let scale = size / max(bg.size.width, bg.size.height)
        bg.setScale(scale)
        container.addChild(bg)
        
        // Arrow icon (stroked, not filled)
        let arrowPath = backArrowPath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .clear
        arrow.strokeColor = .white
        arrow.lineWidth = 3.5
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.glowWidth = 0
        arrow.zPosition = 1
        container.addChild(arrow)
        
        return container
    }
    
    // MARK: - Button Animations
    
    /// Adds a subtle pulse animation to a button.
    /// - Parameters:
    ///   - button: The button node to animate
    ///   - scale: Maximum scale for pulse (default 1.03)
    ///   - duration: Duration of one pulse cycle (default 2.0)
    static func addPulseAnimation(to button: SKNode, scale: CGFloat = 1.03, duration: TimeInterval = 2.0) {
        let pulse = SKAction.sequence([
            SKAction.scale(to: scale, duration: duration / 2),
            SKAction.scale(to: 1.0, duration: duration / 2)
        ])
        button.run(SKAction.repeatForever(pulse))
    }
    
    /// Adds press feedback animation to a button.
    /// - Parameter button: The button node
    static func animatePress(_ button: SKNode) {
        button.run(SKAction.scale(to: 0.95, duration: 0.1))
    }
    
    /// Resets button to normal scale after press.
    /// - Parameter button: The button node
    static func animateRelease(_ button: SKNode) {
        button.run(SKAction.scale(to: 1.0, duration: 0.1))
    }
}
