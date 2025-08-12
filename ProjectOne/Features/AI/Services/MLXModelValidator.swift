//
//  MLXModelValidator.swift
//  ProjectOne
//
//  Model validation and compatibility checking service
//  Ensures models are compatible with the device and MLX framework
//

import Foundation
import os.log

#if canImport(IOKit)
import IOKit
#endif

/// Service for validating MLX model compatibility and requirements
public class MLXModelValidator {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXModelValidator")
    
    // MARK: - System Information
    
    public struct SystemInfo {
        let isAppleSilicon: Bool
        let totalMemoryGB: Int
        let availableMemoryGB: Int
        let deviceModel: String
        let osVersion: String
        let mlxSupported: Bool
        
        public var memoryStatus: MemoryStatus {
            if availableMemoryGB >= 16 {
                return .excellent
            } else if availableMemoryGB >= 8 {
                return .good
            } else if availableMemoryGB >= 4 {
                return .limited
            } else {
                return .insufficient
            }
        }
    }
    
    public enum MemoryStatus {
        case excellent  // 16GB+
        case good       // 8-15GB
        case limited    // 4-7GB
        case insufficient // <4GB
        
        public var displayName: String {
            switch self {
            case .excellent: return "Excellent (16GB+)"
            case .good: return "Good (8-15GB)"
            case .limited: return "Limited (4-7GB)"
            case .insufficient: return "Insufficient (<4GB)"
            }
        }
        
