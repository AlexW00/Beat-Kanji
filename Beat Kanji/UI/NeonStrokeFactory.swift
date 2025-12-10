//
//  NeonStrokeFactory.swift
//  Beat Kanji
//
//  Factory for creating seamless neon stroke effects.
//  Uses filled outlines to avoid SpriteKit stroke join artifacts.
//

import SpriteKit

/// Factory for creating neon stroke effects without SpriteKit join artifacts.
/// Key technique: Convert stroke paths to filled outlines.
enum NeonStrokeFactory {
    
    // MARK: - Main API
    
    /// Creates a complete neon stroke node with glow and core layers.
    /// Returns a container SKNode with proper z-ordering.
    ///
    /// - Parameters:
    ///   - path: The CGPath for the stroke
    ///   - glowColor: Color for the outer glow
    ///   - coreColor: Color for the solid center (typically white)
    ///   - glowWidth: Width of the outermost glow stroke
    ///   - coreWidth: Width of the core stroke
    ///   - glowAlpha: Alpha for the glow layers
    ///   - coreAlpha: Alpha for the core layer
    ///   - blendMode: Blend mode for the glow (default: .add for neon effect)
    /// - Returns: SKNode containing the complete neon stroke
    static func createNeonStroke(
        path: CGPath,
        glowColor: SKColor,
        coreColor: SKColor = .white,
        glowWidth: CGFloat = 14.0,
        coreWidth: CGFloat = 4.0,
        glowAlpha: CGFloat = 0.7,
        coreAlpha: CGFloat = 1.0,
        blendMode: SKBlendMode = .add
    ) -> SKNode {
        let container = SKNode()
        
        // Use layered filled outlines for vibrant neon effect (matches flying strokes)
        // Layer 1: Outer glow (widest, most transparent)
        let outerGlow = createFilledStrokeNode(
            path: path,
            color: glowColor,
            width: glowWidth,
            alpha: glowAlpha * 0.5,
            blendMode: blendMode
        )
        outerGlow.name = "outerGlow"
        outerGlow.zPosition = 0
        container.addChild(outerGlow)
        
        // Layer 2: Inner glow (medium width, brighter)
        let innerGlow = createFilledStrokeNode(
            path: path,
            color: glowColor,
            width: glowWidth * 0.7,
            alpha: glowAlpha * 0.8,
            blendMode: blendMode
        )
        innerGlow.name = "glow"
        innerGlow.zPosition = 1
        container.addChild(innerGlow)
        
        // Layer 3: Core (narrowest, solid)
        let coreNode = createFilledStrokeNode(
            path: path,
            color: coreColor,
            width: coreWidth,
            alpha: coreAlpha
        )
        coreNode.name = "core"
        coreNode.zPosition = 2
        container.addChild(coreNode)
        
        return container
    }
    
    /// Creates a simple filled stroke node from a path (no blur).
    /// Uses CGPath.copy(strokingWithWidth:...) to convert stroke to filled outline.
    static func createFilledStrokeNode(
        path: CGPath,
        color: SKColor,
        width: CGFloat,
        alpha: CGFloat = 1.0,
        blendMode: SKBlendMode = .alpha
    ) -> SKShapeNode {
        let filledPath = path.copy(
            strokingWithWidth: width,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 4,
            transform: .identity
        )
        
        let node = SKShapeNode(path: filledPath)
        node.fillColor = color.withAlphaComponent(alpha)
        node.strokeColor = .clear
        node.lineWidth = 0
        node.glowWidth = 0
        node.blendMode = blendMode
        node.isAntialiased = true
        return node
    }
    
    // MARK: - Catmull-Rom Spline Smoothing
    
    /// Converts a polyline path to a smooth Bézier curve path using Catmull-Rom interpolation.
    /// This eliminates sharp corners that cause visual artifacts on the inside of curves.
    ///
    /// - Parameters:
    ///   - points: Array of points defining the polyline
    ///   - tension: Controls curve tightness (0 = sharp, 1 = smooth). Default 0.5
    /// - Returns: A smooth CGPath using cubic Bézier curves
    static func smoothPath(from points: [CGPoint], tension: CGFloat = 0.5) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else {
            if let first = points.first {
                path.move(to: first)
            }
            return path
        }
        
        // For just 2 points, draw a simple line
        if points.count == 2 {
            path.move(to: points[0])
            path.addLine(to: points[1])
            return path
        }
        
        path.move(to: points[0])
        
        // Catmull-Rom to Bézier conversion factor
        let alpha: CGFloat = (1.0 - tension) / 6.0
        
        for i in 0..<(points.count - 1) {
            // Get 4 control points (with clamping at ends)
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]
            
            // Calculate Bézier control points from Catmull-Rom control points
            let cp1 = CGPoint(
                x: p1.x + alpha * (p2.x - p0.x),
                y: p1.y + alpha * (p2.y - p0.y)
            )
            let cp2 = CGPoint(
                x: p2.x - alpha * (p3.x - p1.x),
                y: p2.y - alpha * (p3.y - p1.y)
            )
            
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        
        return path
    }
    
    /// Creates a smooth path from points with optional deduplication.
    /// Combines deduplication with Catmull-Rom smoothing for artifact-free strokes.
    ///
    /// - Parameters:
    ///   - points: Array of points in normalized (0-1) coordinates
    ///   - scale: Scale factor to convert to screen coordinates
    ///   - dedupeEpsilon: Minimum distance between consecutive points in screen pixels
    ///   - tension: Catmull-Rom tension (0 = sharp, 1 = smooth). Default 0.5
    /// - Returns: A smooth CGPath using cubic Bézier curves
    static func makeSmoothPath(
        from points: [CGPoint],
        scale: CGFloat,
        dedupeEpsilon: CGFloat = 0.7,
        tension: CGFloat = 0.5
    ) -> CGPath {
        guard !points.isEmpty else { return CGMutablePath() }
        
        // Convert to screen space and dedupe
        var screenPoints: [CGPoint] = []
        
        func screenPoint(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: p.x * scale,
                y: (1.0 - p.y) * scale
            )
        }
        
        let first = screenPoint(points[0])
        screenPoints.append(first)
        var lastAdded = first
        
        for i in 1..<points.count {
            let p = screenPoint(points[i])
            let dist = hypot(p.x - lastAdded.x, p.y - lastAdded.y)
            
            // Skip ultra-short segments
            if dist < dedupeEpsilon && i < points.count - 1 {
                continue
            }
            
            screenPoints.append(p)
            lastAdded = p
        }
        
        return smoothPath(from: screenPoints, tension: tension)
    }
}
