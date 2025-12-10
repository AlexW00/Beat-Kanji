//
//  iPadModeSwitcher.swift
//  Beat Kanji
//
//  Dropdown control for selecting iPad input mode (Default / Apple Pencil).
//

import SpriteKit

final class iPadModeSwitcher: SKNode {
    
    // MARK: - Public API
    
    var onChange: ((iPadInputMode) -> Void)?
    
    var selectedMode: iPadInputMode {
        didSet {
            updateAppearance()
            if oldValue != selectedMode {
                onChange?(selectedMode)
            }
        }
    }
    
    // MARK: - Private UI
    
    private let button = SKNode()
    private var buttonBg: SKSpriteNode!
    private var titleLabel: SKLabelNode!
    private var dropdown: SKNode?
    private var isDropdownVisible = false
    
    // MARK: - Init
    
    init(initialMode: iPadInputMode) {
        self.selectedMode = initialMode
        super.init()
        isUserInteractionEnabled = false
        setupButton()
        updateAppearance()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        button.name = "iPadModeButton"
        button.position = .zero
        button.zPosition = 100
        
        let bg = SKSpriteNode(imageNamed: "button")
        let targetWidth: CGFloat = 160
        let scale = targetWidth / bg.size.width
        bg.setScale(scale)
        bg.name = "iPadModeButtonBg"
        button.addChild(bg)
        buttonBg = bg
        
        titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.fontSize = 20
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 0)
        titleLabel.zPosition = 1
        button.addChild(titleLabel)

        addChild(button)
    }
    
    // MARK: - Interaction

    /// Used by parent scenes to decide if a touch should be intercepted before gameplay.
    func shouldConsumeTouch(location: CGPoint, nodes: [SKNode]) -> Bool {
        // If dropdown is open, consume all touches so they don't reach the play area.
        if isDropdownVisible { return true }
        
        // Quick hit-test using the tapped nodes (covers button bg/label).
        if nodes.contains(where: { node in
            guard let name = node.name else { return false }
            return name == "iPadModeButton" || name == "iPadModeButtonBg"
        }) {
            return true
        }
        
        // Fallback to a simple local bounds check around the button.
        let localPoint = convert(location, from: scene ?? parent ?? self)
        return abs(localPoint.x) < 50 && abs(localPoint.y) < 50
    }
    
    /// Handles touches in the parent scene. Returns true when the switcher consumed the touch.
    func handleTouchEnded(location: CGPoint, nodes: [SKNode]) -> Bool {
        if isDropdownVisible {
            if let selected = mode(from: nodes) {
                applySelection(selected)
            } else {
                hideDropdown()
            }
            return true
        }
        
        let localPoint = convert(location, from: scene ?? parent ?? self)
        if abs(localPoint.x) < 50 && abs(localPoint.y) < 50 {
            toggleDropdown()
            return true
        }
        
        return false
    }
    
    func closeDropdown() {
        hideDropdown()
    }
    
    // MARK: - Dropdown
    
    private func toggleDropdown() {
        if isDropdownVisible {
            hideDropdown()
        } else {
            showDropdown()
        }
    }
    
    var isDropdownOpen: Bool {
        return isDropdownVisible
    }
    
    private func showDropdown() {
        guard dropdown == nil else { return }
        
        isDropdownVisible = true
        AudioManager.shared.playUISound(.popupCollapse)
        
        let dropdown = SKNode()
        dropdown.zPosition = 150

        let modes: [iPadInputMode] = [.default, .applePencil]
        let itemHeight: CGFloat = 44
        let itemSpacing: CGFloat = 6
        let anchorOffset: CGFloat = 32
        let optionButtonWidth: CGFloat = 160

        // Compute a tighter popup size (aligned with settings pickers)
        let totalItemsHeight = CGFloat(modes.count) * itemHeight + CGFloat(modes.count - 1) * itemSpacing
        let popupContentHeight = totalItemsHeight + anchorOffset + 24
        let popupWidth: CGFloat = optionButtonWidth + 40

        let popupBg = SKSpriteNode(imageNamed: "popup-anchor-top")
        let bgScaleX = popupWidth / popupBg.size.width
        let bgScaleY = popupContentHeight / popupBg.size.height
        popupBg.xScale = bgScaleX
        popupBg.yScale = bgScaleY
        popupBg.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        popupBg.position = .zero
        dropdown.addChild(popupBg)

        dropdown.position = CGPoint(x: 0, y: -38)

        // Stack items downward from the anchor
        for (index, mode) in modes.enumerated() {
            let itemY = -anchorOffset - itemHeight / 2 - CGFloat(index) * (itemHeight + itemSpacing)

            let itemBg = SKSpriteNode(imageNamed: "button")
            let btnScale: CGFloat = optionButtonWidth / itemBg.size.width
            itemBg.setScale(btnScale)
            itemBg.position = CGPoint(x: 0, y: itemY)
            itemBg.zPosition = 0.5
            itemBg.name = "modeOption_\(mode.rawValue)"
            dropdown.addChild(itemBg)

            let optionLabel = SKLabelNode(fontNamed: FontConfig.bold)
            optionLabel.text = mode.displayName
            optionLabel.fontSize = 18
            optionLabel.fontColor = .white
            optionLabel.verticalAlignmentMode = .center
            optionLabel.horizontalAlignmentMode = .center
            optionLabel.position = CGPoint(x: 0, y: itemY)
            optionLabel.zPosition = 1
            dropdown.addChild(optionLabel)
        }
        
        dropdown.alpha = 0
        dropdown.setScale(0.8)
        dropdown.run(SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1.0, duration: 0.15)
        ]))
        
        addChild(dropdown)
        self.dropdown = dropdown
    }
    
    private func hideDropdown(silent: Bool = false) {
        guard let dropdown else { return }
        
        isDropdownVisible = false
        if !silent {
            AudioManager.shared.playUISound(.popupCollapse)
        }
        
        dropdown.run(SKAction.group([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.scale(to: 0.8, duration: 0.1)
        ])) {
            dropdown.removeFromParent()
        }
        self.dropdown = nil
    }
    
    private func mode(from nodes: [SKNode]) -> iPadInputMode? {
        for node in nodes {
            if let name = node.name, name.hasPrefix("modeOption_") {
                if let modeStr = name.split(separator: "_").last {
                    return iPadInputMode(rawValue: String(modeStr))
                }
            }
        }
        return nil
    }
    
    private func applySelection(_ mode: iPadInputMode) {
        AudioManager.shared.playUISound(.button)
        selectedMode = mode
        hideDropdown(silent: true)
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        titleLabel.text = selectedMode.displayName
    }
}
