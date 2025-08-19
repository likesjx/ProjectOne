//
//  GlassDesignSystem.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Glass Design System components for iOS/macOS 26.0+ cognitive interfaces
//

import SwiftUI

// MARK: - Glass Design System

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct GlassDesignSystem {
    
    // MARK: - Glass Materials
    
    public struct Materials {
        public static let ultraThin = Material.ultraThin
        public static let thin = Material.thin
        public static let regular = Material.regular
        public static let thick = Material.thick
        public static let ultraThick = Material.ultraThick
        
        // Cognitive-specific materials
        public static let cognitiveOverlay = Material.ultraThin
        public static let memoryLayer = Material.thin
        public static let fusionConnection = Material.regular
    }
    
    // MARK: - Glass Colors
    
    public struct Colors {
        // Cognitive layer colors with glass transparency
        public static let veridicalGlass = Color.blue.opacity(0.15)
        public static let semanticGlass = Color.purple.opacity(0.15)
        public static let episodicGlass = Color.green.opacity(0.15)
        public static let fusionGlass = Color.orange.opacity(0.15)
        
        // Status colors with glass effect
        public static let activeGlass = Color.cyan.opacity(0.2)
        public static let processingGlass = Color.yellow.opacity(0.2)
        public static let completedGlass = Color.mint.opacity(0.2)
        public static let errorGlass = Color.red.opacity(0.2)
        
        // Background tints
        public static let primaryGlass = Color.primary.opacity(0.05)
        public static let secondaryGlass = Color.secondary.opacity(0.03)
        
        // Accent colors for cognitive interfaces
        public static let cognitiveAccent = Color.accentColor
        public static let memoryHighlight = Color.cyan
        public static let fusionHighlight = Color.orange
    }
    
    // MARK: - Typography
    
    public struct Typography {
        public static let title = Font.largeTitle.weight(.medium)
        public static let headline = Font.headline.weight(.semibold)
        public static let subheadline = Font.subheadline.weight(.medium)
        public static let body = Font.body
        public static let caption = Font.caption
        public static let caption2 = Font.caption2
        
        // Cognitive-specific typography
        public static let cognitiveTitle = Font.title2.weight(.medium)
        public static let layerLabel = Font.caption.weight(.semibold)
        public static let metricValue = Font.title3.weight(.medium)
        public static let statusText = Font.caption2.weight(.medium)
    }
    
    // MARK: - Spacing
    
    public struct Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        
        // Cognitive-specific spacing
        public static let layerSpacing: CGFloat = 12
        public static let nodeSpacing: CGFloat = 20
        public static let connectionSpacing: CGFloat = 8
    }
    
    // MARK: - Corner Radius
    
    public struct CornerRadius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
        
        // Cognitive component radii
        public static let memoryCard: CGFloat = 12
        public static let cognitiveNode: CGFloat = 16
        public static let dashboard: CGFloat = 20
    }
    
    // MARK: - Animations
    
    public struct Animations {
        public static let quick = Animation.easeInOut(duration: 0.2)
        public static let standard = Animation.easeInOut(duration: 0.3)
        public static let slow = Animation.easeInOut(duration: 0.5)
        public static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
        
        // Cognitive-specific animations
        public static let memoryLoad = Animation.easeOut(duration: 0.4)
        public static let fusionPulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        public static let cognitiveFlow = Animation.linear(duration: 2.0).repeatForever(autoreverses: false)
    }
}

