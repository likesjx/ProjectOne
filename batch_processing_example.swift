#!/usr/bin/env swift

// Example: How to use the batch processing functionality
// This demonstrates how to process unprocessed or failed notes and recordings

import Foundation

/**
 * Example usage of the batch processing system
 * 
 * This would typically be called from within the app after the MemoryAgentService is running.
 */

// Example: Process all unprocessed items
func processAllUnprocessedItems() async {
    // Get reference to the MemoryAgentService (would be from your app's dependency injection)
    // let memoryService = getMemoryAgentService()
    
    do {
        // Check how many unprocessed items exist
        // let count = try memoryService.getUnprocessedItemsCount()
        // print("📊 Found \(count.total) unprocessed items:")
        // print("   📝 Notes: \(count.notes)")
        // print("   🎤 Recordings: \(count.recordings)")
        
        // Process all unprocessed items
        // let result = try await memoryService.processUnprocessedItems()
        
        // print("✅ Batch processing completed:")
        // print("   📝 Notes: \(result.notesProcessed) processed, \(result.notesFailed) failed")
        // print("   🎤 Recordings: \(result.recordingsProcessed) processed, \(result.recordingsFailed) failed")
        // print("   ⏱️ Total time: \(String(format: "%.2f", result.totalProcessingTime))s")
        // print("   📈 Success rate: \(String(format: "%.1f", result.successRate * 100))%")
        
        print("Example: All unprocessed items processed successfully!")
        
    } catch {
        print("❌ Failed to process unprocessed items: \(error)")
    }
}

// Example: Process only notes
func processUnprocessedNotesOnly() async {
    // let memoryService = getMemoryAgentService()
    
    do {
        // let (processed, failed) = try await memoryService.processUnprocessedNotes()
        // print("📝 Notes processing complete: \(processed) processed, \(failed) failed")
        
        print("Example: Unprocessed notes processed!")
        
    } catch {
        print("❌ Failed to process notes: \(error)")
    }
}

// Example: Process only recordings  
func processUnprocessedRecordingsOnly() async {
    // let memoryService = getMemoryAgentService()
    
    do {
        // let (processed, failed) = try await memoryService.processUnprocessedRecordings()
        // print("🎤 Recordings processing complete: \(processed) processed, \(failed) failed")
        
        print("Example: Unprocessed recordings processed!")
        
    } catch {
        print("❌ Failed to process recordings: \(error)")
    }
}

// Example: Monitor and auto-process
func monitorAndAutoProcess() async {
    // let memoryService = getMemoryAgentService()
    
    while true {
        do {
            // let count = try memoryService.getUnprocessedItemsCount()
            
            // if count.total > 0 {
            //     print("🔄 Found \(count.total) unprocessed items, starting batch processing...")
            //     let result = try await memoryService.processUnprocessedItems()
            //     print("✅ Auto-processed \(result.totalProcessed) items")
            // }
            
            print("Example: Auto-processing check completed")
            
        } catch {
            print("❌ Auto-processing error: \(error)")
        }
        
        // Wait 5 minutes before checking again
        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
    }
}

// Run examples
await processAllUnprocessedItems()
await processUnprocessedNotesOnly()
await processUnprocessedRecordingsOnly()

print("\n🎯 Batch processing examples completed!")
print("\nTo use this in your app:")
print("1. Ensure MemoryAgentService is running")
print("2. Call memoryService.processUnprocessedItems() when needed")
print("3. Monitor unprocessed counts with getUnprocessedItemsCount()")
print("4. Set up periodic processing for failed items")