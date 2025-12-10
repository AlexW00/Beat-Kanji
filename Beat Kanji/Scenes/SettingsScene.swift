//
//  SettingsScene.swift
//  Beat Kanji
//
//  Created by Copilot on 29.11.25.
//

import SpriteKit

class SettingsScene: SKScene {
    
    // MARK: - Conveyor Belt
    
    private var conveyorManager: ConveyorBeltManager?
    
    // Use shared timer for seamless transitions between scenes
    private var globalTimer: GlobalBeatTimer { GlobalBeatTimer.shared }
    
    // MARK: - UI Elements
    
    private var backButton: SKNode!
    private var musicSlider: SliderComponent!
    private var interfaceSlider: SliderComponent!
    private var displayPicker: DropdownPicker<PostKanjiDisplayOption>!
    private var iPadModePicker: DropdownPicker<iPadInputMode>!
    
    // Pagination (iPad only)
    private var currentPage: Int = 0
    private var paginationContainer: SKNode?
    private var page1Container: SKNode?
    private var page2Container: SKNode?
    
    // MARK: - Touch State Tracking

    private var backButtonTouchBegan = false
    private var xButtonTouchBegan = false
    private var githubButtonTouchBegan = false
    private var prevPageButtonTouchBegan = false
    private var nextPageButtonTouchBegan = false
    
    // MARK: - Settings Store
    
    private var settings: SettingsStore { SettingsStore.shared }
    
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
    
    private var xButton: SKNode!
    private var githubButton: SKNode!
    
    private func setupUI() {
        setupBackButton()
        setupTitle()
        
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        
        if isIPad {
            // iPad: Use pagination - page 1 has Sound, Display, iPad; page 2 has About
            setupPage1Container()
            setupPage2Container()
            setupPaginationControls()
            showPage(0)
        } else {
            // iPhone: Show all categories (no iPad settings panel)
            setupSoundCategory(parentNode: self)
            setupDisplayCategory(parentNode: self)
            setupAboutCategory(parentNode: self)
        }
    }
    
