//
//  SongSelectScene.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

class SongSelectScene: SKScene {
    
    // MARK: - Data Structures
    
    struct Song {
        let title: String
        let beatmapName: String  // Name of the beatmap JSON file (without extension)
        let audioFilename: String
        let songId: String
        let priority: Int
    }
    
    struct SongPack {
        let name: String
        var songs: [Song]
        var isExpanded: Bool = false
    }
    
    // MARK: - State
    
    private var songPacks: [SongPack] = []
    
    private var menuClipNode: SKCropNode!
    private var menuContainer: SKNode!
    private var menuClipHeight: CGFloat = 0
    private var paginationContainer: SKNode!
    private var currentPage: Int = MenuStateStore.shared.currentPage
    private var backButton: SKNode!
    private var difficultySwitcher: DifficultySwitcher!
    
    // Difficulty state (persisted)
    private var selectedDifficulty: DifficultyLevel {
        get { MenuStateStore.shared.selectedDifficulty }
        set { MenuStateStore.shared.selectedDifficulty = newValue }
    }
    
    // Layout constants - now computed from LayoutConstants where appropriate
    private let menuStartY: CGFloat = 0.78
    private let menuWidth: CGFloat = 0.85
    private let menuSpacing: CGFloat = 12
    private let visibleSongCount: Int = 3 // Visible slots per category
    private let songAreaTopPadding: CGFloat = -5  // Slightly overlap header area (used only when scrolling)
    private let songAreaBottomPadding: CGFloat = 25 // Keep space above the bottom border (used only when scrolling)
    private let categoriesPerPage: Int = 2
    
    // Computed layout values from LayoutConstants
    private var collapsedMenuHeight: CGFloat { LayoutConstants.shared.listHeaderHeight }
    private var expandedHeaderHeight: CGFloat { LayoutConstants.shared.listHeaderHeight }
    private var songItemHeight: CGFloat { LayoutConstants.shared.listItemHeight }
    private var menuClipTopInset: CGFloat { LayoutConstants.shared.menuClipTopInset }
    private var menuClipBottomInset: CGFloat { LayoutConstants.shared.menuClipBottomInset }
    private var paginationButtonEdge: CGFloat { LayoutConstants.shared.paginationButtonSize }
    
    // Scroll state per pack and touch tracking
    private var packScrollOffsets: [Int: CGFloat] = [:]
    private var activeScrollPack: Int? = nil
    private var touchStartY: CGFloat = 0
    private var isDragging: Bool = false
    
    // MARK: - Touch State Tracking (for button press validation)
    private var backButtonTouchBegan = false
    private var prevPageButtonTouchBegan = false
    private var nextPageButtonTouchBegan = false
    private var activePackHeader: Int? = nil
    private var activeSongItem: (packIndex: Int, songIndex: Int)? = nil
    
    // Conveyor Belt
    private var conveyorManager: ConveyorBeltManager?
    
    // Debug: tier icon cycling
    #if DEBUG
    private var debugTierOverride: TierRank? = nil
    #endif
    
