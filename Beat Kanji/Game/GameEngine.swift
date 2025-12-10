//
//  GameEngine.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import Foundation
import CoreGraphics

enum ScoreType {
    case perfect
    case acceptable
    case miss
    
    var points: Int {
        switch self {
        case .perfect: return 100
        case .acceptable: return 30
        case .miss: return 0
        }
    }
}

/// Represents a stroke event synced to a beat
struct StrokeBeatEvent {
    let beatTime: Double      // When the stroke should "land" (beat time)
    let kanjiIndex: Int       // Which kanji in the sequence
    let strokeIndex: Int      // Which stroke within that kanji
    let isRainbow: Bool       // Rainbow strokes restore health on perfect completion
}

class GameEngine {
    
    static let defaultLives: Int = 4
    static let rainbowStrokeChance: Double = 1.0 / 20.0
    
    var score: Int = 0
    var lives: Int = GameEngine.defaultLives
    var maxLives: Int = GameEngine.defaultLives
    var currentKanji: KanjiEntry?
    var currentStrokeIndex: Int = 0
    var kanjiQueue: [KanjiEntry] = []
    
    // Life loss cooldown: prevent losing more than 1 life per second
    var lastLifeLostTime: TimeInterval = -1.0
    static let lifeLossCooldown: TimeInterval = 1.0
    
    // Beatmap integration
    var beatmap: Beatmap?
    var difficulty: DifficultyLevel = .easy
    var beatEvents: [StrokeBeatEvent] = []
    var currentBeatEventIndex: Int = 0
    private var hasSongCompletionBeenTriggered: Bool = false
    var maxPossibleScore: Int {
        if !beatEvents.isEmpty {
            return beatEvents.count * ScoreType.perfect.points
        }
        if !selectedKanjiSequence.isEmpty {
            let strokeCount = selectedKanjiSequence.reduce(0) { partial, kanji in
                partial + kanji.strokeCount
            }
            return strokeCount * ScoreType.perfect.points
        }
        let queueStrokeCount = (currentKanji?.strokeCount ?? 0) + kanjiQueue.reduce(0) { partial, kanji in
            partial + kanji.strokeCount
        }
        return queueStrokeCount * ScoreType.perfect.points
    }
    
    // The sequence of kanji selected for this session (based on beat count)
    var selectedKanjiSequence: [KanjiEntry] = []
    var currentKanjiIndexInSequence: Int = 0
    
    // Timing
    var currentTime: TimeInterval = 0
    var strokeArrivalTimes: [TimeInterval] = [] // Time when the stroke should reach the player (Z=0)
    var flightDuration: TimeInterval = 2.0 // Time it takes for a stroke to fly from spawn to player
    var strokeDuration: TimeInterval = 1.0 // Window to draw AFTER arrival (or tolerance)
    
    // Stroke timing window - defines when player can draw a stroke
    // Window opens at (arrivalTime - windowBeforeArrival) and closes at (arrivalTime + windowAfterArrival)
    var windowBeforeArrival: TimeInterval = 0.5 // Time before arrival when drawing is allowed
    var windowAfterArrival: TimeInterval = 0.8  // Time after arrival when drawing is still allowed
    
    // BPM-related
    var bpm: Double = 120.0 // Default BPM, will be set from beatmap
    
    // Callback for game over
    var onGameOver: (() -> Void)?
    var onStrokeMiss: (() -> Void)? // Callback for timeout miss
    var onKanjiCompleted: (() -> Void)? // Callback when a kanji is fully completed
    var onSongCompleted: (() -> Void)? // Callback when all beat events are done
    var onHealthRestored: (() -> Void)? // Callback when health is restored from perfect kanji streak
    var onLifeLost: (() -> Void)? // Callback when a life is lost
    
    init() {
    }
    
    // Gap in milliseconds between the last stroke of a kanji and the first stroke of the next
    // This gives players a brief moment to prepare for the next kanji
    // Same gap for all display modes to maintain consistent gameplay rhythm
    var gapBetweenKanjiMs: Double {
        return 800.0 // 0.8 seconds gap - same for all modes
    }
    
