//
//  PlayScene+ConveyorBelt.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

extension PlayScene {
    
    func updateConveyorBelt() {
        // 1. Spawn new lines synced to BPM
        if gameEngine.currentTime >= nextConveyorSpawnTime {
            spawnConveyorLineManual()
            nextConveyorSpawnTime = gameEngine.currentTime + conveyorSpawnInterval
        }
        
        // 2. Update existing lines
        // Speed is based on BPM - lines should travel the full distance in flightDuration
        // At higher BPM, lines spawn more frequently but travel at the same speed
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let floorEndY = size.height * SharedBackground.conveyorHorizonY
        let targetDY = floorEndY - center.y
        let bottomWidth = size.width * 1.0
        
        for i in (0..<conveyorLines.count).reversed() {
            let line = conveyorLines[i]
            let elapsed = gameEngine.currentTime - line.spawnTime
            let progress = CGFloat(elapsed / gameEngine.flightDuration)
            
            if progress >= 1.0 {
                // Reached the end
                line.node.removeFromParent()
                conveyorLines.remove(at: i)
                continue
            }
            
            let currentDepth = spawnDepth * (1.0 - progress)
            
            // Calculate scale based on perspective
            let scale = 1.0 / (1.0 + currentDepth * perspectiveFactor)
            
            // Calculate Y position using perspective
            let y = center.y + targetDY * scale
            
            // Calculate Width at this Y
            let currentWidth = bottomWidth * scale
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x - currentWidth/2, y: y))
            path.addLine(to: CGPoint(x: center.x + currentWidth/2, y: y))
            
            line.node.path = path
            
            // Pulse effect on beat - brighter when close to a beat time
            var beatPulse: CGFloat = 0.0
            if beatmap != nil {
                let interval = conveyorSpawnInterval
                let timeInBeat = elapsed.truncatingRemainder(dividingBy: interval)
                let normalizedBeatTime = timeInBeat / interval
                // Pulse at the start of each beat
                beatPulse = max(0, 1.0 - CGFloat(normalizedBeatTime) * 4.0) * 0.3
            }
            
            line.node.alpha = 0.1 + 0.4 * scale + beatPulse // Fade in with beat pulse
        }
    }
    
    private func spawnConveyorLineManual() {
        // Find grid node (It has zPosition -98 and is a child of self)
        guard let gridNode = children.first(where: { $0.zPosition == -98 }) else {
            return
        }
        
        let line = SKShapeNode()
        line.strokeColor = SKColor(white: 1.0, alpha: 0.5)
        line.lineWidth = 2
        
        gridNode.addChild(line)
       
        let conveyorLine = ConveyorLine(node: line, spawnTime: gameEngine.currentTime)
        conveyorLines.append(conveyorLine)
    }
}