    // Use shared timer for seamless transitions between scenes
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    override func didMove(to view: SKView) {
        // Configure layout constants for this screen size
        LayoutConstants.configure(for: size)
        
        loadSongsFromBeatmaps()
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
    
    /// Load songs dynamically from beatmap JSON files
    private func loadSongsFromBeatmaps() {
        let categories = BeatmapLoader.shared.discoverSongs()
        let menuState = MenuStateStore.shared
        
        songPacks = categories.map { category in
            let songs = category.songs.map { songInfo in
                Song(
                    title: songInfo.title,
                    beatmapName: songInfo.beatmapName,
                    audioFilename: songInfo.audioFilename,
                    songId: songInfo.id,
                    priority: songInfo.priority
                )
            }
            // Restore expanded state from persisted menu state
            return SongPack(name: category.name, songs: songs, isExpanded: menuState.isPackExpanded(category.name))
        }
        
        print("Loaded \(songPacks.count) song packs with \(songPacks.flatMap { $0.songs }.count) songs")
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Update shared global timer
        globalTimer.update(systemTime: currentTime)
        
        // Update conveyor belt
        conveyorManager?.update()
    }
    
    // MARK: - Background Setup
    
    private func setupBackground() {
        SharedBackground.setupComplete(for: self)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        setupTopBar()
        setupMenuContainer()
        rebuildMenu()
        setupPaginationControls()
        #if DEBUG
        setupDebugTierButton()
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
        
        // Arrow icon using ButtonFactory
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
        
        // Difficulty switcher (top right)
        difficultySwitcher = DifficultySwitcher(initialDifficulty: selectedDifficulty)
        difficultySwitcher.position = CGPoint(x: size.width - layout.edgeMargin - 30, y: layout.topBarY)
        difficultySwitcher.zPosition = 100
        difficultySwitcher.onChange = { [weak self] difficulty in
            guard let self else { return }
            self.selectedDifficulty = difficulty
            self.rebuildMenu()
        }
        addChild(difficultySwitcher)
        
        // Title label (centered)
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = "Songs"
        titleLabel.fontSize = layout.titleFontSize
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - layout.titleTopOffset)
        titleLabel.zPosition = 50
        addChild(titleLabel)
    }
    
