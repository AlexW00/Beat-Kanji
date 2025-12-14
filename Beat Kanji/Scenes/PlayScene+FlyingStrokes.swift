//
//  PlayScene+FlyingStrokes.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

extension PlayScene {
    
    func spawnIncomingStrokes() {
        guard let kanji = gameEngine.currentKanji else { return }
        
        // Spawn strokes for current kanji
        while nextSpawnIndex < kanji.strokes.count && nextSpawnIndex < gameEngine.strokeArrivalTimes.count {
            let arrivalTime = gameEngine.strokeArrivalTimes[nextSpawnIndex]
            let timeUntilArrival = arrivalTime - gameEngine.currentTime
            
            // If it's within flight duration, spawn it
            if timeUntilArrival <= gameEngine.flightDuration {
                spawnFlyingStroke(
                    index: nextSpawnIndex,
                    arrivalTime: arrivalTime,
                    kanjiIndex: gameEngine.currentKanjiIndexInSequence,
                    isNextKanji: false
                )
                nextSpawnIndex += 1
            } else {
                break
            }
        }
        
        // Look-ahead: spawn strokes for next kanji if current kanji is almost complete
        spawnLookAheadStrokes()
    }
    
    /// Spawn strokes from the next kanji when the current one is almost complete
    private func spawnLookAheadStrokes() {
        guard let currentKanji = gameEngine.currentKanji else { return }
        
        let remainingStrokes = currentKanji.strokes.count - gameEngine.currentStrokeIndex
        
        // Only look ahead if we're on the last 2 strokes of current kanji
        guard remainingStrokes <= 2 else { return }
        
        // Get upcoming beat events that belong to the next kanji
        let upcomingEvents = gameEngine.getUpcomingBeatEvents(count: 5, afterTime: gameEngine.currentTime)
        let nextKanjiIndex = gameEngine.currentKanjiIndexInSequence + 1
        
        for event in upcomingEvents {
            // Only spawn if it's for the next kanji
            guard event.kanjiIndex == nextKanjiIndex else { continue }
            
            let timeUntilArrival = event.beatTime - gameEngine.currentTime
            
            // Only spawn if within flight duration
            guard timeUntilArrival <= gameEngine.flightDuration else { continue }
            
            // Check if we already have this stroke flying
            let alreadySpawned = flyingStrokes.contains { fs in
                fs.kanjiIndex == event.kanjiIndex && fs.index == event.strokeIndex
            }
            guard !alreadySpawned else { continue }
            
            spawnFlyingStroke(
                index: event.strokeIndex,
                arrivalTime: event.beatTime,
                kanjiIndex: event.kanjiIndex,
                isNextKanji: true
            )
        }
    }
    
