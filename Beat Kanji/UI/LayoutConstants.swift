//
//  LayoutConstants.swift
//  Beat Kanji
//
//  Responsive layout utilities for adapting UI to different screen sizes and aspect ratios.
//

import SpriteKit
import UIKit

/// Provides responsive layout calculations for different device sizes and aspect ratios.
/// 
/// **iPad Strategy**: Instead of scaling UI to fill the wider screen, we use fixed
/// iPhone-like dimensions centered on screen. This prevents distortion and maintains
/// the intended visual design.
/// 
/// Usage: Call `LayoutConstants.configure(for: sceneSize)` once when a scene loads,
/// then access layout values via the shared instance.
struct LayoutConstants {
    
    // MARK: - Singleton
    
    private(set) static var shared = LayoutConstants(size: CGSize(width: 393, height: 852))
    
    /// Configure the layout constants for a given scene size.
    /// Call this in `didMove(to:)` before setting up UI.
    static func configure(for size: CGSize) {
        shared = LayoutConstants(size: size)
    }
    
    // MARK: - Device Info
    
    let sceneSize: CGSize
    let isIPad: Bool
    let aspectRatio: CGFloat  // width / height (< 1 for portrait)
    
    /// Scale factor relative to iPhone 15 Pro reference (393 x 852)
    /// On iPad, this is intentionally kept close to 1.0 to use iPhone-like sizing
    let scaleFactor: CGFloat
    
    // MARK: - Margins & Spacing
    
    /// Margin from screen edges for buttons (e.g., back button)
    let edgeMargin: CGFloat
    
    /// Top bar Y position (for back button, difficulty switcher, etc.)
    let topBarY: CGFloat
    
    /// Y offset from top for title labels
    let titleTopOffset: CGFloat
    
    // MARK: - Menu Dimensions
    
    /// Maximum width for menu containers - KEY for iPad layout
    /// This prevents menus from becoming too wide on iPad
    let maxMenuWidth: CGFloat
    
    /// Menu width - uses fixed width on iPad, percentage on iPhone
    var menuWidth: CGFloat {
        if isIPad {
            // iPad: use fixed width, don't scale to screen width
            return maxMenuWidth
        } else {
            // iPhone: use percentage of screen width
            return sceneSize.width * 0.85
        }
    }
    
    /// Centered X position for menus
    var menuCenterX: CGFloat {
        return sceneSize.width / 2
    }
    
    // MARK: - Button Sizes (fixed, not scaled)
    
    /// Size for square buttons (back, pause, etc.)
    let squareButtonSize: CGFloat = 85
    
    /// Width for standard text buttons
    let standardButtonWidth: CGFloat = 200
    
    /// Width for small buttons (e.g., About section)
    let smallButtonWidth: CGFloat = 120
    
    // MARK: - Font Sizes (fixed, not scaled)
    
    /// Large title font size
    let titleFontSize: CGFloat = 32
    
    /// Category header font size
    let headerFontSize: CGFloat = 22
    
    /// Standard body font size
    let bodyFontSize: CGFloat = 18
    
    /// Small label font size
    let smallFontSize: CGFloat = 16
    
    // MARK: - List Component Sizes (fixed, not scaled)
    
    /// Height for list headers
    let listHeaderHeight: CGFloat = 70
    
    /// Height for list items
    let listItemHeight: CGFloat = 50
    
    /// Size for checkboxes
    let checkboxSize: CGFloat = 28
    
    // MARK: - Category Layout (Settings Scene)
    
    /// Content height for tall categories (Sound)
    let tallCategoryHeight: CGFloat = 210
    
    /// Content height for standard categories (Display, About)
    let standardCategoryHeight: CGFloat = 150

    // MARK: - Kanji Stroke Widths
    // iPad uses thicker strokes for better visibility on larger screens
    
    /// Background stroke width (the template stroke to trace)
    var kanjiBackgroundStrokeWidth: CGFloat {
        isIPad ? 13.0 : 10.0
    }
    
    /// Neon glow outer width for current stroke
    var kanjiGlowWidth: CGFloat {
        isIPad ? 20.0 : 16.0
    }
    
    /// Neon core width for current stroke
    var kanjiCoreWidth: CGFloat {
        isIPad ? 6.5 : 5.0
    }
    
    /// Flying stroke background width (base, before depth scaling)
    var flyingStrokeBgWidth: CGFloat {
        isIPad ? 10.0 : 8.0
    }
    
