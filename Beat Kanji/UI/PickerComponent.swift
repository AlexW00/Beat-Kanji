//
//  PickerComponent.swift
//  Beat Kanji
//
//  Created by Copilot on 02.12.25.
//

import SpriteKit

/// A reusable dropdown picker component similar to DifficultySwitcher.
/// Shows a button that opens a popup with selectable options.
final class DropdownPicker<T: Equatable>: SKNode {
    
    // MARK: - Public API
    
    var onSelectionChanged: ((T) -> Void)?
    
    private(set) var selectedOption: T {
        didSet {
            updateAppearance()
            if let oldIdx = options.firstIndex(where: { $0.value == oldValue }),
               let newIdx = options.firstIndex(where: { $0.value == selectedOption }),
               oldIdx != newIdx {
                onSelectionChanged?(selectedOption)
            }
        }
    }
    
    // MARK: - Data
    
    private let options: [(value: T, label: String)]
    private let buttonWidth: CGFloat
    
    // MARK: - Private UI
    
    private let button = SKNode()
    private var buttonBg: SKSpriteNode!
    private var label: SKLabelNode!
    private var dropdown: SKNode?
    private var isDropdownVisible = false
    
    // MARK: - Init
    
    /// Creates a dropdown picker with the given options.
    /// - Parameters:
    ///   - width: Width of the button
    ///   - options: Array of tuples with (value, display label)
    ///   - initialSelection: The initially selected value
    init(width: CGFloat, options: [(value: T, label: String)], initialSelection: T) {
        self.buttonWidth = width
        self.options = options
        self.selectedOption = initialSelection
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
        button.name = "dropdownButton"
        button.position = .zero
        button.zPosition = 100
        
        let bg = SKSpriteNode(imageNamed: "button")
        let bgScale: CGFloat = buttonWidth / bg.size.width
        bg.setScale(bgScale)
        bg.name = "dropdownButtonBg"
        button.addChild(bg)
        buttonBg = bg
        
        label = SKLabelNode(fontNamed: FontConfig.bold)
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: -12, y: 0)
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
        caret.position = CGPoint(x: buttonWidth / 2 - 30, y: 0)
        caret.name = "dropdownCaret"
        button.addChild(caret)
        
        addChild(button)
    }
    
    // MARK: - Interaction
    
    /// Handles touches in the parent scene. Returns true when the picker consumed the touch.
    func handleTouchEnded(location: CGPoint, nodes: [SKNode]) -> Bool {
        if isDropdownVisible {
            if let selected = optionFromNodes(nodes) {
                applySelection(selected)
            } else {
                hideDropdown()
            }
            return true
        }
        
        let localPoint = convert(location, from: scene ?? parent ?? self)
        let halfWidth = buttonWidth / 2
        if abs(localPoint.x) < halfWidth && abs(localPoint.y) < 25 {
            toggleDropdown()
            return true
        }
        
        return false
    }
    
    func closeDropdown() {
        hideDropdown()
    }
    
    var isDropdownOpen: Bool {
        return isDropdownVisible
    }
    
    // MARK: - Dropdown
    
    private func toggleDropdown() {
        if isDropdownVisible {
            hideDropdown()
        } else {
            showDropdown()
        }
    }
    
    private func showDropdown() {
        guard dropdown == nil else { return }
        
        isDropdownVisible = true
        AudioManager.shared.playUISound(.popupCollapse)
        
        let dropdown = SKNode()
        dropdown.zPosition = 150
        
        let itemHeight: CGFloat = 44
        let itemSpacing: CGFloat = 6
        let anchorOffset: CGFloat = 30  // Space from anchor point to first button
        let optionButtonWidth: CGFloat = 160
        
        // Calculate total popup height needed
        let totalItemsHeight = CGFloat(options.count) * itemHeight + CGFloat(options.count - 1) * itemSpacing
        let popupContentHeight = totalItemsHeight + anchorOffset + 30  // Add padding at top
        let popupWidth: CGFloat = optionButtonWidth + 50  // Add horizontal padding
        
        // Use popup-anchor-bottom with proper scaling to fit content
        let popupBg = SKSpriteNode(imageNamed: "popup-anchor-bottom")
        let bgScaleX = popupWidth / popupBg.size.width
        let bgScaleY = popupContentHeight / popupBg.size.height
        popupBg.xScale = bgScaleX
        popupBg.yScale = bgScaleY
        popupBg.anchorPoint = CGPoint(x: 0.5, y: 0.0)  // Anchor at bottom
        popupBg.position = .zero
        dropdown.addChild(popupBg)
        
        // Position dropdown above the button
        dropdown.position = CGPoint(x: 0, y: 22)
        
        // Position items going upward from the anchor
        for (index, option) in options.enumerated() {
            // Items stack upward: index 0 at bottom, index n-1 at top
            let itemY = anchorOffset + itemHeight / 2 + CGFloat(index) * (itemHeight + itemSpacing)
            
            let optionBg = SKSpriteNode(imageNamed: "button")
            let btnScale: CGFloat = optionButtonWidth / optionBg.size.width
            optionBg.setScale(btnScale)
            optionBg.position = CGPoint(x: 0, y: itemY)
            optionBg.zPosition = 0.5
            optionBg.name = "dropdownOption_\(index)"
            
            // Highlight selected option
            if option.value == selectedOption {
                optionBg.color = SKColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
                optionBg.colorBlendFactor = 0.3
            }
            
            dropdown.addChild(optionBg)
            
            let optionLabel = SKLabelNode(fontNamed: FontConfig.bold)
            optionLabel.text = option.label
            optionLabel.fontSize = 16
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
    
    private func optionFromNodes(_ nodes: [SKNode]) -> T? {
        for node in nodes {
            if let name = node.name, name.hasPrefix("dropdownOption_") {
                if let indexStr = name.split(separator: "_").last,
                   let index = Int(indexStr),
                   index < options.count {
                    return options[index].value
                }
            }
        }
        return nil
    }
    
    private func applySelection(_ value: T) {
        AudioManager.shared.playUISound(.button)
        selectedOption = value
        hideDropdown(silent: true)
    }
    
    // MARK: - Appearance
    
    private func updateAppearance() {
        if let option = options.first(where: { $0.value == selectedOption }) {
            label.text = option.label
        }
    }
}

