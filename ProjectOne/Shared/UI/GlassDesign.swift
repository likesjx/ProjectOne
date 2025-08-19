import SwiftUI

// MARK: - Glass Design Abstractions
// Material + tint simulation of the intended iOS 26 Glass API ("GlassEffect") so code compiles on current SDKs.
// When the real API becomes available, you can reintroduce a conditional branch that uses it.

public enum AppGlassStyle: Sendable {
    case surface          // neutral panels
    case elevated         // cards / grouped content
    case header           // top bars, search regions
    case pill             // compact controls / chips
    case accent           // highlighted emphasis
}

private struct AnyShapeWrapper: Shape {
    // Marked @Sendable so the wrapper can be safely captured in concurrent contexts SwiftUI may synthesize.
    private let _path: @Sendable (CGRect) -> Path
    init<S: Shape & Sendable>(_ shape: S) { _path = { rect in shape.path(in: rect) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

private struct AppGlassModifier: ViewModifier {
    let style: AppGlassStyle
    let tint: Color?
    let shape: AnyShapeWrapper?
    let interactive: Bool
    let cornerRadius: CGFloat?
    
    // Tuned base opacities for style categories (rough approximation of intended GlassEffect layering)
    private var baseOpacity: Double {
        switch style {
        case .surface: 0.10
        case .elevated: 0.14
        case .header: 0.12
        case .pill: 0.18
        case .accent: 0.20
        }
    }
    
    // Shadow / depth values
    private var shadowSpec: (color: Color, radius: CGFloat, y: CGFloat) {
        switch style {
        case .elevated: return (.black.opacity(0.22), 18, 8)
        case .accent: return (.black.opacity(0.18), 14, 6)
        case .pill: return (.black.opacity(0.20), 10, 4)
        default: return (.black.opacity(0.15), 8, 3)
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        let resolvedShape: AnyShapeWrapper = shape ?? AnyShapeWrapper(RoundedRectangle(cornerRadius: cornerRadius ?? 20, style: .continuous))
        let tintOverlay = tint?.opacity(baseOpacity)
        content
            .background(
                ZStack {
                    // Core material layer
                    resolvedShape.fill(.ultraThinMaterial)
                    // Subtle inner highlight for elevation styles
                    if style == .elevated || style == .accent {
                        resolvedShape
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                            .blur(radius: 0.3)
                    }
                    // Tint overlay
                    if let tintOverlay { resolvedShape.fill(tintOverlay) }
                    // Interactive emphasis (slightly brighter rim)
                    if interactive {
                        resolvedShape
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.0)
                            .blendMode(.plusLighter)
                    }
                }
            )
            .clipShape(resolvedShape)
            // Depth / shadow
            .shadow(color: shadowSpec.color, radius: shadowSpec.radius, y: shadowSpec.y)
            // Light border for non-elevated subtle styles
            .overlay {
                if style == .surface || style == .header {
                    resolvedShape
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                }
            }
            // Slight scale animation cue when interactive (opt-in)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: interactive)
    }
}

public extension View {
    func appGlass(_ style: AppGlassStyle = .surface,
                  tint: Color? = nil,
                  shape: some Shape = RoundedRectangle(cornerRadius: 20, style: .continuous),
                  interactive: Bool = false) -> some View {
        modifier(AppGlassModifier(style: style,
                                  tint: tint,
                                  shape: AnyShapeWrapper(shape),
                                  interactive: interactive,
                                  cornerRadius: (shape as? RoundedRectangle)?.cornerSize.width))
    }
}

// Convenience for capsule / circle usage
public extension View {
    func pillGlass(tint: Color) -> some View { appGlass(.pill, tint: tint, shape: Capsule(), interactive: true) }
    func circleGlass(tint: Color) -> some View { appGlass(.pill, tint: tint, shape: Circle(), interactive: true) }
}
