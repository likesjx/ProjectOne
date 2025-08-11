// NOTE: AgentInterface, MemoryAgent, and CentralAgentRegistry are already defined in the project. Import those modules/files for use. Only define message protocols or helpers here.

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

// Usage example (assuming AgentInterface, CentralAgentRegistry, and agent implementations are imported from elsewhere):
/*
 let registry = CentralAgentRegistry()
 let promptAgent = PromptAgent()
 let memoryAgent = MemoryAgent()
 await registry.register(promptAgent)
 await registry.register(memoryAgent)
 let msg = BasicAgentMessage(senderId: promptAgent.agentId, recipientId: memoryAgent.agentId, messageType: "RequestMemory", payload: "What's current memory context?")
 await registry.send(msg)
*/
