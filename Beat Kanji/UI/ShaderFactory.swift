//
//  ShaderFactory.swift
//  Beat Kanji
//
//  Factory for creating reusable shaders.
//

import SpriteKit

/// Factory for creating shader effects used across the game.
enum ShaderFactory {
    
    // MARK: - Hue Shift Shader
    
    /// Creates a hue shift shader for recoloring sprites.
    /// The base button asset is cyan (~180°).
    /// - Parameter hueShift: The amount to shift the hue in radians
    /// - Returns: An SKShader configured with the hue shift
    static func createHueShiftShader(hueShift: Float) -> SKShader {
        let shaderSource = """
        void main() {
            vec4 color = texture2D(u_texture, v_tex_coord);
            
            // Convert RGB to HSV
            float cmax = max(color.r, max(color.g, color.b));
            float cmin = min(color.r, min(color.g, color.b));
            float delta = cmax - cmin;
            
            float hue = 0.0;
            if (delta > 0.0) {
                if (cmax == color.r) {
                    hue = mod((color.g - color.b) / delta, 6.0);
                } else if (cmax == color.g) {
                    hue = (color.b - color.r) / delta + 2.0;
                } else {
                    hue = (color.r - color.g) / delta + 4.0;
                }
                hue /= 6.0;
            }
            
            float sat = cmax > 0.0 ? delta / cmax : 0.0;
            float val = cmax;
            
            // Apply hue shift
            hue = mod(hue + u_hueShift / 6.28318, 1.0);
            
            // Convert back to RGB
            float c = val * sat;
            float x = c * (1.0 - abs(mod(hue * 6.0, 2.0) - 1.0));
            float m = val - c;
            
            vec3 rgb;
            float h6 = hue * 6.0;
            if (h6 < 1.0) rgb = vec3(c, x, 0.0);
            else if (h6 < 2.0) rgb = vec3(x, c, 0.0);
            else if (h6 < 3.0) rgb = vec3(0.0, c, x);
            else if (h6 < 4.0) rgb = vec3(0.0, x, c);
            else if (h6 < 5.0) rgb = vec3(x, 0.0, c);
            else rgb = vec3(c, 0.0, x);
            
            gl_FragColor = vec4(rgb + m, color.a);
        }
        """
        
        let shader = SKShader(source: shaderSource)
        shader.uniforms = [
            SKUniform(name: "u_hueShift", float: hueShift)
        ]
        return shader
    }
    
    /// Creates a hue shift shader for a difficulty level.
    /// Base button is cyan (~180°). Shifts to:
    /// - Easy (Green): ~120° → shift by -60° (-1.05 rad)
    /// - Medium (Yellow): ~60° → shift by -140° (-2.44 rad)
    /// - Hard (Red): ~0° → shift by -200° (-3.49 rad)
    /// - Parameter difficulty: The difficulty level
    /// - Returns: An SKShader configured for the difficulty color
    static func createHueShiftShader(for difficulty: DifficultyLevel) -> SKShader {
        let hueShift: Float
        switch difficulty {
        case .easy:
            hueShift = -1.05  // Cyan to Green
        case .medium:
            hueShift = -2.44  // Cyan to Yellow
        case .hard:
            hueShift = -3.49  // Cyan to Red
        }
        return createHueShiftShader(hueShift: hueShift)
    }
}

// MARK: - Difficulty Colors

extension DifficultyLevel {
    /// The display color for this difficulty level.
    var color: SKColor {
        switch self {
        case .easy:
            return SKColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        case .medium:
            return SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        case .hard:
            return SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
}
