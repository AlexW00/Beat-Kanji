//
//  ParticleFactory.swift
//  Beat Kanji
//
//  Factory for creating particle effects used across the game.
//

import SpriteKit

/// Factory for creating reusable particle effects.
enum ParticleFactory {
    
    // MARK: - Button Sparkle Particles
    
    /// Adds sparkle particle effects around a button.
    /// - Parameters:
    ///   - container: The container node to add particles to
    ///   - buttonSize: The size of the button for positioning particles
    static func addButtonSparkles(to container: SKNode, buttonSize: CGSize) {
        // 1. Star sparkles scattered around button area (star_04)
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        starEmitter.particleBirthRate = 4
        starEmitter.particleLifetime = 3.0
        starEmitter.particleLifetimeRange = 1.5
        starEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 1.4, dy: buttonSize.height * 2.0)
        starEmitter.particleSpeed = 3
        starEmitter.particleSpeedRange = 2
        starEmitter.emissionAngle = .pi / 2
        starEmitter.emissionAngleRange = .pi
        starEmitter.particleAlpha = 0.6
        starEmitter.particleAlphaRange = 0.3
        starEmitter.particleAlphaSpeed = -0.15
        starEmitter.particleScale = 0.04
        starEmitter.particleScaleRange = 0.02
        starEmitter.particleColor = SKColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
        starEmitter.particleColorBlendFactor = 0.6
        starEmitter.particleBlendMode = .add
        starEmitter.position = .zero
        starEmitter.zPosition = -2
        container.addChild(starEmitter)
        