// MARK: - Glass View Modifiers

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct GlassCard: ViewModifier {
    let material: Material
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    public init(
        material: Material = GlassDesignSystem.Materials.thin,
        cornerRadius: CGFloat = GlassDesignSystem.CornerRadius.md,
        shadowRadius: CGFloat = 2
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .primary.opacity(0.1), radius: shadowRadius)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool
    
    public init(color: Color, radius: CGFloat = 4, isActive: Bool = true) {
        self.color = color
        self.radius = radius
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(0.6) : .clear,
                radius: radius
            )
            .animation(GlassDesignSystem.Animations.standard, value: isActive)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryLayerStyle: ViewModifier {
    let layerType: CognitiveLayerType
    let isActive: Bool
    
    public init(layerType: CognitiveLayerType, isActive: Bool = false) {
        self.layerType = layerType
        self.isActive = isActive
    }
    
    public func body(content: Content) -> some View {
        content
            .background {
                layerBackgroundColor
                    .opacity(isActive ? 0.3 : 0.1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.md)
                    .stroke(layerBorderColor, lineWidth: isActive ? 2 : 1)
            }
            .modifier(CognitiveGlow(color: layerBorderColor, isActive: isActive))
    }
    
    private var layerBackgroundColor: Color {
        switch layerType {
        case .veridical: return GlassDesignSystem.Colors.veridicalGlass
        case .semantic: return GlassDesignSystem.Colors.semanticGlass
        case .episodic: return GlassDesignSystem.Colors.episodicGlass
        case .fusion: return GlassDesignSystem.Colors.fusionGlass
        }
    }
    
    private var layerBorderColor: Color {
        switch layerType {
        case .veridical: return .blue
        case .semantic: return .purple
        case .episodic: return .green
        case .fusion: return .orange
        }
    }
}

// MARK: - View Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension View {
    public func glassCard(
        material: Material = GlassDesignSystem.Materials.thin,
        cornerRadius: CGFloat = GlassDesignSystem.CornerRadius.md,
        shadowRadius: CGFloat = 2
    ) -> some View {
        modifier(GlassCard(material: material, cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    
    public func cognitiveGlow(
        color: Color,
        radius: CGFloat = 4,
        isActive: Bool = true
    ) -> some View {
        modifier(CognitiveGlow(color: color, radius: radius, isActive: isActive))
    }
    
    public func memoryLayerStyle(
        _ layerType: CognitiveLayerType,
        isActive: Bool = false
    ) -> some View {
        modifier(MemoryLayerStyle(layerType: layerType, isActive: isActive))
    }
}

// MARK: - Cognitive Component Styles

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveMetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    let isActive: Bool
    
    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        color: Color = GlassDesignSystem.Colors.cognitiveAccent,
        isActive: Bool = false
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.isActive = isActive
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isActive {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .modifier(CognitiveGlow(color: color, radius: 2))
                }
            }
            
            Text(value)
                .font(GlassDesignSystem.Typography.metricValue)
                .foregroundColor(.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(GlassDesignSystem.Typography.caption2)
                    .foregroundColor(.tertiary)
            }
        }
        .padding(GlassDesignSystem.Spacing.md)
        .glassCard()
        .animation(GlassDesignSystem.Animations.standard, value: isActive)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    
    public init(
        progress: Double,
        color: Color = GlassDesignSystem.Colors.cognitiveAccent,
        height: CGFloat = 4
    ) {
        self.progress = max(0, min(1, progress))
        self.color = color
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
                    .modifier(CognitiveGlow(color: color, radius: 1))
                    .animation(GlassDesignSystem.Animations.standard, value: progress)
            }
        }
        .frame(height: height)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct LayerIndicator: View {
    let layerType: CognitiveLayerType
    let isActive: Bool
    let size: CGFloat
    
    public init(layerType: CognitiveLayerType, isActive: Bool = false, size: CGFloat = 12) {
        self.layerType = layerType
        self.isActive = isActive
        self.size = size
    }
    
    public var body: some View {
        Circle()
            .fill(layerColor)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(layerColor.opacity(0.5), lineWidth: 1)
                    .scaleEffect(isActive ? 1.5 : 1.0)
                    .opacity(isActive ? 0.3 : 0.0)
            }
            .modifier(CognitiveGlow(color: layerColor, isActive: isActive))
            .animation(GlassDesignSystem.Animations.spring, value: isActive)
    }
    
    private var layerColor: Color {
        switch layerType {
        case .veridical: return .blue
        case .semantic: return .purple
        case .episodic: return .green
        case .fusion: return .orange
        }
    }
}

// MARK: - Cognitive Status Badge

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveStatusBadge: View {
    let status: CognitiveStatus
    let isAnimated: Bool
    
    public init(status: CognitiveStatus, isAnimated: Bool = true) {
        self.status = status
        self.isAnimated = isAnimated
    }
    
    public var body: some View {
        HStack(spacing: GlassDesignSystem.Spacing.xs) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .modifier(CognitiveGlow(color: status.color, radius: 1, isActive: isAnimated && status.shouldGlow))
            
            Text(status.displayName)
                .font(GlassDesignSystem.Typography.statusText)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, GlassDesignSystem.Spacing.sm)
        .padding(.vertical, GlassDesignSystem.Spacing.xs)
        .background(status.color.opacity(0.1))
        .overlay {
            RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.xs)
                .stroke(status.color.opacity(0.3), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.xs))
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum CognitiveStatus: CaseIterable {
    case idle
    case processing
    case consolidating
    case fusing
    case completed
    case error
    
    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .processing: return "Processing"
        case .consolidating: return "Consolidating"
        case .fusing: return "Fusing"
        case .completed: return "Completed"
        case .error: return "Error"
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return .secondary
        case .processing: return .cyan
        case .consolidating: return .blue
        case .fusing: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }
    
    public var shouldGlow: Bool {
        switch self {
        case .processing, .consolidating, .fusing: return true
        case .idle, .completed, .error: return false
        }
    }
}