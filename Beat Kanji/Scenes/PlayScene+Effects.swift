//
//  PlayScene+Effects.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

private enum TouchParticleTextures {
    static let trail = SKTexture(imageNamed: "circle_01")
    static let path = SKTexture(imageNamed: "star_04")
    static let burst = SKTexture(imageNamed: "star_07")
    static let tip = SKTexture(imageNamed: "star_08")
}

extension PlayScene {
    
    func setupSparkEmitter() {
        sparkEmitter = SKEmitterNode()
        sparkEmitter?.particleTexture = TouchParticleTextures.trail
        sparkEmitter?.particleBirthRate = 110
        sparkEmitter?.particleLifetime = 0.22
        sparkEmitter?.particlePositionRange = CGVector(dx: 6, dy: 6)
        sparkEmitter?.particleAlpha = 0.9
        sparkEmitter?.particleAlphaSpeed = -4.0
        sparkEmitter?.particleScale = 0.05
        sparkEmitter?.particleScaleRange = 0.015
        sparkEmitter?.particleScaleSpeed = -0.2
        sparkEmitter?.particleColor = .cyan
        sparkEmitter?.particleColorBlendFactor = 1.0
        sparkEmitter?.particleBlendMode = .add
        sparkEmitter?.targetNode = self
        sparkEmitter?.alpha = 0.0 // Start hidden
        sparkEmitter?.zPosition = 50
        addChild(sparkEmitter!)
    }
    
    func setupStrokeTrailEmitter() {
        let emitter = SKEmitterNode()
        emitter.particleTexture = TouchParticleTextures.path // star_04
        emitter.particleBirthRate = 150
        emitter.particleLifetime = 0.5
        emitter.particlePositionRange = CGVector(dx: 18, dy: 18)
        emitter.particleSpeed = 55
        emitter.particleSpeedRange = 35
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -2.0
        emitter.particleScale = 0.10
        emitter.particleScaleRange = 0.04
        emitter.particleScaleSpeed = -0.2
        emitter.particleColor = SKColor(red: 0.4, green: 0.72, blue: 1.0, alpha: 1.0) // Blue stars
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.targetNode = self
        emitter.alpha = 0.0 // Hidden until drawing starts
        emitter.zPosition = 55
        strokeTrailEmitter = emitter
        addChild(emitter)
    }
    
