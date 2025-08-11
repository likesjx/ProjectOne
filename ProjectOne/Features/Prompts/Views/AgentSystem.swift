// AgentSystem.swift
// Defines protocols and infrastructure for Agent-to-Agent (A2A) messaging

import Foundation

// MARK: - Agent Message Protocol

public protocol AgentMessage: Sendable {
    var senderId: String { get }
    var recipientId: String? { get } // nil for broadcast
    var messageType: String { get }
}

// Example base message (extend for custom payloads)
public struct BasicAgentMessage: AgentMessage {
    public let senderId: String
    public let recipientId: String?
    public let messageType: String
    public let payload: String?
    public init(senderId: String, recipientId: String? = nil, messageType: String, payload: String? = nil) {
        self.senderId = senderId
        self.recipientId = recipientId
        self.messageType = messageType
        self.payload = payload
    }
}

// MARK: - Agent Interface Protocol

public protocol AgentInterface: AnyObject, Sendable {
    var agentId: String { get }
    func receive(_ message: AgentMessage) async
}

// MARK: - Central Agent Registry / Message Bus

public actor CentralAgentRegistry {
    private var agents: [String: AgentInterface] = [:]
    
    public init() {}
    
    public func register(_ agent: AgentInterface) {
        agents[agent.agentId] = agent
    }
    
    public func unregister(agentId: String) {
        agents.removeValue(forKey: agentId)
    }
    
    /// Sends a message to the intended recipient (if recipientId provided), otherwise broadcasts to all except sender
    public func send(_ message: AgentMessage) async {
        if let recipientId = message.recipientId {
            if let recipient = agents[recipientId] {
                await recipient.receive(message)
            }
        } else {
            for (id, agent) in agents where id != message.senderId {
                await agent.receive(message)
            }
        }
    }
    
    public func listRegisteredAgents() -> [String] {
        return Array(agents.keys)
    }
}

// MARK: - Example Agent Stubs

public final class PromptAgent: AgentInterface {
    public let agentId: String
    public init(agentId: String = "PromptAgent") { self.agentId = agentId }
    public func receive(_ message: AgentMessage) async {
        print("[\(agentId)] received message: \(message.messageType) from \(message.senderId)")
    }
}

public final class MemoryAgent: AgentInterface {
    public let agentId: String
    public init(agentId: String = "MemoryAgent") { self.agentId = agentId }
    public func receive(_ message: AgentMessage) async {
        print("[\(agentId)] received message: \(message.messageType) from \(message.senderId)")
    }
}

// Usage Example (add to your initialization logic):
// let registry = CentralAgentRegistry()
// let promptAgent = PromptAgent()
// let memoryAgent = MemoryAgent()
// await registry.register(promptAgent)
// await registry.register(memoryAgent)
// let msg = BasicAgentMessage(senderId: "PromptAgent", recipientId: "MemoryAgent", messageType: "RequestMemory", payload: "What's current memory context?")
// await registry.send(msg)
