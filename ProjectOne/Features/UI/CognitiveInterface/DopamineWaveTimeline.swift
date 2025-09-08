//
//  DopamineWaveTimeline.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Dopamine Wave Timeline visualization for cognitive optimization
//

import SwiftUI
import Foundation
import os.log

// MARK: - Dopamine Wave Timeline

/// Interactive timeline showing dopamine waves with events and cognitive opportunities
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct DopamineWaveTimeline: View {
    
    // MARK: - State
    
    @State private var currentTime: Date = Date()
    @State private var selectedWindow: DopamineWindow?
    @State private var showingDetails: Bool = false
    @State private var timelineEvents: [TimelineEvent] = []
    @State private var bubbleUpItems: [BubbleUpItem] = []
    @State private var scrollOffset: CGFloat = 0
    
    // MARK: - Configuration
    
    private let timeRange: TimeRange
    private let onWindowSelected: (DopamineWindow) -> Void
    private let onEventTapped: (TimelineEvent) -> Void
    
    public init(timeRange: TimeRange = .today,
                onWindowSelected: @escaping (DopamineWindow) -> Void = { _ in },
                onEventTapped: @escaping (TimelineEvent) -> Void = { _ in }) {
        self.timeRange = timeRange
        self.onWindowSelected = onWindowSelected
        self.onEventTapped = onEventTapped
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with current status
            TimelineHeader(
                currentWindow: DopamineWindow.current,
                cognitiveCapacity: DopamineWindow.current.cognitiveCapacity,
                nextWindow: nextDopamineWindow,
                timeToNext: timeToNextWindow
            )
            
            // Main timeline
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(dopamineWindows, id: \.window) { windowData in
                            DopamineWindowView(
                                windowData: windowData,
                                events: eventsForWindow(windowData.window),
                                bubbleUps: bubbleUpsForWindow(windowData.window),
                                isSelected: selectedWindow == windowData.window,
                                onTap: {
                                    selectedWindow = windowData.window
                                    onWindowSelected(windowData.window)
                                }
                            )
                            .frame(width: windowWidth(for: windowData.window))
                        }
                    }
                    .padding(.horizontal)
                }
                .coordinateSpace(name: "timeline")
                .onAppear {
                    scrollToCurrentTime(proxy: proxy)
                }
                .onChange(of: currentTime) { _, _ in
                    scrollToCurrentTime(proxy: proxy)
                }
            }
            
            // Details panel (when window selected)
            if let selectedWindow = selectedWindow {
                WindowDetailsPanel(
                    window: selectedWindow,
                    events: eventsForWindow(selectedWindow),
                    bubbleUps: bubbleUpsForWindow(selectedWindow),
                    onClose: { self.selectedWindow = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            setupTimelineData()
            startTimeUpdates()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedWindow)
    }
    
    // MARK: - Computed Properties
    
    private var dopamineWindows: [DopamineWindowData] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: currentTime)
        
        return DopamineWindow.allCases.map { window in
            let windowStart = startOfDay.addingTimeInterval(TimeInterval(window.startHour * 3600))
            let windowEnd = startOfDay.addingTimeInterval(TimeInterval(window.endHour * 3600))
            
            return DopamineWindowData(
                window: window,
                startTime: windowStart,
                endTime: windowEnd,
                capacity: window.cognitiveCapacity,
                optimalTasks: window.optimalTaskTypes,
                isActive: window == DopamineWindow.current
            )
        }
    }
    
    private var nextDopamineWindow: DopamineWindow {
        let currentHour = Calendar.current.component(.hour, from: currentTime)
        let nextWindows = DopamineWindow.allCases.filter { $0.startHour > currentHour }
        return nextWindows.first ?? DopamineWindow.allCases.first!
    }
    
    private var timeToNextWindow: TimeInterval {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let nextHour = nextDopamineWindow.startHour
        
        if nextHour > currentHour {
            return TimeInterval((nextHour - currentHour) * 3600)
        } else {
            // Next day
            return TimeInterval((24 - currentHour + nextHour) * 3600)
        }
    }
    
    // MARK: - Helper Methods
    
    private func windowWidth(for window: DopamineWindow) -> CGFloat {
        let duration = window.duration
        let totalDayWidth: CGFloat = 800 // Total width for 24 hours
        return totalDayWidth * CGFloat(duration / 24.0)
    }
    
    private func eventsForWindow(_ window: DopamineWindow) -> [TimelineEvent] {
        return timelineEvents.filter { event in
            let eventHour = Calendar.current.component(.hour, from: event.timestamp)
            return eventHour >= window.startHour && eventHour < window.endHour
        }
    }
    
    private func bubbleUpsForWindow(_ window: DopamineWindow) -> [BubbleUpItem] {
        return bubbleUpItems.filter { item in
            item.preferredWindows.contains(window)
        }
    }
    
    private func scrollToCurrentTime(proxy: ScrollViewReader) {
        let currentWindow = DopamineWindow.current
        proxy.scrollTo(currentWindow.rawValue, anchor: .center)
    }
    
    private func setupTimelineData() {
        // TODO: Load timeline events from data sources
        timelineEvents = generateSampleEvents()
        // TODO: Load bubble-up items from BubbleUpEngine
        bubbleUpItems = []
    }
    
    private func startTimeUpdates() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func generateSampleEvents() -> [TimelineEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: currentTime)
        
        return [
            TimelineEvent(
                id: UUID(),
                title: "Morning Focus Session",
                description: "Deep work on project planning",
                timestamp: startOfDay.addingTimeInterval(8 * 3600),
                type: .focus,
                cognitiveImpact: 0.8,
                duration: 3600
            ),
            TimelineEvent(
                id: UUID(),
                title: "Creative Brainstorm",
                description: "Generate ideas for new features",
                timestamp: startOfDay.addingTimeInterval(19 * 3600),
                type: .creative,
                cognitiveImpact: 0.6,
                duration: 1800
            )
        ]
    }
}

