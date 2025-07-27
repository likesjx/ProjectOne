import Foundation

// Quick test to verify notification system
print("🧪 Testing notification posting...")

// Simulate the same notification that NoteCreationView posts
let testNoteId = UUID(uuidString: "4A942C69-04D1-4B23-96D0-A0C41A9C8025")!

NotificationCenter.default.post(
    name: Notification.Name("newNoteCreated"),
    object: nil,
    userInfo: ["noteId": testNoteId]
)

print("📨 Posted .newNoteCreated notification with noteId: \(testNoteId)")
print("🔍 If MemoryAgentIntegration is running, you should see debug logs:")
print("   [MemoryAgentIntegration] Handling new note notification")
print("   [MemoryAgentIntegration] Handling note item: [content preview]...")