import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// View for displaying relationship edges in the knowledge graph
struct RelationshipEdgeView: View {
    let relationship: Relationship
    let startPosition: CGPoint
    let endPosition: CGPoint
    let isSelected: Bool
    
    private var lineWidth: CGFloat {
        return CGFloat(relationship.edgeWidth)
    }
    
    private var lineColor: Color {
        return Color(relationship.edgeColor)
    }
    
    private var selectedLineColor: Color {
        return lineColor.opacity(0.8)
    }
    
    private var arrowSize: CGFloat {
        return 8.0
    }
    
    var body: some View {
        ZStack {
            // Main edge line
            EdgeLine(
                start: startPosition,
                end: endPosition,
                lineWidth: lineWidth,
                color: isSelected ? selectedLineColor : lineColor.opacity(0.6),
                isDashed: !relationship.isActive
            )
            
            // Directional arrow
            if !relationship.bidirectional {
                Arrow(
                    start: startPosition,
                    end: endPosition,
                    size: arrowSize,
                    color: isSelected ? selectedLineColor : lineColor.opacity(0.8)
                )
            }
            
            // Relationship label (shown when selected or high importance)
            if isSelected || relationship.importance > 0.7 {
                RelationshipLabel(
                    relationship: relationship,
                    position: midpoint(start: startPosition, end: endPosition)
                )
            }
        }
    }
    
    private func midpoint(start: CGPoint, end: CGPoint) -> CGPoint {
        return CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
    }
}

/// Line connecting two points with optional dashing
struct EdgeLine: View {
    let start: CGPoint
    let end: CGPoint
    let lineWidth: CGFloat
    let color: Color
    let isDashed: Bool
    
    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            color,
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                dash: isDashed ? [5, 5] : []
            )
        )
    }
}

/// Directional arrow for non-bidirectional relationships
struct Arrow: View {
    let start: CGPoint
    let end: CGPoint
    let size: CGFloat
    let color: Color
    
    private var angle: Double {
        return atan2(end.y - start.y, end.x - start.x)
    }
    
    private var arrowTipPosition: CGPoint {
        let distance = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let adjustedDistance = distance - 25 // Offset from node edge
        
        return CGPoint(
            x: start.x + adjustedDistance * CoreGraphics.cos(angle),
            y: start.y + adjustedDistance * CoreGraphics.sin(angle)
        )
    }
    
    var body: some View {
        Path { path in
            let tipX = arrowTipPosition.x
            let tipY = arrowTipPosition.y
            
            // Arrow tip
            path.move(to: CGPoint(x: tipX, y: tipY))
            
            // Left arrow wing
            path.addLine(to: CGPoint(
                x: tipX - size * CoreGraphics.cos(angle - .pi / 6),
                y: tipY - size * CoreGraphics.sin(angle - .pi / 6)
            ))
            
            // Back to tip
            path.move(to: CGPoint(x: tipX, y: tipY))
            
            // Right arrow wing
            path.addLine(to: CGPoint(
                x: tipX - size * CoreGraphics.cos(angle + .pi / 6),
                y: tipY - size * CoreGraphics.sin(angle + .pi / 6)
            ))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

/// Label displaying relationship information
struct RelationshipLabel: View {
    let relationship: Relationship
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 2) {
            Text(relationship.description)
                .font(.caption)
                .fontWeight(.medium)
            
            if relationship.confidence > 0 {
                Text("\(Int(relationship.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background({
            #if canImport(AppKit)
            return Color(NSColor.controlBackgroundColor)
            #else
            return Color(.systemBackground)
            #endif
        }())
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .position(position)
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
        
        RelationshipEdgeView(
            relationship: {
                let rel = Relationship(
                    subjectEntityId: UUID(),
                    predicateType: .worksFor,
                    objectEntityId: UUID()
                )
                rel.confidence = 0.85
                rel.importance = 0.7
                return rel
            }(),
            startPosition: CGPoint(x: 100, y: 100),
            endPosition: CGPoint(x: 300, y: 200),
            isSelected: true
        )
    }
    .frame(width: 400, height: 300)
}