// MARK: - Timeline Header

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct TimelineHeader: View {
    let currentWindow: DopamineWindow
    let cognitiveCapacity: Double
    let nextWindow: DopamineWindow
    let timeToNext: TimeInterval
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Current window status
                HStack(spacing: 8) {
                    Circle()
                        .fill(currentWindow.color)
                        .frame(width: 12, height: 12)
                    
                    Text(currentWindow.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Cognitive capacity indicator
                CognitiveCapacityIndicator(capacity: cognitiveCapacity)
            }
            
            HStack {
                Text("Next: \(nextWindow.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("in \(formatTimeInterval(timeToNext))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Cognitive Capacity Indicator

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CognitiveCapacityIndicator: View {
    let capacity: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Capacity:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(index < Int(capacity * 5) ? capacityColor : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                }
            }
        }
    }
    
    private var capacityColor: Color {
        switch capacity {
        case 0.8...: return .green
        case 0.5...: return .orange
        default: return .red
        }
    }
}

// MARK: - Dopamine Window View

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct DopamineWindowView: View {
    let windowData: DopamineWindowData
    let events: [TimelineEvent]
    let bubbleUps: [BubbleUpItem]
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Window header
            VStack(spacing: 4) {
                Text(windowData.window.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(windowData.window.timeRange)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            // Capacity visualization
            CapacityVisualization(
                capacity: windowData.capacity,
                isActive: windowData.isActive,
                isSelected: isSelected
            )
            
            // Events and bubble-ups
            VStack(spacing: 4) {
                ForEach(events.prefix(3), id: \.id) { event in
                    EventIndicator(event: event, isCompact: true)
                }
                
                if bubbleUps.count > 0 {
                    BubbleUpIndicator(count: bubbleUps.count)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? windowData.window.color : windowData.window.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            windowData.isActive ? windowData.window.color : Color.clear,
                            lineWidth: windowData.isActive ? 2 : 0
                        )
                )
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct CapacityVisualization: View {
    let capacity: Double
    let isActive: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<4) { row in
                HStack(spacing: 2) {
                    ForEach(0..<5) { col in
                        let index = row * 5 + col
                        let threshold = Double(index) / 20.0
                        
                        Rectangle()
                            .fill(threshold < capacity ? indicatorColor : Color.gray.opacity(0.2))
                            .frame(width: 3, height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 0.5))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: capacity)
    }
    
    private var indicatorColor: Color {
        if isSelected {
            return .white
        } else if isActive {
            return .primary
        } else {
            return .secondary
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct EventIndicator: View {
    let event: TimelineEvent
    let isCompact: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(event.type.color)
                .frame(width: 6, height: 6)
            
            if !isCompact {
                Text(event.title)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct BubbleUpIndicator: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bubble.left")
                .font(.caption2)
                .foregroundColor(.blue)
            
            Text("\(count)")
                .font(.caption2)
                .foregroundColor(.blue)
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct WindowDetailsPanel: View {
    let window: DopamineWindow
    let events: [TimelineEvent]
    let bubbleUps: [BubbleUpItem]
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(window.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Capacity: \(Int(window.cognitiveCapacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    onClose()
                }
                .buttonStyle(.bordered)
            }
            
            // Events
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events")
                        .font(.headline)
                    
                    ForEach(events, id: \.id) { event in
                        EventRow(event: event)
                    }
                }
            }
            
            // Bubble-ups
            if !bubbleUps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Opportunities")
                        .font(.headline)
                    
                    ForEach(bubbleUps.prefix(3), id: \.id) { item in
                        BubbleUpRow(item: item)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 10)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct EventRow: View {
    let event: TimelineEvent
    
    var body: some View {
        HStack {
            Circle()
                .fill(event.type.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatTime(event.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        DateFormatter.timeOnly.string(from: date)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct BubbleUpRow: View {
    let item: BubbleUpItem
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb")
                .foregroundColor(.blue)
                .frame(width: 8, height: 8)
            
            Text(item.content)
                .font(.subheadline)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Data Models

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct DopamineWindowData {
    let window: DopamineWindow
    let startTime: Date
    let endTime: Date
    let capacity: Double
    let optimalTasks: [BubbleUpTaskType]
    let isActive: Bool
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct TimelineEvent: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let timestamp: Date
    public let type: EventType
    public let cognitiveImpact: Double
    public let duration: TimeInterval
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum EventType: String, CaseIterable, Sendable {
    case focus = "focus"
    case creative = "creative"
    case routine = "routine"
    case breakTime = "break"
    case meeting = "meeting"
    
    var color: Color {
        switch self {
        case .focus: return .blue
        case .creative: return .purple
        case .routine: return .green
        case .breakTime: return .gray
        case .meeting: return .orange
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum TimeRange {
    case today
    case week
    case custom(DateInterval)
}

// MARK: - Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension DopamineWindow {
    var startHour: Int {
        switch self {
        case .morningPeak: return 6
        case .midDayDip: return 10
        case .afternoonBoost: return 14
        case .eveningCreative: return 18
        case .nightRest: return 22
        }
    }
    
    var endHour: Int {
        switch self {
        case .morningPeak: return 10
        case .midDayDip: return 14
        case .afternoonBoost: return 18
        case .eveningCreative: return 22
        case .nightRest: return 6
        }
    }
    
    var duration: Double {
        if self == .nightRest {
            return 8.0 // 22:00 to 06:00 next day
        } else {
            return Double(endHour - startHour)
        }
    }
    
    var displayName: String {
        switch self {
        case .morningPeak: return "Morning Peak"
        case .midDayDip: return "Midday Dip"
        case .afternoonBoost: return "Afternoon Boost"
        case .eveningCreative: return "Evening Creative"
        case .nightRest: return "Night Rest"
        }
    }
    
    var timeRange: String {
        if self == .nightRest {
            return "22:00-06:00"
        } else {
            return String(format: "%02d:00-%02d:00", startHour, endHour)
        }
    }
    
    var color: Color {
        switch self {
        case .morningPeak: return .green
        case .midDayDip: return .orange
        case .afternoonBoost: return .blue
        case .eveningCreative: return .purple
        case .nightRest: return .indigo
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}