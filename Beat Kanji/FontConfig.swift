//
//  FontConfig.swift
//  Beat Kanji
//
//  Centralized font configuration for the game.
//

import UIKit
import CoreText

/// Font configuration for consistent typography across the game.
/// Uses Noto Sans JP static fonts for Japanese character support.
enum FontConfig {
    // MARK: - Font Names
    
    /// Bold weight font name
    static let bold = "NotoSansJP-Bold"
    
    /// SemiBold weight font name
    static let semiBold = "NotoSansJP-SemiBold"
    
    /// Medium weight font name (uses SemiBold)
    static let medium = "NotoSansJP-SemiBold"
    
    /// Regular weight font name
    static let regular = "NotoSansJP-Regular"
    
    // MARK: - Registration
    
    /// Ensures custom fonts are registered at runtime (helps if UIAppFonts is misconfigured in some builds).
    static func registerFontsIfNeeded() {
        for name in [bold, semiBold, regular] {
            // If the font is already available, skip registration.
            if UIFont(name: name, size: 12) != nil { continue }
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
    
    // MARK: - UIKit Helpers
    
    /// Returns a UIFont with the specified size and weight
    static func uiFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        let fontName: String
        switch weight {
        case .bold, .heavy, .black:
            fontName = bold
        case .semibold, .medium:
            fontName = semiBold
        default:
            fontName = regular
        }
        return UIFont(name: fontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
    }
    
}
