import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// View for displaying entity nodes in the knowledge graph
struct EntityNodeView: View {
    let entity: Entity
    let position: CGPoint
    let isSelected: Bool
    
    private var nodeSize: CGFloat {
        let baseSize: CGFloat = 40
        let sizeMultiplier = 1.0 + (entity.importance * 0.5) // Scale based on importance
        return baseSize * sizeMultiplier
    }
    
    private var nodeColor: Color {
        return Color(entity.type.color)
    }
    
    private var selectedColor: Color {
        return nodeColor.opacity(0.9)
    }
    
    private var strokeWidth: CGFloat {
        return isSelected ? 3.0 : 1.5
    }
    
    private var strokeColor: Color {
        if isSelected {
            return .primary
        } else if entity.isValidated {
            return .green
        } else {
            return .secondary
        }
    }
    
    var body: some View {
        ZStack {
            // Node background circle
            Circle()
                .fill(nodeColor.opacity(0.3))
                .frame(width: nodeSize, height: nodeSize)
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                )
            
            // Entity type icon
            Image(systemName: entity.type.iconName)
                .font(.system(size: nodeSize * 0.4))
                .foregroundColor(nodeColor)
                .fontWeight(.medium)
            
            // Importance indicator ring
            if entity.importance > 0.7 {
                Circle()
                    .stroke(
                        nodeColor,
                        style: StrokeStyle(lineWidth: 2, dash: [3, 3])
                    )
                    .frame(width: nodeSize + 8, height: nodeSize + 8)
                    .opacity(0.6)
            }
            
            // Validation badge
            if entity.isValidated {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                    .background({
                        #if canImport(AppKit)
                        return Color(NSColor.controlBackgroundColor)
                        #else
                        return Color(.systemBackground)
                        #endif
                    }())
                    .clipShape(Circle())
                    .offset(x: nodeSize / 2 - 4, y: -nodeSize / 2 + 4)
            }
            
            // Entity name label
            EntityNameLabel(entity: entity, isSelected: isSelected)
                .offset(y: nodeSize / 2 + 15)
        }
        .position(position)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Label displaying entity name and metadata
struct EntityNameLabel: View {
    let entity: Entity
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(entity.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            if isSelected {
                HStack(spacing: 4) {
                    // Mentions indicator
                    if entity.mentions > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.caption2)
                            Text("\(entity.mentions)")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Confidence indicator
                    if entity.confidence > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                            Text("\(Int(entity.confidence * 100))%")
                                .font(.caption2)
                        }
                        .foregroundColor(entity.confidence > 0.7 ? .green : .orange)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background({
            #if canImport(AppKit)
            return Color(NSColor.controlBackgroundColor).opacity(0.9)
            #else
            return Color(.systemBackground).opacity(0.9)
            #endif
        }())
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// Pulsing animation for high-importance entities
struct PulsingRing: View {
    let size: CGFloat
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.3 : 0.8)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

/// Specialized view for different entity types
struct EntityTypeIndicator: View {
    let entity: Entity
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Type-specific background patterns
            switch entity.type {
            case .person:
                PersonIndicator(size: size)
            case .organization:
                OrganizationIndicator(size: size)
            case .location:
                LocationIndicator(size: size)
            case .activity:
                ActivityIndicator(size: size)
            case .concept:
                ConceptIndicator(size: size)
            }
        }
    }
}

struct PersonIndicator: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
    }
}

struct OrganizationIndicator: View {
    let size: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
    }
}

struct LocationIndicator: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                center: .center,
                startRadius: 0,
                endRadius: size / 2
            ))
            .frame(width: size, height: size)
    }
}

struct ActivityIndicator: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: size, height: size)
    }
}

struct ConceptIndicator: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        {
            #if canImport(AppKit)
            return Color(NSColor.systemGray)
            #else
            return Color(.systemGray)
            #endif
        }()
            .ignoresSafeArea()
        
        VStack(spacing: 50) {
            // Regular entity
            EntityNodeView(
                entity: {
                    let entity = Entity(name: "John Doe", type: .person)
                    entity.confidence = 0.85
                    entity.importance = 0.6
                    entity.mentions = 5
                    entity.isValidated = true
                    return entity
                }(),
                position: CGPoint(x: 100, y: 100),
                isSelected: false
            )
            
            // Selected high-importance entity
            EntityNodeView(
                entity: {
                    let entity = Entity(name: "Apple Inc.", type: .organization)
                    entity.confidence = 0.95
                    entity.importance = 0.9
                    entity.mentions = 15
                    entity.isValidated = true
                    return entity
                }(),
                position: CGPoint(x: 300, y: 100),
                isSelected: true
            )
        }
    }
    .frame(width: 400, height: 300)
}