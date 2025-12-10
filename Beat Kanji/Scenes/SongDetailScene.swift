//
//  SongDetailScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

class SongDetailScene: SKScene {
    
    // MARK: - Song Info (set before presenting)
    var songTitle: String = ""
    var songFilename: String = ""
    var songId: String = ""
    var selectedDifficulty: DifficultyLevel = .easy
    
    // MARK: - UI Elements
    private var backButton: SKNode!
    private var difficultySwitcher: DifficultySwitcher!
    private var playButton: SKNode!
    private var playButtonBg: SKSpriteNode!
    private var kanjiList: CheckboxListComponent!
    private var kanaList: CheckboxListComponent!
    private var titleLabel: SKLabelNode!
    private var tierIcon: SKSpriteNode?
    private var tierParticleContainer: SKNode?
    private var highScoreLabel: SKLabelNode!
    
    // MARK: - Conveyor Belt
    private var conveyorManager: ConveyorBeltManager?
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // Debug: tier icon cycling
    #if DEBUG
    private var debugTierOverride: TierRank? = nil
    private var debugTutorialTouchBegan = false
    private var debugKanjiTouchBegan = false
    #endif
    
    // MARK: - Layout Constants (computed from LayoutConstants)
    private var menuWidth: CGFloat { min(size.width * 0.85, LayoutConstants.shared.maxMenuWidth) / size.width }
    private var contentTopOffset: CGFloat { LayoutConstants.shared.titleTopOffset }
    private let titleToTierSpacing: CGFloat = 55
    private let tierToScoreSpacing: CGFloat = 60
    private let scoreToListSpacing: CGFloat = 20

    private var titleYPosition: CGFloat { size.height - contentTopOffset }
    private var tierIconYPosition: CGFloat { titleYPosition - titleToTierSpacing }
    private var highScoreYPosition: CGFloat { tierIconYPosition - tierToScoreSpacing }
    private var categoryListYPosition: CGFloat { highScoreYPosition - scoreToListSpacing }
    
    // MARK: - Touch Tracking
    private var isDragging: Bool = false
    private var touchStartY: CGFloat = 0
    private var lastTouchY: CGFloat = 0
    private var activeScrollList: CheckboxListComponent?
    
    // MARK: - Touch State Tracking (for button press validation)
    private var backButtonTouchBegan = false
    private var playButtonTouchBegan = false
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        // Configure layout constants for this screen size
        LayoutConstants.configure(for: size)
        
        setupBackground()
        setupUI()
        
        // Start conveyor belt
        if let gridNode = children.first(where: { $0.zPosition == -98 }) {
            conveyorManager = ConveyorBeltManager(scene: self, gridNode: gridNode)
            conveyorManager?.start()
        }
        