    func showFeedback(type: ScoreType, at _: CGPoint? = nil) {
        // Screen flash for miss
        if type == .miss {
            if let flash = childNode(withName: "redFlash") {
                flash.removeAllActions()
                flash.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                    SKAction.fadeAlpha(to: 0.0, duration: 0.2)
                ]))
            }
            // Shake the camera/scene
            let shake = SKAction.sequence([
                SKAction.moveBy(x: -10, y: 0, duration: 0.05),
                SKAction.moveBy(x: 20, y: 0, duration: 0.05),
                SKAction.moveBy(x: -10, y: 0, duration: 0.05)
            ])
            run(shake)
        } else if type == .perfect {
            // Particle burst for perfect (handled in touchesEnded now for lock-in, but keep fallback)
            // We can remove this or keep it as a secondary effect. 
            // Let's keep it minimal or remove it to avoid clutter since we have lock-in burst.
        }
    }
    
    func createLockInBurst(at position: CGPoint, color: UIColor, intensity: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = TouchParticleTextures.burst
        emitter.particleBirthRate = 1000 // High rate for instant burst
        emitter.numParticlesToEmit = Int(40 * intensity)
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 100 * intensity // Reduced speed
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -2.5
        emitter.particleScale = 0.12 * intensity
        emitter.particleScaleRange = 0.05 * intensity
        emitter.particleScaleSpeed = -0.25
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.zPosition = 110
        addChild(emitter)
        
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }
    
    func createStrokePathParticles(for stroke: Stroke, color: UIColor, intensity: CGFloat) {
        guard let node = currentKanjiNode,
              let scale = node.userData?["scale"] as? CGFloat,
              let offsetX = node.userData?["offsetX"] as? CGFloat,
              let offsetY = node.userData?["offsetY"] as? CGFloat else { return }
        
        let points = stroke.cgPoints
        // Spawn particles at intervals along the path
        // Adjust density based on intensity
        let density = max(5.0, 15.0 * intensity)
        let step = max(1, Int(Double(points.count) / density))
        
        for i in stride(from: 0, to: points.count, by: step) {
            let p = points[i]
            let point = CGPoint(x: p.x * scale + offsetX, y: (1.0 - p.y) * scale + offsetY)
            
            let emitter = SKEmitterNode()
            emitter.particleTexture = TouchParticleTextures.path
            emitter.particleBirthRate = 1000
            emitter.numParticlesToEmit = max(1, Int(2.0 * intensity))
            emitter.particleLifetime = 0.4
            emitter.particleSpeed = 50
            emitter.particleSpeedRange = 30
            emitter.emissionAngleRange = 2 * .pi
            emitter.particlePositionRange = CGVector(dx: 6, dy: 6)
            emitter.particleScale = 0.08 * intensity
            emitter.particleScaleRange = 0.04 * intensity
            emitter.particleScaleSpeed = -0.15
            emitter.particleColor = color
            emitter.particleColorBlendFactor = 1.0
            emitter.particleBlendMode = .add
            emitter.position = point
            emitter.zPosition = 110
            addChild(emitter)
            
            emitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        }
        
        // Tip accent (single star_08 at final point)
        if let last = points.last {
            let tipPoint = CGPoint(x: last.x * scale + offsetX, y: (1.0 - last.y) * scale + offsetY)
            let tipEmitter = SKEmitterNode()
            tipEmitter.particleTexture = TouchParticleTextures.tip
            tipEmitter.particleBirthRate = 200
            tipEmitter.numParticlesToEmit = 1
            tipEmitter.particleLifetime = 0.5
            tipEmitter.particleSpeed = 15
            tipEmitter.particleSpeedRange = 10
            tipEmitter.emissionAngleRange = .pi / 2
            tipEmitter.particleScale = 0.12 * intensity
            tipEmitter.particleScaleRange = 0.05 * intensity
            tipEmitter.particleScaleSpeed = -0.2
            tipEmitter.particleColor = color
            tipEmitter.particleColorBlendFactor = 1.0
            tipEmitter.particleBlendMode = .add
            tipEmitter.position = tipPoint
            tipEmitter.zPosition = 115
            addChild(tipEmitter)
            tipEmitter.run(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.removeFromParent()
            ]))
        }
    }
    
    func showTooEarlyToast(at position: CGPoint) {
        // Container so background and text animate together
        let container = SKNode()
        // Render above hearts (z=1) but below pause (z=2) when on hudLayer; fallback to 200 if hud missing
        if hudLayer != nil {
            container.zPosition = 1.5
        } else {
            container.zPosition = 200
        }
        container.alpha = 0.0

        // Position above the touch so the user's thumb doesn't hide it
        let offset: CGFloat = 80
        container.position = CGPoint(x: position.x, y: min(position.y + offset, size.height - 50))

        // Background uses button.png tinted red (hard difficulty hue)
        let background = SKSpriteNode(imageNamed: "button")
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = NSLocalizedString("play.tooearly", comment: "Too early feedback")
        label.fontSize = 26
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1

        // Use a layout label at the previous size to preserve button dimensions
        let layoutFontSize: CGFloat = 28
        let layoutLabel = SKLabelNode(fontNamed: FontConfig.bold)
        layoutLabel.text = label.text
        layoutLabel.fontSize = layoutFontSize

        let horizontalPadding: CGFloat = 36
        let verticalPadding: CGFloat = 18
        let bgScaleX = (layoutLabel.frame.width + horizontalPadding) / background.size.width
        let bgScaleY = (layoutLabel.frame.height + verticalPadding) / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.zPosition = 0
        background.shader = ShaderFactory.createHueShiftShader(for: .hard)

        container.addChild(background)
        container.addChild(label)

        if let hudLayer {
            hudLayer.addChild(container)
        } else {
            addChild(container)
        }

        // Animate: fade in, float up slightly, then fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.1)
        let moveUp = SKAction.moveBy(x: 0, y: 20, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let floatAndFade = SKAction.group([moveUp, SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            fadeOut
        ])])
        
        container.run(SKAction.sequence([
            fadeIn,
            floatAndFade,
            SKAction.removeFromParent()
        ]))
    }
}
