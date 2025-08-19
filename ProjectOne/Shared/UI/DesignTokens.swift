import SwiftUI

// MARK: - Design Tokens
// Centralized semantic tokens for colors & opacities used across glass surfaces.

public enum GlassTintToken {
    public static let primary = Color.accentColor
    public static let info = Color.blue
    public static let success = Color.green
    public static let warning = Color.orange
    public static let danger = Color.red
    public static let purple = Color.purple
    public static let mint = Color.mint
}

public enum GlassOpacityToken {
    // Base overlay opacities for accent backgrounds / overlays
    public static let subtle: Double = 0.08
    public static let light: Double = 0.12
    public static let medium: Double = 0.18
    public static let strong: Double = 0.25
}

public extension View {
    // Convenience helpers for common tinted glass chips / pills
    func glassPill(_ tint: Color) -> some View {
        pillGlass(tint: tint)
    }
}
