import SwiftUI

/// Visual representation of an entity node in the knowledge graph
struct EntityNodeView: View {
    let entity: Entity
    let position: CGPoint
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Node background
            Circle()
                .fill(Color(entity.nodeColor).opacity(0.8))
                .frame(width: entity.nodeSize, height: entity.nodeSize)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color(entity.nodeColor), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            
            // Entity icon
            Image(systemName: entity.type.iconName)
                .font(.system(size: entity.nodeSize * 0.4))
                .foregroundColor(.white)
        }
        .position(position)
        .overlay(
            // Entity label
            Text(entity.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .position(x: position.x, y: position.y + entity.nodeSize * 0.7)
                .opacity(entity.nodeSize > 30 ? 1.0 : 0.0) // Hide label for small nodes
        )
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Node Tooltip

struct EntityTooltipView: View {
    let entity: Entity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entity.type.iconName)
                    .foregroundColor(Color(entity.type.color))
                
                Text(entity.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(entity.type.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !entity.aliases.isEmpty {
                Text("Also known as: \(entity.aliases.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(entity.mentions) mentions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Score: \(String(format: "%.1f", entity.entityScore * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = entity.entityDescription {
                Text(description)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.primary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .frame(maxWidth: 200)
    }
}

// MARK: - Animated Node

struct AnimatedEntityNodeView: View {
    let entity: Entity
    let position: CGPoint
    let isSelected: Bool
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        EntityNodeView(entity: entity, position: position, isSelected: isSelected)
            .scaleEffect(pulseScale)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                startAnimations()
            }
    }
    
    private func startAnimations() {
        // Pulse animation for high-importance entities
        if entity.importance > 0.8 {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        
        // Rotation animation for entities with many relationships
        if entity.relationships.count > 5 {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Clustered Node

struct ClusteredEntityNodeView: View {
    let entities: [Entity]
    let position: CGPoint
    let isSelected: Bool
    
    private var primaryEntity: Entity {
        entities.max(by: { $0.entityScore < $1.entityScore }) ?? entities.first!
    }
    
    private var clusterSize: Double {
        return max(30.0, min(60.0, 20.0 + Double(entities.count) * 5.0))
    }
    
    var body: some View {
        ZStack {
            // Cluster background
            Circle()
                .fill(Color(primaryEntity.nodeColor).opacity(0.6))
                .frame(width: clusterSize, height: clusterSize)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color(primaryEntity.nodeColor), lineWidth: 2)
                )
            
            // Entity count badge
            Circle()
                .fill(Color.accentColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(entities.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .position(x: clusterSize * 0.8, y: clusterSize * 0.2)
            
            // Primary entity icon
            Image(systemName: primaryEntity.type.iconName)
                .font(.system(size: clusterSize * 0.3))
                .foregroundColor(.white)
        }
        .position(position)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 50) {
        EntityNodeView(
            entity: Entity(name: "John Doe", type: .person),
            position: CGPoint(x: 100, y: 100),
            isSelected: false
        )
        
        EntityNodeView(
            entity: Entity(name: "Apple Inc.", type: .organization),
            position: CGPoint(x: 200, y: 100),
            isSelected: true
        )
        
        EntityTooltipView(entity: {
            let entity = Entity(name: "Machine Learning", type: .concept)
            entity.entityDescription = "Artificial intelligence technique for pattern recognition"
            entity.mentions = 15
            entity.aliases = ["ML", "AI Learning"]
            return entity
        }())
    }
    .frame(width: 400, height: 300)
    .background(Color(.systemGray6))
}