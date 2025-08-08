//
//  HapticFeedbackUtil.swift
//  ProjectOne
//
//  Utility to handle haptic feedback safely across devices and simulators
//

#if os(iOS)
import UIKit

enum HapticFeedbackUtil {
    
    /// Safely triggers haptic feedback only on supported physical devices
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isHapticFeedbackSupported else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    /// Safely triggers selection haptic feedback only on supported physical devices
    @MainActor
    static func selection() {
        guard isHapticFeedbackSupported else { return }
        
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
    
    /// Safely triggers notification haptic feedback only on supported physical devices
    @MainActor
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticFeedbackSupported else { return }
        
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(type)
    }
    
    /// Checks if haptic feedback is supported on the current device
    @MainActor
    private static var isHapticFeedbackSupported: Bool {
        // Skip haptics on simulator
        #if targetEnvironment(simulator)
        return false
        #else
        // Only enable haptics on iPhone (not iPad or Mac Catalyst)
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }
}

#else
// Provide no-op implementations for macOS
enum HapticFeedbackUtil {
    static func impact(_ style: Any = 0) {}
    static func selection() {}
    static func notification(_ type: Any) {}
}
#endif