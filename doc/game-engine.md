# Game Engine

Location: `Beat Kanji/Game/GameEngine.swift`

## State

- `score`, `lives`: Player stats
- `currentKanji`, `currentStrokeIndex`: Current drawing target
- `strokeArrivalTimes`: When each stroke should land (from beatmap)
- `beatEvents`: Mapping of beat times to kanji strokes
- `selectedKanjiSequence`: Pre-selected kanji list for the song

## Callbacks

- `onGameOver`: Triggered when lives reach 0
- `onStrokeMiss`: Triggered on timeout miss
- `onKanjiCompleted`: Triggered when a kanji is fully drawn
- `onSongCompleted`: Triggered when all beat events are done

## Beatmap Integration

### Flow

1. `startGameWithBeatmap(kanjiList:beatmap:difficulty:)`:

   - Filters beatmap notes by difficulty level
   - Selects random kanji sequence to match beat notes (inserting gaps between kanji)
   - Creates beat events mapping notes → strokes
   - Loads first kanji

2. `update(deltaTime:)`:

   - Advances `currentTime`
   - Checks for stroke timeout (0.3s grace period)
   - Triggers miss and auto-advance if needed
   - Calls `onSongCompleted` when all events processed

3. `advanceStroke()`:

   - Increments stroke and beat event indices
   - Returns true if kanji is complete

4. `nextKanjiInSequence()`:
   - Moves to next kanji in pre-selected sequence
   - Generates stroke arrival times from beat events

### Kanji Selection Algorithm

```swift
selectKanjiForStrokeCount(from: kanjiList, targetStrokeCount: Int)
```

- Randomly selects kanji until total strokes match beat count
- Tries to find exact-fit kanji when close to target
- Ensures no stray beat markers (every beat has a stroke)

### Look-ahead Support

```swift
getUpcomingBeatEvents(count:afterTime:) -> [StrokeBeatEvent]
hasUpcomingNextKanjiStrokes(withinTime:) -> Bool
```

Enables spawning next kanji strokes before current kanji completes.

## Timing Constants

- `flightDuration`: Time for stroke to travel from spawn to player (2.0s)
- `bpm`: Beats per minute from beatmap (affects conveyor speed)

## Rainbow Strokes

- Spawn chance: `1/20` per stroke while the player is below max lives (pre-tagged in beat events).
- Effect: Visible only when not at full health; a perfect rainbow stroke restores 1 life.
