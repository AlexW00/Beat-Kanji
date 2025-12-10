//
//  DifficultySwitcher.swift
//  Beat Kanji
//
//  Shared dropdown control for selecting difficulty levels.
//

import SpriteKit

final class DifficultySwitcher: SKNode {
    
    // MARK: - Public API
    
    var onChange: ((DifficultyLevel) -> Void)?
    
    var selectedDifficulty: DifficultyLevel {
        didSet {
            updateAppearance()
            if oldValue != selectedDifficulty {
                onChange?(selectedDifficulty)
            }
        }
    }
    
    // MARK: - Private UI
    
    private let button = SKNode()
    private var buttonBg: SKSpriteNode!
    private var label: SKLabelNode!
    private var dropdown: SKNode?
    private var isDropdownVisible = false
    
    // MARK: - Init
    
    init(initialDifficulty: DifficultyLevel) {
        self.selectedDifficulty = initialDifficulty
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
        button.name = "difficultyButton"
        button.position = .zero
        button.zPosition = 100
        
        let diffBg = SKSpriteNode(imageNamed: "button")
        let diffScale: CGFloat = 140 / diffBg.size.width
        diffBg.setScale(diffScale)
        diffBg.name = "difficultyButtonBg"
        diffBg.shader = ShaderFactory.createHueShiftShader(for: selectedDifficulty)
        button.addChild(diffBg)
        buttonBg = diffBg
        
        label = SKLabelNode(fontNamed: FontConfig.bold)
        label.text = selectedDifficulty.displayName
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: -10, y: 0)
        label.zPosition = 1
        button.addChild(label)
        
        let caretPath = ButtonFactory.caretPath(pointingDown: true)
        let caret = SKShapeNode(path: caretPath)
        caret.fillColor = .clear
        caret.strokeColor = .white
        caret.lineWidth = 2.5
        caret.lineCap = .round
        caret.lineJoin = .round
        caret.glowWidth = 0
        caret.zPosition = 1
        caret.position = CGPoint(x: 42, y: 0)
        caret.name = "difficultyCaret"
        button.addChild(caret)
        
        addChild(button)
    }
    
    // MARK: - Interaction
    
    /// Handles touches in the parent scene. Returns true when the switcher consumed the touch.
    func handleTouchEnded(location: CGPoint, nodes: [SKNode]) -> Bool {
        if isDropdownVisible {
            if let selected = difficulty(from: nodes) {
                applySelection(selected)
            } else {
                hideDropdown()
            }
            return true
        }
        
        let localPoint = convert(location, from: scene ?? parent ?? self)
        if abs(localPoint.x) < 70 && abs(localPoint.y) < 25 {
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
        
        let popupBg = SKSpriteNode(imageNamed: "popup-anchor-top")
        let popupScale: CGFloat = 190 / popupBg.size.width
        popupBg.setScale(popupScale)
        popupBg.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        popupBg.position = .zero
        dropdown.addChild(popupBg)
        
        dropdown.position = CGPoint(x: 0, y: -18)
        
        let difficulties: [DifficultyLevel] = [.easy, .medium, .hard]
        let itemHeight: CGFloat = 44
        let anchorOffset: CGFloat = 25
        let startY: CGFloat = -anchorOffset - itemHeight / 2 - 8
        let buttonWidth: CGFloat = 140
        
        for (index, difficulty) in difficulties.enumerated() {
            let itemY = startY - CGFloat(index) * (itemHeight + 6)
            
            let buttonBg = SKSpriteNode(imageNamed: "button")
            let btnScale: CGFloat = buttonWidth / buttonBg.size.width
            buttonBg.setScale(btnScale)
            buttonBg.position = CGPoint(x: 0, y: itemY)
            buttonBg.zPosition = 0.5
            buttonBg.name = "diffOption_\(difficulty.rawValue)"
            buttonBg.shader = ShaderFactory.createHueShiftShader(for: difficulty)
            dropdown.addChild(buttonBg)
            
            let optionLabel = SKLabelNode(fontNamed: FontConfig.bold)
            optionLabel.text = difficulty.displayName
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
    
    private func difficulty(from nodes: [SKNode]) -> DifficultyLevel? {
        for node in nodes {
            if let name = node.name, name.hasPrefix("diffOption_") {
                if let levelStr = name.split(separator: "_").last,
                   let level = Int(levelStr) {
                    return DifficultyLevel(rawValue: level)
                }
            }
        }
        return nil
    }
    
    private func applySelection(_ difficulty: DifficultyLevel) {
        AudioManager.shared.playUISound(.button)
        selectedDifficulty = difficulty
        hideDropdown(silent: true)
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        label.text = selectedDifficulty.displayName
        label.fontColor = .white
        buttonBg.shader = ShaderFactory.createHueShiftShader(for: selectedDifficulty)
    }
}
