//
//  PlayScene+Kanji.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

extension PlayScene {
    
    /// Build a CGPath for a stroke, optionally deduping near-identical consecutive points in screen space.
    /// Uses Catmull-Rom spline smoothing to eliminate sharp corners that cause rendering artifacts.
    /// Returns both the path and the minimum screen-space segment length (after dedupe).
    private func makeStrokePath(
        from points: [CGPoint],
        scale: CGFloat,
        dedupeEpsilon: CGFloat
    ) -> (CGPath, CGFloat) {
        guard let first = points.first else { return (CGMutablePath(), .infinity) }
        
        // Convert to screen space (same transform used in rendering)
        func screenPoint(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: p.x * scale,
                y: (1.0 - p.y) * scale
            )
        }
        
        let firstScreen = screenPoint(first)
        var dedupedPoints: [CGPoint] = [firstScreen]
        var lastAdded = firstScreen
        var minSeg: CGFloat = .infinity
        
        for i in 1..<points.count {
            let p = screenPoint(points[i])
            let dist = hypot(p.x - lastAdded.x, p.y - lastAdded.y)
            
            // Deduping very short segments can avoid SpriteKit line-join artifacts.
            if dist < dedupeEpsilon && i < points.count - 1 {
                // Skip adding this point but still track min segment based on raw spacing
                minSeg = min(minSeg, dist)
                continue
            }
            
            dedupedPoints.append(p)
            minSeg = min(minSeg, dist)
            lastAdded = p
        }
        
