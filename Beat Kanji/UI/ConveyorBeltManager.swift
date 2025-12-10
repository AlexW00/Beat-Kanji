//
//  ConveyorBeltManager.swift
//  Beat Kanji
//
//  Manages conveyor belt animation synced to BPM for menu scenes.
//

import SpriteKit

/// Manages the animated conveyor belt (horizontal lines moving toward player).
/// Used in StartScene, SongSelectScene, and GameOverScene for visual consistency.
class ConveyorBeltManager {
    
    // MARK: - Line Data
    
    struct ConveyorLine {
        let node: SKShapeNode
        let spawnTime: TimeInterval
    }
    
    // MARK: - Properties
    
    private weak var scene: SKScene?
    private weak var gridNode: SKNode?
    
    private var lines: [ConveyorLine] = []
    private var nextSpawnTime: TimeInterval = 0
    
    // Layout constants
    private let horizonY: CGFloat
    private let spawnDepth: CGFloat = 10.0
    private let perspectiveFactor: CGFloat = 0.5
    
    /// Reference to global beat timer
    private var timer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // MARK: - Initialization
    
    /// Creates a conveyor belt manager for a scene.
    /// - Parameters:
    ///   - scene: The scene containing the conveyor belt
    ///   - gridNode: The node to add conveyor lines to (usually zPosition -98)
    ///   - horizonY: The horizon line position as fraction of screen height (default 0.15)
    init(scene: SKScene, gridNode: SKNode, horizonY: CGFloat = SharedBackground.conveyorHorizonY) {
        self.scene = scene
        self.gridNode = gridNode
        self.horizonY = horizonY
    }
    
    // MARK: - Setup
    
    /// Initializes the conveyor belt by aligning to the beat and pre-populating visible lines.
    func start() {
        nextSpawnTime = timer.nextAlignedSpawnTime(after: timer.globalTime)
        prepopulateLines()
    }
    
    /// Pre-populate lines that should already be visible based on global time.
    private func prepopulateLines() {
        guard scene != nil, let gridNode = gridNode else { return }
        
        let currentTime = timer.globalTime
        let interval = timer.conveyorSpawnInterval
        let flightDuration = timer.flightDuration
        
        // Find lines that would have spawned in the past but are still visible
        let oldestVisibleSpawnTime = currentTime - flightDuration
        
        // Find the first beat-aligned spawn time after oldestVisibleSpawnTime
        var spawnTime = timer.nextAlignedSpawnTime(after: max(0, oldestVisibleSpawnTime))
        
        // Create all lines that should currently be visible
        while spawnTime < currentTime {
            let line = createLine()
            gridNode.addChild(line)
            lines.append(ConveyorLine(node: line, spawnTime: spawnTime))
            spawnTime += interval
        }
    }
    
    /// Spawns a new conveyor line.
    private func spawnLine() {
        guard let gridNode = gridNode else { return }
        
        let line = createLine()
        gridNode.addChild(line)
        lines.append(ConveyorLine(node: line, spawnTime: timer.globalTime))
    }
    
    /// Creates a new line shape node.
    private func createLine() -> SKShapeNode {
        let line = SKShapeNode()
        line.strokeColor = SKColor(white: 1.0, alpha: 0.5)
        line.lineWidth = 2
        return line
    }
    
    // MARK: - Update
    
    /// Updates the conveyor belt. Call this from the scene's update method.
    func update() {
        guard let scene = scene else { return }
        
        let currentTime = timer.globalTime
        
        // Spawn new lines synced to BPM
        if currentTime >= nextSpawnTime {
            spawnLine()
            nextSpawnTime = currentTime + timer.conveyorSpawnInterval
        }
        
        // Update existing lines
        let center = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
        let floorEndY = scene.size.height * horizonY
        let targetDY = floorEndY - center.y
        let bottomWidth = scene.size.width
        
        for i in (0..<lines.count).reversed() {
            let line = lines[i]
            let elapsed = currentTime - line.spawnTime
            let progress = CGFloat(elapsed / timer.flightDuration)
            
            // Remove lines that reached the end
            if progress >= 1.0 {
                line.node.removeFromParent()
                lines.remove(at: i)
                continue
            }
            
            // Calculate perspective position
            let currentDepth = spawnDepth * (1.0 - progress)
            let scale = 1.0 / (1.0 + currentDepth * perspectiveFactor)
            let y = center.y + targetDY * scale
            let currentWidth = bottomWidth * scale
            
            // Update line path
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x - currentWidth / 2, y: y))
            path.addLine(to: CGPoint(x: center.x + currentWidth / 2, y: y))
            line.node.path = path
            
            // Beat pulse effect
            let interval = timer.conveyorSpawnInterval
            let timeInBeat = elapsed.truncatingRemainder(dividingBy: interval)
            let normalizedBeatTime = timeInBeat / interval
            let beatPulse = max(0, 1.0 - CGFloat(normalizedBeatTime) * 4.0) * 0.3
            
            line.node.alpha = 0.1 + 0.4 * scale + beatPulse
        }
    }
    
    // MARK: - Cleanup
    
    /// Removes all conveyor lines.
    func removeAll() {
        for line in lines {
            line.node.removeFromParent()
        }
        lines.removeAll()
    }
}
