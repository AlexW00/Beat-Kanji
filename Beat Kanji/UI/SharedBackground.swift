//
//  SharedBackground.swift
//  Beat Kanji
//
//  Reusable background component with perspective grid.
//

import SpriteKit

/// Provides shared background and perspective grid setup used across multiple scenes.
enum SharedBackground {
    
    // MARK: - Layout Constants
    
    /// Y offset to move background up
    // Shift the background upward so the horizon aligns with the conveyor belt spawn
    static let backgroundOffsetY: CGFloat = 50.0
    
    /// Horizon line relative to screen height (where grid converges)
    static let conveyorHorizonY: CGFloat = 0.15
    
    // MARK: - Background Setup
    
    /// Creates and adds the main background image to a scene.
    /// - Parameters:
    ///   - scene: The scene to add the background to
    ///   - alpha: Background alpha (use lower value for darker scenes like game over)
    /// - Returns: The created background sprite node
    @discardableResult
    static func addBackground(to scene: SKScene, alpha: CGFloat = 1.0) -> SKSpriteNode {
        scene.backgroundColor = .black
        
        let bg = SKSpriteNode(imageNamed: "bg1.jpeg")
        bg.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2 + backgroundOffsetY)
        bg.zPosition = -100
        bg.alpha = alpha
        
        // Aspect Fill
        let aspect = bg.size.width / bg.size.height
        let viewAspect = scene.size.width / scene.size.height
        
        if aspect > viewAspect {
            bg.size = CGSize(width: scene.size.height * aspect, height: scene.size.height)
        } else {
            bg.size = CGSize(width: scene.size.width, height: scene.size.width / aspect)
        }

        // Add extra height to cover the upward offset so no black band appears at the bottom
        let verticalPadding = abs(backgroundOffsetY) * 2
        if verticalPadding > 0 {
            let newHeight = bg.size.height + verticalPadding
            let newWidth = newHeight * aspect
            bg.size = CGSize(width: newWidth, height: newHeight)
        }
        
        scene.addChild(bg)
        return bg
    }
    
    // MARK: - Grid Setup
    
    /// Creates and adds the perspective grid (floor grid / conveyor belt base) to a scene.
    /// - Parameters:
    ///   - scene: The scene to add the grid to
    ///   - lineAlpha: Alpha for grid lines (use lower for darker scenes)
    /// - Returns: The grid container node
    @discardableResult
    static func addPerspectiveGrid(to scene: SKScene, lineAlpha: CGFloat = 0.3) -> SKNode {
        let center = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        let floorEndY = scene.size.height * conveyorHorizonY
        
        let gridNode = SKNode()
        gridNode.position = .zero
        gridNode.zPosition = -98
        scene.addChild(gridNode)
        
        // Vertical Lines (converging to center)
        let numLines = 8
        let bottomWidth = scene.size.width
        
        for i in 0...numLines {
            let t = CGFloat(i) / CGFloat(numLines)
            let xOffset = (t - 0.5) * bottomWidth
            
            let path = CGMutablePath()
            path.move(to: center)
            let bottomX = center.x + xOffset
            path.addLine(to: CGPoint(x: bottomX, y: floorEndY))
            
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(white: 1.0, alpha: lineAlpha)
            line.lineWidth = 1
            gridNode.addChild(line)
        }
        
        // Closing Line at horizon
        let closingPath = CGMutablePath()
        let leftX = center.x - 0.5 * bottomWidth
        let rightX = center.x + 0.5 * bottomWidth
        closingPath.move(to: CGPoint(x: leftX, y: floorEndY))
        closingPath.addLine(to: CGPoint(x: rightX, y: floorEndY))
        
        let closingLine = SKShapeNode(path: closingPath)
        closingLine.strokeColor = SKColor(white: 1.0, alpha: 0.1)
        closingLine.lineWidth = 2
        gridNode.addChild(closingLine)
        
        return gridNode
    }
    
    // MARK: - Particles
    
    /// Adds background particle effects to a scene.
    /// - Parameter scene: The scene to add particles to
    @discardableResult
    static func addBackgroundParticles(to scene: SKScene) -> SKEmitterNode? {
        guard let particles = SKEmitterNode(fileNamed: "BackgroundParticles") else {
            return nil
        }
        particles.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        particles.zPosition = -99
        scene.addChild(particles)
        return particles
    }
    
    // MARK: - Combined Setup
    
    /// Sets up the complete shared background (background image, grid, particles).
    /// - Parameters:
    ///   - scene: The scene to set up
    ///   - backgroundAlpha: Alpha for background image
    ///   - gridAlpha: Alpha for grid lines
    static func setupComplete(for scene: SKScene, backgroundAlpha: CGFloat = 1.0, gridAlpha: CGFloat = 0.3) {
        addBackground(to: scene, alpha: backgroundAlpha)
        addPerspectiveGrid(to: scene, lineAlpha: gridAlpha)
        addBackgroundParticles(to: scene)
    }
}
