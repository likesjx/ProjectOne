import SwiftUI

/// Visual representation of a relationship edge in the knowledge graph
struct RelationshipEdgeView: View {
    let relationship: Relationship
    let startPosition: CGPoint
    let endPosition: CGPoint
    let isSelected: Bool
    
    private var edgeVector: CGVector {
        CGVector(
            dx: endPosition.x - startPosition.x,
            dy: endPosition.y - startPosition.y
        )
    }
    
    private var edgeLength: CGFloat {
        sqrt(edgeVector.dx * edgeVector.dx + edgeVector.dy * edgeVector.dy)
    }
    
    private var edgeAngle: Double {
        atan2(edgeVector.dy, edgeVector.dx) * 180 / .pi
    }
    
    private var midPoint: CGPoint {
        CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: (startPosition.y + endPosition.y) / 2
        )
    }
    
    var body: some View {
        ZStack {
            // Main edge line
            Path { path in
                path.move(to: startPosition)
                path.addLine(to: endPosition)
            }
            .stroke(
                Color(relationship.edgeColor).opacity(isSelected ? 1.0 : 0.7),
                style: StrokeStyle(
                    lineWidth: relationship.edgeWidth,
                    lineCap: .round,
                    dash: relationship.isActive ? [] : [5, 5]
                )
            )
            
            // Arrow head
            if relationship.bidirectional {
                // Bidirectional arrows
                ArrowHeadView(
                    position: CGPoint(
                        x: endPosition.x - cos(edgeAngle * .pi / 180) * 15,
                        y: endPosition.y - sin(edgeAngle * .pi / 180) * 15
                    ),
                    angle: edgeAngle,
                    color: Color(relationship.edgeColor),
                    isSelected: isSelected
                )
                
                ArrowHeadView(
                    position: CGPoint(
                        x: startPosition.x + cos(edgeAngle * .pi / 180) * 15,
                        y: startPosition.y + sin(edgeAngle * .pi / 180) * 15
                    ),
                    angle: edgeAngle + 180,
                    color: Color(relationship.edgeColor),
                    isSelected: isSelected
                )
            } else {
                // Unidirectional arrow
                ArrowHeadView(
                    position: CGPoint(
                        x: endPosition.x - cos(edgeAngle * .pi / 180) * 15,
                        y: endPosition.y - sin(edgeAngle * .pi / 180) * 15
                    ),
                    angle: edgeAngle,
                    color: Color(relationship.edgeColor),
                    isSelected: isSelected
                )
            }
            
            // Relationship label
            if edgeLength > 100 && relationship.edgeWidth > 2 {
                RelationshipLabelView(
                    relationship: relationship,
                    position: midPoint,
                    angle: edgeAngle,
                    isSelected: isSelected
                )
            }
            
            // Confidence indicator
            if relationship.confidence < 0.7 {
                ConfidenceIndicatorView(
                    confidence: relationship.confidence,
                    position: CGPoint(
                        x: midPoint.x + 20,
                        y: midPoint.y - 10
                    )
                )
            }
        }
        .opacity(isSelected ? 1.0 : 0.8)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Arrow Head

struct ArrowHeadView: View {
    let position: CGPoint
    let angle: Double
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            let arrowSize: CGFloat = isSelected ? 12 : 8
            
            // Arrow head triangle
            path.move(to: CGPoint(x: arrowSize, y: 0))
            path.addLine(to: CGPoint(x: -arrowSize/2, y: arrowSize/2))
            path.addLine(to: CGPoint(x: -arrowSize/2, y: -arrowSize/2))
            path.closeSubpath()
        }
        .fill(color)
        .rotationEffect(.degrees(angle))
        .position(position)
    }
}

// MARK: - Relationship Label

struct RelationshipLabelView: View {
    let relationship: Relationship
    let position: CGPoint
    let angle: Double
    let isSelected: Bool
    
    private var normalizedAngle: Double {
        // Ensure text is always readable (not upside down)
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized > 90 && normalized < 270 {
            return normalized + 180
        }
        return normalized
    }
    
    var body: some View {
        Text(relationship.predicateType.description)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .medium)
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemBackground).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(relationship.edgeColor), lineWidth: 1)
                    )
            )
            .rotationEffect(.degrees(normalizedAngle))
            .position(position)
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicatorView: View {
    let confidence: Double
    let position: CGPoint
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        Circle()
            .fill(confidenceColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
            .position(position)
    }
}

