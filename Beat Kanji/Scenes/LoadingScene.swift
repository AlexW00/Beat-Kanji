//
//  LoadingScene.swift
//  Beat Kanji
//
//  Splash/Loading screen displayed on app launch while data loads.
//

import SpriteKit

class LoadingScene: SKScene {
    
    private var loadingLabel: SKLabelNode?
    private var dotCount = 0
    private var dotTimer: Timer?
    
    override func didMove(to view: SKView) {
        setupBackground()
        setupLogo()
        setupLoadingText()
        startLoading()
    }
    
    override func willMove(from view: SKView) {
        dotTimer?.invalidate()
        dotTimer = nil
    }
    
    // MARK: - Background Setup
    
    private func setupBackground() {
        // Use shared background (no particles during loading)
        SharedBackground.addBackground(to: self, alpha: 1.0)
        addStaticConveyorLines()
    }
    
    /// Adds static conveyor lines (no animation, no dashed horizontal lines)
    private func addStaticConveyorLines() {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let horizonY = size.height * SharedBackground.conveyorHorizonY
        
        let gridNode = SKNode()
        gridNode.position = .zero
        gridNode.zPosition = -98
        addChild(gridNode)
        
        // Vertical Lines (converging to center) - same as SharedBackground
        let numLines = 8
        let bottomWidth = size.width
        
        for i in 0...numLines {
            let t = CGFloat(i) / CGFloat(numLines)
            let xOffset = (t - 0.5) * bottomWidth
            
            let path = CGMutablePath()
            path.move(to: center)
            let bottomX = center.x + xOffset
            path.addLine(to: CGPoint(x: bottomX, y: horizonY))
            
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(white: 1.0, alpha: 0.3)
            line.lineWidth = 1
            gridNode.addChild(line)
        }
        
        // Closing Line at horizon
        let closingPath = CGMutablePath()
        let leftX = center.x - 0.5 * bottomWidth
        let rightX = center.x + 0.5 * bottomWidth
        closingPath.move(to: CGPoint(x: leftX, y: horizonY))
        closingPath.addLine(to: CGPoint(x: rightX, y: horizonY))
        
        let closingLine = SKShapeNode(path: closingPath)
        closingLine.strokeColor = SKColor(white: 1.0, alpha: 0.1)
        closingLine.lineWidth = 2
        gridNode.addChild(closingLine)
    }
    
    // MARK: - Logo Setup
    
    private func setupLogo() {
        let logoNode = SKSpriteNode(imageNamed: "start-screen-logo")
        
        // Scale logo to be larger and more prominent (same as StartScene)
        let maxWidth = size.width * 0.95
        let maxHeight = size.height * 0.35
        let scale = min(maxWidth / logoNode.size.width, maxHeight / logoNode.size.height, 1.0)
        logoNode.setScale(scale)
        
        // Position at center of screen (same as StartScene)
        logoNode.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        logoNode.zPosition = 100
        addChild(logoNode)
    }
    
    // MARK: - Loading Text
    
    private func setupLoadingText() {
        // Position where the play button usually is
        let label = SKLabelNode(fontNamed: FontConfig.bold)
        label.fontSize = 24
        label.fontColor = .white
        label.alpha = 0.9
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        label.zPosition = 100
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.text = "Loading"
        addChild(label)
        loadingLabel = label
        
        // Animate the dots
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dotCount = (self.dotCount + 1) % 4
            let dots = String(repeating: ".", count: self.dotCount)
            self.loadingLabel?.text = "Loading\(dots)"
        }
    }
    
    // MARK: - Data Loading
    
    private func startLoading() {
        // Load data on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Preload kanji data
            KanjiDataLoader.shared.preloadPrototypeData()
            
            // Small delay to ensure splash is visible even on fast devices
            Thread.sleep(forTimeInterval: 0.5)
            
            // Transition on main thread
            DispatchQueue.main.async {
                self?.transitionToStartScene()
            }
        }
    }
    
    private func transitionToStartScene() {
        guard let view = self.view else { return }
        
        // Stop the dot animation
        dotTimer?.invalidate()
        dotTimer = nil
        
        // Create start scene
        let startScene = StartScene(size: size)
        startScene.scaleMode = .aspectFill
        
        // Crossfade transition (both scenes blend together)
        let transition = SKTransition.crossFade(withDuration: 0.8)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        
        view.presentScene(startScene, transition: transition)
    }
}
