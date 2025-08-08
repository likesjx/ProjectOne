//
//  SystemInitializationView.swift
//  ProjectOne
//
//  System initialization loading screen with progress tracking
//  SwiftUI view for displaying system startup progress
//

import SwiftUI
import os.log

/// Loading screen displayed during system initialization
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SystemInitializationView: View {
    
    private var systemManager: UnifiedSystemManager?
    @State private var animationPhase = 0.0
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "SystemInitializationView")
    
    public init(systemManager: UnifiedSystemManager? = nil) {
        self.systemManager = systemManager
    }
    
    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App icon or logo placeholder
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .scaleEffect(1.0 + sin(animationPhase) * 0.1)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animationPhase)
                
                VStack(spacing: 16) {
                    Text("ProjectOne")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Initializing AI System...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Progress section
                VStack(spacing: 12) {
                    ProgressView(value: currentProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 250)
                    
                    Text(currentStatusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 20)
                }
                
                // Loading indicators
                HStack(spacing: 20) {
                    LoadingDot(delay: 0.0)
                    LoadingDot(delay: 0.2)
                    LoadingDot(delay: 0.4)
                }
            }
            .padding()
        }
        .onAppear {
            animationPhase = 1.0
            logger.info("System initialization view appeared")
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentProgress: Double {
        systemManager?.initializationProgress ?? 0.0
    }
    
    private var currentStatusMessage: String {
        guard let systemManager = systemManager else {
            return "Starting system initialization..."
        }
        
        let progress = systemManager.initializationProgress
        
        switch progress {
        case 0.0..<0.2:
            return "Initializing core services..."
        case 0.2..<0.4:
            return "Loading AI providers..."
        case 0.4..<0.6:
            return "Setting up memory systems..."
        case 0.6..<0.8:
            return "Configuring agent network..."
        case 0.8..<1.0:
            return "Finalizing initialization..."
        default:
            return "System ready!"
        }
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct LoadingDot: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.5 : 0.5)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    SystemInitializationView()
}