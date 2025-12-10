//
//  TutorialScene.swift
//  Beat Kanji
//
//  Tutorial scene displayed before a user's first game.
//

import SpriteKit

class TutorialScene: SKScene {
    
    // MARK: - Tutorial Page Data
    
    private struct TutorialPage {
        let titleKey: String
        let imageName: String
        let bodyKey: String
    }

    private let pages: [TutorialPage] = [
        TutorialPage(
            titleKey: "tutorial.basics.title",
            imageName: "tutorial-start",
            bodyKey: "tutorial.basics.body"
        ),
        TutorialPage(
            titleKey: "tutorial.strokes.title",
            imageName: "tutorial-swipe-stroke",
            bodyKey: "tutorial.strokes.body"
        ),
        TutorialPage(
            titleKey: "tutorial.hearts.title",
            imageName: "tutorial-lose-heart",
            bodyKey: "tutorial.hearts.body"
        ),
        TutorialPage(
            titleKey: "tutorial.rainbow.title",
            imageName: "tutorial-rainbow-stroke",
            bodyKey: "tutorial.rainbow.body"
        ),
        TutorialPage(
            titleKey: "tutorial.score.title",
            imageName: "tutorial-win",
            bodyKey: "tutorial.score.body"
        )
    ]
    
    // MARK: - Song Info (passed from SongDetailScene)
    
    var songTitle: String = ""
    var songFilename: String = ""
    var songId: String = ""
    var selectedDifficulty: DifficultyLevel = .easy
    var enabledTags: Set<String> = []
    
    // MARK: - State
    
    private var currentPage: Int = 0
    
    // MARK: - UI Elements
    
    private var backButton: SKNode!
    private var menuBackground: SKSpriteNode!
    private var titleLabel: SKLabelNode!
    private var tutorialImage: SKSpriteNode!
    private var descriptionLabel: SKLabelNode!
    private var paginationContainer: SKNode!
    private var playButton: SKNode!
    
    // MARK: - Layout Constants (computed from LayoutConstants)
    private var menuWidthFraction: CGFloat { 0.9 }
    private var paginationButtonEdge: CGFloat { LayoutConstants.shared.paginationButtonSize }
    private let menuTopY: CGFloat = 0.72  // Center panel vertically
    
    // MARK: - Touch Tracking
    
    private var backButtonTouchBegan = false
    private var prevButtonTouchBegan = false
    private var nextButtonTouchBegan = false
    private var playButtonTouchBegan = false
    
    // MARK: - Conveyor Belt
    
    private var conveyorManager: ConveyorBeltManager?
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
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
        
