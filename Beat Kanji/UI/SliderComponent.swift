//
//  SliderComponent.swift
//  Beat Kanji
//
//  Created by Copilot on 29.11.25.
//

import SpriteKit

/// A reusable slider component using slider-bg, slider-filling, and slider-knob assets.
/// The filling is clipped at the knob center rather than stretched.
class SliderComponent: SKNode {
    
    // MARK: - Properties
    
    /// Current value from 0 to 1
    private(set) var value: Float = 0.5 {
        didSet {
            updateFilling()
        }
    }
    
    /// Callback when value changes
    var onValueChanged: ((Float) -> Void)?
    
    // MARK: - Nodes
    
    private let background: SKSpriteNode
    private let filling: SKSpriteNode
    private let fillingCrop: SKCropNode
    private let fillingMask: SKSpriteNode
    private let knob: SKSpriteNode
    
    // MARK: - Layout
    
    private let sliderWidth: CGFloat
    private let knobWidth: CGFloat
    
    /// Horizontal range the knob can travel (from center of left edge to center of right edge)
    private var knobMinX: CGFloat { -sliderWidth / 2 + knobWidth / 2 }
    private var knobMaxX: CGFloat { sliderWidth / 2 - knobWidth / 2 }
    private var knobRange: CGFloat { knobMaxX - knobMinX }
    
    // MARK: - Touch Tracking
    
    private var isDragging = false
    
    // MARK: - Initialization
    
    /// Creates a slider with the given width. Height is determined by assets.
    init(width: CGFloat, initialValue: Float = 0.5) {
        // Load assets
        background = SKSpriteNode(imageNamed: "slider-bg")
        filling = SKSpriteNode(imageNamed: "slider-filling")
        knob = SKSpriteNode(imageNamed: "slider-knob")
        
        // Calculate scale to fit width
        let scale = width / background.size.width
        sliderWidth = width
        knobWidth = knob.size.width * scale
        
        // Scale background
        background.setScale(scale)
        background.zPosition = 0
        
        // Scale filling
        filling.setScale(scale)
        filling.anchorPoint = CGPoint(x: 0, y: 0.5) // Anchor left for masking
        filling.position = CGPoint(x: -sliderWidth / 2, y: 0)
        filling.zPosition = 1
        
        // Create crop node with mask for filling
        fillingCrop = SKCropNode()
        fillingCrop.zPosition = 1
        
        // Mask is a white rectangle that will be resized
        fillingMask = SKSpriteNode(color: .white, size: CGSize(width: sliderWidth, height: filling.size.height * scale))
        fillingMask.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillingMask.position = CGPoint(x: -sliderWidth / 2, y: 0)
        fillingCrop.maskNode = fillingMask
        fillingCrop.addChild(filling)
        
        // Scale knob
        knob.setScale(scale)
        knob.zPosition = 2
        
        super.init()
        
        isUserInteractionEnabled = true
        
        addChild(background)
        addChild(fillingCrop)
        addChild(knob)
        
        // Set initial value
        self.value = max(0, min(1, initialValue))
        updateFilling()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Value Updates
    
    func setValue(_ newValue: Float, animated: Bool = false) {
        let clamped = max(0, min(1, newValue))
        if animated {
            let targetX = knobMinX + CGFloat(clamped) * knobRange
            let move = SKAction.moveTo(x: targetX, duration: 0.15)
            move.timingMode = .easeOut
            knob.run(move)
            
            // Animate mask width - at 100% show full filling
            let targetWidth = clamped >= 0.99 ? sliderWidth : (targetX + sliderWidth / 2)
            let startWidth = fillingMask.size.width
            let resize = SKAction.customAction(withDuration: 0.15) { [weak self] _, elapsed in
                guard let self else { return }
                let progress = elapsed / 0.15
                let currentWidth = startWidth + (targetWidth - startWidth) * progress
                self.fillingMask.size.width = max(0, currentWidth)
            }
            fillingMask.run(resize)
            
            value = clamped
        } else {
            value = clamped
        }
    }
    
    private func updateFilling() {
        // Position knob
        let knobX = knobMinX + CGFloat(value) * knobRange
        knob.position = CGPoint(x: knobX, y: 0)
        
        // Update mask width to clip at knob center
        // At 100%, show the full filling without cutoff
        if value >= 0.99 {
            fillingMask.size.width = sliderWidth
        } else {
            // Mask extends from left edge (-sliderWidth/2) to knob center (knobX)
            // So mask width = knobX - (-sliderWidth/2) = knobX + sliderWidth/2
            let maskWidth = knobX + sliderWidth / 2
            fillingMask.size.width = max(0, maskWidth)
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Expand hit area for easier grabbing
        let hitArea = knob.frame.insetBy(dx: -20, dy: -20)
        if hitArea.contains(location) || background.frame.contains(location) {
            isDragging = true
            updateValueFromLocation(location)
            
            // Visual feedback
            knob.run(SKAction.scale(to: knob.xScale * 1.1, duration: 0.1))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDragging, let touch = touches.first else { return }
        let location = touch.location(in: self)
        updateValueFromLocation(location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDragging {
            isDragging = false
            // Reset knob scale
            let originalScale = sliderWidth / background.texture!.size().width
            knob.run(SKAction.scale(to: originalScale, duration: 0.1))
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    private func updateValueFromLocation(_ location: CGPoint) {
        // Calculate value from x position
        let clampedX = max(knobMinX, min(knobMaxX, location.x))
        let newValue = Float((clampedX - knobMinX) / knobRange)
        
        if abs(newValue - value) > 0.001 {
            value = newValue
            onValueChanged?(value)
        }
    }
}
