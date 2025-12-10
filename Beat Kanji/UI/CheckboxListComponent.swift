//
//  CheckboxListComponent.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import SpriteKit

/// A reusable collapsible list component with checkboxes
class CheckboxListComponent: SKNode {
    
    // MARK: - Types

    private enum CheckboxState {
        case checked
        case unchecked
        case mixed
    }

    struct Item {
        let id: String
        let title: String
        var isChecked: Bool
    }
    
    // MARK: - Configuration
    
    private let title: String
    private var items: [Item]
    private let width: CGFloat
    private let useSmallBackground: Bool
    private let onItemToggled: ((String, Bool) -> Void)?
    
    // MARK: - Layout Constants (computed from LayoutConstants)
    
    private var headerHeight: CGFloat { LayoutConstants.shared.listHeaderHeight }
    private var itemHeight: CGFloat { LayoutConstants.shared.listItemHeight }
    private var checkboxSize: CGFloat { LayoutConstants.shared.checkboxSize }
    private let maxVisibleItems: Int = 4 // Maximum items visible without scrolling
    
    // MARK: - State
    
    private(set) var isExpanded: Bool = true
    private var scrollOffset: CGFloat = 0
    private var contentNode: SKNode?
    private var backgroundNode: SKSpriteNode?
    private var headerTouchArea: SKSpriteNode?
    private var headerCheckbox: SKNode?
    private var caretNode: SKShapeNode?
    private var cropNode: SKCropNode?
    private var scrollContent: SKNode?
    
    // Scroll tracking
    private var isScrolling: Bool = false
    private var lastTouchY: CGFloat = 0
    private var touchStartY: CGFloat = 0
    
    // MARK: - Computed Properties
    
    private var needsScrolling: Bool {
        return items.count > maxVisibleItems && !useSmallBackground
    }
    
    private var visibleItemCount: Int {
        if useSmallBackground {
            return items.count // Small background shows all items
        }
        return min(maxVisibleItems, items.count)
    }
    
    // MARK: - Initialization
    
