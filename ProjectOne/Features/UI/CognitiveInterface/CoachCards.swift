//
//  CoachCards.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  ADHD-friendly Coach Cards for actionable bubble-up nudges
//

import SwiftUI
import os.log

// MARK: - Coach Card Types

/// Different types of coach cards for various cognitive interventions
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum CoachCardType: String, CaseIterable, Codable, Sendable {
    case action = "action"           // Specific actionable tasks
    case insight = "insight"         // Key insights and patterns
    case reminder = "reminder"       // Important reminders
    case context = "context"         // Contextual information and connections
    
    public var iconName: String {
        switch self {
        case .action: return "bolt.circle.fill"
        case .insight: return "lightbulb.circle.fill"
        case .reminder: return "bell.circle.fill"
        case .context: return "link.circle.fill"
        }
    }
    
    public var primaryColor: Color {
        switch self {
        case .action: return .blue
        case .insight: return .yellow
        case .reminder: return .orange
        case .context: return .purple
        }
    }
    
    public var accessibilityLabel: String {
        switch self {
        case .action: return "Action Card"
        case .insight: return "Insight Card"
        case .reminder: return "Reminder Card"
        case .context: return "Context Card"
        }
    }
}

// MARK: - Coach Card Style

/// Visual styling configuration for coach cards
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CoachCardStyle: Sendable {
    public let backgroundColor: Color
    public let borderColor: Color
    public let textColor: Color
    public let iconColor: Color
    public let shadowOpacity: Double
    
    public init(
        backgroundColor: Color,
        borderColor: Color,
        textColor: Color = .primary,
        iconColor: Color? = nil,
        shadowOpacity: Double = 0.1
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.textColor = textColor
        self.iconColor = iconColor ?? borderColor
        self.shadowOpacity = shadowOpacity
    }
}

// MARK: - Coach Card Data Model

/// Data model for a coach card
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CoachCardData: Identifiable, Sendable {
    public let id: UUID
    public let type: CoachCardType
    public let title: String
    public let content: String
    public let priority: IdeaPriority
    public let createdAt: Date
    public var interactionCount: Int
    public var lastInteraction: Date?
    
    // Cognitive optimization
    public let cognitiveLoad: Double
    public let estimatedDuration: TimeInterval? // In minutes
    public let optimalWindows: [DopamineWindow]
    
    // Actions and navigation
    public let primaryAction: CoachCardAction?
    public let secondaryActions: [CoachCardAction]
    public let relatedItemIDs: [UUID] // BubbleUpItem, IdeaNode, etc.
    
    // Visual customization
    public let customColor: Color?
    public let customIcon: String?
    
    public init(id: UUID = UUID(),
                type: CoachCardType,
                title: String,
                content: String,
                priority: IdeaPriority = .medium,
                cognitiveLoad: Double = 0.5,
                estimatedDuration: TimeInterval? = nil,
                optimalWindows: [DopamineWindow] = [],
                primaryAction: CoachCardAction? = nil,
                secondaryActions: [CoachCardAction] = [],
                relatedItemIDs: [UUID] = [],
                customColor: Color? = nil,
                customIcon: String? = nil) {
        
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.priority = priority
        self.createdAt = Date()
        self.interactionCount = 0
        self.lastInteraction = nil
        self.cognitiveLoad = cognitiveLoad
        self.estimatedDuration = estimatedDuration
        self.optimalWindows = optimalWindows.isEmpty ? type.defaultWindows : optimalWindows
        self.primaryAction = primaryAction
        self.secondaryActions = secondaryActions
        self.relatedItemIDs = relatedItemIDs
        self.customColor = customColor
        self.customIcon = customIcon
    }
}