    private func spawnFlyingStroke(index: Int, arrivalTime: TimeInterval, kanjiIndex: Int, isNextKanji: Bool) {
        // Get the correct kanji for this stroke
        guard let kanji = gameEngine.getKanjiAtIndex(kanjiIndex) else { return }
        guard index < kanji.strokes.count else { return }
        
        let stroke = kanji.strokes[index]
        let points = stroke.cgPoints
        guard !points.isEmpty else { return }
        
        // === PRECOMPUTE PATH DATA (done once at spawn, not per-frame) ===
        // Calculate segment lengths and total length
        var segmentLengths: [Double] = []
        var totalLength: Double = 0
        for i in 1..<points.count {
            let segLen = hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
            segmentLengths.append(segLen)
            totalLength += segLen
        }
        
        // Precompute deduplicated points for smooth path generation
        // This avoids the expensive deduplication logic every frame
        let minDistanceThreshold: CGFloat = 0.7 / 300.0 // Normalize threshold to 0-1 space (assuming ~300px scale)
        var smoothFullPathPoints: [CGPoint] = []
        if let first = points.first {
            smoothFullPathPoints.append(first)
            var lastAdded = first
            for i in 1..<points.count {
                let p = points[i]
                let dist = hypot(p.x - lastAdded.x, p.y - lastAdded.y)
                if dist >= minDistanceThreshold || i == points.count - 1 {
                    smoothFullPathPoints.append(p)
                    lastAdded = p
                }
            }
        }
        
        // Check if this is a rainbow stroke
        let isRainbow = gameEngine.isStrokeRainbow(kanjiIndex: kanjiIndex, strokeIndex: index)
        
        // Use currentKanjiNode for current kanji, or create preview for next kanji
        let targetNode: SKNode
        if isNextKanji {
            // Create or get the next kanji preview node
            if nextKanjiNode == nil {
                setupNextKanjiPreview(for: kanji)
            }
            guard let previewNode = nextKanjiNode else { return }
            targetNode = previewNode
        } else {
            guard let node = currentKanjiNode else { return }
            targetNode = node
        }
        
        // Determine stroke color based on rainbow status
        // Flying strokes use vibrant neon colors for visibility while approaching
        let flyingNeonCyan = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let nextKanjiNeonOrange = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        let strokeColor: UIColor = isRainbow ? .magenta : (isNextKanji ? nextKanjiNeonOrange : flyingNeonCyan)
        
        // Background Node (Faint full stroke) - for non-rainbow, or container for rainbow segments
        let bgShape = SKShapeNode()
        bgShape.fillColor = .clear  // Explicitly clear to prevent white fill when path is set
        if !isRainbow {
            bgShape.strokeColor = strokeColor
            bgShape.lineWidth = LayoutConstants.shared.flyingStrokeBgWidth
            bgShape.lineCap = .round
            bgShape.lineJoin = .round
        }
        bgShape.alpha = isNextKanji ? 0.15 : 0.2
        bgShape.glowWidth = 0.0
        targetNode.addChild(bgShape)
        
        // Fill Node (Progressive fill) - Container
        let fillContainer = SKNode()
        fillContainer.alpha = isNextKanji ? 0.8 : 1.0
        targetNode.addChild(fillContainer)
        
        if isRainbow {
            // Create rainbow segment nodes for the glow layer
            // Use filled outlines instead of strokes to avoid join artifacts
            let rainbowColors: [UIColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
            for (idx, color) in rainbowColors.enumerated() {
                let segmentGlow = SKShapeNode()
                segmentGlow.name = "rainbowGlow_\(idx)"
                // Store the original color for later use when converting to filled path
                segmentGlow.strokeColor = color
                segmentGlow.fillColor = color.withAlphaComponent(0.7)
                segmentGlow.lineWidth = 0  // Will use filled outline
                segmentGlow.lineCap = .round
                segmentGlow.lineJoin = .round
                segmentGlow.glowWidth = 0  // No glowWidth - avoid gaps
                segmentGlow.blendMode = .add
                segmentGlow.alpha = 1.0
                segmentGlow.zPosition = 0
                fillContainer.addChild(segmentGlow)
                
                // Also add to background
                let segmentBg = SKShapeNode()
                segmentBg.name = "rainbowBg_\(idx)"
                segmentBg.strokeColor = color
                segmentBg.lineWidth = LayoutConstants.shared.flyingStrokeBgWidth
                segmentBg.lineCap = .round
                segmentBg.lineJoin = .round
                segmentBg.glowWidth = 0.0
                segmentBg.alpha = 1.0
                bgShape.addChild(segmentBg)
            }
            
            // Store rainbow phase for animation
            fillContainer.userData = NSMutableDictionary()
            fillContainer.userData?["rainbowPhase"] = 0.0
        } else {
            // Standard glow node - use filled outline approach for vibrant neon
            let fillGlow = SKShapeNode()
            fillGlow.name = "glow"
            // Store the color in strokeColor for reference, but render as fill
            fillGlow.strokeColor = strokeColor
            fillGlow.fillColor = strokeColor.withAlphaComponent(0.85)  // Bright vibrant glow
            fillGlow.lineWidth = 0  // Will use filled outline
            fillGlow.lineCap = .round
            fillGlow.lineJoin = .round
            fillGlow.glowWidth = 0.0  // No glowWidth - avoid gaps
            fillGlow.blendMode = .add  // Additive for neon glow effect
            fillGlow.alpha = 1.0
            fillGlow.zPosition = 0
            fillContainer.addChild(fillGlow)
        }
        
        // Core Node (white center) - use filled outline approach
        let fillCore = SKShapeNode()
        fillCore.name = "core"
        fillCore.strokeColor = .white
        fillCore.fillColor = .white
        fillCore.lineWidth = 0  // Will use filled outline
        fillCore.lineCap = .round
        fillCore.lineJoin = .round
        fillCore.glowWidth = 0.0
        fillCore.alpha = 1.0
        fillCore.zPosition = 1
        fillContainer.addChild(fillCore)
        
        let flying = FlyingStroke(
            index: index,
            bgNode: bgShape,
            fillNode: fillContainer,
            arrivalTime: arrivalTime,
            depth: spawnDepth,
            kanjiIndex: kanjiIndex,
            isNextKanji: isNextKanji,
            isRainbow: isRainbow,
            normalizedPoints: points,
            segmentLengths: segmentLengths,
            totalLength: totalLength,
            smoothFullPathPoints: smoothFullPathPoints
        )
        flyingStrokes.append(flying)
    }
    
    /// Setup a preview node for the next kanji (positioned at same location as current kanji)
    private func setupNextKanjiPreview(for kanji: KanjiEntry) {
        let node = SKNode()
        node.alpha = 0.5 // Preview is semi-transparent
        
        // Calculate scale and offset using predefined kanji size from settings
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let kanjiSize = SettingsStore.shared.kanjiSize
        let scaleFactor: CGFloat = isIPad ? kanjiSize.iPadScale : kanjiSize.iPhoneScale
        let scale = min(size.width, size.height) * scaleFactor
        let offsetX = (size.width - scale) / 2 // Centered horizontally
        let bottomOffset: CGFloat = isIPad ? kanjiSize.iPadBottomOffset : kanjiSize.iPhoneBottomOffset
        let offsetY = size.height * bottomOffset
        
        node.userData = ["scale": scale, "offsetX": offsetX, "offsetY": offsetY]
        node.position = CGPoint(x: offsetX, y: offsetY)
        node.zPosition = -5 // Behind current kanji
        
        addChild(node)
        nextKanjiNode = node
    }
    
    /// Clean up the next kanji preview when transitioning
    func cleanupNextKanjiPreview() {
        nextKanjiNode?.removeFromParent()
        nextKanjiNode = nil
    }
    
    func updateFlyingStrokes() {
        let screenCenter = CGPoint(x: size.width/2, y: size.height/2)
        
        for i in (0..<flyingStrokes.count).reversed() {
            var flying = flyingStrokes[i]
            
            // Get the correct node for this flying stroke
            let targetNode: SKNode?
            
            if flying.isNextKanji {
                targetNode = nextKanjiNode
            } else {
                targetNode = currentKanjiNode
            }
            
            guard let node = targetNode,
                  let scale = node.userData?["scale"] as? CGFloat else {
                // Remove orphaned flying strokes
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            let nodePos = node.position
            
            // Calculate current depth based on time
            let timeUntilArrival = flying.arrivalTime - gameEngine.currentTime
            let progress = CGFloat(timeUntilArrival / gameEngine.flightDuration)
            
            // Clamp depth to 0 to prevent overshooting
            flying.depth = max(0.0, progress * spawnDepth)
            
            // Remove strokes that have passed
            if flying.depth < -2.0 {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            // Also remove look-ahead strokes when they become current
            if flying.isNextKanji && flying.kanjiIndex == gameEngine.currentKanjiIndexInSequence {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            // Use cached path data from spawn (avoids per-frame geometry calculations)
            let points = flying.normalizedPoints
            let segmentLengths = flying.segmentLengths
            let totalLength = flying.totalLength
            
            guard !points.isEmpty else {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            // Calculate fill percentage based on flight progress
            let fillPercent = 1.0 - max(0.0, min(1.0, progress))
            let targetLen = totalLength * Double(fillPercent)
            
            // Helper to project a local point (0..1) - only operation that varies per-frame
            @inline(__always) func projectPoint(_ p: CGPoint) -> CGPoint {
                let localX = p.x * scale
                let localY = (1.0 - p.y) * scale
                let screenX = localX + nodePos.x
                let screenY = localY + nodePos.y
                let projScreen = project(point: CGPoint(x: screenX, y: screenY), depth: flying.depth, center: screenCenter)
                return CGPoint(x: projScreen.x - nodePos.x, y: projScreen.y - nodePos.y)
            }
            
            // Project all points (using cached normalized points)
            let projectedPoints = points.map { projectPoint($0) }
            
            // Build full path from cached smooth points (pre-deduplicated at spawn)
            let projectedSmoothPoints = flying.smoothFullPathPoints.map { projectPoint($0) }
            let fullPath = buildSimplePath(from: projectedSmoothPoints)
            
            // Build fill path based on fill percentage
            let fillPath = buildPartialPath(
                projectedPoints: projectedPoints,
                segmentLengths: segmentLengths,
                fillPercent: fillPercent,
                totalLength: totalLength
            )
            
            // Handle rainbow strokes with gradient segments
            if flying.isRainbow {
                let rainbowColors: [UIColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
                let numColors = rainbowColors.count
                
                // Animate the rainbow phase
                var phase: Double = 0.0
                if let userData = flying.fillNode.userData,
                   let storedPhase = userData["rainbowPhase"] as? Double {
                    phase = storedPhase + 0.02 // Animation speed
                    if phase > 1.0 { phase -= 1.0 }
                    userData["rainbowPhase"] = phase
                }
                
                let depthScale = 1.0 / (1.0 + flying.depth * perspectiveFactor)
                let flyingLayout = LayoutConstants.shared
                let glowWidth = flyingLayout.flyingStrokeGlowWidth * depthScale
                let bgWidth = flyingLayout.flyingStrokeBgWidth * depthScale
                let coreWidth = flyingLayout.flyingStrokeCoreWidth * depthScale
                
                // Create paths for each rainbow color segment
                for colorIdx in 0..<numColors {
                    // Calculate start and end positions for this color segment
                    let segmentSize = 1.0 / Double(numColors)
                    let segStart = (Double(colorIdx) * segmentSize + phase).truncatingRemainder(dividingBy: 1.0)
                    let segEnd = segStart + segmentSize
                    
                    // Handle wrap-around
                    let paths = createRainbowSegmentPaths(
                        projectedPoints: projectedPoints,
                        segmentLengths: segmentLengths,
                        totalLength: totalLength,
                        segStart: segStart,
                        segEnd: segEnd,
                        fillPercent: fillPercent
                    )
                    
                    // Update glow nodes - use filled outlines for seamless appearance
                    if let glowNode = flying.fillNode.childNode(withName: "rainbowGlow_\(colorIdx)") as? SKShapeNode {
                        // Convert to filled outline to avoid join artifacts
                        glowNode.path = strokedPath(from: paths.fillPath, width: glowWidth)
                        glowNode.strokeColor = .clear
                        glowNode.lineWidth = 0
                        glowNode.glowWidth = 0  // No glowWidth - key to avoiding gaps
                    }
                    
                    // Update background nodes
                    if let bgNode = flying.bgNode.childNode(withName: "rainbowBg_\(colorIdx)") as? SKShapeNode {
                        bgNode.path = paths.bgPath
                        bgNode.lineWidth = bgWidth
                        bgNode.glowWidth = 0
                    }
                }
                
                // Update the core (white center) - use filled outline
                if let coreNode = flying.fillNode.childNode(withName: "core") as? SKShapeNode {
                    coreNode.path = strokedPath(from: fillPath, width: coreWidth)
                    coreNode.strokeColor = .clear
                    coreNode.lineWidth = 0
                    coreNode.glowWidth = 0
                }
            } else {
                // Standard stroke - use native SKShapeNode stroke rendering (avoids expensive strokedPath calls)
                let depthScale = 1.0 / (1.0 + flying.depth * perspectiveFactor)
                let stdLayout = LayoutConstants.shared
                let bgWidth = stdLayout.flyingStrokeBgWidth * depthScale
                let glowOuterWidth = stdLayout.flyingStrokeGlowOuterWidth * depthScale
                let coreWidth = stdLayout.flyingStrokeStandardCoreWidth * depthScale
                
                // Background stroke - use native stroke rendering
                flying.bgNode.path = fullPath
                flying.bgNode.fillColor = .clear
                flying.bgNode.lineWidth = bgWidth
                flying.bgNode.lineCap = .round
                flying.bgNode.lineJoin = .round
                flying.bgNode.glowWidth = 0
                
                for child in flying.fillNode.children {
                    guard let shape = child as? SKShapeNode else { continue }
                    if shape.name == "glow" {
                        // Use filled outline for seamless vibrant glow
                        shape.path = strokedPath(from: fillPath, width: glowOuterWidth)
                        shape.fillColor = shape.strokeColor.withAlphaComponent(0.5)  // Visible glow
                        shape.strokeColor = .clear
                        shape.lineWidth = 0
                        shape.glowWidth = 0  // No glowWidth - key to avoiding gaps
                        shape.blendMode = .add  // Additive for neon glow effect
                    } else if shape.name == "core" {
                        // Use filled outline for core too - avoids join artifacts
                        shape.path = strokedPath(from: fillPath, width: coreWidth)
                        shape.fillColor = .white
                        shape.strokeColor = .clear
                        shape.lineWidth = 0
                        shape.glowWidth = 0
                        shape.blendMode = .alpha
                    }
                }
            }
            
            // Fade in/out
            let alpha = max(0.0, min(1.0, 1.0 - (flying.depth / spawnDepth)))
            let lookAheadMultiplier: CGFloat = flying.isNextKanji ? 0.6 : 1.0
            flying.bgNode.alpha = alpha * 0.3 * lookAheadMultiplier
            flying.fillNode.alpha = alpha * 1.0 * lookAheadMultiplier
            
            flyingStrokes[i] = flying
        }
    }
    
    /// Create paths for a rainbow segment between normalized positions
    private func createRainbowSegmentPaths(
        projectedPoints: [CGPoint],
        segmentLengths: [Double],
        totalLength: Double,
        segStart: Double,
        segEnd: Double,
        fillPercent: Double
    ) -> (bgPath: CGPath, fillPath: CGPath) {
        let bgPath = CGMutablePath()
        let fillPath = CGMutablePath()
        
        guard !projectedPoints.isEmpty, totalLength > 0 else {
            return (bgPath, fillPath)
        }
        
        // Minimum distance threshold to avoid rendering artifacts
        let minDistanceThreshold: CGFloat = 0.7
        
        // Handle wrap-around by splitting into two segments if needed
        var segments: [(start: Double, end: Double)] = []
        if segEnd > 1.0 {
            segments.append((segStart, 1.0))
            segments.append((0.0, segEnd - 1.0))
        } else {
            segments.append((segStart, segEnd))
        }
        
        for segment in segments {
            let startPos = segment.start * totalLength
            let endPos = segment.end * totalLength
            
            var pathStarted = false
            var currentDist: Double = 0
            var lastBgPoint: CGPoint = .zero
            var lastFillPoint: CGPoint = .zero
            var fillSegmentStarted = false
            
            for i in 0..<segmentLengths.count {
                let segLen = segmentLengths[i]
                let segStartDist = currentDist
                let segEndDist = currentDist + segLen
                
                // Check if this segment overlaps with our color range
                if segEndDist > startPos && segStartDist < endPos {
                    // Calculate the portion of this segment we need
                    let clipStart = max(startPos, segStartDist)
                    let clipEnd = min(endPos, segEndDist)
                    
                    // Interpolate points
                    let t1 = (clipStart - segStartDist) / segLen
                    let t2 = (clipEnd - segStartDist) / segLen
                    
                    let p1 = projectedPoints[i]
                    let p2 = projectedPoints[i + 1]
                    
                    let startPt = CGPoint(
                        x: p1.x + (p2.x - p1.x) * t1,
                        y: p1.y + (p2.y - p1.y) * t1
                    )
                    let endPt = CGPoint(
                        x: p1.x + (p2.x - p1.x) * t2,
                        y: p1.y + (p2.y - p1.y) * t2
                    )
                    
                    if !pathStarted {
                        bgPath.move(to: startPt)
                        lastBgPoint = startPt
                        pathStarted = true
                    }
                    
                    // Only add to bg path if distance is significant
                    let bgDist = hypot(endPt.x - lastBgPoint.x, endPt.y - lastBgPoint.y)
                    if bgDist >= minDistanceThreshold {
                        bgPath.addLine(to: endPt)
                        lastBgPoint = endPt
                    }
                    
                    // For fill path, also check against fillPercent
                    let fillEndDist = fillPercent * totalLength
                    if clipStart < fillEndDist {
                        let fillClipEnd = min(clipEnd, fillEndDist)
                        let ft2 = (fillClipEnd - segStartDist) / segLen
                        let fillEndPt = CGPoint(
                            x: p1.x + (p2.x - p1.x) * ft2,
                            y: p1.y + (p2.y - p1.y) * ft2
                        )
                        
                        // Start a new subpath for each wrapped segment to avoid connecting lines
                        if !fillSegmentStarted {
                            fillPath.move(to: startPt)
                            lastFillPoint = startPt
                            fillSegmentStarted = true
                        }
                        
                        // Only add to fill path if distance is significant
                        let fillDist = hypot(fillEndPt.x - lastFillPoint.x, fillEndPt.y - lastFillPoint.y)
                        if fillDist >= minDistanceThreshold {
                            fillPath.addLine(to: fillEndPt)
                            lastFillPoint = fillEndPt
                        }
                    }
                }
                
                currentDist += segLen
            }
        }
        
        return (bgPath, fillPath)
    }
    
    // MARK: - Optimized Path Building Helpers
    
    /// Build a simple CGPath from an array of points (no Catmull-Rom smoothing per-frame)
    /// Uses quadratic curves for acceptable smoothness with much lower CPU cost
    private func buildSimplePath(from points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard points.count >= 2 else {
            if let first = points.first {
                path.move(to: first)
            }
            return path
        }
        
        path.move(to: points[0])
        
        // Use simple line segments (the deduplication at spawn keeps point count low)
        // This avoids the expensive Catmull-Rom spline calculation every frame
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        return path
    }
    
    /// Build a partial path for fill animation based on fill percentage
    /// Uses cached segment lengths to avoid recalculation
    private func buildPartialPath(
        projectedPoints: [CGPoint],
        segmentLengths: [Double],
        fillPercent: Double,
        totalLength: Double
    ) -> CGPath {
        let path = CGMutablePath()
        guard !projectedPoints.isEmpty, totalLength > 0 else { return path }
        
        let targetLen = totalLength * fillPercent
        var currentLen: Double = 0
        
        path.move(to: projectedPoints[0])
        
        for i in 0..<segmentLengths.count {
            let segLen = segmentLengths[i]
            
            if currentLen >= targetLen {
                break
            }
            
            if currentLen + segLen <= targetLen {
                // Add full segment
                path.addLine(to: projectedPoints[i + 1])
            } else {
                // Add partial segment - interpolate the endpoint
                let remaining = targetLen - currentLen
                let t = remaining / segLen
                let p1 = projectedPoints[i]
                let p2 = projectedPoints[i + 1]
                let partialPt = CGPoint(
                    x: p1.x + (p2.x - p1.x) * t,
                    y: p1.y + (p2.y - p1.y) * t
                )
                path.addLine(to: partialPt)
                break
            }
            currentLen += segLen
        }
        
        return path
    }
    
    private func project(point: CGPoint, depth: CGFloat, center: CGPoint) -> CGPoint {
        let d = max(-0.5, depth)
        let scale = 1.0 / (1.0 + d * perspectiveFactor)
        
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        let px = center.x + dx * scale
        let py = center.y + dy * scale
        
        return CGPoint(x: px, y: py)
    }
}