// MARK: - Curved Edge

struct CurvedRelationshipEdgeView: View {
    let relationship: Relationship
    let startPosition: CGPoint
    let endPosition: CGPoint
    let isSelected: Bool
    let curvature: CGFloat = 0.3 // 0 = straight, 1 = highly curved
    
    private var controlPoint: CGPoint {
        let midX = (startPosition.x + endPosition.x) / 2
        let midY = (startPosition.y + endPosition.y) / 2
        
        // Calculate perpendicular offset
        let dx = endPosition.x - startPosition.x
        let dy = endPosition.y - startPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        let perpX = -dy / distance * curvature * distance * 0.3
        let perpY = dx / distance * curvature * distance * 0.3
        
        return CGPoint(x: midX + perpX, y: midY + perpY)
    }
    
    var body: some View {
        Path { path in
            path.move(to: startPosition)
            path.addQuadCurve(to: endPosition, control: controlPoint)
        }
        .stroke(
            Color(relationship.edgeColor).opacity(isSelected ? 1.0 : 0.7),
            style: StrokeStyle(
                lineWidth: relationship.edgeWidth,
                lineCap: .round,
                dash: relationship.isActive ? [] : [5, 5]
            )
        )
    }
}

// MARK: - Animated Edge

struct AnimatedRelationshipEdgeView: View {
    let relationship: Relationship
    let startPosition: CGPoint
    let endPosition: CGPoint
    let isSelected: Bool
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base edge
            RelationshipEdgeView(
                relationship: relationship,
                startPosition: startPosition,
                endPosition: endPosition,
                isSelected: isSelected
            )
            
            // Animated flow indicator for high-strength relationships
            if relationship.strength > 0.8 {
                Path { path in
                    path.move(to: startPosition)
                    path.addLine(to: endPosition)
                }
                .stroke(
                    Color(relationship.edgeColor).opacity(0.6),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        dash: [10, 20],
                        dashPhase: animationOffset
                    )
                )
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        animationOffset = 30
                    }
                }
            }
        }
    }
}

// MARK: - Multiple Relationships Edge

struct MultipleRelationshipsEdgeView: View {
    let relationships: [Relationship]
    let startPosition: CGPoint
    let endPosition: CGPoint
    let selectedRelationship: Relationship?
    
    private let spacing: CGFloat = 3.0
    
    var body: some View {
        ZStack {
            ForEach(Array(relationships.enumerated()), id: \.element.id) { index, relationship in
                let offset = CGFloat(index - relationships.count / 2) * spacing
                let isSelected = selectedRelationship?.id == relationship.id
                
                RelationshipEdgeView(
                    relationship: relationship,
                    startPosition: offsetPosition(startPosition, offset: offset),
                    endPosition: offsetPosition(endPosition, offset: offset),
                    isSelected: isSelected
                )
            }
            
            // Relationship count badge
            if relationships.count > 1 {
                let midPoint = CGPoint(
                    x: (startPosition.x + endPosition.x) / 2,
                    y: (startPosition.y + endPosition.y) / 2
                )
                
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("\(relationships.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .position(midPoint)
            }
        }
    }
    
    private func offsetPosition(_ position: CGPoint, offset: CGFloat) -> CGPoint {
        // Calculate perpendicular offset
        let dx = endPosition.x - startPosition.x
        let dy = endPosition.y - startPosition.y
        let distance = sqrt(dx * dx + dy * dy)
        
        guard distance > 0 else { return position }
        
        let perpX = -dy / distance * offset
        let perpY = dx / distance * offset
        
        return CGPoint(x: position.x + perpX, y: position.y + perpY)
    }
}

// MARK: - Preview

#Preview {
    let relationship = Relationship(
        subjectEntityId: UUID(),
        predicateType: .worksFor,
        objectEntityId: UUID()
    )
    relationship.confidence = 0.85
    relationship.strength = 0.9
    
    return ZStack {
        RelationshipEdgeView(
            relationship: relationship,
            startPosition: CGPoint(x: 50, y: 100),
            endPosition: CGPoint(x: 250, y: 200),
            isSelected: false
        )
        
        RelationshipEdgeView(
            relationship: relationship,
            startPosition: CGPoint(x: 50, y: 150),
            endPosition: CGPoint(x: 250, y: 250),
            isSelected: true
        )
    }
    .frame(width: 300, height: 300)
    .background(Color(.systemGray6))
}