    /// Start game with beatmap integration
    func startGameWithBeatmap(kanjiList: [KanjiEntry], beatmap: Beatmap, difficulty: DifficultyLevel) {
        self.score = 0
        self.lives = GameEngine.defaultLives
        self.maxLives = GameEngine.defaultLives
        self.currentTime = 0
        self.beatmap = beatmap
        self.difficulty = difficulty
        self.bpm = beatmap.meta.bpm
        self.lastLifeLostTime = -1.0
        self.hasSongCompletionBeenTriggered = false
        
        // Configure timing windows based on difficulty
        configureTimingWindows(for: difficulty)
        
        // Get notes for this difficulty
        let notes = beatmap.notesForDifficulty(difficulty)
        
        print("Starting game with \(notes.count) beat events for difficulty: \(difficulty.displayName)")
        
        // Select kanji with gaps between them (removes notes that are too close after each kanji ends)
        let (selectedKanji, filteredNotes) = selectKanjiWithGaps(from: kanjiList, notes: notes, gapMs: gapBetweenKanjiMs)
        selectedKanjiSequence = selectedKanji
        
        // Create beat events from the filtered notes
        beatEvents = createBeatEvents(from: filteredNotes)
        
        currentKanjiIndexInSequence = 0
        currentBeatEventIndex = 0
        
        // Preload all stroke data for selected kanji to avoid SQLite blocking during gameplay
        KanjiDataLoader.shared.preloadStrokes(for: selectedKanjiSequence)
        
        // Load the first kanji
        loadNextKanjiFromSequence()
    }
    
    /// Select random kanji and filter notes to ensure gaps between kanji
    /// Returns the selected kanji sequence and the filtered notes with gaps
    private func selectKanjiWithGaps(from kanjiList: [KanjiEntry], notes: [BeatNote], gapMs: Double) -> ([KanjiEntry], [BeatNote]) {
        guard !kanjiList.isEmpty, !notes.isEmpty else { return ([], []) }
        
        let gapSeconds = gapMs / 1000.0
        var selectedKanji: [KanjiEntry] = []
        var usedNotes: [BeatNote] = []
        var availableNotes = notes
        var shuffledKanji = kanjiList.shuffled()
        var shuffleIndex = 0
        
        while !availableNotes.isEmpty {
            // If we've used all kanji, reshuffle and continue
            if shuffleIndex >= shuffledKanji.count {
                shuffledKanji = kanjiList.shuffled()
                shuffleIndex = 0
            }
            
            let kanji = shuffledKanji[shuffleIndex]
            let strokeCount = kanji.strokeCount
            
            // Check if we have enough notes for this kanji
            if strokeCount <= availableNotes.count {
                // Take notes for this kanji
                let kanjiNotes = Array(availableNotes.prefix(strokeCount))
                usedNotes.append(contentsOf: kanjiNotes)
                selectedKanji.append(kanji)
                
                // Remove the used notes
                availableNotes.removeFirst(strokeCount)
                
                // If there are remaining notes, remove any that occur within the gap period
                if let lastNoteTime = kanjiNotes.last?.time, !availableNotes.isEmpty {
                    let gapEndTime = lastNoteTime + gapSeconds
                    
                    // Remove notes that fall within the gap period
                    let removedCount = availableNotes.filter { $0.time < gapEndTime }.count
                    availableNotes.removeAll { $0.time < gapEndTime }
                    
                    if removedCount > 0 {
                        print("Removed \(removedCount) notes within gap period after kanji '\(kanji.char)'")
                    }
                }
            } else {
                // Not enough notes left - try to find a smaller kanji
                if let smallerKanji = shuffledKanji.first(where: { $0.strokeCount <= availableNotes.count }) {
                    // Found a fitting kanji, use it (will be processed in next iteration)
                    shuffledKanji.removeAll { $0.char == smallerKanji.char }
                    shuffledKanji.insert(smallerKanji, at: shuffleIndex)
                    continue
                } else {
                    // No kanji fits, we're done
                    break
                }
            }
            shuffleIndex += 1
        }
        
        print("Selected \(selectedKanji.count) kanji with \(usedNotes.count) notes (original: \(notes.count) notes, removed \(notes.count - usedNotes.count) for gaps)")
        return (selectedKanji, usedNotes)
    }
    