        public var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .limited: return "orange"
            case .insufficient: return "red"
            }
        }
    }
    
    public struct ValidationResult {
        let isCompatible: Bool
        let compatibility: CompatibilityLevel
        let warnings: [ValidationWarning]
        let recommendations: [String]
        let estimatedPerformance: PerformanceEstimate
        
        public var canRun: Bool {
            return compatibility != .incompatible
        }
        
        public var shouldRecommend: Bool {
            return compatibility == .excellent || compatibility == .good
        }
    }
    
    public enum CompatibilityLevel: String, CaseIterable {
        case excellent = "excellent"
        case good = "good"
        case acceptable = "acceptable"
        case poor = "poor"
        case incompatible = "incompatible"
        
        public var displayName: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .acceptable: return "Acceptable"
            case .poor: return "Poor"
            case .incompatible: return "Incompatible"
            }
        }
        
        public var emoji: String {
            switch self {
            case .excellent: return "🟢"
            case .good: return "🔵"
            case .acceptable: return "🟡"
            case .poor: return "🟠"
            case .incompatible: return "🔴"
            }
        }
    }
    
    public enum ValidationWarning {
        case highMemoryUsage(required: Int, available: Int)
        case slowPerformanceExpected
        case quantizationRecommended
        case appleSiliconRequired
        case insufficientMemory
        case modelTooLarge
        case experimentalModel
        
        public var message: String {
            switch self {
            case .highMemoryUsage(let required, let available):
                return "Model requires ~\(required)GB memory, only \(available)GB available"
            case .slowPerformanceExpected:
                return "Performance may be slow on this device"
            case .quantizationRecommended:
                return "Consider using quantized version for better performance"
            case .appleSiliconRequired:
                return "Requires Apple Silicon (M-series chip)"
            case .insufficientMemory:
                return "Insufficient memory to run this model"
            case .modelTooLarge:
                return "Model is too large for optimal performance"
            case .experimentalModel:
                return "This is an experimental model - results may vary"
            }
        }
        
        public var severity: WarningSeverity {
            switch self {
            case .insufficientMemory, .appleSiliconRequired:
                return .critical
            case .modelTooLarge, .highMemoryUsage:
                return .high
            case .slowPerformanceExpected, .quantizationRecommended:
                return .medium
            case .experimentalModel:
                return .low
            }
        }
    }
    
    public enum WarningSeverity {
        case critical, high, medium, low
        
        public var color: String {
            switch self {
            case .critical: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "blue"
            }
        }
    }
    
    public struct PerformanceEstimate {
        let tokensPerSecond: Double
        let memoryEfficiency: Double
        let powerConsumption: PowerConsumption
        let thermalImpact: ThermalImpact
        
        public var overallRating: String {
            let average = (tokensPerSecond / 50.0 + memoryEfficiency) / 2.0
            if average >= 0.8 { return "Excellent" }
            else if average >= 0.6 { return "Good" }
            else if average >= 0.4 { return "Fair" }
            else { return "Poor" }
        }
    }
    
    public enum PowerConsumption: String, CaseIterable {
        case low, medium, high, veryHigh
        
        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .veryHigh: return "Very High"
            }
        }
    }
    
    public enum ThermalImpact: String, CaseIterable {
        case minimal, moderate, significant, severe
        
        public var displayName: String {
            switch self {
            case .minimal: return "Minimal"
            case .moderate: return "Moderate"
            case .significant: return "Significant"
            case .severe: return "Severe"
            }
        }
    }
    
    // MARK: - Singleton
    
    public static let shared = MLXModelValidator()
    
    private init() {
        logger.info("MLX Model Validator initialized")
    }
    
    // MARK: - System Information
    
    public func getSystemInfo() -> SystemInfo {
        let isAppleSilicon = ProcessInfo.processInfo.processorCount > 0 && isRunningOnAppleSilicon()
        let totalMemory = getTotalMemoryGB()
        let availableMemory = getAvailableMemoryGB()
        let deviceModel = getDeviceModel()
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let mlxSupported = isAppleSilicon // MLX requires Apple Silicon
        
        return SystemInfo(
            isAppleSilicon: isAppleSilicon,
            totalMemoryGB: totalMemory,
            availableMemoryGB: availableMemory,
            deviceModel: deviceModel,
            osVersion: osVersion,
            mlxSupported: mlxSupported
        )
    }
    
    private func isRunningOnAppleSilicon() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        // Apple Silicon Macs have arm64 architecture
        return machine?.contains("arm64") == true
    }
    
    private func getTotalMemoryGB() -> Int {
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        return Int(memoryBytes / (1024 * 1024 * 1024))
    }
    
    private func getAvailableMemoryGB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self(), task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            // Fallback to conservative estimate
            return max(1, getTotalMemoryGB() - 4) // Assume 4GB used by system
        }
        
        let totalMemory = getTotalMemoryGB()
        let usedMemory = Int(info.resident_size / (1024 * 1024 * 1024))
        return max(1, totalMemory - usedMemory - 2) // Reserve 2GB for system
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    // MARK: - Model Validation
    
    public func validateModel(_ model: MLXCommunityModel) -> ValidationResult {
        let systemInfo = getSystemInfo()
        
        var warnings: [ValidationWarning] = []
        var recommendations: [String] = []
        var compatibility: CompatibilityLevel = .excellent
        
        // Basic Apple Silicon check
        if !systemInfo.isAppleSilicon {
            warnings.append(.appleSiliconRequired)
            compatibility = .incompatible
        }
        
        // Memory requirements check
        let estimatedMemoryGB = extractMemoryRequirement(from: model)
        if estimatedMemoryGB > systemInfo.availableMemoryGB {
            warnings.append(.highMemoryUsage(required: estimatedMemoryGB, available: systemInfo.availableMemoryGB))
            
            if estimatedMemoryGB > systemInfo.availableMemoryGB + 2 {
                warnings.append(.insufficientMemory)
                compatibility = .incompatible
            } else {
                compatibility = min(compatibility, .poor)
                recommendations.append("Close other applications to free up memory")
            }
        }
        
        // Model size analysis
        let modelCategory = categorizeModel(model)
        let deviceCategory = categorizeDevice(systemInfo)
        
        switch (modelCategory, deviceCategory) {
        case (.large, .lowEnd), (.veryLarge, .lowEnd), (.veryLarge, .midRange):
            compatibility = min(compatibility, .poor)
            warnings.append(.slowPerformanceExpected)
            recommendations.append("Consider using a smaller or quantized model")
            
        case (.large, .midRange):
            compatibility = min(compatibility, .acceptable)
            warnings.append(.slowPerformanceExpected)
            
        case (.medium, .lowEnd):
            compatibility = min(compatibility, .acceptable)
            
        default:
            break
        }
        
        // Quantization recommendations
        if !model.isQuantized && estimatedMemoryGB > 4 {
            warnings.append(.quantizationRecommended)
            recommendations.append("Consider using the 4-bit quantized version for better performance")
        }
        
        // Experimental model check
        if isExperimentalModel(model) {
            warnings.append(.experimentalModel)
            recommendations.append("This model is experimental - consider using a stable alternative")
        }
        
        // Performance estimation
        let performance = estimatePerformance(model: model, systemInfo: systemInfo, warnings: warnings)
        
        // Final compatibility adjustment based on warnings
        if warnings.contains(where: { $0.severity == .critical }) {
            compatibility = .incompatible
        } else if warnings.count > 3 {
            compatibility = min(compatibility, .poor)
        } else if warnings.count > 1 {
            compatibility = min(compatibility, .acceptable)
        }
        
        return ValidationResult(
            isCompatible: compatibility != .incompatible,
            compatibility: compatibility,
            warnings: warnings,
            recommendations: recommendations,
            estimatedPerformance: performance
        )
    }
    
    private func extractMemoryRequirement(from model: MLXCommunityModel) -> Int {
        // Parse memory requirement from model info
        let memoryString = model.memoryRequirement.lowercased()
        
        if let range = memoryString.range(of: #"\d+"#, options: .regularExpression) {
            let numberString = String(memoryString[range])
            if let number = Int(numberString) {
                return number
            }
        }
        
        // Fallback: estimate based on model name
        let name = model.name.lowercased()
        if name.contains("70b") { return 40 }
        else if name.contains("13b") { return 8 }
        else if name.contains("7b") { return 4 }
        else if name.contains("3b") { return 2 }
        else if name.contains("2b") { return 1 }
        else { return 4 } // Default estimate
    }
    
    private func categorizeModel(_ model: MLXCommunityModel) -> ModelCategory {
        let name = model.name.lowercased()
        let memoryGB = extractMemoryRequirement(from: model)
        
        if name.contains("70b") || memoryGB > 20 {
            return .veryLarge
        } else if name.contains("13b") || name.contains("7b") || memoryGB > 6 {
            return .large
        } else if name.contains("3b") || memoryGB > 2 {
            return .medium
        } else {
            return .small
        }
    }
    
    private func categorizeDevice(_ systemInfo: SystemInfo) -> DeviceCategory {
        if systemInfo.totalMemoryGB >= 16 && systemInfo.isAppleSilicon {
            return .highEnd
        } else if systemInfo.totalMemoryGB >= 8 && systemInfo.isAppleSilicon {
            return .midRange
        } else {
            return .lowEnd
        }
    }
    
    private func isExperimentalModel(_ model: MLXCommunityModel) -> Bool {
        let experimentalKeywords = ["experimental", "alpha", "beta", "unstable", "dev"]
        let nameAndDescription = (model.name + " " + model.description).lowercased()
        
        return experimentalKeywords.contains { nameAndDescription.contains($0) } ||
               model.tags.contains { tag in
                   experimentalKeywords.contains { tag.lowercased().contains($0) }
               }
    }
    
    private func estimatePerformance(model: MLXCommunityModel, systemInfo: SystemInfo, warnings: [ValidationWarning]) -> PerformanceEstimate {
        let hasPerformanceWarnings = warnings.contains { warning in
            switch warning {
            case .slowPerformanceExpected, .highMemoryUsage, .modelTooLarge:
                return true
            default:
                return false
            }
        }
        
        let baseTokensPerSecond: Double
        let modelCategory = categorizeModel(model)
        let deviceCategory = categorizeDevice(systemInfo)
        
        // Base performance estimates (tokens per second)
        switch (modelCategory, deviceCategory) {
        case (.small, .highEnd): baseTokensPerSecond = 50.0
        case (.small, .midRange): baseTokensPerSecond = 30.0
        case (.small, .lowEnd): baseTokensPerSecond = 15.0
        case (.medium, .highEnd): baseTokensPerSecond = 25.0
        case (.medium, .midRange): baseTokensPerSecond = 15.0
        case (.medium, .lowEnd): baseTokensPerSecond = 8.0
        case (.large, .highEnd): baseTokensPerSecond = 12.0
        case (.large, .midRange): baseTokensPerSecond = 6.0
        case (.large, .lowEnd): baseTokensPerSecond = 3.0
        case (.veryLarge, .highEnd): baseTokensPerSecond = 5.0
        case (.veryLarge, .midRange): baseTokensPerSecond = 2.0
        case (.veryLarge, .lowEnd): baseTokensPerSecond = 1.0
        }
        
        // Adjust for quantization
        let quantizationMultiplier = model.isQuantized ? 1.5 : 1.0
        let adjustedTokensPerSecond = baseTokensPerSecond * quantizationMultiplier
        
        // Memory efficiency (0.0 to 1.0)
        let memoryRequired = extractMemoryRequirement(from: model)
        let memoryEfficiency = min(1.0, Double(systemInfo.availableMemoryGB) / Double(memoryRequired))
        
        // Power consumption estimate
        let powerConsumption: PowerConsumption
        switch (modelCategory, deviceCategory) {
        case (.small, _): powerConsumption = .low
        case (.medium, .highEnd): powerConsumption = .low
        case (.medium, _): powerConsumption = .medium
        case (.large, .highEnd): powerConsumption = .medium
        case (.large, _): powerConsumption = .high
        case (.veryLarge, _): powerConsumption = .veryHigh
        }
        
        // Thermal impact
        let thermalImpact: ThermalImpact
        if hasPerformanceWarnings || memoryRequired > systemInfo.availableMemoryGB {
            thermalImpact = .significant
        } else {
            switch powerConsumption {
            case .low: thermalImpact = .minimal
            case .medium: thermalImpact = .moderate
            case .high: thermalImpact = .significant
            case .veryHigh: thermalImpact = .severe
            }
        }
        
        return PerformanceEstimate(
            tokensPerSecond: adjustedTokensPerSecond,
            memoryEfficiency: memoryEfficiency,
            powerConsumption: powerConsumption,
            thermalImpact: thermalImpact
        )
    }
    
    // MARK: - Bulk Validation
    
    public func validateModels(_ models: [MLXCommunityModel]) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]
        
        for model in models {
            results[model.id] = validateModel(model)
        }
        
        return results
    }
    
    public func getRecommendedModels(_ models: [MLXCommunityModel]) -> [MLXCommunityModel] {
        let validationResults = validateModels(models)
        
        return models.filter { model in
            guard let result = validationResults[model.id] else { return false }
            return result.shouldRecommend
        }.sorted { model1, model2 in
            let result1 = validationResults[model1.id]!
            let result2 = validationResults[model2.id]!
            
            if result1.compatibility != result2.compatibility {
                return result1.compatibility.rawValue < result2.compatibility.rawValue
            }
            
            return model1.downloads > model2.downloads
        }
    }
    
    // MARK: - Supporting Enums
    
    private enum ModelCategory {
        case small, medium, large, veryLarge
    }
    
    private enum DeviceCategory {
        case lowEnd, midRange, highEnd
    }
}