        // Play menu music
        AudioManager.shared.playMenuMusic()
    }
    
    override func update(_ currentTime: TimeInterval) {
        globalTimer.update(systemTime: currentTime)
        conveyorManager?.update()
    }
    
    // MARK: - Setup
    
    private func setupBackground() {
        SharedBackground.setupComplete(for: self)
    }
    
    private func setupUI() {
        setupTopBar()
        setupSongInfo()
        setupCategoryLists()
        setupPlayButton()
        updatePlayButtonState()
        #if DEBUG
        setupDebugTierButton()
        setupDebugTutorialButton()
        setupDebugKanjiButton()
        #endif
    }
    
    private func setupTopBar() {
        let layout = LayoutConstants.shared
        
        // Back button (top left)
        backButton = SKNode()
        backButton.name = "backButton"
        backButton.position = CGPoint(x: layout.edgeMargin, y: layout.topBarY)
        backButton.zPosition = 100
        
        let backBg = SKSpriteNode(imageNamed: "button-square")
        let backScale: CGFloat = layout.squareButtonSize / max(backBg.size.width, backBg.size.height)
        backBg.setScale(backScale)
        backButton.addChild(backBg)
        
        // Arrow icon
        let arrowPath = ButtonFactory.backArrowPath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .clear
        arrow.strokeColor = .white
        arrow.lineWidth = 3.5
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.glowWidth = 0
        arrow.zPosition = 1
        backButton.addChild(arrow)
        
        addChild(backButton)
        
        difficultySwitcher = DifficultySwitcher(initialDifficulty: selectedDifficulty)
        difficultySwitcher.position = CGPoint(x: size.width - layout.edgeMargin - 30, y: layout.topBarY)
        difficultySwitcher.zPosition = 100
        difficultySwitcher.onChange = { [weak self] difficulty in
            guard let self else { return }
            self.selectedDifficulty = difficulty
            // Persist difficulty change
            MenuStateStore.shared.selectedDifficulty = difficulty
            self.refreshHighScoreLabel()
        }
        addChild(difficultySwitcher)
    }
    
    private func setupSongInfo() {
        let layout = LayoutConstants.shared
        let centerX = size.width / 2

        // Song title
        titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = songTitle
        titleLabel.fontSize = layout.titleFontSize
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: centerX, y: titleYPosition)
        titleLabel.zPosition = 50
        addChild(titleLabel)
        adjustTitleLabelForOverflow()
        
        // Tier icon (will be shown/hidden based on score)
        tierIcon = SKSpriteNode()
        if let icon = tierIcon {
            icon.position = CGPoint(x: centerX, y: tierIconYPosition)
            icon.zPosition = 50
            icon.isHidden = true
            addChild(icon)
        }
        
        // Particle container for S tier (positioned behind icon)
        tierParticleContainer = SKNode()
        if let container = tierParticleContainer {
            container.position = CGPoint(x: centerX, y: tierIconYPosition)
            container.zPosition = 49
            container.isHidden = true
            addChild(container)
        }
        
        // High score
        highScoreLabel = SKLabelNode(fontNamed: FontConfig.medium)
        highScoreLabel.fontSize = layout.bodyFontSize
        highScoreLabel.fontColor = .white
        highScoreLabel.verticalAlignmentMode = .center
        highScoreLabel.horizontalAlignmentMode = .center
        highScoreLabel.position = CGPoint(x: centerX, y: highScoreYPosition)
        highScoreLabel.zPosition = 50
        addChild(highScoreLabel)
        
        refreshHighScoreLabel()
    }

    /// Shrinks the song title if it would overflow the screen width.
    private func adjustTitleLabelForOverflow() {
        let maxWidth = size.width * 0.84 // leave comfortable margins on both sides
        var currentFontSize = titleLabel.fontSize

        // Step down the font size until it fits or we reach a sensible minimum.
        while titleLabel.frame.width > maxWidth && currentFontSize > 18 {
            currentFontSize -= 1
            titleLabel.fontSize = currentFontSize
        }

        // If it still doesn't fit (very long titles), scale proportionally once.
        if titleLabel.frame.width > maxWidth {
            let scale = maxWidth / titleLabel.frame.width
            titleLabel.fontSize *= scale
        }
    }
    
    private func setupCategoryLists() {
        let menuW = size.width * menuWidth
        let centerX = size.width / 2
        let prefs = CategoryPreferenceStore.shared
        
        // Kanji list (N5-N1)
        let kanjiItems = KanjiCategory.kanjiCategories.map { category in
            CheckboxListComponent.Item(
                id: category.rawValue,
                title: category.displayName,
                isChecked: prefs.isEnabled(category)
            )
        }
        
        kanjiList = CheckboxListComponent(
            title: "Kanji",
            items: kanjiItems,
            width: menuW,
            useSmallBackground: false,
            onItemToggled: { [weak self] id, isChecked in
                if let category = KanjiCategory(rawValue: id) {
                    CategoryPreferenceStore.shared.setEnabled(category, enabled: isChecked)
                    self?.updatePlayButtonState()
                }
            }
        )
        kanjiList.position = CGPoint(x: centerX, y: categoryListYPosition)
        kanjiList.zPosition = 50
        addChild(kanjiList)
        
        // Kana list (Hiragana, Katakana)
        let kanaItems = KanjiCategory.kanaCategories.map { category in
            CheckboxListComponent.Item(
                id: category.rawValue,
                title: category.displayName,
                isChecked: prefs.isEnabled(category)
            )
        }
        
        kanaList = CheckboxListComponent(
            title: "Kana",
            items: kanaItems,
            width: menuW,
            useSmallBackground: true,
            onItemToggled: { [weak self] id, isChecked in
                if let category = KanjiCategory(rawValue: id) {
                    CategoryPreferenceStore.shared.setEnabled(category, enabled: isChecked)
                    self?.updatePlayButtonState()
                }
            }
        )
        
        // Position kana list below kanji list
        let kanjiListBottom = kanjiList.position.y - kanjiList.totalHeight()
        kanaList.position = CGPoint(x: centerX, y: kanjiListBottom - 10)
        kanaList.zPosition = 50
        addChild(kanaList)
    }
    
    private func setupPlayButton() {
        let layout = LayoutConstants.shared
        playButton = SKNode()
        playButton.name = "playButton"
        playButton.position = CGPoint(x: size.width / 2, y: layout.paginationBottomOffset)
        playButton.zPosition = 100
        
        let buttonBg = SKSpriteNode(imageNamed: "button")
        let targetWidth = layout.standardButtonWidth
        let scale = targetWidth / buttonBg.size.width
        buttonBg.setScale(scale)
        buttonBg.name = "playButtonBg"
        playButton.addChild(buttonBg)
        playButtonBg = buttonBg
        
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "Play"
        label.fontSize = layout.headerFontSize + 4
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        label.name = "playButtonLabel"
        playButton.addChild(label)
        
        addChild(playButton)
    }
    
    private func updatePlayButtonState() {
        let hasAnyEnabled = CategoryPreferenceStore.shared.hasAnyEnabled
        
        // Visual feedback - dim the button if disabled
        let alpha: CGFloat = hasAnyEnabled ? 1.0 : 0.4
        playButton.alpha = alpha
        
        // Store state for touch handling
        playButton.userData = ["enabled": hasAnyEnabled]
    }
    
    private func refreshHighScoreLabel() {
        guard let highScoreLabel else { return }
        
        #if DEBUG
        let displayTier = debugTierOverride
        let displayPercentage: Double? = debugTierOverride != nil ? 95.0 : SongScoreStore.shared.bestPercentage(for: songId, difficulty: selectedDifficulty)
        #else
        let displayPercentage = SongScoreStore.shared.bestPercentage(for: songId, difficulty: selectedDifficulty)
        #endif
        
        let scoreText: String
        if let percentage = displayPercentage {
            scoreText = "(\(Int(round(percentage)))%)"
            
            // Update tier icon
            #if DEBUG
            let tier = displayTier ?? TierRank.from(percentage: percentage)
            #else
            let tier = TierRank.from(percentage: percentage)
            #endif
            
            if let icon = tierIcon {
                // Reset scale before changing texture to avoid compounding
                icon.setScale(1.0)
                icon.texture = SKTexture(imageNamed: tier.iconName)
                icon.size = icon.texture?.size() ?? CGSize(width: 100, height: 100)
                let tierIconSize: CGFloat = 100
                let tierScale = tierIconSize / max(icon.size.width, icon.size.height)
                icon.setScale(tierScale)
                icon.isHidden = false
            }
            
            // Show particles for S tier only
            if let container = tierParticleContainer {
                container.removeAllChildren()
                if tier == .S {
                    ParticleFactory.addSTierSparkles(to: container, iconSize: CGSize(width: 100, height: 100))
                    container.isHidden = false
                } else {
                    container.isHidden = true
                }
            }
        } else {
            scoreText = "No score yet"
            tierIcon?.isHidden = true
            tierParticleContainer?.isHidden = true
        }

        highScoreLabel.text = scoreText
        highScoreLabel.fontColor = .white
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        touchStartY = location.y
        lastTouchY = location.y
        isDragging = false
        activeScrollList = nil
        
        let dropdownOpen = difficultySwitcher.isDropdownOpen
        
        // Check if touch starts in a scrollable list
        if !dropdownOpen {
            if kanjiList.touchBegan(at: location) {
                activeScrollList = kanjiList
            } else if kanaList.touchBegan(at: location) {
                activeScrollList = kanaList
            }
        }
        
        // Check back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if abs(backLocation.x) < 40 && abs(backLocation.y) < 40 {
                backButtonTouchBegan = true
                back.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
        
        // Check play button
        if let play = playButton {
            let playLocation = touch.location(in: play)
            if abs(playLocation.x) < 100 && abs(playLocation.y) < 30 {
                let isEnabled = (play.userData?["enabled"] as? Bool) ?? true
                if isEnabled {
                    playButtonTouchBegan = true
                    play.run(SKAction.scale(to: 0.95, duration: 0.1))
                }
            }
        }

        #if DEBUG
        if let debugTutorial = childNode(withName: "debugTutorialButton") {
            let local = touch.location(in: debugTutorial)
            if abs(local.x) < 60 && abs(local.y) < 18 {
                debugTutorialTouchBegan = true
                debugTutorial.run(SKAction.scale(to: 0.95, duration: 0.1))
            }
        }
        if let debugKanji = childNode(withName: "debugKanjiButton") {
            let local = touch.location(in: debugKanji)
            if abs(local.x) < 90 && abs(local.y) < 18 {
                debugKanjiTouchBegan = true
                debugKanji.run(SKAction.scale(to: 0.95, duration: 0.1))
            }
        }
        #endif
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if difficultySwitcher.isDropdownOpen {
            return
        }
        
        let totalDelta = abs(location.y - touchStartY)
        if totalDelta > 8 {
            isDragging = true
        }
        
        // Handle scrolling in active list
        if isDragging, let list = activeScrollList {
            _ = list.touchMoved(to: location)
        }
        
        lastTouchY = location.y
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Reset button scales
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        playButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        #if DEBUG
        childNode(withName: "debugTutorialButton")?.run(SKAction.scale(to: 1.0, duration: 0.1))
        childNode(withName: "debugKanjiButton")?.run(SKAction.scale(to: 1.0, duration: 0.1))
        #endif
        
        if difficultySwitcher.isDropdownOpen && difficultySwitcher.handleTouchEnded(location: location, nodes: nodes) {
            isDragging = false
            activeScrollList = nil
            backButtonTouchBegan = false
            playButtonTouchBegan = false
            return
        }
        
        // If scrolling list, end scroll and check if it was a tap
        if let list = activeScrollList {
            if list.touchEnded(at: location, wasDragging: isDragging) {
                updateListPositions()
                isDragging = false
                activeScrollList = nil
                backButtonTouchBegan = false
                playButtonTouchBegan = false
                return
            }
        }
        
        // If we were dragging, don't process taps
        if isDragging {
            isDragging = false
            activeScrollList = nil
            backButtonTouchBegan = false
            playButtonTouchBegan = false
            return
        }
        
        activeScrollList = nil
        
        // Check debug tier button
        #if DEBUG
        if nodes.contains(where: { $0.name == "debugTierButton" || $0.parent?.name == "debugTierButton" }) {
            cycleDebugTier()
            backButtonTouchBegan = false
            playButtonTouchBegan = false
            debugTutorialTouchBegan = false
            return
        }
        if nodes.contains(where: { $0.name == "debugTutorialButton" || $0.parent?.name == "debugTutorialButton" }) {
            if debugTutorialTouchBegan {
                AudioManager.shared.playUISound(.button)
                presentTutorial(force: true)
            }
            backButtonTouchBegan = false
            playButtonTouchBegan = false
            debugTutorialTouchBegan = false
            return
        }
        if nodes.contains(where: { $0.name == "debugKanjiButton" || $0.parent?.name == "debugKanjiButton" }) {
            if debugKanjiTouchBegan {
                AudioManager.shared.playUISound(.button)
                presentDebugKanjiPlayScene()
            }
            backButtonTouchBegan = false
            playButtonTouchBegan = false
            debugTutorialTouchBegan = false
            debugKanjiTouchBegan = false
            return
        }
        #endif
        
        // Check back button - only trigger if touch began on it
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if backButtonTouchBegan && abs(backLocation.x) < 40 && abs(backLocation.y) < 40 {
                backButtonTouchBegan = false
                playButtonTouchBegan = false
                AudioManager.shared.playUISound(.buttonBack)
                transitionToSongSelect()
                return
            }
        }
        backButtonTouchBegan = false
        
        if difficultySwitcher.handleTouchEnded(location: location, nodes: nodes) {
            playButtonTouchBegan = false
            return
        }
        
        // Check play button - only trigger if touch began on it
        if let play = playButton {
            let playLocation = touch.location(in: play)
            if playButtonTouchBegan && abs(playLocation.x) < 100 && abs(playLocation.y) < 30 {
                let isEnabled = (play.userData?["enabled"] as? Bool) ?? true
                if isEnabled {
                    playButtonTouchBegan = false
                    AudioManager.shared.playUISound(.button)
                    startGame()
                    return
                }
            }
        }
        playButtonTouchBegan = false
        
        // Check category lists (for taps) - check kana first since it's positioned below
        if kanaList.handleTouch(at: location) {
            updateListPositions()
            return
        }
        
        if kanjiList.handleTouch(at: location) {
            updateListPositions()
            return
        }
        #if DEBUG
        debugTutorialTouchBegan = false
        debugKanjiTouchBegan = false
        #endif
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        playButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        #if DEBUG
        childNode(withName: "debugTutorialButton")?.run(SKAction.scale(to: 1.0, duration: 0.1))
        childNode(withName: "debugKanjiButton")?.run(SKAction.scale(to: 1.0, duration: 0.1))
        debugTutorialTouchBegan = false
        debugKanjiTouchBegan = false
        #endif
        isDragging = false
        activeScrollList = nil
        backButtonTouchBegan = false
        playButtonTouchBegan = false
    }
    
    // MARK: - Layout Updates
    
    private func updateListPositions() {
        // Reposition kana list when kanji list expands/collapses
        let kanjiListBottom = kanjiList.position.y - kanjiList.totalHeight()
        kanaList.position = CGPoint(x: size.width / 2, y: kanjiListBottom - 20)
    }
    
    // MARK: - Navigation
    
    private func transitionToSongSelect() {
        globalTimer.prepareForSceneTransition()
        difficultySwitcher.closeDropdown()
        
        let songSelectScene = SongSelectScene(size: size)
        songSelectScene.scaleMode = scaleMode
        view?.presentScene(songSelectScene)
    }
    
    private func startGame() {
        difficultySwitcher.closeDropdown()
        presentTutorial(force: false)
    }

    private func presentTutorial(force: Bool) {
        if !force && TutorialStore.shared.hasCompletedTutorial {
            presentPlayScene()
            return
        }
        let tutorialScene = TutorialScene(size: size)
        tutorialScene.scaleMode = scaleMode
        tutorialScene.selectedDifficulty = selectedDifficulty
        tutorialScene.songId = songId
        tutorialScene.songFilename = songFilename
        tutorialScene.songTitle = songTitle
        tutorialScene.enabledTags = CategoryPreferenceStore.shared.enabledTags
        view?.presentScene(tutorialScene)
    }
    
    private func presentPlayScene() {
        let playScene = PlayScene(size: size)
        playScene.scaleMode = scaleMode
        playScene.selectedDifficulty = selectedDifficulty
        playScene.selectedSongId = songId
        playScene.selectedSongFilename = songFilename
        playScene.selectedSongTitle = songTitle
        playScene.enabledTags = CategoryPreferenceStore.shared.enabledTags
        view?.presentScene(playScene)
    }
    
    #if DEBUG
    private func presentDebugKanjiPlayScene() {
        let playScene = PlayScene(size: size)
        playScene.scaleMode = scaleMode
        playScene.selectedDifficulty = selectedDifficulty
        playScene.selectedSongId = songId
        playScene.selectedSongFilename = songFilename
        playScene.selectedSongTitle = songTitle + " [debug 南/青]"
        playScene.enabledTags = KanjiCategory.allTags // allow any tags
        playScene.debugForcedKanjiIds = ["南", "青"]
        view?.presentScene(playScene)
    }
    #endif
    
    // MARK: - Debug Tier Cycling
    
    #if DEBUG
    private func setupDebugTierButton() {
        let tierButton = SKNode()
        tierButton.name = "debugTierButton"
        tierButton.position = CGPoint(x: 60, y: 50)
        tierButton.zPosition = 250
        
        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: 80, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        tierButton.addChild(bg)
        
        // Label
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "TIER ⏭"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "debugTierLabel"
        tierButton.addChild(label)
        
        addChild(tierButton)
    }

    private func setupDebugTutorialButton() {
        let tutorialButton = SKNode()
        tutorialButton.name = "debugTutorialButton"
        tutorialButton.position = CGPoint(x: size.width - 60, y: 50)
        tutorialButton.zPosition = 250
        
        let bg = SKShapeNode(rectOf: CGSize(width: 120, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        tutorialButton.addChild(bg)
        
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "TUTORIAL"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "debugTutorialLabel"
        tutorialButton.addChild(label)
        
        addChild(tutorialButton)
    }
    
    private func setupDebugKanjiButton() {
        let btn = SKNode()
        btn.name = "debugKanjiButton"
        btn.position = CGPoint(x: size.width / 2, y: 50)
        btn.zPosition = 250
        
        let bg = SKShapeNode(rectOf: CGSize(width: 180, height: 36), cornerRadius: 8)
        bg.fillColor = SKColor(white: 0.2, alpha: 0.7)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        btn.addChild(bg)
        
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = "DEBUG 南 + 青"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = "debugKanjiLabel"
        btn.addChild(label)
        
        addChild(btn)
    }
    
    private func cycleDebugTier() {
        let allTiers: [TierRank?] = [nil, .S, .A, .B, .C, .D]
        let currentIndex = allTiers.firstIndex(where: { $0 == debugTierOverride }) ?? 0
        let nextIndex = (currentIndex + 1) % allTiers.count
        debugTierOverride = allTiers[nextIndex]
        
        // Update button label to show current tier
        if let button = childNode(withName: "debugTierButton"),
           let label = button.childNode(withName: "debugTierLabel") as? SKLabelNode {
            if let tier = debugTierOverride {
                label.text = "TIER: \(tier.rawValue)"
            } else {
                label.text = "TIER ⏭"
            }
        }
        
        // Refresh display
        refreshHighScoreLabel()
    }
    #endif
}
