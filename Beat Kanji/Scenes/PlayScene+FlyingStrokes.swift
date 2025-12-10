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
            isRainbow: isRainbow
        )
        flyingStrokes.append(flying)
    }
    
    /// Setup a preview node for the next kanji (positioned at same location as current kanji)
    private func setupNextKanjiPreview(for kanji: KanjiEntry) {
        let node = SKNode()
        node.alpha = 0.5 // Preview is semi-transparent
        
        // Calculate scale and offset - same as current kanji (no horizontal offset)
        let scale = min(size.width, size.height) * 0.8 // Same size as main kanji
        let offsetX = (size.width - scale) / 2 // Centered horizontally
        let offsetY = size.height * 0.15 // Same vertical position as current kanji
        
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
            
            // Get the correct node and kanji for this flying stroke
            let targetNode: SKNode?
            let kanjiEntry: KanjiEntry?
            
            if flying.isNextKanji {
                targetNode = nextKanjiNode
                kanjiEntry = gameEngine.getKanjiAtIndex(flying.kanjiIndex)
            } else {
                targetNode = currentKanjiNode
                kanjiEntry = gameEngine.currentKanji
            }
            
            guard let node = targetNode,
                  let scale = node.userData?["scale"] as? CGFloat,
                  let kanji = kanjiEntry else {
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
                // This stroke now belongs to the current kanji, remove the look-ahead version
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            guard flying.index < kanji.strokes.count else {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
                continue
            }
            
            let stroke = kanji.strokes[flying.index]
            let points = stroke.cgPoints
            
            // 1. Create Full Path (Background)
            let fullPath = CGMutablePath()
            // 2. Create Partial Path (Fill)
            let fillPath = CGMutablePath()
            
            // Calculate fill percentage based on flight progress
            let fillPercent = 1.0 - max(0.0, min(1.0, progress))
            let targetLen = stroke.length() * Double(fillPercent)
            var currentLen: Double = 0
            let totalLength = stroke.length()
            
            // For rainbow strokes, we need to track segment positions
            var projectedPoints: [CGPoint] = []
            var segmentLengths: [Double] = []
            
            if let first = points.first {
                // Helper to project a local point (0..1)
                func getProjectedPoint(_ p: CGPoint) -> CGPoint {
                    // Local (0..1) -> Local Scaled
                    let localX = p.x * scale
                    let localY = (1.0 - p.y) * scale
                    
                    // Local Scaled -> Screen Space
                    let screenX = localX + nodePos.x
                    let screenY = localY + nodePos.y
                    
                    // Project in Screen Space
                    let projScreen = project(point: CGPoint(x: screenX, y: screenY), depth: flying.depth, center: screenCenter)
                    
                    // Screen Space -> Local Scaled
                    return CGPoint(x: projScreen.x - nodePos.x, y: projScreen.y - nodePos.y)
                }
                
                let p1 = getProjectedPoint(first)
                projectedPoints.append(p1)
                
                // Minimum distance threshold to avoid rendering artifacts from near-identical points
                // When strokes are scaled down by perspective, consecutive points can become
                // extremely close, causing SpriteKit's line join calculations to produce visual glitches.
                let minDistanceThreshold: CGFloat = 0.7
                
                // Collect all projected points with deduplication
                var dedupedFullPoints: [CGPoint] = [p1]
                var lastFullPoint = p1
                
                for j in 1..<points.count {
                    let pa = points[j-1]
                    let pb = points[j]
                    let segLen = hypot(pb.x - pa.x, pb.y - pa.y)
                    
                    let p_proj = getProjectedPoint(pb)
                    
                    // Only add to full path if distance from last added point is significant
                    let fullPathDist = hypot(p_proj.x - lastFullPoint.x, p_proj.y - lastFullPoint.y)
                    if fullPathDist >= minDistanceThreshold || j == points.count - 1 {
                        dedupedFullPoints.append(p_proj)
                        lastFullPoint = p_proj
                    }
                    
                    projectedPoints.append(p_proj)
                    segmentLengths.append(segLen)
                    currentLen += segLen
                }
                
                // Create smooth full path using Catmull-Rom splines
                let smoothFullPath = NeonStrokeFactory.smoothPath(from: dedupedFullPoints, tension: 0.5)
                fullPath.addPath(smoothFullPath)
                
                // Build fill path points based on fill percentage
                currentLen = 0
                var dedupedFillPoints: [CGPoint] = [p1]
                var lastFillPoint = p1
                
                for j in 1..<points.count {
                    let pa = points[j-1]
                    let pb = points[j]
                    let segLen = hypot(pb.x - pa.x, pb.y - pa.y)
                    
                    if currentLen < targetLen {
                        if currentLen + segLen <= targetLen {
                            // Add full segment - but only if distance is significant
                            let p_proj = projectedPoints[j]
                            let fillDist = hypot(p_proj.x - lastFillPoint.x, p_proj.y - lastFillPoint.y)
                            if fillDist >= minDistanceThreshold || j == points.count - 1 {
                                dedupedFillPoints.append(p_proj)
                                lastFillPoint = p_proj
                            }
                        } else {
                            // Add partial segment
                            let rem = targetLen - currentLen
                            let t = rem / segLen
                            let newX = pa.x + (pb.x - pa.x) * Double(t)
                            let newY = pa.y + (pb.y - pa.y) * Double(t)
                            let p_partial = getProjectedPoint(CGPoint(x: newX, y: newY))
                            // Always add the final partial point for accuracy
                            dedupedFillPoints.append(p_partial)
                            lastFillPoint = p_partial
                        }
                    }
                    currentLen += segLen
                }
                
                // Create smooth fill path using Catmull-Rom splines
                let smoothFillPath = NeonStrokeFactory.smoothPath(from: dedupedFillPoints, tension: 0.5)
                fillPath.addPath(smoothFillPath)
            }
            
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
                // Standard stroke - update paths with neon glow and filled core to avoid seams
                let depthScale = 1.0 / (1.0 + flying.depth * perspectiveFactor)
                let stdLayout = LayoutConstants.shared
                let bgWidth = stdLayout.flyingStrokeBgWidth * depthScale
                let glowOuterWidth = stdLayout.flyingStrokeGlowOuterWidth * depthScale
                let coreWidth = stdLayout.flyingStrokeStandardCoreWidth * depthScale
                
                // Background stroke (no glowWidth)
                flying.bgNode.path = fullPath
                flying.bgNode.lineWidth = bgWidth
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
    
    private func project(point: CGPoint, depth: CGFloat, center: CGPoint) -> CGPoint {
        let d = max(-0.5, depth)
        let scale = 1.0 / (1.0 + d * perspectiveFactor)
        
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        let px = center.x + dx * scale
        let py = center.y + dy * scale
        
        return CGPoint(x: px, y: py)
    }
    
    /// Rebuilds flying strokes after a mode change (e.g., kanji size changed)
    /// Re-parents existing flying stroke nodes to the new kanji node
    func rebuildFlyingStrokesForModeChange(newScale: CGFloat, newOffsetX: CGFloat, newOffsetY: CGFloat) {
        guard currentKanjiNode != nil else { return }
        
        // We need to respawn any flying strokes that were attached to the old (now removed) kanji node
        // The simplest approach: remove all current-kanji flying strokes and let them respawn
        // But we need to reset nextSpawnIndex to allow respawning
        
        // Find the minimum stroke index among flying strokes for current kanji
        var minFlyingIndex = Int.max
        var hadFlyingStrokes = false
        
        for i in (0..<flyingStrokes.count).reversed() {
            let flying = flyingStrokes[i]
            
            // Only handle current kanji strokes (not look-ahead)
            if !flying.isNextKanji && flying.kanjiIndex == gameEngine.currentKanjiIndexInSequence {
                hadFlyingStrokes = true
                minFlyingIndex = min(minFlyingIndex, flying.index)
                
                // Remove the orphaned nodes (they were attached to the old kanji node)
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
            }
        }
        
        // Reset spawn index to allow respawning of strokes that were in flight
        // Use the minimum of: current stroke index (already completed strokes) and min flying index
        if hadFlyingStrokes {
            nextSpawnIndex = min(gameEngine.currentStrokeIndex, minFlyingIndex)
        }
        // If no flying strokes were affected, nextSpawnIndex stays the same
        
        // Clean up look-ahead strokes too (they were attached to nextKanjiNode which was also cleaned up)
        for i in (0..<flyingStrokes.count).reversed() {
            let flying = flyingStrokes[i]
            if flying.isNextKanji {
                flying.bgNode.removeFromParent()
                flying.fillNode.removeFromParent()
                flyingStrokes.remove(at: i)
            }
        }
    }
}