    private func setupTitle() {
        let layout = LayoutConstants.shared
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = NSLocalizedString("settings.title", comment: "Settings title")
        titleLabel.fontSize = layout.titleFontSize
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - layout.titleTopOffset)
        titleLabel.zPosition = 100
        addChild(titleLabel)
    }
    
    private func setupBackButton() {
        let layout = LayoutConstants.shared
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
    }
    
    private func setupSoundCategory(parentNode: SKNode) {
        let layout = LayoutConstants.shared
        let menuWidth = layout.menuWidth
        let sliderWidth = layout.sliderWidth
        let centerX = layout.menuCenterX
        let categoryPositions = layout.settingsCategoryYPositions()
        let categoryY = categoryPositions.sound
        
        // Container for the category
        let categoryContainer = SKNode()
        categoryContainer.name = "soundCategory"
        categoryContainer.position = CGPoint(x: centerX, y: categoryY)
        categoryContainer.zPosition = 50
        parentNode.addChild(categoryContainer)
        
        // Background using menu-expanded-mid with NON-UNIFORM scaling (assets are designed for this)
        let background = SKSpriteNode(imageNamed: "menu-expanded-mid")
        let contentHeight = layout.tallCategoryHeight
        let bgScaleX = menuWidth / background.size.width
        let bgScaleY = contentHeight / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.position = .zero
        background.zPosition = 0
        categoryContainer.addChild(background)
        
        // Category header label
        let headerLabel = SKLabelNode(fontNamed: FontConfig.bold)
        headerLabel.text = NSLocalizedString("settings.category.sound", comment: "Sound category header")
        headerLabel.fontSize = layout.headerFontSize
        headerLabel.fontColor = .white
        headerLabel.horizontalAlignmentMode = .center
        headerLabel.verticalAlignmentMode = .center
        headerLabel.position = CGPoint(x: 0, y: contentHeight / 2 - layout.tallCategoryHeaderTopPadding)
        headerLabel.zPosition = 10
        categoryContainer.addChild(headerLabel)
        
        // Music Volume slider
        let musicLabel = SKLabelNode(fontNamed: FontConfig.regular)
        musicLabel.text = NSLocalizedString("settings.music", comment: "Music volume label")
        musicLabel.fontSize = layout.bodyFontSize
        musicLabel.fontColor = .white
        musicLabel.horizontalAlignmentMode = .left
        musicLabel.verticalAlignmentMode = .center
        musicLabel.position = CGPoint(x: -sliderWidth / 2, y: 25)
        musicLabel.zPosition = 10
        categoryContainer.addChild(musicLabel)
        
        musicSlider = SliderComponent(width: sliderWidth, initialValue: settings.musicVolume)
        musicSlider.position = CGPoint(x: 0, y: 0)
        musicSlider.zPosition = 10
        musicSlider.onValueChanged = { value in
            // Use AudioManager to apply volume immediately to playing music
            AudioManager.shared.musicVolume = value
        }
        categoryContainer.addChild(musicSlider)
        
        // Interface Volume slider
        let interfaceLabel = SKLabelNode(fontNamed: FontConfig.regular)
        interfaceLabel.text = NSLocalizedString("settings.interface", comment: "Interface volume label")
        interfaceLabel.fontSize = layout.bodyFontSize
        interfaceLabel.fontColor = .white
        interfaceLabel.horizontalAlignmentMode = .left
        interfaceLabel.verticalAlignmentMode = .center
        interfaceLabel.position = CGPoint(x: -sliderWidth / 2, y: -45)
        interfaceLabel.zPosition = 10
        categoryContainer.addChild(interfaceLabel)
        
        interfaceSlider = SliderComponent(width: sliderWidth, initialValue: settings.interfaceVolume)
        interfaceSlider.position = CGPoint(x: 0, y: -70)
        interfaceSlider.zPosition = 10
        interfaceSlider.onValueChanged = { value in
            // Use AudioManager to store interface volume
            AudioManager.shared.interfaceVolume = value
        }
        categoryContainer.addChild(interfaceSlider)
    }
    
    private func setupDisplayCategory(parentNode: SKNode) {
        let layout = LayoutConstants.shared
        let menuWidth = layout.menuWidth
        let centerX = layout.menuCenterX
        let categoryPositions = layout.settingsCategoryYPositions()
        let categoryY = categoryPositions.display
        
        // Content layout (header in title bar + label + picker)
        let contentHeight = layout.standardCategoryHeight
        
        // Container for the category
        let categoryContainer = SKNode()
        categoryContainer.name = "displayCategory"
        categoryContainer.position = CGPoint(x: centerX, y: categoryY)
        categoryContainer.zPosition = 60  // Higher z to ensure dropdown appears on top
        parentNode.addChild(categoryContainer)
        
        // Background using menu-expanded-mid with NON-UNIFORM scaling
        let background = SKSpriteNode(imageNamed: "menu-expanded-mid")
        let bgScaleX = menuWidth / background.size.width
        let bgScaleY = contentHeight / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.position = .zero
        background.zPosition = 0
        categoryContainer.addChild(background)
        
        // Category header label (at title bar - top edge of container)
        let headerLabel = SKLabelNode(fontNamed: FontConfig.bold)
        headerLabel.text = NSLocalizedString("settings.category.display", comment: "Display category header")
        headerLabel.fontSize = layout.headerFontSize
        headerLabel.fontColor = .white
        headerLabel.horizontalAlignmentMode = .center
        headerLabel.verticalAlignmentMode = .center
        headerLabel.position = CGPoint(x: 0, y: contentHeight / 2 - layout.standardCategoryHeaderTopPadding)
        headerLabel.zPosition = 10
        categoryContainer.addChild(headerLabel)
        
        // Display after kanji label
        let displayLabel = SKLabelNode(fontNamed: FontConfig.regular)
        displayLabel.text = NSLocalizedString("settings.displayAfterKanji", comment: "Display after kanji label")
        displayLabel.fontSize = layout.bodyFontSize
        displayLabel.fontColor = .white
        displayLabel.horizontalAlignmentMode = .center
        displayLabel.verticalAlignmentMode = .center
        displayLabel.position = CGPoint(x: 0, y: 20)
        displayLabel.zPosition = 10
        categoryContainer.addChild(displayLabel)
        
        // Picker options
        let pickerOptions: [(value: PostKanjiDisplayOption, label: String)] = PostKanjiDisplayOption.allCases.map { option in
            (value: option, label: option.displayName)
        }
        
        displayPicker = DropdownPicker(
            width: 180,
            options: pickerOptions,
            initialSelection: settings.postKanjiDisplay
        )
        displayPicker.position = CGPoint(x: 0, y: -30)
        displayPicker.zPosition = 100
        displayPicker.onSelectionChanged = { [weak self] value in
            self?.settings.postKanjiDisplay = value
        }
        categoryContainer.addChild(displayPicker)
    }
    
    private func setupAboutCategory(parentNode: SKNode) {
        let layout = LayoutConstants.shared
        let menuWidth = layout.menuWidth
        let centerX = layout.menuCenterX
        let categoryPositions = layout.settingsCategoryYPositions()
        // For iPad page 2, use the sound category position (top of page)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let categoryY = isIPad && parentNode != self ? categoryPositions.sound : categoryPositions.about
        
        // Same content height as display category
        let contentHeight = layout.standardCategoryHeight
        
        // Container for the category
        let categoryContainer = SKNode()
        categoryContainer.name = "aboutCategory"
        categoryContainer.position = CGPoint(x: centerX, y: categoryY)
        categoryContainer.zPosition = 50
        parentNode.addChild(categoryContainer)
        
        // Background using menu-expanded-mid with NON-UNIFORM scaling
        let background = SKSpriteNode(imageNamed: "menu-expanded-mid")
        let bgScaleX = menuWidth / background.size.width
        let bgScaleY = contentHeight / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.position = .zero
        background.zPosition = 0
        categoryContainer.addChild(background)
        
        // Category header label (same positioning as display category)
        let headerLabel = SKLabelNode(fontNamed: FontConfig.bold)
        headerLabel.text = NSLocalizedString("settings.category.about", comment: "About category header")
        headerLabel.fontSize = layout.headerFontSize
        headerLabel.fontColor = .white
        headerLabel.horizontalAlignmentMode = .center
        headerLabel.verticalAlignmentMode = .center
        headerLabel.position = CGPoint(x: 0, y: contentHeight / 2 - layout.aboutCategoryHeaderTopPadding)
        headerLabel.zPosition = 10
        categoryContainer.addChild(headerLabel)
        
        // Buttons using the button asset
        // X (Twitter) button
        xButton = createAboutButton(
            label: "X",
            position: CGPoint(x: -70, y: -20)
        )
        xButton.name = "xButton"
        categoryContainer.addChild(xButton)

        // GitHub button
        githubButton = createAboutButton(
            label: NSLocalizedString("settings.github", comment: "GitHub button"),
            position: CGPoint(x: 70, y: -20)
        )
        githubButton.name = "githubButton"
        categoryContainer.addChild(githubButton)
    }
    
    private func createAboutButton(label: String, position: CGPoint) -> SKNode {
        let button = SKNode()
        button.position = position
        button.zPosition = 10
        
        // Button background using button asset
        let bg = SKSpriteNode(imageNamed: "button")
        let targetWidth: CGFloat = 120
        let scale = targetWidth / bg.size.width
        bg.setScale(scale)
        bg.zPosition = 0
        button.addChild(bg)
        
        // Button label
        let labelNode = SKLabelNode(fontNamed: FontConfig.bold)
        labelNode.text = label
        labelNode.fontSize = 18
        labelNode.fontColor = .white
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        labelNode.zPosition = 1
        button.addChild(labelNode)
        
        return button
    }
    
    // MARK: - iPad Pagination
    
    private func setupPage1Container() {
        page1Container = SKNode()
        page1Container?.name = "page1"
        page1Container?.zPosition = 40
        addChild(page1Container!)
        
        setupSoundCategory(parentNode: page1Container!)
        setupDisplayCategory(parentNode: page1Container!)
        setupiPadCategory(parentNode: page1Container!)
    }
    
    private func setupPage2Container() {
        page2Container = SKNode()
        page2Container?.name = "page2"
        page2Container?.zPosition = 40
        page2Container?.alpha = 0
        addChild(page2Container!)
        
        setupAboutCategory(parentNode: page2Container!)
    }
    
    private func setupiPadCategory(parentNode: SKNode) {
        let layout = LayoutConstants.shared
        let menuWidth = layout.menuWidth
        let centerX = layout.menuCenterX
        let categoryPositions = layout.settingsCategoryYPositions()
        let categoryY = categoryPositions.about  // Use the about position (bottom)
        
        // Content layout (header in title bar + label + picker)
        let contentHeight = layout.standardCategoryHeight
        
        // Container for the category
        let categoryContainer = SKNode()
        categoryContainer.name = "iPadCategory"
        categoryContainer.position = CGPoint(x: centerX, y: categoryY)
        categoryContainer.zPosition = 55
        parentNode.addChild(categoryContainer)
        
        // Background using menu-expanded-mid with NON-UNIFORM scaling
        let background = SKSpriteNode(imageNamed: "menu-expanded-mid")
        let bgScaleX = menuWidth / background.size.width
        let bgScaleY = contentHeight / background.size.height
        background.xScale = bgScaleX
        background.yScale = bgScaleY
        background.position = .zero
        background.zPosition = 0
        categoryContainer.addChild(background)
        
        // Category header label
        let headerLabel = SKLabelNode(fontNamed: FontConfig.bold)
        headerLabel.text = NSLocalizedString("settings.category.ipad", comment: "iPad category header")
        headerLabel.fontSize = layout.headerFontSize
        headerLabel.fontColor = .white
        headerLabel.horizontalAlignmentMode = .center
        headerLabel.verticalAlignmentMode = .center
        headerLabel.position = CGPoint(x: 0, y: contentHeight / 2 - layout.standardCategoryHeaderTopPadding)
        headerLabel.zPosition = 10
        categoryContainer.addChild(headerLabel)
        
        // Input mode label
        let inputLabel = SKLabelNode(fontNamed: FontConfig.regular)
        inputLabel.text = NSLocalizedString("settings.ipad.inputMode", comment: "Input mode label")
        inputLabel.fontSize = layout.bodyFontSize
        inputLabel.fontColor = .white
        inputLabel.horizontalAlignmentMode = .center
        inputLabel.verticalAlignmentMode = .center
        inputLabel.position = CGPoint(x: 0, y: 20)
        inputLabel.zPosition = 10
        categoryContainer.addChild(inputLabel)
        
        // Picker options
        let pickerOptions: [(value: iPadInputMode, label: String)] = iPadInputMode.allCases.map { option in
            (value: option, label: option.displayName)
        }
        
        iPadModePicker = DropdownPicker(
            width: 200,
            options: pickerOptions,
            initialSelection: settings.iPadInputMode
        )
        iPadModePicker.position = CGPoint(x: 0, y: -30)
        iPadModePicker.zPosition = 100
        iPadModePicker.onSelectionChanged = { [weak self] value in
            self?.settings.iPadInputMode = value
        }
        categoryContainer.addChild(iPadModePicker)
    }
    
    private func setupPaginationControls() {
        paginationContainer?.removeFromParent()
        
        paginationContainer = SKNode()
        paginationContainer?.zPosition = 120
        
        let layout = LayoutConstants.shared
        let yPos: CGFloat = layout.paginationBottomOffset
        
        let prevButton = createPaginationButton(name: "prevPageButton", isLeft: true)
        prevButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer?.addChild(prevButton)
        
        let nextButton = createPaginationButton(name: "nextPageButton", isLeft: false)
        nextButton.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer?.addChild(nextButton)
        
        let indicatorLabel = SKLabelNode(fontNamed: FontConfig.bold)
        indicatorLabel.name = "pageIndicator"
        indicatorLabel.fontSize = 22
        indicatorLabel.fontColor = .white
        indicatorLabel.verticalAlignmentMode = .center
        indicatorLabel.horizontalAlignmentMode = .center
        indicatorLabel.position = CGPoint(x: size.width / 2, y: yPos)
        paginationContainer?.addChild(indicatorLabel)
        
        addChild(paginationContainer!)
        updatePaginationControls()
    }
    
    private func createPaginationButton(name: String, isLeft: Bool) -> SKNode {
        let layout = LayoutConstants.shared
        let buttonNode = SKNode()
        buttonNode.name = name
        
        let bg = SKSpriteNode(imageNamed: "button-square")
        let scale = layout.paginationButtonSize / max(bg.size.width, bg.size.height)
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
    
    private func updatePaginationControls() {
        guard let indicatorLabel = paginationContainer?.childNode(withName: "pageIndicator") as? SKLabelNode else { return }
        let totalPages = 2
        indicatorLabel.text = "\(currentPage + 1) / \(totalPages)"
        
        if let prevButton = paginationContainer?.childNode(withName: "prevPageButton") {
            prevButton.alpha = currentPage > 0 ? 1.0 : 0.4
        }
        if let nextButton = paginationContainer?.childNode(withName: "nextPageButton") {
            nextButton.alpha = currentPage < totalPages - 1 ? 1.0 : 0.4
        }
        
        layoutPaginationPositions()
    }
    
    private func layoutPaginationPositions() {
        guard let paginationContainer else { return }
        guard
            let prevButton = paginationContainer.childNode(withName: "prevPageButton"),
            let nextButton = paginationContainer.childNode(withName: "nextPageButton"),
            let indicatorLabel = paginationContainer.childNode(withName: "pageIndicator") as? SKLabelNode
        else { return }
        
        let layout = LayoutConstants.shared
        let yPos: CGFloat = layout.paginationBottomOffset
        let buttonWidth = prevButton.calculateAccumulatedFrame().width
        let indicatorWidth = indicatorLabel.frame.width
        let spacing: CGFloat = 6
        
        let centerX = size.width / 2
        indicatorLabel.position = CGPoint(x: centerX, y: yPos)
        prevButton.position = CGPoint(x: centerX - (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
        nextButton.position = CGPoint(x: centerX + (indicatorWidth / 2 + spacing + buttonWidth / 2), y: yPos)
    }
    
    private func showPage(_ page: Int) {
        currentPage = page
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        
        if page == 0 {
            page2Container?.run(fadeOut)
            page1Container?.run(fadeIn)
        } else {
            page1Container?.run(fadeOut)
            page2Container?.run(fadeIn)
        }
        
        updatePaginationControls()
    }
    
    private func changePage(by delta: Int) {
        let totalPages = 2
        let newPage = min(max(0, currentPage + delta), totalPages - 1)
        guard newPage != currentPage else { return }
        showPage(newPage)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check back button
        if let back = backButton {
            let backLocation = touch.location(in: back)
            if abs(backLocation.x) < 50 && abs(backLocation.y) < 50 {
                backButtonTouchBegan = true
                back.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
        
        // Check X button
        if let xBtn = xButton {
            let xLocation = touch.location(in: xBtn)
            if abs(xLocation.x) < 70 && abs(xLocation.y) < 25 {
                xButtonTouchBegan = true
                xBtn.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }

        // Check GitHub button
        if let githubBtn = githubButton {
            let githubLocation = touch.location(in: githubBtn)
            if abs(githubLocation.x) < 70 && abs(githubLocation.y) < 25 {
                githubButtonTouchBegan = true
                githubBtn.run(SKAction.scale(to: 0.9, duration: 0.1))
            }
        }
        
        // Check pagination buttons (iPad only)
        let nodes = nodes(at: location)
        if nodes.contains(where: { $0.name == "prevPageButton" || $0.parent?.name == "prevPageButton" }) {
            prevPageButtonTouchBegan = true
        }
        if nodes.contains(where: { $0.name == "nextPageButton" || $0.parent?.name == "nextPageButton" }) {
            nextPageButtonTouchBegan = true
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)
        
        // Check dropdown pickers first (handles dropdown and button)
        if displayPicker?.handleTouchEnded(location: location, nodes: nodes) == true {
            resetTouchState()
            backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
            return
        }
        
        if iPadModePicker?.handleTouchEnded(location: location, nodes: nodes) == true {
            resetTouchState()
            backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
            return
        }
        
        // Check pagination buttons (iPad only)
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
        
        // Check back button - only trigger if touch began on it
        if let back = backButton {
            let backLocation = touch.location(in: back)
            back.run(SKAction.scale(to: 1.0, duration: 0.1))
            if backButtonTouchBegan && abs(backLocation.x) < 50 && abs(backLocation.y) < 50 {
                resetTouchState()
                displayPicker?.closeDropdown()
                iPadModePicker?.closeDropdown()
                AudioManager.shared.playUISound(.buttonBack)
                transitionToStartScene()
                return
            }
            backButtonTouchBegan = false
        }
        
        // Check X button - only trigger if touch began on it
        if let xBtn = xButton {
            let xLocation = touch.location(in: xBtn)
            xBtn.run(SKAction.scale(to: 1.0, duration: 0.1))
            if xButtonTouchBegan && abs(xLocation.x) < 70 && abs(xLocation.y) < 25 {
                resetTouchState()
                AudioManager.shared.playUISound(.button)
                openTwitterLink()
                return
            }
            xButtonTouchBegan = false
        }

        // Check GitHub button - only trigger if touch began on it
        if let githubBtn = githubButton {
            let githubLocation = touch.location(in: githubBtn)
            githubBtn.run(SKAction.scale(to: 1.0, duration: 0.1))
            if githubButtonTouchBegan && abs(githubLocation.x) < 70 && abs(githubLocation.y) < 25 {
                resetTouchState()
                AudioManager.shared.playUISound(.button)
                openGithubLink()
                return
            }
            githubButtonTouchBegan = false
        }
        
        resetTouchState()
    }
    
    private func resetTouchState() {
        backButtonTouchBegan = false
        xButtonTouchBegan = false
        githubButtonTouchBegan = false
        prevPageButtonTouchBegan = false
        nextPageButtonTouchBegan = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        xButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        githubButton?.run(SKAction.scale(to: 1.0, duration: 0.1))
        resetTouchState()
    }
    
    // MARK: - Navigation
    
    private func transitionToStartScene() {
        globalTimer.prepareForSceneTransition()
        let startScene = StartScene(size: size)
        startScene.scaleMode = scaleMode
        view?.presentScene(startScene)
    }

    private func openTwitterLink() {
        if let url = URL(string: "https://x.com/AlexWeichart") {
            UIApplication.shared.open(url)
        }
    }

    private func openGithubLink() {
        if let url = URL(string: "https://github.com/AlexW00/Beat-Kanji") {
            UIApplication.shared.open(url)
        }
    }
}