    /// Create a checkbox list component
    /// - Parameters:
    ///   - title: Header title for the list
    ///   - items: Array of items with id, title, and initial checked state
    ///   - width: Width of the component
    ///   - useSmallBackground: If true, uses menu-expanded-small (for 2 items). If false, uses menu-expanded-mid (for scrollable lists)
    ///   - onItemToggled: Callback when an item is toggled (id, newState)
    init(title: String, items: [Item], width: CGFloat, useSmallBackground: Bool = false, onItemToggled: ((String, Bool) -> Void)? = nil) {
        self.title = title
        self.items = items
        self.width = width
        self.useSmallBackground = useSmallBackground
        self.onItemToggled = onItemToggled
        super.init()
        
        rebuild()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    /// Toggle expanded/collapsed state
    func toggleExpanded() {
        // Play appropriate sound for expand/collapse
        AudioManager.shared.playUISound(isExpanded ? .categoryCollapse : .categoryExpand)
        isExpanded.toggle()
        scrollOffset = 0
        rebuild()
    }
    
    /// Update an item's checked state
    func setItemChecked(id: String, checked: Bool) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isChecked = checked
            rebuild()
        }
    }
    
    /// Get current items state
    func getItems() -> [Item] {
        return items
    }
    
    /// Check if all items are checked
    private var allItemsChecked: Bool {
        return items.allSatisfy { $0.isChecked }
    }
    
    /// Check if any items are checked
    private var anyItemsChecked: Bool {
        return items.contains { $0.isChecked }
    }

    /// Determine the header checkbox state (supports mixed state)
    private var headerCheckboxState: CheckboxState {
        if allItemsChecked {
            return .checked
        }
        if anyItemsChecked {
            return .mixed
        }
        return .unchecked
    }
    
    /// Toggle all items on or off
    private func toggleAllItems() {
        let newState = !allItemsChecked
        // Play appropriate sound for toggle
        AudioManager.shared.playUISound(newState ? .checkOn : .checkOff)
        for index in items.indices {
            if items[index].isChecked != newState {
                items[index].isChecked = newState
                onItemToggled?(items[index].id, newState)
            }
        }
        rebuild()
    }
    
    /// Calculate total height of the component
    func totalHeight() -> CGFloat {
        if isExpanded {
            // Calculate based on uniformly scaled background
            // bg.size is the ORIGINAL size before scaling
            let bgImageName = useSmallBackground ? "menu-expanded-small" : "menu-expanded-mid"
            let bg = SKSpriteNode(imageNamed: bgImageName)
            let originalWidth = bg.size.width
            let originalHeight = bg.size.height
            let bgScale = width / originalWidth
            return originalHeight * bgScale
        } else {
            return headerHeight
        }
    }
    
    // MARK: - Build UI
    
    private func rebuild() {
        removeAllChildren()
        scrollContent = nil
        cropNode = nil
        
        if isExpanded {
            buildExpandedState()
        } else {
            buildCollapsedState()
        }
    }
    
    private func buildCollapsedState() {
        // Background
        let bg = SKSpriteNode(imageNamed: "menu-collapsed")
        let bgScale = width / bg.size.width
        bg.setScale(bgScale)
        bg.position = CGPoint(x: 0, y: -headerHeight / 2)
        bg.zPosition = -1
        addChild(bg)
        backgroundNode = bg
        
        // Header checkbox (check all)
        let checkbox = createCheckbox(state: headerCheckboxState)
        checkbox.position = CGPoint(x: -width / 2 + 40, y: -headerHeight / 2)
        checkbox.name = "headerCheckbox"
        checkbox.zPosition = 3
        addChild(checkbox)
        headerCheckbox = checkbox
        
        // Title (shifted right to make room for checkbox)
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = title
        titleLabel.fontSize = LayoutConstants.shared.headerFontSize
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -width / 2 + 70, y: -headerHeight / 2)
        titleLabel.zPosition = 1
        addChild(titleLabel)
        
        // Caret down (collapsed)
        let caret = createCaret(pointingUp: false)
        caret.position = CGPoint(x: width / 2 - 35, y: -headerHeight / 2)
        addChild(caret)
        caretNode = caret
        
        // Touch area for header (excluding checkbox area)
        let touchArea = SKSpriteNode(color: .clear, size: CGSize(width: width - 80, height: headerHeight))
        touchArea.name = "checkboxListHeader"
        touchArea.position = CGPoint(x: 40, y: -headerHeight / 2)
        touchArea.zPosition = 2
        addChild(touchArea)
        headerTouchArea = touchArea
        
        // Touch area for checkbox
        let checkboxTouchArea = SKSpriteNode(color: .clear, size: CGSize(width: 60, height: headerHeight))
        checkboxTouchArea.name = "headerCheckboxTouch"
        checkboxTouchArea.position = CGPoint(x: -width / 2 + 40, y: -headerHeight / 2)
        checkboxTouchArea.zPosition = 4
        addChild(checkboxTouchArea)
    }
    
    private func buildExpandedState() {
        // Background - use uniform scaling (no vertical stretch)
        let bgImageName = useSmallBackground ? "menu-expanded-small" : "menu-expanded-mid"
        let bg = SKSpriteNode(imageNamed: bgImageName)
        let originalWidth = bg.size.width
        let originalHeight = bg.size.height
        let bgScale = width / originalWidth
        bg.setScale(bgScale)
        
        // Calculate actual height from the scaled background
        // Note: after setScale(), bg.size already reflects scaled size
        let scaledBgHeight = originalHeight * bgScale
        bg.position = CGPoint(x: 0, y: -scaledBgHeight / 2)
        bg.zPosition = -1
        addChild(bg)
        backgroundNode = bg
        
        // Use the actual background height for layout
        let totalHeight = scaledBgHeight
        let visibleHeight = totalHeight - headerHeight
        
        // Header checkbox (check all)
        let checkbox = createCheckbox(state: headerCheckboxState)
        checkbox.position = CGPoint(x: -width / 2 + 40, y: -headerHeight / 2)
        checkbox.name = "headerCheckbox"
        checkbox.zPosition = 3
        addChild(checkbox)
        headerCheckbox = checkbox
        
        // Header title (shifted right to make room for checkbox)
        let titleLabel = SKLabelNode(fontNamed: FontConfig.bold)
        titleLabel.text = title
        titleLabel.fontSize = LayoutConstants.shared.headerFontSize
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -width / 2 + 70, y: -headerHeight / 2)
        titleLabel.zPosition = 1
        addChild(titleLabel)
        
        // Caret up (expanded)
        let caret = createCaret(pointingUp: true)
        caret.position = CGPoint(x: width / 2 - 35, y: -headerHeight / 2)
        addChild(caret)
        caretNode = caret
        
        // Header touch area (excluding checkbox area)
        let headerTouch = SKSpriteNode(color: .clear, size: CGSize(width: width - 80, height: headerHeight))
        headerTouch.name = "checkboxListHeader"
        headerTouch.position = CGPoint(x: 40, y: -headerHeight / 2)
        headerTouch.zPosition = 2
        addChild(headerTouch)
        headerTouchArea = headerTouch
        
        // Touch area for checkbox
        let checkboxTouchArea = SKSpriteNode(color: .clear, size: CGSize(width: 60, height: headerHeight))
        checkboxTouchArea.name = "headerCheckboxTouch"
        checkboxTouchArea.position = CGPoint(x: -width / 2 + 40, y: -headerHeight / 2)
        checkboxTouchArea.zPosition = 4
        addChild(checkboxTouchArea)
        
        // Build items with or without scrolling
        if needsScrolling {
            buildScrollableItems(visibleHeight: visibleHeight)
        } else {
            buildStaticItems(visibleHeight: visibleHeight)
        }
    }
    
    private func buildStaticItems(visibleHeight: CGFloat) {
        // For small background or lists with <= maxVisibleItems, no scrolling needed
        // Content is positioned in the item area with slight upward offset for visual balance
        contentNode = SKNode()
        contentNode?.zPosition = 1
        addChild(contentNode!)
        
        let totalItemsHeight = CGFloat(items.count) * itemHeight
        // Calculate offset to position items in the visible area (shifted up by 10pt for better visual balance)
        let verticalOffset: CGFloat = useSmallBackground ? 10 : 0
        let itemAreaCenterY = -headerHeight - visibleHeight / 2 + verticalOffset
        let contentStartY = itemAreaCenterY + totalItemsHeight / 2 - itemHeight / 2
        
        for (index, item) in items.enumerated() {
            let itemY = contentStartY - CGFloat(index) * itemHeight
            
            // Dots separator (between items)
            if index > 0 {
                let dots = SKSpriteNode(imageNamed: "dots")
                let dotsScale = (width * 0.85) / dots.size.width
                dots.setScale(dotsScale)
                dots.position = CGPoint(x: 0, y: itemY + itemHeight / 2 - 5)
                dots.alpha = 1.0
                contentNode?.addChild(dots)
            }
            
            addItemNode(item: item, at: itemY, to: contentNode!)
        }
    }
    
    private func buildScrollableItems(visibleHeight: CGFloat) {
        // Scrollable list with crop node (like SongSelectScene)
        let songAreaTopPadding: CGFloat = -5
        let songAreaBottomPadding: CGFloat = 25
        let adjustedVisibleHeight = visibleHeight - songAreaBottomPadding - songAreaTopPadding
        
        // Create crop node for clipping
        let crop = SKCropNode()
        crop.position = CGPoint(x: 0, y: -headerHeight - songAreaTopPadding - adjustedVisibleHeight / 2)
        crop.zPosition = 0
        crop.name = "itemCrop"
        
        // Mask for visible area
        let maskShape = SKSpriteNode(color: .white, size: CGSize(width: width, height: adjustedVisibleHeight))
        maskShape.position = .zero
        crop.maskNode = maskShape
        
        // Scrollable content
        let content = SKNode()
        content.name = "scrollContent"
        
        // Position content based on scroll offset
        content.position = CGPoint(x: 0, y: adjustedVisibleHeight / 2 - itemHeight / 2 + scrollOffset)
        
        // Add items to scroll content
        for (index, item) in items.enumerated() {
            let itemY = -CGFloat(index) * itemHeight
            
            // Dots separator (between items)
            if index > 0 {
                let dots = SKSpriteNode(imageNamed: "dots")
                let dotsScale = (width * 0.85) / dots.size.width
                dots.setScale(dotsScale)
                dots.position = CGPoint(x: 0, y: itemY + itemHeight / 2 - 5)
                dots.alpha = 1.0
                content.addChild(dots)
            }
            
            addItemNode(item: item, at: itemY, to: content)
        }
        
        crop.addChild(content)
        addChild(crop)
        cropNode = crop
        scrollContent = content
        
        // Touch area for scrolling
        let scrollTouchArea = SKSpriteNode(color: .clear, size: CGSize(width: width, height: adjustedVisibleHeight))
        scrollTouchArea.name = "checkboxScrollArea"
        scrollTouchArea.position = CGPoint(x: 0, y: -headerHeight - songAreaTopPadding - adjustedVisibleHeight / 2)
        scrollTouchArea.zPosition = 1.5
        addChild(scrollTouchArea)
    }
    
    private func addItemNode(item: Item, at y: CGFloat, to parent: SKNode) {
        let itemContainer = SKNode()
        itemContainer.name = "checkboxItem_\(item.id)"
        itemContainer.position = CGPoint(x: 0, y: y)
        
        // Checkbox
        let checkboxState: CheckboxState = item.isChecked ? .checked : .unchecked
        let checkbox = createCheckbox(state: checkboxState)
        checkbox.position = CGPoint(x: -width / 2 + 40, y: 0)
        checkbox.name = "checkbox_\(item.id)"
        itemContainer.addChild(checkbox)
        
        // Item title
        let itemLabel = SKLabelNode(fontNamed: FontConfig.medium)
        itemLabel.text = item.title
        itemLabel.fontSize = LayoutConstants.shared.bodyFontSize
        itemLabel.fontColor = .white
        itemLabel.verticalAlignmentMode = .center
        itemLabel.horizontalAlignmentMode = .left
        itemLabel.position = CGPoint(x: -width / 2 + 70, y: 0)
        itemLabel.zPosition = 1
        itemContainer.addChild(itemLabel)
        
        // Touch area for item
        let itemTouch = SKSpriteNode(color: .clear, size: CGSize(width: width, height: itemHeight))
        itemTouch.name = "checkboxItemTouch_\(item.id)"
        itemTouch.position = .zero
        itemTouch.zPosition = 2
        itemContainer.addChild(itemTouch)
        
        parent.addChild(itemContainer)
    }
    
    // MARK: - Scrolling
    
    /// Calculate the visible height for the item area from the background
    private func calculateVisibleHeight() -> CGFloat {
        let bgImageName = useSmallBackground ? "menu-expanded-small" : "menu-expanded-mid"
        let bg = SKSpriteNode(imageNamed: bgImageName)
        let originalWidth = bg.size.width
        let originalHeight = bg.size.height
        let bgScale = width / originalWidth
        let scaledBgHeight = originalHeight * bgScale
        return scaledBgHeight - headerHeight
    }
    
    private func updateScrollPosition() {
        guard let content = scrollContent, needsScrolling else { return }
        
        let visibleHeight = calculateVisibleHeight()
        let songAreaTopPadding: CGFloat = -5
        let songAreaBottomPadding: CGFloat = 25
        let adjustedVisibleHeight = visibleHeight - songAreaBottomPadding - songAreaTopPadding
        
        content.position = CGPoint(x: 0, y: adjustedVisibleHeight / 2 - itemHeight / 2 + scrollOffset)
    }
    
    private func clampScrollOffset() {
        guard needsScrolling else { return }
        
        let visibleHeight = calculateVisibleHeight()
        let totalContentHeight = CGFloat(items.count) * itemHeight
        let songAreaTopPadding: CGFloat = -5
        let songAreaBottomPadding: CGFloat = 25
        let adjustedVisibleHeight = visibleHeight - songAreaBottomPadding - songAreaTopPadding
        let maxScroll = max(0, totalContentHeight - adjustedVisibleHeight)
        
        scrollOffset = min(maxScroll, max(0, scrollOffset))
    }
    
    // MARK: - UI Helpers
    
    private func createCaret(pointingUp: Bool) -> SKShapeNode {
        let path = CGMutablePath()
        if pointingUp {
            path.move(to: CGPoint(x: -6, y: -4))
            path.addLine(to: CGPoint(x: 0, y: 4))
            path.addLine(to: CGPoint(x: 6, y: -4))
        } else {
            path.move(to: CGPoint(x: -6, y: 4))
            path.addLine(to: CGPoint(x: 0, y: -4))
            path.addLine(to: CGPoint(x: 6, y: 4))
        }
        
        let caret = SKShapeNode(path: path)
        caret.fillColor = .clear
        caret.strokeColor = .white
        caret.lineWidth = 3.0
        caret.lineCap = .round
        caret.lineJoin = .round
        caret.glowWidth = 0
        caret.zPosition = 1
        return caret
    }
    
    private func createCheckbox(state: CheckboxState) -> SKNode {
        let container = SKNode()
        
        // Use checkbox assets
        let imageName: String
        switch state {
        case .checked:
            imageName = "checkbox-checked"
        case .unchecked:
            imageName = "checkbox-unchecked"
        case .mixed:
            imageName = "checkbox-mixed"
        }
        let checkbox = SKSpriteNode(imageNamed: imageName)
        let scale = checkboxSize / max(checkbox.size.width, checkbox.size.height)
        checkbox.setScale(scale)
        checkbox.zPosition = 0
        container.addChild(checkbox)
        
        return container
    }
    
    // MARK: - Touch Handling
    
    /// Called when touch begins. Returns true if this component is handling the touch.
    func touchBegan(at location: CGPoint) -> Bool {
        let localLocation = convert(location, from: parent ?? self)
        let nodes = self.nodes(at: localLocation)
        
        // Check if touch is in scroll area
        for node in nodes {
            if node.name == "checkboxScrollArea" {
                isScrolling = true
                touchStartY = localLocation.y
                lastTouchY = localLocation.y
                return true
            }
        }
        
        return false
    }
    
    /// Called when touch moves. Returns true if this component handled the move.
    func touchMoved(to location: CGPoint) -> Bool {
        guard isScrolling, needsScrolling else { return false }
        
        let localLocation = convert(location, from: parent ?? self)
        let deltaY = localLocation.y - lastTouchY
        lastTouchY = localLocation.y
        
        scrollOffset += deltaY
        clampScrollOffset()
        updateScrollPosition()
        
        return true
    }
    
    /// Called when touch ends. Returns true if touch was handled as a tap.
    func touchEnded(at location: CGPoint, wasDragging: Bool) -> Bool {
        let wasScrolling = isScrolling
        isScrolling = false
        
        // If we were dragging, don't process as tap
        if wasDragging && wasScrolling {
            return false
        }
        
        return handleTap(at: location)
    }
    
    /// Handle a tap at the given location. Returns true if the touch was handled.
    func handleTouch(at location: CGPoint) -> Bool {
        return handleTap(at: location)
    }
    
    private func handleTap(at location: CGPoint) -> Bool {
        let localLocation = convert(location, from: parent ?? self)
        let nodes = self.nodes(at: localLocation)
        
        // First pass: check for header taps (prioritized over item taps)
        // This is important because when scrolled, clipped items can still be hit-tested
        // and we need to ensure header taps always take priority
        for node in nodes {
            guard let name = node.name else { continue }
            
            // Header checkbox tap - toggle all items
            if name == "headerCheckboxTouch" || name == "headerCheckbox" {
                toggleAllItems()
                return true
            }
            
            // Header tap - toggle expansion
            if name == "checkboxListHeader" {
                toggleExpanded()
                return true
            }
        }
        
        // Second pass: check for item taps
        for node in nodes {
            guard let name = node.name else { continue }
            
            // Item tap - toggle checkbox
            if name.hasPrefix("checkboxItemTouch_") || name.hasPrefix("checkboxItem_") || name.hasPrefix("checkbox_") {
                let itemId = name.replacingOccurrences(of: "checkboxItemTouch_", with: "")
                    .replacingOccurrences(of: "checkboxItem_", with: "")
                    .replacingOccurrences(of: "checkbox_", with: "")
                
                if let index = items.firstIndex(where: { $0.id == itemId }) {
                    items[index].isChecked.toggle()
                    // Play appropriate sound for check/uncheck
                    AudioManager.shared.playUISound(items[index].isChecked ? .checkOn : .checkOff)
                    rebuild()
                    onItemToggled?(itemId, items[index].isChecked)
                    return true
                }
            }
        }
        
        return false
    }
}
