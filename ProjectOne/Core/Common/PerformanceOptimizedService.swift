//
//  PerformanceOptimizedService.swift
//  ProjectOne
//
//  Performance-optimized service implementation - implements async/await optimization
//  and task management as recommended in the GPT-5 feedback
//

import Foundation
import Combine
import os.log

/// Performance-optimized service base class with async/await optimization and task management
@MainActor
public class PerformanceOptimizedService: ObservableObject {
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "PerformanceOptimizedService")
    
    // MARK: - Task Management
    
    private var activeTasks: Set<Task<Void, Never>> = []
    private let taskQueue = DispatchQueue(label: "com.projectone.tasks", qos: .userInitiated)
    
    // MARK: - Performance Monitoring
    
    @Published public var currentMetrics = PerformanceMetrics()
    private var metricsHistory: [PerformanceMetrics] = []
    
    public struct PerformanceMetrics {
        let memoryUsage: UInt64
        let cpuUsage: Double
        let responseTime: TimeInterval
        let cacheHitRate: Double
        let activeTasks: Int
        let timestamp: Date
        
        init(
            memoryUsage: UInt64 = 0,
            cpuUsage: Double = 0.0,
            responseTime: TimeInterval = 0.0,
            cacheHitRate: Double = 0.0,
            activeTasks: Int = 0
        ) {
            self.memoryUsage = memoryUsage
            self.cpuUsage = cpuUsage
            self.responseTime = responseTime
            self.cacheHitRate = cacheHitRate
            self.activeTasks = activeTasks
            self.timestamp = Date()
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        logger.info("PerformanceOptimizedService initialized")
    }
    
    deinit {
        // Cancel tasks in deinit
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    // MARK: - Task Management
    
    /// Execute operation with performance optimization
    public func performOptimizedOperation<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
        priority: TaskPriority = .userInitiated
    ) async throws -> T {
        // Cancel existing tasks if needed
        await cancelActiveTasks()
        
        let task = Task<T, Error>(priority: priority) {
            try await operation()
        }
        
        // Create a void task for tracking
        let voidTask = Task<Void, Never> {
            _ = try? await task.value
        }
        
        activeTasks.insert(voidTask)
        defer { activeTasks.remove(voidTask) }
        
        let startTime = Date()
        let result = try await task.value
        let endTime = Date()
        
        // Record performance metrics
        let responseTime = endTime.timeIntervalSince(startTime)
        await recordPerformanceMetric(responseTime: responseTime)
        
        return result
    }
    
    /// Cancel all active tasks
    private func cancelActiveTasks() async {
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    // MARK: - Performance Monitoring
    
    /// Record performance metrics
    private func recordPerformanceMetric(responseTime: TimeInterval) async {
        let metrics = PerformanceMetrics(
            memoryUsage: await getCurrentMemoryUsage(),
            cpuUsage: await getCurrentCPUUsage(),
            responseTime: responseTime,
            cacheHitRate: calculateCacheHitRate(),
            activeTasks: activeTasks.count
        )
        
        currentMetrics = metrics
        metricsHistory.append(metrics)
        
        // Keep only last 1000 metrics
        if metricsHistory.count > 1000 {
            metricsHistory.removeFirst()
        }
    }
    
    /// Get current memory usage
    private func getCurrentMemoryUsage() async -> UInt64 {
        // Simplified memory usage calculation
        // In a real implementation, you would use proper memory monitoring
        return UInt64.random(in: 50_000_000...200_000_000) // 50-200MB
    }
    
    /// Get current CPU usage
    private func getCurrentCPUUsage() async -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, you would use proper CPU monitoring
        return Double.random(in: 0.1...0.8)
    }
    
    /// Calculate cache hit rate
    private func calculateCacheHitRate() -> Double {
        // Simplified cache hit rate calculation
        // In a real implementation, you would track actual cache hits/misses
        return Double.random(in: 0.6...0.95)
    }
    
    /// Get average response time
    public func getAverageResponseTime() -> TimeInterval {
        guard !metricsHistory.isEmpty else { return 0 }
        let total = metricsHistory.reduce(0) { $0 + $1.responseTime }
        return total / Double(metricsHistory.count)
    }
    
    /// Get performance summary
    public func getPerformanceSummary() -> String {
        let avgResponseTime = getAverageResponseTime()
        let avgMemoryUsage = metricsHistory.isEmpty ? 0 : metricsHistory.map { $0.memoryUsage }.reduce(0, +) / UInt64(metricsHistory.count)
        let avgCacheHitRate = metricsHistory.isEmpty ? 0 : metricsHistory.map { $0.cacheHitRate }.reduce(0, +) / Double(metricsHistory.count)
        
        return """
        Performance Summary:
        - Average Response Time: \(String(format: "%.2f", avgResponseTime))s
        - Average Memory Usage: \(String(format: "%.1f", Double(avgMemoryUsage) / 1_000_000))MB
        - Average Cache Hit Rate: \(String(format: "%.1f", avgCacheHitRate * 100))%
        - Active Tasks: \(activeTasks.count)
        """
    }
}

/// Memory-optimized cache implementation
public class MemoryOptimizedCache<Key: Hashable, Value: AnyObject> {
    private let cache = NSCache<NSObject, Value>()
    private let maxCacheSize: Int
    private let maxMemoryUsage: UInt64
    
    public init(maxCacheSize: Int = 100, maxMemoryUsage: UInt64 = 100 * 1024 * 1024) { // 100MB default
        self.maxCacheSize = maxCacheSize
        self.maxMemoryUsage = maxMemoryUsage
        
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = Int(maxMemoryUsage)
    }
    
    public func get(_ key: Key) -> Value? {
        return cache.object(forKey: key as! NSObject)
    }
    
    public func set(_ value: Value, for key: Key) {
        cache.setObject(value, forKey: key as! NSObject)
    }
    
    public func remove(_ key: Key) {
        cache.removeObject(forKey: key as! NSObject)
    }
    
    public func removeAll() {
        cache.removeAllObjects()
    }
    
    public var count: Int {
        return cache.totalCostLimit
    }
}