        // Use Catmull-Rom spline smoothing to eliminate sharp corners
        let smoothPath = NeonStrokeFactory.smoothPath(from: dedupedPoints, tension: 0.5)
        return (smoothPath, minSeg)
    }
    
    /// Create a stroked CGPath (filled outline) to avoid SpriteKit stroke artifacts.
    func strokedPath(from path: CGPath, width: CGFloat) -> CGPath {
        path.copy(
            strokingWithWidth: width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4,
            transform: .identity
        )
    }
    
    /// Build a filled shape node from a stroked outline (avoids stroke seam artifacts).
    private func makeFilledStrokeNode(path: CGPath, width: CGFloat, color: SKColor, alpha: CGFloat, blend: SKBlendMode = .alpha, z: CGFloat = 0) -> SKShapeNode {
        let stroked = strokedPath(from: path, width: width)
        let node = SKShapeNode(path: stroked)
        node.fillColor = color.withAlphaComponent(alpha)
        node.strokeColor = .clear
        node.lineWidth = 0
        node.blendMode = blend
        node.zPosition = z
        node.isAntialiased = true
        return node
    }
    
    // Dedupe threshold applied in all builds to avoid SpriteKit line-join gaps on ultra-short segments.
    private var strokeDedupeEpsilonPx: CGFloat { 0.7 }
    
    #if DEBUG
    private var debugLogShortSeg: Bool { true }
    #else
    private var debugLogShortSeg: Bool { false }
    #endif
    
    /// Duration for the floating meaning animation (seconds)
    static let meaningToastDuration: TimeInterval = 1.8
    
    /// Shows a non-blocking toast below the HUD with "kanji: meaning" format
    /// Uses button.png as background, scaled to fit text width
    /// - Parameters:
    ///   - kanji: The kanji character to display
    ///   - meaning: The meaning/keyword to display
    func showMeaningToast(kanji: String, meaning: String) {
        guard !meaning.isEmpty else { return }
        
        // Remove any existing meaning node regardless of parent
        childNode(withName: "meaningToast")?.removeFromParent()
        hudLayer?.childNode(withName: "meaningToast")?.removeFromParent()
        
        // Determine a start position just above the completed kanji
        let defaultPosition = CGPoint(x: size.width / 2, y: size.height * 0.7)
        let toastStart: CGPoint = {
            guard
                let node = currentKanjiNode,
                let scale = node.userData?["scale"] as? CGFloat,
                let offsetX = node.userData?["offsetX"] as? CGFloat,
                let offsetY = node.userData?["offsetY"] as? CGFloat
            else { return defaultPosition }
            let centerX = offsetX + scale / 2
            let topY = offsetY + scale
            let startY = min(size.height - 80, topY + 24)
            return CGPoint(x: centerX, y: startY)
        }()
        
        // Container so we can animate position/alpha together
        let toastContainer = SKNode()
        toastContainer.name = "meaningToast"
        toastContainer.zPosition = 350
        toastContainer.position = toastStart
        toastContainer.alpha = 0.0
        
        // Shadow for contrast
        let shadowLabel = SKLabelNode(fontNamed: FontConfig.bold)
        shadowLabel.text = "\(kanji)  \(meaning)"
        shadowLabel.fontSize = 26
        shadowLabel.fontColor = SKColor.black.withAlphaComponent(0.45)
        shadowLabel.horizontalAlignmentMode = .center
        shadowLabel.verticalAlignmentMode = .center
        shadowLabel.position = CGPoint(x: 2, y: -2)
        shadowLabel.zPosition = 0
        
        // Main label
        let toastLabel = SKLabelNode(fontNamed: FontConfig.bold)
        toastLabel.text = "\(kanji)  \(meaning)"
        toastLabel.fontSize = 26
        toastLabel.fontColor = SKColor(white: 1.0, alpha: 0.98)
        toastLabel.horizontalAlignmentMode = .center
        toastLabel.verticalAlignmentMode = .center
        toastLabel.zPosition = 1
        
        // Use a layout label at the previous size to keep button dimensions consistent
        let layoutFontSize: CGFloat = 28
        let layoutLabel = SKLabelNode(fontNamed: FontConfig.bold)
        layoutLabel.text = toastLabel.text
        layoutLabel.fontSize = layoutFontSize

        // Scale down if text would overflow the screen
        let maxWidth = size.width * 0.8
        let layoutWidth = layoutLabel.frame.width
        let layoutHeight = layoutLabel.frame.height
        let initialScale = layoutWidth > maxWidth ? maxWidth / layoutWidth : 1.0

        // Background sized to text width/height with padding
        let background = SKSpriteNode(imageNamed: "button")
        let horizontalPadding: CGFloat = 44
        let verticalPadding: CGFloat = 22
        let bgScaleX = (layoutWidth + horizontalPadding) / background.size.width
        let bgScaleY = (layoutHeight + verticalPadding) / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.zPosition = -1

        toastContainer.setScale(initialScale)
        
        toastContainer.addChild(background)
        toastContainer.addChild(shadowLabel)
        toastContainer.addChild(toastLabel)
        addChild(toastContainer)
        
        // Pop in, then float upward while fading out
        let popIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.12),
            SKAction.scale(to: initialScale * 1.05, duration: 0.12)
        ])
        let settle = SKAction.scale(to: initialScale, duration: 0.08)
        let availableHeadroom = size.height - toastStart.y - 20
        let floatDistance = max(20, min(60, availableHeadroom))
        let moveUp = SKAction.moveBy(x: 0, y: floatDistance, duration: Self.meaningToastDuration)
        moveUp.timingMode = .easeIn // start slower, speed up near the end
        let fadeDuration = Self.meaningToastDuration * 0.75
        let fadeOut = SKAction.fadeOut(withDuration: fadeDuration)
        fadeOut.timingMode = .easeIn
        let floatUp = SKAction.group([moveUp, fadeOut])
        toastContainer.run(SKAction.sequence([
            popIn,
            settle,
            floatUp,
            SKAction.removeFromParent()
        ]))
    }
    
    /// Creates a dissolve particle effect for any node (keyword or kanji)
    /// - Parameters:
    ///   - node: The node to create the dissolve effect for
    ///   - color: The color of the particles
    ///   - particleCount: Number of particles to emit
    func createDissolveEffect(for node: SKNode, color: SKColor, particleCount: Int) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = nil // Square particles
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = 1500
        emitter.numParticlesToEmit = particleCount
        emitter.particleLifetime = 0.25
        emitter.particleLifetimeRange = 0.08
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -4.5
        emitter.particleScale = 3.5
        emitter.particleScaleRange = 1.5
        emitter.particleScaleSpeed = -6.0
        
        // Calculate position and spread based on node type
        if node == currentKanjiNode,
           let scale = node.userData?["scale"] as? CGFloat,
           let offsetX = node.userData?["offsetX"] as? CGFloat,
           let offsetY = node.userData?["offsetY"] as? CGFloat {
            // Kanji node - position at center with larger spread
            let center = CGPoint(x: offsetX + scale/2, y: offsetY + scale/2)
            emitter.position = center
            emitter.particlePositionRange = CGVector(dx: scale * 0.6, dy: scale * 0.6)
        } else {
            // Keyword label or other node - use node position with width-based spread
            emitter.position = node.position
            emitter.particlePositionRange = CGVector(dx: max(node.frame.width * 0.8, 50), dy: 20)
        }
        
        emitter.zPosition = 150
        addChild(emitter)
        
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.removeFromParent()
        ]))
    }
    
    func showNextKanji() {
        // Reset stroke results
        strokeResults.removeAll()
        strokeEarnedPoints.removeAll()
        nextSpawnIndex = 0
        
        // Clean up current flying strokes (only for current kanji, keep look-ahead ones)
        for i in (0..<flyingStrokes.count).reversed() {
            if !flyingStrokes[i].isNextKanji {
                flyingStrokes[i].bgNode.removeFromParent()
                flyingStrokes[i].fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
            }
        }
        
        // Transfer look-ahead strokes from nextKanjiNode to currentKanjiNode
        // (They will be re-parented when we create the new currentKanjiNode)
        
        // Clean up next kanji preview if it exists
        cleanupNextKanjiPreview()
        
        // If kanji node still exists (wasn't dissolved by keyword overlay), clean it up
        if let oldNode = currentKanjiNode {
            // Dissolve effect only if we're not coming from keyword overlay
            // (keyword overlay already dissolved the kanji)
            createDissolveEffect(for: oldNode, color: .cyan, particleCount: 100)
            oldNode.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.25),
                SKAction.removeFromParent()
            ]))
            currentKanjiNode = nil
        }
        
        guard let kanji = gameEngine.currentKanji else { return }
        KanjiUserStore.shared.markSeen(kanjiId: kanji.id)
        
        let node = SKNode()
        node.alpha = 0.0
        
        // Calculate scale and offset to center the kanji
        // On iPad with Apple Pencil mode, use a smaller kanji for easier drawing
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let useApplePencilMode = isIPad && SettingsStore.shared.iPadInputMode == .applePencil
        let scaleFactor: CGFloat = useApplePencilMode ? 0.45 : 0.8
        let scale = min(size.width, size.height) * scaleFactor
        let offsetX = (size.width - scale) / 2
        // Move to bottom (e.g., 10% from bottom for normal, slightly higher for Apple Pencil mode)
        let bottomOffset: CGFloat = useApplePencilMode ? 0.25 : 0.15
        let offsetY = size.height * bottomOffset
        node.userData = ["scale": scale, "offsetX": offsetX, "offsetY": offsetY]
        node.position = CGPoint(x: offsetX, y: offsetY)
        
        // Create nodes for all strokes
        for (index, stroke) in kanji.strokes.enumerated() {
            let points = stroke.cgPoints
            guard !points.isEmpty else { continue }
            
            let (path, minSeg) = makeStrokePath(
                from: points,
                scale: scale,
                dedupeEpsilon: strokeDedupeEpsilonPx
            )
            
            if debugLogShortSeg {
                print("[StrokePath] kanji=\(kanji.char) stroke=\(index) minSegPx=\(String(format: "%.4f", minSeg))")
            }
            
            // Background Node (Template - Gray) filled outline to avoid seams
            // Always use white/gray for background - no debug coloring here
            let bgShape = makeFilledStrokeNode(path: path, width: 10, color: SKColor(white: 1.0, alpha: 0.35), alpha: 1.0, blend: .alpha, z: 0)
            bgShape.name = "stroke_bg_\(index)"
            node.addChild(bgShape)
            
            // Fill Node (Animation/Completion) - Use NeonStrokeFactory for seamless neon glow
            // Muted neon effect: dark teal glow that blends with background
            let neonStroke = NeonStrokeFactory.createNeonStroke(
                path: path,
                glowColor: SKColor(red: 0.1, green: 0.35, blue: 0.45, alpha: 1.0), // very muted teal
                coreColor: SKColor(white: 0.85, alpha: 1.0), // softer white
                glowWidth: 16.0,
                coreWidth: 5.0,
                glowAlpha: 0.6,
                coreAlpha: 0.95,
                blendMode: .alpha // use alpha instead of add for less brightness
            )
            neonStroke.name = "stroke_fill_\(index)"
            neonStroke.alpha = 0.0 // Start invisible
            neonStroke.userData = NSMutableDictionary()
            neonStroke.userData?["fullPath"] = path
            node.addChild(neonStroke)
        }
        
        addChild(node)
        currentKanjiNode = node
        
        updateKanjiVisuals()
        node.run(SKAction.fadeIn(withDuration: 0.5))
    }
    
    /// Rebuilds the current kanji node with new sizing (e.g., after mode switch)
    /// Does NOT reset game state - preserves strokeResults, strokeEarnedPoints, and flying strokes
    func rebuildCurrentKanjiNode() {
        guard let kanji = gameEngine.currentKanji else { return }
        
        // Remove old kanji node (no dissolve effect - instant replacement)
        currentKanjiNode?.removeFromParent()
        currentKanjiNode = nil
        
        // Clean up next kanji preview if it exists
        cleanupNextKanjiPreview()
        
        let node = SKNode()
        node.alpha = 0.0
        
        // Calculate scale and offset to center the kanji
        // On iPad with Apple Pencil mode, use a smaller kanji for easier drawing
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let useApplePencilMode = isIPad && SettingsStore.shared.iPadInputMode == .applePencil
        let scaleFactor: CGFloat = useApplePencilMode ? 0.45 : 0.8
        let scale = min(size.width, size.height) * scaleFactor
        let offsetX = (size.width - scale) / 2
        // Move to bottom (e.g., 10% from bottom for normal, slightly higher for Apple Pencil mode)
        let bottomOffset: CGFloat = useApplePencilMode ? 0.25 : 0.15
        let offsetY = size.height * bottomOffset
        node.userData = ["scale": scale, "offsetX": offsetX, "offsetY": offsetY]
        node.position = CGPoint(x: offsetX, y: offsetY)
        
        // Create nodes for all strokes
        for (index, stroke) in kanji.strokes.enumerated() {
            let points = stroke.cgPoints
            guard !points.isEmpty else { continue }
            
            let (path, minSeg) = makeStrokePath(
                from: points,
                scale: scale,
                dedupeEpsilon: strokeDedupeEpsilonPx
            )
            
            if debugLogShortSeg {
                print("[StrokePath] (rebuild) kanji=\(kanji.char) stroke=\(index) minSegPx=\(String(format: "%.4f", minSeg))")
            }
            
            // Background Node (Template - Gray) simple stroke
            // Always use white/gray for background - no debug coloring here
            let bgShape = SKShapeNode(path: path)
            bgShape.name = "stroke_bg_\(index)"
            bgShape.strokeColor = SKColor(white: 1.0, alpha: 0.35)
            bgShape.alpha = 1.0
            bgShape.lineWidth = 8
            bgShape.lineCap = .round
            bgShape.lineJoin = .round
            bgShape.glowWidth = 0.0
            node.addChild(bgShape)
            
            // Fill Node - Use NeonStrokeFactory for seamless neon glow
            // Muted neon effect: dark teal glow that blends with background
            let neonStroke = NeonStrokeFactory.createNeonStroke(
                path: path,
                glowColor: SKColor(red: 0.1, green: 0.35, blue: 0.45, alpha: 1.0), // very muted teal
                coreColor: SKColor(white: 0.85, alpha: 1.0), // softer white
                glowWidth: 14.0,
                coreWidth: 4.0,
                glowAlpha: 0.6,
                coreAlpha: 0.95,
                blendMode: .alpha // use alpha instead of add for less brightness
            )
            neonStroke.name = "stroke_fill_\(index)"
            neonStroke.alpha = 0.0 // Start invisible
            neonStroke.userData = NSMutableDictionary()
            neonStroke.userData?["fullPath"] = path
            node.addChild(neonStroke)
        }
        
        addChild(node)
        currentKanjiNode = node
        
        // Update visuals (this will apply correct colors based on preserved strokeResults)
        updateKanjiVisuals()
        node.run(SKAction.fadeIn(withDuration: 0.2)) // Faster fade for mode switch
        
        // Also rebuild any existing flying strokes to use new scale
        rebuildFlyingStrokesForModeChange(newScale: scale, newOffsetX: offsetX, newOffsetY: offsetY)
    }
    
    func updateKanjiVisuals() {
        guard let node = currentKanjiNode, let kanji = gameEngine.currentKanji else { return }
        
        // Check if stroke window is active for visual feedback
        let windowState = gameEngine.isStrokeWindowActive()
        let isWindowActive = windowState.isActive
        let windowProgress = windowState.progress
        
        for i in 0..<kanji.strokes.count {
            guard let bgNode = node.childNode(withName: "stroke_bg_\(i)") as? SKShapeNode else { continue }
            guard let fillContainer = node.childNode(withName: "stroke_fill_\(i)") else { continue }
            
            // Helper to update glow colors in the neon stroke structure
            // Structure: fillContainer -> outerGlow + glow + core (all SKShapeNodes with fillColor)
            func updateNeonColors(_ color: SKColor) {
                // Update outer glow layer
                if let outerGlow = fillContainer.childNode(withName: "outerGlow") as? SKShapeNode {
                    outerGlow.fillColor = color.withAlphaComponent(0.4)
                }
                // Update inner glow layer
                if let glow = fillContainer.childNode(withName: "glow") as? SKShapeNode {
                    glow.fillColor = color.withAlphaComponent(0.7)
                }
                // Keep core white for crisp center (matches flying strokes)
                if let coreShape = fillContainer.childNode(withName: "core") as? SKShapeNode {
                    coreShape.fillColor = .white
                }
            }
            
            if i < gameEngine.currentStrokeIndex {
                // Completed stroke - show with result color
                if let result = strokeResults[i] {
                    switch result {
                    case .perfect: updateNeonColors(.green)
                    case .acceptable: updateNeonColors(.yellow)
                    case .miss: updateNeonColors(.red)
                    }
                } else {
                    updateNeonColors(.white) // Fallback
                }
                fillContainer.alpha = 1.0
                // Dim background - use fillColor for filled outlines, strokeColor for stroked paths
                bgNode.fillColor = SKColor(white: 1.0, alpha: 0.15)
                bgNode.strokeColor = SKColor(white: 1.0, alpha: 0.15)
            } else if i == gameEngine.currentStrokeIndex {
                // Current stroke - highlight if window is active
                fillContainer.alpha = 0.0 // Not drawn yet
                
                if isWindowActive {
                    // Window is active! Highlight the stroke to indicate player can draw
                    // Pulse effect based on progress (brighter near arrival time)
                    let pulseIntensity: CGFloat
                    if windowProgress < 1.0 {
                        // Before arrival - building up
                        pulseIntensity = 0.5 + CGFloat(windowProgress) * 0.5
                    } else {
                        // After arrival - fading urgency
                        let fadeProgress = (windowProgress - 1.0) // 0.0 to 1.0
                        pulseIntensity = max(0.3, 1.0 - CGFloat(fadeProgress) * 0.7)
                    }
                    
                    // Make the background stroke bright blue to indicate it's drawable
                    let highlightColor = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: min(1.0, pulseIntensity + 0.3))
                    bgNode.fillColor = highlightColor
                    bgNode.strokeColor = highlightColor
                } else {
                    // Window not active yet - show as waiting (dim)
                    bgNode.fillColor = SKColor(white: 1.0, alpha: 0.35)
                    bgNode.strokeColor = SKColor(white: 1.0, alpha: 0.35)
                }
            } else {
                // Future stroke - not completed yet
                fillContainer.alpha = 0.0
                bgNode.fillColor = SKColor(white: 1.0, alpha: 0.25)
                bgNode.strokeColor = SKColor(white: 1.0, alpha: 0.25)
            }
        }
        
        // Also remove any flying strokes that correspond to completed strokes
        // (In case user finished early) - only for current kanji
        for i in (0..<flyingStrokes.count).reversed() {
            let flying = flyingStrokes[i]
            // Only remove if it's for the current kanji and the stroke is completed
            if !flying.isNextKanji && flying.kanjiIndex == gameEngine.currentKanjiIndexInSequence && flying.index < gameEngine.currentStrokeIndex {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
            }
        }
    }
    

}