    /// Create beat events from notes, mapping to kanji strokes
    /// Rainbow strokes are determined randomly (1/20 chance) when player is not at full health
    /// Note: Rainbow status is pre-determined but only visually shown when lives < maxLives
    private func createBeatEvents(from notes: [BeatNote]) -> [StrokeBeatEvent] {
        var events: [StrokeBeatEvent] = []
        var kanjiIdx = 0
        var strokeIdx = 0
        
        for note in notes {
            // Check if we've exhausted the current kanji
            if kanjiIdx < selectedKanjiSequence.count {
                let currentKanjiStrokeCount = selectedKanjiSequence[kanjiIdx].strokeCount
                if strokeIdx >= currentKanjiStrokeCount {
                    kanjiIdx += 1
                    strokeIdx = 0
                }
            }
            
            // Safety check
            guard kanjiIdx < selectedKanjiSequence.count else { break }
            
            // Determine if this stroke could be rainbow (1/20 chance)
            let isRainbow = Double.random(in: 0..<1) < GameEngine.rainbowStrokeChance
            
            let event = StrokeBeatEvent(beatTime: note.time, kanjiIndex: kanjiIdx, strokeIndex: strokeIdx, isRainbow: isRainbow)
            events.append(event)
            strokeIdx += 1
        }
        
        return events
    }
    
    /// Load the next kanji from the pre-selected sequence
    private func loadNextKanjiFromSequence() {
        guard currentKanjiIndexInSequence < selectedKanjiSequence.count else {
            currentKanji = nil
            return
        }
        
        currentKanji = selectedKanjiSequence[currentKanjiIndexInSequence]
        // debugAssertStrokeCount(currentKanji)
        currentStrokeIndex = 0
        
        // Generate stroke arrival times based on beat events for this kanji
        strokeArrivalTimes = []
        for event in beatEvents where event.kanjiIndex == currentKanjiIndexInSequence {
            strokeArrivalTimes.append(event.beatTime)
        }
        
        print("Loaded kanji '\(currentKanji?.char ?? "?")' with \(strokeArrivalTimes.count) strokes")
    }
    
    // Legacy method for non-beatmap gameplay
    func startGame(with kanjiList: [KanjiEntry]) {
        self.score = 0
        self.lives = GameEngine.defaultLives
        self.maxLives = GameEngine.defaultLives
        self.kanjiQueue = kanjiList.shuffled()
        self.currentTime = 0
        self.lastLifeLostTime = -1.0
        self.hasSongCompletionBeenTriggered = false
        nextKanji()
    }
    
    // Track if user is currently drawing (set by PlayScene)
    var isUserDrawing: Bool = false
    
    /// Update game state with the current audio playback time
    /// - Parameter audioTime: The current playback position from AudioManager
    func update(audioTime: TimeInterval) {
        currentTime = audioTime
        
        guard let kanji = currentKanji else {
            // Check if we've completed all events AND the song has finished
            if !beatEvents.isEmpty && currentBeatEventIndex >= beatEvents.count && !hasSongCompletionBeenTriggered {
                // Prefer actual audio duration; fall back to beatmap meta
                let metaDuration = beatmap?.meta.total_duration ?? 0
                let audioDuration = AudioManager.shared.currentSongDuration
                let targetDuration = audioDuration > 0 ? audioDuration : metaDuration
                let tolerance: TimeInterval = 0.35
                let playbackTime = audioTime
                
                let durationKnown = targetDuration > 0
                let reachedEnd = durationKnown && playbackTime >= (targetDuration - tolerance)
                
                // Also consider the player stopping near the expected end (handles metadata drift)
                let playbackStoppedNearEnd = durationKnown &&
                    !AudioManager.shared.isPlaying &&
                    playbackTime >= max(0, targetDuration - 1.0)
                
                if reachedEnd || playbackStoppedNearEnd || !durationKnown {
                    hasSongCompletionBeenTriggered = true
                    onSongCompleted?()
                }
            }
            return
        }
        
        // Check for timeout on current stroke
        // Miss occurs when the full window (including grace period) closes
        // If user is actively drawing, defer the miss check
        if currentStrokeIndex < kanji.strokeCount && currentStrokeIndex < strokeArrivalTimes.count {
            let arrivalTime = strokeArrivalTimes[currentStrokeIndex]
            let windowEnd = arrivalTime + windowAfterArrival
            if currentTime > windowEnd && !isUserDrawing {
                handleMiss()
                onStrokeMiss?()
                _ = advanceStroke()
            }
        }
    }
    