    /// Flying stroke glow width (base, before depth scaling)
    var flyingStrokeGlowWidth: CGFloat {
        isIPad ? 17.0 : 14.0
    }
    
    /// Flying stroke core width (base, before depth scaling)
    var flyingStrokeCoreWidth: CGFloat {
        isIPad ? 5.0 : 4.0
    }
    
    /// Standard stroke glow outer width for flying strokes
    var flyingStrokeGlowOuterWidth: CGFloat {
        isIPad ? 15.0 : 12.0
    }
    
    /// Standard stroke core width for flying strokes
    var flyingStrokeStandardCoreWidth: CGFloat {
        isIPad ? 3.75 : 3.0
    }
    
    /// User drawing glow width
    var drawingGlowWidth: CGFloat {
        isIPad ? 20.0 : 16.0
    }
    
    /// User drawing core width
    var drawingCoreWidth: CGFloat {
        isIPad ? 6.5 : 5.0
    }

    /// Padding from the top edge for tall category headers (Sound)
    let tallCategoryHeaderTopPadding: CGFloat = 30
    
    /// Padding from the top edge for standard category headers (Display/iPad)
    let standardCategoryHeaderTopPadding: CGFloat = 24

    /// Padding tweak for About category header only (slightly higher)
    let aboutCategoryHeaderTopPadding: CGFloat = 20
    
    // MARK: - Pagination
    
    /// Size for pagination buttons
    let paginationButtonSize: CGFloat = 85
    
    /// Y position for pagination controls from bottom
    let paginationBottomOffset: CGFloat = 90
    
    // MARK: - Clip/Inset Values (SongSelectScene)
    
    /// Top inset for menu clip node
    let menuClipTopInset: CGFloat
    
    /// Bottom inset for menu clip node
    let menuClipBottomInset: CGFloat
    
    // MARK: - Initialization
    
    private init(size: CGSize) {
        self.sceneSize = size
        self.isIPad = UIDevice.current.userInterfaceIdiom == .pad
        self.aspectRatio = size.width / size.height
        
        // Reference device: iPhone 15 Pro (393 x 852)
        let referenceWidth: CGFloat = 393
        
        // Scale factor: on iPhone, scale proportionally; on iPad, keep close to 1.0
        if isIPad {
            // iPad: minimal scaling - use iPhone-like sizes
            self.scaleFactor = 1.0
            // Fixed menu width that looks good on iPad (similar to iPhone proportions)
            self.maxMenuWidth = 380
        } else {
            // iPhone: scale based on device width
            self.scaleFactor = size.width / referenceWidth
            self.maxMenuWidth = 600 // Not really used on iPhone
        }
        
        // Margins - fixed offset from edges
        self.edgeMargin = 60
        
        // Top bar positioning - fixed offset from top
        self.topBarY = size.height - 75
        self.titleTopOffset = 150
        
        // Clip insets - fixed values that work for both devices
        self.menuClipTopInset = 170
        self.menuClipBottomInset = 150
    }
    
    // MARK: - Helper Methods
    
    /// Calculate proportional Y position from top of screen
    func fromTop(_ offset: CGFloat) -> CGFloat {
        return sceneSize.height - offset
    }
    
    /// Calculate proportional Y position based on fraction of screen height
    func heightFraction(_ fraction: CGFloat) -> CGFloat {
        return sceneSize.height * fraction
    }
    
    /// Calculate slider width based on menu width
    var sliderWidth: CGFloat {
        return menuWidth * 0.8
    }
    
    /// Get the appropriate category Y positions for settings screen
    /// Returns (soundY, displayY, aboutY) based on screen height
    func settingsCategoryYPositions() -> (sound: CGFloat, display: CGFloat, about: CGFloat) {
        // Compress vertical spread on iPad to keep pagination clear
        if isIPad {
            let soundY = sceneSize.height * 0.64
            let displayY = sceneSize.height * 0.46
            let aboutY = sceneSize.height * 0.30
            return (soundY, displayY, aboutY)
        }
        
        // Slightly tighter grouping on iPhone while keeping clear spacing
        let soundY = sceneSize.height * 0.64
        let displayY = sceneSize.height * 0.42
        let aboutY = sceneSize.height * 0.24
        
        return (soundY, displayY, aboutY)
    }
}

// MARK: - Utility Functions

private func clamp(_ value: CGFloat, min minVal: CGFloat, max maxVal: CGFloat) -> CGFloat {
    return Swift.min(Swift.max(value, minVal), maxVal)
}