        // 2. Soft ambient flare glow
        let flareEmitter = SKEmitterNode()
        flareEmitter.particleTexture = SKTexture(imageNamed: "flare_01")
        flareEmitter.particleBirthRate = 1.5
        flareEmitter.particleLifetime = 4.0
        flareEmitter.particleLifetimeRange = 2.0
        flareEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 1.2, dy: buttonSize.height * 1.5)
        flareEmitter.particleSpeed = 1
        flareEmitter.particleSpeedRange = 1
        flareEmitter.emissionAngleRange = .pi * 2
        flareEmitter.particleAlpha = 0.25
        flareEmitter.particleAlphaRange = 0.15
        flareEmitter.particleAlphaSpeed = -0.05
        flareEmitter.particleScale = 0.12
        flareEmitter.particleScaleRange = 0.06
        flareEmitter.particleColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        flareEmitter.particleColorBlendFactor = 0.7
        flareEmitter.particleBlendMode = .add
        flareEmitter.position = .zero
        flareEmitter.zPosition = -3
        container.addChild(flareEmitter)
        
        // 3. Occasional bright star twinkle (star_04)
        let twinkleEmitter = SKEmitterNode()
        twinkleEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        twinkleEmitter.particleBirthRate = 1.0
        twinkleEmitter.particleLifetime = 1.5
        twinkleEmitter.particleLifetimeRange = 0.5
        twinkleEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 1.6, dy: buttonSize.height * 2.5)
        twinkleEmitter.particleSpeed = 0
        twinkleEmitter.particleAlpha = 0.9
        twinkleEmitter.particleAlphaSpeed = -0.6
        twinkleEmitter.particleScale = 0.06
        twinkleEmitter.particleScaleRange = 0.03
        twinkleEmitter.particleColor = .white
        twinkleEmitter.particleColorBlendFactor = 0.3
        twinkleEmitter.particleBlendMode = .add
        twinkleEmitter.position = .zero
        twinkleEmitter.zPosition = -1
        container.addChild(twinkleEmitter)
        
        // 4. Star_08 compass-style stars scattered around
        let star08Emitter = SKEmitterNode()
        star08Emitter.particleTexture = SKTexture(imageNamed: "star_08")
        star08Emitter.particleBirthRate = 0.8
        star08Emitter.particleLifetime = 2.5
        star08Emitter.particleLifetimeRange = 1.0
        star08Emitter.particlePositionRange = CGVector(dx: buttonSize.width * 1.5, dy: buttonSize.height * 2.2)
        star08Emitter.particleSpeed = 2
        star08Emitter.particleSpeedRange = 1
        star08Emitter.emissionAngleRange = .pi * 2
        star08Emitter.particleAlpha = 0.5
        star08Emitter.particleAlphaRange = 0.2
        star08Emitter.particleAlphaSpeed = -0.18
        star08Emitter.particleScale = 0.05
        star08Emitter.particleScaleRange = 0.025
        star08Emitter.particleRotation = 0
        star08Emitter.particleRotationSpeed = 0.3
        star08Emitter.particleRotationRange = .pi
        star08Emitter.particleColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        star08Emitter.particleColorBlendFactor = 0.5
        star08Emitter.particleBlendMode = .add
        star08Emitter.position = .zero
        star08Emitter.zPosition = -1
        container.addChild(star08Emitter)
    }
    
    // MARK: - Logo Particles
    
    /// Adds sparkle particle effects around a logo.
    /// - Parameters:
    ///   - container: The container node to add particles to (should be at logo position)
    ///   - logoSize: The size of the logo for positioning particles
    static func addLogoSparkles(to container: SKNode, logoSize: CGSize) {
        // 1. Scattered star sparkles around the logo (star_04)
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        starEmitter.particleBirthRate = 2.0
        starEmitter.particleLifetime = 3.0
        starEmitter.particleLifetimeRange = 1.5
        starEmitter.particlePositionRange = CGVector(dx: logoSize.width * 1.2, dy: logoSize.height * 1.4)
        starEmitter.particleSpeed = 2
        starEmitter.particleSpeedRange = 1
        starEmitter.emissionAngleRange = .pi * 2
        starEmitter.particleAlpha = 0.6
        starEmitter.particleAlphaRange = 0.2
        starEmitter.particleAlphaSpeed = -0.15
        starEmitter.particleScale = 0.06
        starEmitter.particleScaleRange = 0.03
        starEmitter.particleColor = SKColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
        starEmitter.particleColorBlendFactor = 0.6
        starEmitter.particleBlendMode = .add
        starEmitter.position = .zero
        starEmitter.zPosition = 1
        container.addChild(starEmitter)
        
        // 2. Occasional bright twinkle stars (bigger, less frequent)
        let twinkleEmitter = SKEmitterNode()
        twinkleEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        twinkleEmitter.particleBirthRate = 0.6
        twinkleEmitter.particleLifetime = 1.8
        twinkleEmitter.particleLifetimeRange = 0.5
        twinkleEmitter.particlePositionRange = CGVector(dx: logoSize.width * 1.3, dy: logoSize.height * 1.5)
        twinkleEmitter.particleSpeed = 0
        twinkleEmitter.particleAlpha = 0.85
        twinkleEmitter.particleAlphaSpeed = -0.4
        twinkleEmitter.particleScale = 0.1
        twinkleEmitter.particleScaleRange = 0.04
        twinkleEmitter.particleColor = .white
        twinkleEmitter.particleColorBlendFactor = 0.2
        twinkleEmitter.particleBlendMode = .add
        twinkleEmitter.position = .zero
        twinkleEmitter.zPosition = 2
        container.addChild(twinkleEmitter)
        
        // 3. Compass-style rotating stars (star_08)
        let star08Emitter = SKEmitterNode()
        star08Emitter.particleTexture = SKTexture(imageNamed: "star_08")
        star08Emitter.particleBirthRate = 0.4
        star08Emitter.particleLifetime = 3.0
        star08Emitter.particleLifetimeRange = 1.0
        star08Emitter.particlePositionRange = CGVector(dx: logoSize.width * 1.1, dy: logoSize.height * 1.2)
        star08Emitter.particleSpeed = 1
        star08Emitter.particleSpeedRange = 0.5
        star08Emitter.emissionAngleRange = .pi * 2
        star08Emitter.particleAlpha = 0.6
        star08Emitter.particleAlphaRange = 0.2
        star08Emitter.particleAlphaSpeed = -0.18
        star08Emitter.particleScale = 0.09
        star08Emitter.particleScaleRange = 0.04
        star08Emitter.particleRotation = 0
        star08Emitter.particleRotationSpeed = 0.25
        star08Emitter.particleRotationRange = .pi
        star08Emitter.particleColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        star08Emitter.particleColorBlendFactor = 0.5
        star08Emitter.particleBlendMode = .add
        star08Emitter.position = .zero
        star08Emitter.zPosition = 1
        container.addChild(star08Emitter)
    }
    
    // MARK: - Smaller Button Particles (for Game Over buttons)
    
    /// Adds smaller sparkle effects for game over style buttons.
    /// - Parameters:
    ///   - container: The button container node
    ///   - buttonSize: The size of the button
    static func addSmallButtonSparkles(to container: SKNode, buttonSize: CGSize) {
        // 1. Star sparkles
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        starEmitter.particleBirthRate = 4
        starEmitter.particleLifetime = 3.0
        starEmitter.particleLifetimeRange = 1.5
        starEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 0.9, dy: buttonSize.height * 1.0)
        starEmitter.particleSpeed = 3
        starEmitter.particleSpeedRange = 2
        starEmitter.emissionAngle = .pi / 2
        starEmitter.emissionAngleRange = .pi
        starEmitter.particleAlpha = 0.6
        starEmitter.particleAlphaRange = 0.3
        starEmitter.particleAlphaSpeed = -0.15
        starEmitter.particleScale = 0.04
        starEmitter.particleScaleRange = 0.02
        starEmitter.particleColor = SKColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
        starEmitter.particleColorBlendFactor = 0.6
        starEmitter.particleBlendMode = .add
        starEmitter.position = .zero
        starEmitter.zPosition = 5
        container.addChild(starEmitter)
        
        // 2. Flare glow
        let flareEmitter = SKEmitterNode()
        flareEmitter.particleTexture = SKTexture(imageNamed: "flare_01")
        flareEmitter.particleBirthRate = 1.5
        flareEmitter.particleLifetime = 4.0
        flareEmitter.particleLifetimeRange = 2.0
        flareEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 0.8, dy: buttonSize.height * 0.9)
        flareEmitter.particleSpeed = 1
        flareEmitter.particleSpeedRange = 1
        flareEmitter.emissionAngleRange = .pi * 2
        flareEmitter.particleAlpha = 0.25
        flareEmitter.particleAlphaRange = 0.15
        flareEmitter.particleAlphaSpeed = -0.05
        flareEmitter.particleScale = 0.12
        flareEmitter.particleScaleRange = 0.06
        flareEmitter.particleColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)
        flareEmitter.particleColorBlendFactor = 0.7
        flareEmitter.particleBlendMode = .add
        flareEmitter.position = .zero
        flareEmitter.zPosition = 4
        container.addChild(flareEmitter)
        
        // 3. Twinkle
        let twinkleEmitter = SKEmitterNode()
        twinkleEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        twinkleEmitter.particleBirthRate = 1.0
        twinkleEmitter.particleLifetime = 1.5
        twinkleEmitter.particleLifetimeRange = 0.5
        twinkleEmitter.particlePositionRange = CGVector(dx: buttonSize.width * 1.0, dy: buttonSize.height * 1.2)
        twinkleEmitter.particleSpeed = 0
        twinkleEmitter.particleAlpha = 0.9
        twinkleEmitter.particleAlphaSpeed = -0.6
        twinkleEmitter.particleScale = 0.06
        twinkleEmitter.particleScaleRange = 0.03
        twinkleEmitter.particleColor = .white
        twinkleEmitter.particleColorBlendFactor = 0.3
        twinkleEmitter.particleBlendMode = .add
        twinkleEmitter.position = .zero
        twinkleEmitter.zPosition = 6
        container.addChild(twinkleEmitter)
        
        // 4. Star_08
        let star08Emitter = SKEmitterNode()
        star08Emitter.particleTexture = SKTexture(imageNamed: "star_08")
        star08Emitter.particleBirthRate = 0.8
        star08Emitter.particleLifetime = 2.5
        star08Emitter.particleLifetimeRange = 1.0
        star08Emitter.particlePositionRange = CGVector(dx: buttonSize.width * 0.95, dy: buttonSize.height * 1.1)
        star08Emitter.particleSpeed = 2
        star08Emitter.particleSpeedRange = 1
        star08Emitter.emissionAngleRange = .pi * 2
        star08Emitter.particleAlpha = 0.5
        star08Emitter.particleAlphaRange = 0.2
        star08Emitter.particleAlphaSpeed = -0.18
        star08Emitter.particleScale = 0.05
        star08Emitter.particleScaleRange = 0.025
        star08Emitter.particleRotation = 0
        star08Emitter.particleRotationSpeed = 0.3
        star08Emitter.particleRotationRange = .pi
        star08Emitter.particleColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        star08Emitter.particleColorBlendFactor = 0.5
        star08Emitter.particleBlendMode = .add
        star08Emitter.position = .zero
        star08Emitter.zPosition = 5
        container.addChild(star08Emitter)
    }
    
    // MARK: - S Tier Icon Particles
    
    /// Adds sparkle particle effects around the S tier icon.
    /// - Parameters:
    ///   - container: The container node to add particles to
    ///   - iconSize: The size of the tier icon for positioning particles
    static func addSTierSparkles(to container: SKNode, iconSize: CGSize) {
        // 1. Golden star_04 sparkles around/below the icon (not on top)
        let starEmitter = SKEmitterNode()
        starEmitter.particleTexture = SKTexture(imageNamed: "star_04")
        starEmitter.particleBirthRate = 4
        starEmitter.particleLifetime = 2.0
        starEmitter.particleLifetimeRange = 0.5
        // Spawn in a ring around the icon (not in center)
        starEmitter.particlePositionRange = CGVector(dx: iconSize.width * 0.8, dy: iconSize.height * 0.8)
        starEmitter.particleSpeed = 8
        starEmitter.particleSpeedRange = 4
        // Emit downward and to the sides (avoid going up over icon)
        starEmitter.emissionAngle = -.pi / 2  // Downward
        starEmitter.emissionAngleRange = .pi * 0.8  // Wide spread but mostly down/sides
        starEmitter.particleAlpha = 0.9
        starEmitter.particleAlphaRange = 0.1
        starEmitter.particleAlphaSpeed = -0.35
        starEmitter.particleScale = 0.07
        starEmitter.particleScaleRange = 0.03
        starEmitter.particleColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        starEmitter.particleColorBlendFactor = 0.7
        starEmitter.particleBlendMode = .add
        starEmitter.position = .zero
        starEmitter.zPosition = -1
        container.addChild(starEmitter)
        
        // 2. Centered flare that pulses ON the icon occasionally
        // Scale flare based on icon size (bigger icon = bigger flare)
        let flareBaseScale: CGFloat = iconSize.width > 50 ? 0.5 : 0.25  // Twice as big for large icons
        let centerFlareEmitter = SKEmitterNode()
        centerFlareEmitter.particleTexture = SKTexture(imageNamed: "flare_01")
        centerFlareEmitter.particleBirthRate = 0.25  // Spawn every ~4 seconds on average
        centerFlareEmitter.particleLifetime = 1.2
        centerFlareEmitter.particleLifetimeRange = 0.6  // Random lifetime for variation
        centerFlareEmitter.particlePositionRange = CGVector(dx: 0, dy: 0)  // Exactly at center
        centerFlareEmitter.particleSpeed = 0
        centerFlareEmitter.particleAlpha = 0.8
        centerFlareEmitter.particleAlphaRange = 0.2  // Random alpha for variation
        centerFlareEmitter.particleAlphaSpeed = -0.6
        centerFlareEmitter.particleScale = flareBaseScale
        centerFlareEmitter.particleScaleRange = flareBaseScale * 0.3  // Proportional variation
        centerFlareEmitter.particleScaleSpeed = -0.05
        centerFlareEmitter.particleColor = SKColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1.0)
        centerFlareEmitter.particleColorBlendFactor = 0.5
        centerFlareEmitter.particleBlendMode = .add
        centerFlareEmitter.position = .zero
        centerFlareEmitter.zPosition = 2
        container.addChild(centerFlareEmitter)
    }
}