    func nextKanji() {
        if kanjiQueue.isEmpty {
            return
        }
        
        currentKanji = kanjiQueue.removeFirst()
        // debugAssertStrokeCount(currentKanji)
        currentStrokeIndex = 0
        
        // Generate simple beatmap for this kanji (legacy non-beatmap mode)
        strokeArrivalTimes = []
        var time = currentTime + 4.0
        if let k = currentKanji {
            for _ in 0..<k.strokeCount {
                strokeArrivalTimes.append(time)
                time += 1.5
            }
        }
    }

#if DEBUG
    private func debugAssertStrokeCount(_ kanji: KanjiEntry?) {
        guard let kanji else { return }
        let loaded = kanji.strokes.count
        assert(loaded == kanji.strokeCount, "Kanji \(kanji.id): strokeCount=\(kanji.strokeCount) but loaded \(loaded)")
    }
#endif
    
    /// Move to next kanji in the beatmap sequence
    func nextKanjiInSequence() {
        currentKanjiIndexInSequence += 1
        loadNextKanjiFromSequence()
        onKanjiCompleted?()
    }
    
    func evaluateStroke(drawnPoints: [CGPoint], targetStroke: Stroke) -> ScoreType {
        let sampleCount = 50
        
        let drawnStroke = Stroke(id: "drawn", points: drawnPoints.map { [Double($0.x), Double($0.y)] })
        let resampledDrawn = drawnStroke.resample(count: sampleCount)
        let resampledTarget = targetStroke.resample(count: sampleCount)
        
        var totalDist: Double = 0
        for i in 0..<sampleCount {
            let p1 = resampledDrawn[i]
            let p2 = resampledTarget[i]
            totalDist += hypot(p2.x - p1.x, p2.y - p1.y)
        }
        let avgDist = totalDist / Double(sampleCount)
        
        // Relaxed thresholds for fun and forgiving gameplay
        // Perfect: good tracing (6% average deviation)
        // Acceptable/Good: reasonable accuracy (12% average deviation)
        // Miss: anything beyond good threshold
        if avgDist < 0.06 {
            return .perfect
        } else if avgDist < 0.12 {
            return .acceptable
        } else {
            return .miss
        }
    }
    
    func handleMiss() {
        // Only lose a life if cooldown has passed (max 1 life per second)
        if currentTime - lastLifeLostTime >= GameEngine.lifeLossCooldown {
            lives -= 1
            lastLifeLostTime = currentTime
            onLifeLost?()
            if lives <= 0 {
                onGameOver?()
            }
        }
    }
    
    /// Check if the current stroke is a rainbow stroke (only active when not at full health)
    func isCurrentStrokeRainbow() -> Bool {
        guard lives < maxLives else { return false }
        guard currentBeatEventIndex < beatEvents.count else { return false }
        return beatEvents[currentBeatEventIndex].isRainbow
    }
    
    /// Check if a specific beat event is rainbow (for flying strokes)
    func isStrokeRainbow(kanjiIndex: Int, strokeIndex: Int) -> Bool {
        guard lives < maxLives else { return false }
        return beatEvents.first { $0.kanjiIndex == kanjiIndex && $0.strokeIndex == strokeIndex }?.isRainbow ?? false
    }
    
    /// Handle rainbow stroke completion - restore health on perfect
    func handleRainbowStrokePerfect() {
        if lives < maxLives {
            lives += 1
            onHealthRestored?()
        }
    }
    
    /// Returns true if kanji is completed
    func advanceStroke() -> Bool {
        guard let kanji = currentKanji else { return false }
        currentStrokeIndex += 1
        currentBeatEventIndex += 1
        
        if currentStrokeIndex >= kanji.strokeCount {
            return true
        }
        return false
    }
    
    /// Get upcoming beat events for look-ahead spawning
    func getUpcomingBeatEvents(count: Int, afterTime: TimeInterval) -> [StrokeBeatEvent] {
        var upcoming: [StrokeBeatEvent] = []
        var idx = currentBeatEventIndex
        
        while idx < beatEvents.count && upcoming.count < count {
            let event = beatEvents[idx]
            if event.beatTime > afterTime {
                upcoming.append(event)
            }
            idx += 1
        }
        
        return upcoming
    }
    
    /// Check if there are upcoming events for the next kanji (for look-ahead rendering)
    func hasUpcomingNextKanjiStrokes(withinTime: TimeInterval) -> Bool {
        guard let kanji = currentKanji else { return false }
        let remainingStrokes = kanji.strokeCount - currentStrokeIndex
        
        // If only 1-2 strokes left on current kanji, check if next kanji strokes are coming
        if remainingStrokes <= 2 {
            let upcoming = getUpcomingBeatEvents(count: 5, afterTime: currentTime)
            for event in upcoming {
                if event.kanjiIndex > currentKanjiIndexInSequence && event.beatTime - currentTime <= withinTime {
                    return true
                }
            }
        }
        return false
    }
    
