//
//  SystemInitializationView.swift
//  ProjectOne
//
//  System initialization loading screen with progress tracking
//  SwiftUI view for displaying system startup progress
//

import SwiftUI
import os.log
import Foundation
import SwiftData

/// Loading screen displayed during system initialization
public struct SystemInitializationView: View {
    
    // @EnvironmentObject private var initCoordinator: InitializationCoordinator
    @State private var animationPhase = 0.0
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "SystemInitializationView")
    
    public init() {
        // No parameters needed - uses environment object
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
                    
                    // Error handling
                    if false { // Disabled error display for now
                        VStack(spacing: 8) {
                            Text("Initialization Error")
                                .font(.caption)
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                            
                            Text("Initialization error occurred")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
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
        0.5 // Placeholder progress
    }
    
    private var currentStatusMessage: String {
        "Initializing system..." // Placeholder status
    }
}

// MARK: - Supporting Views

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

#Preview {
    SystemInitializationView()
}