// MARK: - Codable Implementation for CoachCardData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CoachCardData: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, type, title, content, priority, createdAt
        case interactionCount, lastInteraction, cognitiveLoad
        case estimatedDuration, optimalWindows, primaryAction
        case secondaryActions, relatedItemIDs, customColorHex, customIcon
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(CoachCardType.self, forKey: .type)
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.priority = try container.decode(IdeaPriority.self, forKey: .priority)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.interactionCount = try container.decode(Int.self, forKey: .interactionCount)
        self.lastInteraction = try container.decodeIfPresent(Date.self, forKey: .lastInteraction)
        self.cognitiveLoad = try container.decode(Double.self, forKey: .cognitiveLoad)
        self.estimatedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration)
        self.optimalWindows = try container.decode([DopamineWindow].self, forKey: .optimalWindows)
        self.primaryAction = try container.decodeIfPresent(CoachCardAction.self, forKey: .primaryAction)
        self.secondaryActions = try container.decode([CoachCardAction].self, forKey: .secondaryActions)
        self.relatedItemIDs = try container.decode([UUID].self, forKey: .relatedItemIDs)
        self.customIcon = try container.decodeIfPresent(String.self, forKey: .customIcon)
        
        // Handle Color conversion from hex string
        if let hexString = try container.decodeIfPresent(String.self, forKey: .customColorHex) {
            self.customColor = Color(hex: hexString)
        } else {
            self.customColor = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(priority, forKey: .priority)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(interactionCount, forKey: .interactionCount)
        try container.encodeIfPresent(lastInteraction, forKey: .lastInteraction)
        try container.encode(cognitiveLoad, forKey: .cognitiveLoad)
        try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(optimalWindows, forKey: .optimalWindows)
        try container.encodeIfPresent(primaryAction, forKey: .primaryAction)
        try container.encode(secondaryActions, forKey: .secondaryActions)
        try container.encode(relatedItemIDs, forKey: .relatedItemIDs)
        try container.encodeIfPresent(customIcon, forKey: .customIcon)
        
        // Handle Color conversion to hex string
        if let color = customColor {
            try container.encode(color.toHex(), forKey: .customColorHex)
        }
    }
}