    /// Get the kanji at a specific index in the sequence
    func getKanjiAtIndex(_ index: Int) -> KanjiEntry? {
        guard index >= 0 && index < selectedKanjiSequence.count else { return nil }
        return selectedKanjiSequence[index]
    }
    
    // MARK: - Stroke Timing Window
    
    /// Configure timing windows based on difficulty
    private func configureTimingWindows(for difficulty: DifficultyLevel) {
        // Standardize the stroke window across all difficulties (use medium values)
        switch difficulty {
        case .easy, .medium, .hard:
            windowBeforeArrival = 0.75  // 750ms before arrival
            windowAfterArrival = 0.5    // 500ms after arrival
        }
    }
    
    /// Check if the current stroke's timing window is active
    /// Drawing is allowed from windowBeforeArrival to windowAfterArrival
    /// Returns: (isActive, progress) where progress is 0.0 at window start, 1.0 at window end
    func isStrokeWindowActive() -> (isActive: Bool, progress: Double) {
        guard let kanji = currentKanji,
              currentStrokeIndex < kanji.strokeCount,
              currentStrokeIndex < strokeArrivalTimes.count else {
            return (false, 0.0)
        }
        
        let arrivalTime = strokeArrivalTimes[currentStrokeIndex]
        let windowStart = arrivalTime - windowBeforeArrival
        let windowEnd = arrivalTime + windowAfterArrival
        
        // Window is active from windowBeforeArrival to windowAfterArrival
        let isActive = currentTime >= windowStart && currentTime <= windowEnd
        
        // Calculate progress: 0.0 at window start, 1.0 at window end
        var progress: Double = 0.0
        let totalWindowDuration = windowBeforeArrival + windowAfterArrival
        if currentTime >= windowStart && currentTime <= windowEnd {
            progress = (currentTime - windowStart) / totalWindowDuration
        } else if currentTime > windowEnd {
            progress = 1.0 // Window has closed
        }
        
        return (isActive, progress)
    }
    
    /// Get the time until the current stroke window opens (negative if already open)
    func timeUntilWindowOpens() -> TimeInterval {
        guard currentStrokeIndex < strokeArrivalTimes.count else { return Double.infinity }
        let arrivalTime = strokeArrivalTimes[currentStrokeIndex]
        let windowStart = arrivalTime - windowBeforeArrival
        return windowStart - currentTime
    }
    
    /// Evaluate a partial (in-progress) stroke when timeout occurs mid-draw
    /// Returns acceptable if >70% complete and roughly on path, otherwise miss
    func evaluatePartialStroke(drawnPoints: [CGPoint], targetStroke: Stroke) -> ScoreType {
        guard drawnPoints.count >= 3 else { return .miss }
        
        let drawnStroke = Stroke(id: "drawn", points: drawnPoints.map { [Double($0.x), Double($0.y)] })
        let drawnLength = drawnStroke.length()
        let targetLength = targetStroke.length()
        
        // Check completion percentage
        let completionRatio = drawnLength / targetLength
        guard completionRatio >= 0.7 else { return .miss }
        
        // Evaluate the partial stroke against the corresponding portion of target
        // Resample both to same count based on how much was drawn
        let partialSampleCount = max(10, Int(50.0 * completionRatio))
        let resampledDrawn = drawnStroke.resample(count: partialSampleCount)
        
        // Get partial target (first N% of the stroke)
        let targetPoints = targetStroke.cgPoints
        let partialTargetPoints = Array(targetPoints.prefix(Int(Double(targetPoints.count) * completionRatio) + 1))
        let partialTarget = Stroke(id: "partial", points: partialTargetPoints.map { [Double($0.x), Double($0.y)] })
        let resampledTarget = partialTarget.resample(count: partialSampleCount)
        
        var totalDist: Double = 0
        for i in 0..<partialSampleCount {
            let p1 = resampledDrawn[i]
            let p2 = resampledTarget[i]
            totalDist += hypot(p2.x - p1.x, p2.y - p1.y)
        }
        let avgDist = totalDist / Double(partialSampleCount)
        
        // Use slightly more lenient thresholds for partial strokes
        if avgDist < 0.10 {
            return .acceptable  // Partial strokes get at most acceptable
        } else {
            return .miss
        }
    }
}