    private func setupMenuContainer() {
        menuClipNode = SKCropNode()
        menuClipNode.zPosition = 50
        
        // Visible area for the menu content (keeps content out of the top bar)
        let maxClipHeight = size.height - menuClipTopInset - menuClipBottomInset
        menuClipHeight = maxClipHeight
        
        let maskNode = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: menuClipHeight))
        maskNode.position = CGPoint(x: size.width / 2, y: menuClipBottomInset + menuClipHeight / 2)
        menuClipNode.maskNode = maskNode
        addChild(menuClipNode)
        
        menuContainer = SKNode()
        menuContainer.position = CGPoint(x: size.width / 2, y: size.height * menuStartY)
        menuClipNode.addChild(menuContainer)
    }
    
    private func rebuildMenu() {
        menuContainer.removeAllChildren()
        
        var currentY: CGFloat = 0
        // Use LayoutConstants.menuWidth with max constraint
        let layout = LayoutConstants.shared
        let menuW = min(size.width * menuWidth, layout.maxMenuWidth)
        
        let totalPages = max(1, Int(ceil(Double(songPacks.count) / Double(categoriesPerPage))))
        currentPage = min(currentPage, totalPages - 1)
        MenuStateStore.shared.currentPage = currentPage
        let startIndex = currentPage * categoriesPerPage
        let endIndex = min(startIndex + categoriesPerPage, songPacks.count)
        let pagePacks = Array(songPacks[startIndex..<endIndex])
        
        for (localIndex, pack) in pagePacks.enumerated() {
            let packIndex = startIndex + localIndex
            let packNode = createPackNode(pack: pack, index: packIndex, width: menuW)
            packNode.position = CGPoint(x: 0, y: currentY)
            packNode.name = "pack_\(packIndex)"
            menuContainer.addChild(packNode)
            
            let packHeight = calculatePackHeight(pack: pack)
            currentY -= packHeight + menuSpacing
        }
        
        updatePaginationControls()
    }
    
    private func calculatePackHeight(pack: SongPack) -> CGFloat {
        if pack.isExpanded {
            // Height matches the number of visible songs (packs currently max 3 songs)
            let itemCount = min(visibleSongCount, pack.songs.count)
            return expandedHeaderHeight + CGFloat(itemCount) * songItemHeight
        } else {
            return collapsedMenuHeight
        }
    }

    private func createPackNode(pack: SongPack, index: Int, width: CGFloat) -> SKNode {
        let container = SKNode()
        let layout = LayoutConstants.shared

        if pack.isExpanded {
            let visibleItemCount = min(visibleSongCount, pack.songs.count)
            let songsToRender = Array(pack.songs.prefix(visibleItemCount))
            let visibleHeight = CGFloat(visibleItemCount) * songItemHeight
            let totalHeight = expandedHeaderHeight + visibleHeight

            // Single background for entire expanded menu - use non-uniform scaling
            let expandedBg = SKSpriteNode(imageNamed: "menu-expanded-mid")
            let bgScaleX = width / expandedBg.size.width
            let bgScaleY = totalHeight / expandedBg.size.height
            expandedBg.xScale = bgScaleX
            expandedBg.yScale = bgScaleY
            // Center the background based on its actual scaled height
            expandedBg.position = CGPoint(x: 0, y: -totalHeight / 2)
            expandedBg.zPosition = -1
            container.addChild(expandedBg)
            
            // Header text (at top of expanded area)
            let headerLabel = SKLabelNode(fontNamed: FontConfig.bold)
            headerLabel.text = pack.name
            headerLabel.fontSize = layout.headerFontSize
            headerLabel.fontColor = .white
            headerLabel.verticalAlignmentMode = .center
            headerLabel.horizontalAlignmentMode = .center
            headerLabel.position = CGPoint(x: 0, y: -expandedHeaderHeight / 2)
            headerLabel.zPosition = 1
            container.addChild(headerLabel)
            
            // Caret up (expanded indicator) - solid white
            let caretPath = CGMutablePath()
            caretPath.move(to: CGPoint(x: -6, y: -4))
            caretPath.addLine(to: CGPoint(x: 0, y: 4))
            caretPath.addLine(to: CGPoint(x: 6, y: -4))
            
            let caret = SKShapeNode(path: caretPath)
            caret.fillColor = .clear
            caret.strokeColor = .white
            caret.lineWidth = 3.0
            caret.lineCap = .round
            caret.lineJoin = .round
            caret.glowWidth = 0
            caret.zPosition = 1
            caret.position = CGPoint(x: width / 2 - 35, y: -expandedHeaderHeight / 2)
            container.addChild(caret)
            
            // Create touch area for header (use SKSpriteNode for reliable invisible hit detection)
            let headerTouchArea = SKSpriteNode(color: .clear, size: CGSize(width: width, height: expandedHeaderHeight))
            headerTouchArea.name = "packHeader_\(index)"
            headerTouchArea.position = CGPoint(x: 0, y: -expandedHeaderHeight / 2)
            headerTouchArea.zPosition = 2
            container.addChild(headerTouchArea)
            
            let listCenterOffset: CGFloat = 10 // nudge songs upward to center visually
            let itemAreaCenterY = -expandedHeaderHeight - visibleHeight / 2 + listCenterOffset
            let midIndex = (CGFloat(visibleItemCount) - 1) / 2
            
            for (songIndex, song) in songsToRender.enumerated() {
                let songContainer = SKNode()
                songContainer.name = "songContainer_\(index)_\(songIndex)"
                let songY = itemAreaCenterY + (midIndex - CGFloat(songIndex)) * songItemHeight
                songContainer.position = CGPoint(x: 0, y: songY)
                
                if songIndex > 0 {
                    let dots = SKSpriteNode(imageNamed: "dots")
                    let dotsScale = (width * 0.85) / dots.size.width
                    dots.setScale(dotsScale)
                    dots.position = CGPoint(x: 0, y: songItemHeight / 2 - 5)
                    dots.alpha = 1.0
                    songContainer.addChild(dots)
                }
                
                let songLabel = SKLabelNode(fontNamed: FontConfig.medium)
                songLabel.text = song.title
                songLabel.fontSize = layout.bodyFontSize
                songLabel.fontColor = .white
                songLabel.verticalAlignmentMode = .center
                songLabel.horizontalAlignmentMode = .left
                songLabel.position = CGPoint(x: -width / 2 + 30, y: 0)
                songLabel.zPosition = 1
                songContainer.addChild(songLabel)
                
                #if DEBUG
                let tier = debugTierOverride ?? scorePercentage(for: song, in: pack).map { TierRank.from(percentage: $0) }
                #else
                let tier = scorePercentage(for: song, in: pack).map { TierRank.from(percentage: $0) }
                #endif
                if let tier = tier {
                    let tierIconSize: CGFloat = 40 * layout.scaleFactor
                    let tierIconPosition = CGPoint(x: width / 2 - 35, y: 0)
                    
                    if tier == .S {
                        let particleContainer = SKNode()
                        particleContainer.position = tierIconPosition
                        particleContainer.zPosition = 0.5
                        ParticleFactory.addSTierSparkles(to: particleContainer, iconSize: CGSize(width: tierIconSize, height: tierIconSize))
                        songContainer.addChild(particleContainer)
                    }
                    
                    let tierIcon = SKSpriteNode(imageNamed: tier.iconName)
                    let tierScale = tierIconSize / max(tierIcon.size.width, tierIcon.size.height)
                    tierIcon.setScale(tierScale)
                    tierIcon.position = tierIconPosition
                    tierIcon.zPosition = 1
                    songContainer.addChild(tierIcon)
                }

                let songTouchArea = SKSpriteNode(color: .clear, size: CGSize(width: width, height: songItemHeight))
                songTouchArea.name = "song_\(index)_\(songIndex)"
                songTouchArea.position = CGPoint(x: 0, y: 0)
                songTouchArea.zPosition = -0.5
                songContainer.addChild(songTouchArea)
                
                container.addChild(songContainer)
            }
        } else {
            // Collapsed state - use non-uniform scaling
            let bg = SKSpriteNode(imageNamed: "menu-collapsed")
            let bgScaleX = width / bg.size.width
            let bgScaleY = collapsedMenuHeight / bg.size.height
            bg.xScale = bgScaleX
            bg.yScale = bgScaleY
            bg.position = CGPoint(x: 0, y: -collapsedMenuHeight / 2)
            container.addChild(bg)
            
            // Pack name
            let label = SKLabelNode(fontNamed: FontConfig.bold)
            label.text = pack.name
            label.fontSize = layout.headerFontSize
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -collapsedMenuHeight / 2)
            label.zPosition = 1
            container.addChild(label)
            
            // Caret down (collapsed indicator) - solid white
            let caretPath = CGMutablePath()
            caretPath.move(to: CGPoint(x: -6, y: 4))
            caretPath.addLine(to: CGPoint(x: 0, y: -4))
            caretPath.addLine(to: CGPoint(x: 6, y: 4))
            
            let caret = SKShapeNode(path: caretPath)
            caret.fillColor = .clear
            caret.strokeColor = .white
            caret.lineWidth = 3.0
            caret.lineCap = .round
            caret.lineJoin = .round
            caret.glowWidth = 0
            caret.zPosition = 1
            caret.position = CGPoint(x: width / 2 - 35, y: -collapsedMenuHeight / 2)
            container.addChild(caret)
            
            // Touch area (use SKSpriteNode for reliable invisible hit detection)
            let touchArea = SKSpriteNode(color: .clear, size: CGSize(width: width, height: collapsedMenuHeight))
            touchArea.name = "packHeader_\(index)"
            touchArea.position = CGPoint(x: 0, y: -collapsedMenuHeight / 2)
            touchArea.zPosition = -0.5
            container.addChild(touchArea)
        }
        
        return container
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        touchStartY = location.y
        isDragging = false
        activeScrollPack = nil
        activePackHeader = nil
        activeSongItem = nil
        
        let nodes = nodes(at: location)
        // No scrollable song lists; skip scroll detection
        
        // Track which menu items touch began on
        for node in nodes {
            if let name = node.name {
                if name.hasPrefix("packHeader_") {
                    if let indexStr = name.split(separator: "_").last,
                       let index = Int(indexStr) {
                        activePackHeader = index
                    }
                }
                if name.hasPrefix("song_") {
                    let parts = name.split(separator: "_")
                    if parts.count == 3,
                       let packIndex = Int(parts[1]),
                       let songIndex = Int(parts[2]) {
                        activeSongItem = (packIndex, songIndex)
                    }
                }
            }
        }
        
        // Check pagination buttons
        if nodes.contains(where: { $0.name == "prevPageButton" || $0.parent?.name == "prevPageButton" }) {
            prevPageButtonTouchBegan = true
        }
        if nodes.contains(where: { $0.name == "nextPageButton" || $0.parent?.name == "nextPageButton" }) {
            nextPageButtonTouchBegan = true
        }
        
        // Check back button - only scale feedback for back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if abs(backLocation.x) < 40 && abs(backLocation.y) < 40 {
                backButtonTouchBegan = true
                back.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
        // No visual feedback for menu items to avoid gray color issues
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let totalDelta = abs(location.y - touchStartY)
        
        // Start dragging if moved more than threshold
        if totalDelta > 8 {
            isDragging = true
        }
        
        if isDragging, let packIndex = activeScrollPack {
            let previous = touch.previousLocation(in: self)
            let deltaY = location.y - previous.y
            scrollPackSongList(packIndex: packIndex, delta: deltaY)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Reset back button
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        
        // If we were dragging, don't process taps
        if isDragging {
            isDragging = false
            activeScrollPack = nil
            resetTouchState()
            return
        }
        
        activeScrollPack = nil
        
        // Pagination buttons - only trigger if touch began on same button
        if prevPageButtonTouchBegan && nodes.contains(where: { $0.name == "prevPageButton" || $0.parent?.name == "prevPageButton" }) {
            resetTouchState()
            AudioManager.shared.playUISound(.button)
            changePage(by: -1)
            return
        }
        if nextPageButtonTouchBegan && nodes.contains(where: { $0.name == "nextPageButton" || $0.parent?.name == "nextPageButton" }) {
            resetTouchState()
            AudioManager.shared.playUISound(.button)
            changePage(by: 1)
            return
        }
        
        // Check debug tier button
        #if DEBUG
        if nodes.contains(where: { $0.name == "debugTierButton" || $0.parent?.name == "debugTierButton" }) {
            cycleDebugTier()
            resetTouchState()
            return
        }
        #endif
        
        // Check back button - only trigger if touch began on it
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if backButtonTouchBegan && abs(backLocation.x) < 40 && abs(backLocation.y) < 40 {
                resetTouchState()
                difficultySwitcher.closeDropdown()
                AudioManager.shared.playUISound(.buttonBack)
                transitionToStartScene()
                return
            }
        }
        
        // Check difficulty switcher (handles dropdown and button)
        if difficultySwitcher.handleTouchEnded(location: location, nodes: nodes) {
            resetTouchState()
            return
        }
        
        // Check menu items - only trigger if touch began on same item
        for node in nodes {
            if let name = node.name {
                if name.hasPrefix("packHeader_") {
                    if let indexStr = name.split(separator: "_").last,
                       let index = Int(indexStr),
                       activePackHeader == index {
                        resetTouchState()
                        togglePack(at: index)
                        return
                    }
                }
                
                if name.hasPrefix("song_") {
                    let parts = name.split(separator: "_")
                    if parts.count == 3,
                       let packIndex = Int(parts[1]),
                       let songIndex = Int(parts[2]),
                       activeSongItem?.packIndex == packIndex,
                       activeSongItem?.songIndex == songIndex {
                        resetTouchState()
                        AudioManager.shared.playUISound(.button)
                        playSong(packIndex: packIndex, songIndex: songIndex)
                        return
                    }
                }
            }
        }
        
        resetTouchState()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        isDragging = false
        activeScrollPack = nil
        resetTouchState()
    }
    
    private func resetTouchState() {
        backButtonTouchBegan = false
        prevPageButtonTouchBegan = false
        nextPageButtonTouchBegan = false
        activePackHeader = nil
        activeSongItem = nil
    }
    
    // MARK: - Scroll Helpers
    
    private func scrollPackSongList(packIndex: Int, delta: CGFloat) {
        guard packIndex < songPacks.count else { return }
        let pack = songPacks[packIndex]
        guard pack.isExpanded else { return }
        guard pack.songs.count > visibleSongCount else { return }
        
        let currentOffset = packScrollOffsets[packIndex] ?? 0
        var newOffset = currentOffset + delta
        
        let totalContentHeight = CGFloat(pack.songs.count) * songItemHeight
        let visibleHeight = CGFloat(min(visibleSongCount, pack.songs.count)) * songItemHeight
        let adjustedVisibleHeight = visibleHeight - songAreaBottomPadding - songAreaTopPadding
        let maxScroll = max(0, totalContentHeight - adjustedVisibleHeight)
        
        newOffset = min(maxScroll, max(0, newOffset))
        packScrollOffsets[packIndex] = newOffset
        updatePackScrollPosition(packIndex: packIndex)
    }
    
    private func updatePackScrollPosition(packIndex: Int) {
        guard let packNode = menuContainer.childNode(withName: "pack_\(packIndex)"),
              let cropNode = packNode.childNode(withName: "songCrop_\(packIndex)") as? SKCropNode,
              let scrollContent = cropNode.childNode(withName: "scrollContent_\(packIndex)") else {
            return
        }
        
        let pack = songPacks[packIndex]
        let offset = packScrollOffsets[packIndex] ?? 0
        let visibleItems = min(visibleSongCount, pack.songs.count)
        let visibleHeight = CGFloat(visibleItems) * songItemHeight
        let adjustedVisibleHeight = visibleHeight - songAreaBottomPadding - songAreaTopPadding
        scrollContent.position = CGPoint(x: 0, y: adjustedVisibleHeight / 2 - songItemHeight / 2 + offset)
    }
    
    // MARK: - Actions
    
    private func togglePack(at index: Int) {
        guard index < songPacks.count else { return }
        let wasExpanded = songPacks[index].isExpanded
        songPacks[index].isExpanded.toggle()
        // Persist the expanded state
        MenuStateStore.shared.setPackExpanded(songPacks[index].name, expanded: songPacks[index].isExpanded)
        // Play sound for expand/collapse
        AudioManager.shared.playUISound(wasExpanded ? .categoryCollapse : .categoryExpand)
        rebuildMenu()
    }
    
    private func playSong(packIndex: Int, songIndex: Int) {
        guard packIndex < songPacks.count,
              songIndex < songPacks[packIndex].songs.count else { return }
        
        difficultySwitcher.closeDropdown()
        let pack = songPacks[packIndex]
        let song = pack.songs[songIndex]
        
        // Prepare timer for smooth transition
        globalTimer.prepareForSceneTransition()
        
        // Transition to song detail scene instead of directly to play scene
        let detailScene = SongDetailScene(size: size)
        detailScene.scaleMode = scaleMode
        detailScene.songTitle = song.title
        detailScene.songFilename = song.beatmapName  // Use beatmap name (matches audio file base name)
        detailScene.songId = song.songId
        detailScene.selectedDifficulty = selectedDifficulty
        view?.presentScene(detailScene)
    }
    
    private func transitionToStartScene() {
        // Prepare timer for smooth transition
        globalTimer.prepareForSceneTransition()
        
        let startScene = StartScene(size: size)
        startScene.scaleMode = scaleMode
        view?.presentScene(startScene)
    }
    
    private func colorForScore(_ percentage: Double?) -> SKColor {
        guard let percentage = percentage else {
            return SKColor(white: 0.8, alpha: 1.0)
        }
        if percentage < 20.0 {
            return .red
        }
        if percentage < 80.0 {
            return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        }
        return SKColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
    }
    
    private func scorePercentage(for song: Song, in pack: SongPack) -> Double? {
        return SongScoreStore.shared.bestPercentage(for: song.songId, difficulty: selectedDifficulty)
    }
    
    // MARK: - Pagination
    
    private func setupPaginationControls() {
        paginationContainer?.removeFromParent()
        
        paginationContainer = SKNode()
        paginationContainer.zPosition = 120
        
        // Place pagination within the reserved bottom inset so categories don't overlap
        let yPos: CGFloat = menuClipBottomInset * 0.6
        
        let prevButton = createPaginationButton(name: "prevPageButton", isLeft: true)
        prevButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(prevButton)
        
        let nextButton = createPaginationButton(name: "nextPageButton", isLeft: false)
        nextButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(nextButton)
        
        let indicatorLabel = SKLabelNode(fontNamed: FontConfig.bold)
        indicatorLabel.name = "pageIndicator"
        indicatorLabel.fontSize = 22
        indicatorLabel.fontColor = .white
        indicatorLabel.verticalAlignmentMode = .center
        indicatorLabel.horizontalAlignmentMode = .center
        indicatorLabel.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(indicatorLabel)
        
        addChild(paginationContainer)
        updatePaginationControls()
    }
    
    private func createPaginationButton(name: String, isLeft: Bool) -> SKNode {
        let buttonNode = SKNode()
        buttonNode.name = name
        
        let bg = SKSpriteNode(imageNamed: "button-square")
        let scale = paginationButtonEdge / max(bg.size.width, bg.size.height)
        bg.setScale(scale)
        bg.zPosition = 0
        buttonNode.addChild(bg)
        
        let arrowPath = CGMutablePath()
        let direction: CGFloat = isLeft ? -1 : 1
        arrowPath.move(to: CGPoint(x: -8 * direction, y: -6))
        arrowPath.addLine(to: CGPoint(x: 8 * direction, y: 0))
        arrowPath.addLine(to: CGPoint(x: -8 * direction, y: 6))
        let arrow = SKShapeNode(path: arrowPath)
        arrow.strokeColor = .white
        arrow.lineWidth = 3.0
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.position = .zero
        arrow.zPosition = 1
        buttonNode.addChild(arrow)
        
        return buttonNode
    }
    
    private func layoutPaginationPositions() {
        guard let paginationContainer else { return }
        guard
            let prevButton = paginationContainer.childNode(withName: "prevPageButton"),
            let nextButton = paginationContainer.childNode(withName: "nextPageButton"),
            let indicatorLabel = paginationContainer.childNode(withName: "pageIndicator") as? SKLabelNode
        else { return }
        
        let yPos = menuClipBottomInset * 0.6
        let buttonWidth = prevButton.calculateAccumulatedFrame().width
        let indicatorWidth = indicatorLabel.frame.width
        let spacing: CGFloat = 6
        
        let centerX = size.width / 2
        indicatorLabel.position = CGPoint(x: centerX, y: yPos)
        prevButton.position = CGPoint(x: centerX - (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
        nextButton.position = CGPoint(x: centerX + (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
    }
    
    private func updatePaginationControls() {
        guard let indicatorLabel = paginationContainer?.childNode(withName: "pageIndicator") as? SKLabelNode else { return }
        let totalPages = max(1, Int(ceil(Double(songPacks.count) / Double(categoriesPerPage))))
        indicatorLabel.text = "\(currentPage + 1) / \(totalPages)"
        
        if let prevButton = paginationContainer?.childNode(withName: "prevPageButton") as? SKNode {
            prevButton.alpha = currentPage > 0 ? 1.0 : 0.4
        }
        if let nextButton = paginationContainer?.childNode(withName: "nextPageButton") as? SKNode {
            nextButton.alpha = currentPage < totalPages - 1 ? 1.0 : 0.4
        }
        
        layoutPaginationPositions()
    }
    
    private func changePage(by delta: Int) {
        let totalPages = max(1, Int(ceil(Double(songPacks.count) / Double(categoriesPerPage))))
        let newPage = min(max(0, currentPage + delta), totalPages - 1)
        guard newPage != currentPage else { return }
        currentPage = newPage
        MenuStateStore.shared.currentPage = newPage
        rebuildMenu()
    }
    
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
        
        // Rebuild menu to show updated icons
        rebuildMenu()
    }
    #endif
}