// MARK: - Coach Card Actions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CoachCardAction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let actionType: CoachCardActionType
    public let navigationTarget: String? // For navigation actions
    public let metadata: [String: String] // Additional action data
    
    public init(id: UUID = UUID(),
                title: String,
                actionType: CoachCardActionType,
                navigationTarget: String? = nil,
                metadata: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.actionType = actionType
        self.navigationTarget = navigationTarget
        self.metadata = metadata
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum CoachCardActionType: String, CaseIterable, Codable, Sendable {
    case complete = "complete"       // Mark as completed
    case snooze = "snooze"          // Snooze for later
    case navigate = "navigate"       // Navigate to related content
    case expand = "expand"           // Show more details
    case dismiss = "dismiss"         // Dismiss the card
    case schedule = "schedule"       // Schedule for optimal time
    case connect = "connect"         // Connect to other ideas
    case createMemory = "create_memory" // Create a thought/memory from this bubble-up
}

// MARK: - Main Coach Card View

/// Individual coach card component with ADHD-friendly design
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CoachCardView: View {
    
    @State private var cardData: CoachCardData
    @State private var isExpanded: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showingActions: Bool = false
    @State private var showingMemoryCreation: Bool = false
    
    private let onAction: (CoachCardAction, CoachCardData) -> Void
    private let onDismiss: (CoachCardData) -> Void
    private let onMemoryCreated: ((Thought) -> Void)?
    
    // Memory creation dependencies (optional)
    private let bubbleUpItem: BubbleUpItem?
    private let memoryCreator: BubbleUpMemoryCreator?
    
    public init(cardData: CoachCardData,
                onAction: @escaping (CoachCardAction, CoachCardData) -> Void = { _, _ in },
                onDismiss: @escaping (CoachCardData) -> Void = { _ in },
                onMemoryCreated: ((Thought) -> Void)? = nil,
                bubbleUpItem: BubbleUpItem? = nil,
                memoryCreator: BubbleUpMemoryCreator? = nil) {
        self._cardData = State(initialValue: cardData)
        self.onAction = onAction
        self.onDismiss = onDismiss
        self.onMemoryCreated = onMemoryCreated
        self.bubbleUpItem = bubbleUpItem
        self.memoryCreator = memoryCreator
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            CoachCardHeader(
                type: cardData.type,
                title: cardData.title,
                priority: cardData.priority,
                customColor: cardData.customColor,
                customIcon: cardData.customIcon
            )
            
            // Content
            CoachCardContent(
                content: cardData.content,
                isExpanded: isExpanded,
                estimatedDuration: cardData.estimatedDuration,
                cognitiveLoad: cardData.cognitiveLoad
            )
            
            // Actions
            if !cardData.secondaryActions.isEmpty || cardData.primaryAction != nil {
                CoachCardActions(
                    primaryAction: cardData.primaryAction,
                    secondaryActions: cardData.secondaryActions,
                    showingActions: $showingActions,
                    onActionTrigger: { action in
                        recordInteraction()
                        
                        if action.actionType == .createMemory {
                            showingMemoryCreation = true
                        } else {
                            onAction(action, cardData)
                        }
                    }
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackgroundGradient)
                .shadow(color: cardData.type.primaryColor.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isHighlighted ? 2 : 1)
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .rotation3DEffect(
            .degrees(dragOffset.width / 20),
            axis: (x: 0, y: 1, z: 0)
        )
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring()) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        if abs(value.translation.x) > 100 {
                            // Swipe to dismiss
                            onDismiss(cardData)
                        } else {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
            recordInteraction()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardData.type.accessibilityLabel)
        .accessibilityHint("Tap to expand, swipe to dismiss")
        .sheet(isPresented: $showingMemoryCreation) {
            if let bubbleUpItem = bubbleUpItem,
               let memoryCreator = memoryCreator {
                MemoryCreationView(
                    bubbleUpItem: bubbleUpItem,
                    memoryCreator: memoryCreator,
                    onMemoryCreated: { thought in
                        showingMemoryCreation = false
                        onMemoryCreated?(thought)
                    },
                    onCancel: {
                        showingMemoryCreation = false
                    }
                )
            } else {
                Text("Memory creation not available")
                    .padding()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardBackgroundGradient: LinearGradient {
        let baseColor = cardData.customColor ?? cardData.type.primaryColor
        return LinearGradient(
            gradient: Gradient(colors: [
                baseColor.opacity(0.1),
                baseColor.opacity(0.05)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderColor: Color {
        if isHighlighted {
            return cardData.type.primaryColor
        } else {
            return Color.primary.opacity(0.2)
        }
    }
    
    private var isHighlighted: Bool {
        let currentWindow = DopamineWindow.current
        return cardData.optimalWindows.contains(currentWindow)
    }
    
    // MARK: - Helper Methods
    
    private func recordInteraction() {
        cardData.interactionCount += 1
        cardData.lastInteraction = Date()
    }
}

// MARK: - Card Header Component

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CoachCardHeader: View {
    let type: CoachCardType
    let title: String
    let priority: IdeaPriority
    let customColor: Color?
    let customIcon: String?
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: customIcon ?? type.iconName)
                .font(.title2)
                .foregroundColor(customColor ?? type.primaryColor)
                .frame(width: 24, height: 24)
            
            // Title
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Priority indicator
            PriorityIndicator(priority: priority)
        }
    }
}

// MARK: - Card Content Component

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CoachCardContent: View {
    let content: String
    let isExpanded: Bool
    let estimatedDuration: TimeInterval?
    let cognitiveLoad: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main content
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
            
            // Metadata (only when expanded)
            if isExpanded {
                CoachCardMetadata(
                    estimatedDuration: estimatedDuration,
                    cognitiveLoad: cognitiveLoad
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Card Actions Component

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CoachCardActions: View {
    let primaryAction: CoachCardAction?
    let secondaryActions: [CoachCardAction]
    @Binding var showingActions: Bool
    let onActionTrigger: (CoachCardAction) -> Void
    
    var body: some View {
        HStack {
            if let primaryAction = primaryAction {
                Button(primaryAction.title) {
                    onActionTrigger(primaryAction)
                }
                .buttonStyle(PrimaryCoachActionStyle())
            }
            
            Spacer()
            
            if !secondaryActions.isEmpty {
                Button("More") {
                    withAnimation(.spring()) {
                        showingActions.toggle()
                    }
                }
                .buttonStyle(SecondaryCoachActionStyle())
                .popover(isPresented: $showingActions) {
                    CoachActionMenu(
                        actions: secondaryActions,
                        onActionTrigger: onActionTrigger
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Components

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct PriorityIndicator: View {
    let priority: IdeaPriority
    
    var body: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(priorityColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 16, height: 16)
            )
            .accessibilityLabel("Priority: \(priorityLabel)")
    }
    
    private var priorityColor: Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    private var priorityLabel: String {
        switch priority {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CoachCardMetadata: View {
    let estimatedDuration: TimeInterval?
    let cognitiveLoad: Double
    
    var body: some View {
        HStack(spacing: 16) {
            if let duration = estimatedDuration {
                Label("\(Int(duration))m", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Label("Load: \(Int(cognitiveLoad * 100))%", systemImage: "brain")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CoachActionMenu: View {
    let actions: [CoachCardAction]
    let onActionTrigger: (CoachCardAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(actions) { action in
                Button(action.title) {
                    onActionTrigger(action)
                }
                .buttonStyle(MenuCoachActionStyle())
            }
        }
        .padding()
        .frame(minWidth: 150)
    }
}

// MARK: - Button Styles

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct PrimaryCoachActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct SecondaryCoachActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 1)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct MenuCoachActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.gray.opacity(0.2) : Color.clear)
            )
    }
}

// MARK: - Coach Card Collection View

/// Container view for displaying multiple coach cards
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CoachCardCollection: View {
    @State private var cards: [CoachCardData]
    private let onCardAction: (CoachCardAction, CoachCardData) -> Void
    private let onCardDismiss: (CoachCardData) -> Void
    
    public init(cards: [CoachCardData],
                onCardAction: @escaping (CoachCardAction, CoachCardData) -> Void = { _, _ in },
                onCardDismiss: @escaping (CoachCardData) -> Void = { _ in }) {
        self._cards = State(initialValue: cards)
        self.onCardAction = onCardAction
        self.onCardDismiss = onCardDismiss
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(cards) { card in
                    CoachCardView(
                        cardData: card,
                        onAction: onCardAction,
                        onDismiss: { dismissedCard in
                            withAnimation(.spring()) {
                                cards.removeAll { $0.id == dismissedCard.id }
                            }
                            onCardDismiss(dismissedCard)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cards)
    }
    
    // MARK: - Public Methods
    
    public func addCard(_ card: CoachCardData) {
        withAnimation(.spring()) {
            cards.insert(card, at: 0)
        }
    }
    
    public func removeCard(withId id: UUID) {
        withAnimation(.spring()) {
            cards.removeAll { $0.id == id }
        }
    }
    
    public func updateCard(_ updatedCard: CoachCardData) {
        if let index = cards.firstIndex(where: { $0.id == updatedCard.id }) {
            withAnimation(.spring()) {
                cards[index] = updatedCard
            }
        }
    }
}

// MARK: - Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CoachCardType {
    public var defaultWindows: [DopamineWindow] {
        switch self {
        case .action:
            return [.morningPeak, .afternoonBoost]
        case .insight:
            return [.eveningCreative, .morningPeak]
        case .reminder:
            return [.midDayDip, .afternoonBoost]
        case .context:
            return [.eveningCreative, .morningPeak]
        }
    }
}

// MARK: - Color Extensions for Codable Support

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06X", rgb)
    }
}