        // Keep menu music playing
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
        setupBackButton()
        setupMenuPanel()
        setupPaginationControls()
        setupPlayButton()
        updatePageContent()
    }
    
    private func setupBackButton() {
        let layout = LayoutConstants.shared
        backButton = ButtonFactory.createBackButton(size: layout.squareButtonSize)
        backButton.position = CGPoint(x: layout.edgeMargin, y: layout.topBarY)
        backButton.zPosition = 150
        addChild(backButton)
    }
    
    private func setupMenuPanel() {
        let layout = LayoutConstants.shared
        
        // Menu background - super big version with max width constraint
        menuBackground = SKSpriteNode(imageNamed: "menu-expanded-super-big")
        let targetWidth = min(size.width * menuWidthFraction, layout.maxMenuWidth)
        let scale = targetWidth / menuBackground.size.width
        menuBackground.setScale(scale)
        
        // Center menu vertically on screen (slightly above true center)
        let menuCenterY = size.height * 0.52
        menuBackground.position = CGPoint(x: size.width / 2, y: menuCenterY)
        menuBackground.zPosition = 50
        addChild(menuBackground)
        
        // Title label - will be positioned in updatePageContent
        titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.fontSize = layout.headerFontSize + 4
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.zPosition = 100  // Higher z to ensure visibility
        addChild(titleLabel)
        
        // Tutorial image - will be positioned in updatePageContent
        tutorialImage = SKSpriteNode()
        tutorialImage.zPosition = 51
        addChild(tutorialImage)
        
        // Description label - will be positioned in updatePageContent
        descriptionLabel = SKLabelNode(fontNamed: FontConfig.regular)
        descriptionLabel.fontSize = layout.bodyFontSize
        descriptionLabel.fontColor = .white
        descriptionLabel.verticalAlignmentMode = .top
        descriptionLabel.horizontalAlignmentMode = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.zPosition = 100  // Higher z to ensure visibility
        addChild(descriptionLabel)
    }
    
    private func setupPaginationControls() {
        let layout = LayoutConstants.shared
        paginationContainer = SKNode()
        paginationContainer.zPosition = 100
        
        let yPos = layout.paginationBottomOffset
        
        let prevButton = createPaginationButton(name: "prevPageButton", isLeft: true)
        prevButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(prevButton)
        
        let nextButton = createPaginationButton(name: "nextPageButton", isLeft: false)
        nextButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(nextButton)
        
        let indicatorLabel = SKLabelNode(fontNamed: FontConfig.bold)
        indicatorLabel.name = "pageIndicator"
        indicatorLabel.fontSize = layout.headerFontSize
        indicatorLabel.fontColor = .white
        indicatorLabel.verticalAlignmentMode = .center
        indicatorLabel.horizontalAlignmentMode = .center
        indicatorLabel.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer.addChild(indicatorLabel)
        
        addChild(paginationContainer)
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
    
    private func setupPlayButton() {
        let layout = LayoutConstants.shared
        playButton = ButtonFactory.createButton(
            text: NSLocalizedString("tutorial.letsgo", comment: "Let's Go button"),
            name: "playButton",
            width: layout.standardButtonWidth,
            fontSize: layout.headerFontSize
        )
        playButton.position = CGPoint(x: size.width / 2, y: layout.paginationBottomOffset)
        playButton.zPosition = 100
        playButton.isHidden = true
        addChild(playButton)
    }
    
    private func updatePageContent() {
        guard currentPage >= 0 && currentPage < pages.count else { return }
        
        let page = pages[currentPage]
        
        // Get the ACTUAL visual frame of the menu background (accounts for scale)
        let menuFrame = menuBackground.frame
        let menuTop = menuFrame.maxY
        let menuBottom = menuFrame.minY
        let scaledMenuWidth = menuFrame.width
        let scaledMenuHeight = menuFrame.height
        
        // DEBUG: Print values
        print("DEBUG TutorialScene Layout (using .frame):")
        print("  menuFrame: \(menuFrame)")
        print("  scaledMenuWidth: \(scaledMenuWidth), scaledMenuHeight: \(scaledMenuHeight)")
        
        // The header is a fixed height strip at the top of the panel
        // Position title in the vertical center of the header (~70pt tall header)
        let titleOffsetFromTop: CGFloat = 45
        
        // Update title - position in header center
        titleLabel.text = NSLocalizedString(page.titleKey, comment: "Tutorial title")
        let titleY = menuTop - titleOffsetFromTop
        titleLabel.position = CGPoint(x: size.width / 2, y: titleY)
        print("  menuTop: \(menuTop), titleLabel.position.y: \(titleY)")
        
        // Header height for content layout (approximately 8% of panel)
        let scaledHeaderHeight = scaledMenuHeight * 0.08
        
        // Update image - reset scale first
        tutorialImage.setScale(1.0)
        tutorialImage.childNode(withName: "imageBorder")?.removeFromParent()
        tutorialImage.childNode(withName: "imageClipMask")?.removeFromParent()
        
        let newImage = SKTexture(imageNamed: page.imageName)
        tutorialImage.texture = newImage
        tutorialImage.size = newImage.size()
        
        // Store ORIGINAL size before any scaling
        let originalImageSize = tutorialImage.size
        print("  originalImageSize: \(originalImageSize)")
        
        // Content area layout
        let contentPadding: CGFloat = 20
        let contentAreaTop = menuTop - scaledHeaderHeight - contentPadding
        let contentAreaBottom = menuBottom + contentPadding
        let contentAreaHeight = contentAreaTop - contentAreaBottom
        
        // Description takes about 115pt at the bottom (extra space for 3-line text)
        let descriptionHeight: CGFloat = 115
        let imageAreaHeight = contentAreaHeight - descriptionHeight
        
        // Scale image to fill 80% of menu width (slightly smaller for better margins)
        let targetImageWidth = scaledMenuWidth * 0.80
        let imageAspect = originalImageSize.width / originalImageSize.height
        
        var finalImageWidth = targetImageWidth
        var finalImageHeight = finalImageWidth / imageAspect
        
        // Constrain by height if needed
        if finalImageHeight > imageAreaHeight {
            finalImageHeight = imageAreaHeight
            finalImageWidth = finalImageHeight * imageAspect
        }
        
        let imageScale = finalImageWidth / originalImageSize.width
        tutorialImage.setScale(imageScale)
        
        // Center image vertically in the image area (between header and description)
        let imageAreaCenterY = contentAreaTop - imageAreaHeight / 2
        tutorialImage.position = CGPoint(x: size.width / 2, y: imageAreaCenterY)
        print("  tutorialImage.position.y: \(imageAreaCenterY), imageScale: \(imageScale)")
        
        // Add rounded border around the FULL image
        // Use original size since border is a child of the scaled sprite
        let cornerRadius: CGFloat = 12
        let halfW = originalImageSize.width / 2
        let halfH = originalImageSize.height / 2
        let borderPadding: CGFloat = 4
        let borderRect = CGRect(
            x: -halfW - borderPadding,
            y: -halfH - borderPadding,
            width: originalImageSize.width + borderPadding * 2,
            height: originalImageSize.height + borderPadding * 2
        )
        let border = SKShapeNode(rect: borderRect, cornerRadius: cornerRadius)
        border.name = "imageBorder"
        border.strokeColor = .white
        border.lineWidth = 3.0
        border.fillColor = .clear
        border.zPosition = 2
        tutorialImage.addChild(border)
        print("  border rect: \(borderRect)")

        // Position description below the image area
        descriptionLabel.text = NSLocalizedString(page.bodyKey, comment: "Tutorial description")
        descriptionLabel.preferredMaxLayoutWidth = scaledMenuWidth - 50
        let descriptionY = contentAreaBottom + descriptionHeight - 10  // Top of description area
        descriptionLabel.position = CGPoint(x: size.width / 2, y: descriptionY)
        print("  descriptionLabel.position.y: \(descriptionY)")
        
        // Update pagination
        updatePaginationControls()
    }
    
    private func updatePaginationControls() {
        let isLastPage = currentPage == pages.count - 1
        
        // On last page: hide pagination entirely, show centered play button
        paginationContainer.isHidden = isLastPage
        playButton.isHidden = !isLastPage
        
        // Update page indicator
        guard let indicatorLabel = paginationContainer.childNode(withName: "pageIndicator") as? SKLabelNode else { return }
        indicatorLabel.text = "\(currentPage + 1) / \(pages.count)"
        
        // Update button visibility/opacity
        if let prevButton = paginationContainer.childNode(withName: "prevPageButton") {
            prevButton.alpha = currentPage > 0 ? 1.0 : 0.4
        }
        
        // Layout pagination
        layoutPaginationPositions()
    }
    
    private func layoutPaginationPositions() {
        let layout = LayoutConstants.shared
        guard
            let prevButton = paginationContainer.childNode(withName: "prevPageButton"),
            let nextButton = paginationContainer.childNode(withName: "nextPageButton"),
            let indicatorLabel = paginationContainer.childNode(withName: "pageIndicator") as? SKLabelNode
        else { return }
        
        let yPos = layout.paginationBottomOffset
        let buttonWidth = prevButton.calculateAccumulatedFrame().width
        let indicatorWidth = indicatorLabel.frame.width
        let spacing: CGFloat = 6
        
        // Standard pagination layout (centered)
        let centerX = size.width / 2
        indicatorLabel.position = CGPoint(x: centerX, y: yPos)
        prevButton.position = CGPoint(x: centerX - (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
        nextButton.position = CGPoint(x: centerX + (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check back button
        if nodes.contains(where: { $0.name == "backButton" || $0.parent?.name == "backButton" }) {
            backButtonTouchBegan = true
            ButtonFactory.animatePress(backButton)
        }
        
        // Check pagination buttons
        if nodes.contains(where: { $0.name == "prevPageButton" || $0.parent?.name == "prevPageButton" }) {
            prevButtonTouchBegan = true
            if let prevButton = paginationContainer.childNode(withName: "prevPageButton") {
                ButtonFactory.animatePress(prevButton)
            }
        }
        
        if nodes.contains(where: { $0.name == "nextPageButton" || $0.parent?.name == "nextPageButton" }) {
            nextButtonTouchBegan = true
            if let nextButton = paginationContainer.childNode(withName: "nextPageButton") {
                ButtonFactory.animatePress(nextButton)
            }
        }
        
        // Check Play button
        if nodes.contains(where: { $0.name == "playButton" || $0.parent?.name == "playButton" }) {
            playButtonTouchBegan = true
            ButtonFactory.animatePress(playButton)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Reset button scales
        ButtonFactory.animateRelease(backButton)
        if let prevButton = paginationContainer.childNode(withName: "prevPageButton") {
            ButtonFactory.animateRelease(prevButton)
        }
        if let nextButton = paginationContainer.childNode(withName: "nextPageButton") {
            ButtonFactory.animateRelease(nextButton)
        }
        ButtonFactory.animateRelease(playButton)
        
        // Handle back button
        if backButtonTouchBegan && nodes.contains(where: { $0.name == "backButton" || $0.parent?.name == "backButton" }) {
            AudioManager.shared.playUISound(.button)
            navigateBackToSongDetail()
        }
        backButtonTouchBegan = false
        
        // Handle prev button
        if prevButtonTouchBegan && nodes.contains(where: { $0.name == "prevPageButton" || $0.parent?.name == "prevPageButton" }) {
            if currentPage > 0 {
                AudioManager.shared.playUISound(.button)
                currentPage -= 1
                updatePageContent()
            }
        }
        prevButtonTouchBegan = false
        
        // Handle next button
        if nextButtonTouchBegan && nodes.contains(where: { $0.name == "nextPageButton" || $0.parent?.name == "nextPageButton" }) {
            if currentPage < pages.count - 1 {
                AudioManager.shared.playUISound(.button)
                currentPage += 1
                updatePageContent()
            }
        }
        nextButtonTouchBegan = false
        
        // Handle Play button
        if playButtonTouchBegan && nodes.contains(where: { $0.name == "playButton" || $0.parent?.name == "playButton" }) {
            AudioManager.shared.playUISound(.button)
            completeTutorialAndStartGame()
        }
        playButtonTouchBegan = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Reset all button states
        ButtonFactory.animateRelease(backButton)
        if let prevButton = paginationContainer.childNode(withName: "prevPageButton") {
            ButtonFactory.animateRelease(prevButton)
        }
        if let nextButton = paginationContainer.childNode(withName: "nextPageButton") {
            ButtonFactory.animateRelease(nextButton)
        }
        ButtonFactory.animateRelease(playButton)
        
        backButtonTouchBegan = false
        prevButtonTouchBegan = false
        nextButtonTouchBegan = false
        playButtonTouchBegan = false
    }
    
    // MARK: - Navigation
    
    private func navigateBackToSongDetail() {
        let songDetailScene = SongDetailScene(size: size)
        songDetailScene.scaleMode = scaleMode
        songDetailScene.songId = songId
        songDetailScene.songTitle = songTitle
        songDetailScene.songFilename = songFilename
        songDetailScene.selectedDifficulty = selectedDifficulty
        view?.presentScene(songDetailScene)
    }
    
    private func completeTutorialAndStartGame() {
        // Mark tutorial as completed (only after user finishes it)
        TutorialStore.shared.hasCompletedTutorial = true
        
        // Transition to PlayScene
        let playScene = PlayScene(size: size)
        playScene.scaleMode = scaleMode
        playScene.selectedDifficulty = selectedDifficulty
        playScene.selectedSongId = songId
        playScene.selectedSongFilename = songFilename
        playScene.selectedSongTitle = songTitle
        playScene.enabledTags = enabledTags
        view?.presentScene(playScene)
    }
}
