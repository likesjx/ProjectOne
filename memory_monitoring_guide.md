# Memory Decision Monitoring Guide

## 🎯 Problem Solved
**Issue**: Memory Agent system was disabled during prompt testing, preventing memory processing after note creation.
**Solution**: ✅ Re-enabled MemoryAgentService in ProjectOneApp.swift with new prompt integration.

## 🔄 Expected Flow After Note Creation

When you save a note with ID `DF8D32A1-9925-49D0-89DC-3F25B3701EB3`:

### 1. Immediate Processing
```
📝 TextIngestionAgent → Memory Agent notified
├─ VoiceMemoView posts .newNoteCreated notification
├─ MemoryAgentIntegration receives notification  
├─ handleNoteItem() called with note data
└─ memoryAgent.ingestData() triggered
```

### 2. Memory Decision Pipeline
```
🧠 MemoryAgent.ingestData()
├─ processNote() called
├─ MemoryPromptResolver.getPromptFor(.noteCategorizationSTMvsLTM)
├─ Template rendered with note content
├─ AI decision: "LONG_TERM" or "SHORT_TERM"
└─ STM or LTM entry created
```

### 3. Entity Extraction
```
🔍 extractEntitiesAndRelationships()
├─ MemoryPromptResolver.getPromptFor(.entityRelationshipExtraction)
├─ Template rendered with text content
├─ AI extracts JSON entities/relationships
└─ Entity and Relationship records created
```

## 📊 Monitoring Logs to Watch For

### App Startup Logs
```
🧠 [ProjectOneApp] Initializing Memory Agent system...
✅ [ProjectOneApp] Memory Agent system initialized successfully
```

### Note Processing Logs
```
📝 [TextIngestionAgent] Processing note ID: DF8D32A1-9925-49D0-89DC-3F25B3701EB3
📝 [TextIngestionAgent] Successfully processed note ID DF8D32A1-9925-49D0-89DC-3F25B3701EB3
📝 [NoteCreation] Note saved and Memory Agent notified for note: DF8D32A1-9925-49D0-89DC-3F25B3701EB3
```

### Memory Agent Processing Logs
```
[MemoryAgentIntegration] Handling note item: [content preview]...
[MemoryAgent] Ingesting data: note
[MemoryPromptResolver] Resolving prompt for operation: Note Categorization (STM vs LTM)
[MemoryPromptResolver] Selected template 'note-categorization-stm-ltm' for operation...
[MemoryAgent] Successfully saved memory entry (Note processing)
[MemoryPromptResolver] Resolving prompt for operation: Entity & Relationship Extraction
[MemoryAgent] Entity extraction completed for content from stm_entry
```

## 🛠️ Monitoring Tools Available

### 1. Console Logs
```bash
# Monitor system logs
log show --predicate 'subsystem == "com.jaredlikes.ProjectOne"' --last 5m

# Monitor specific categories
log show --predicate 'category CONTAINS "MemoryAgent"' --last 5m
log show --predicate 'category CONTAINS "PromptManager"' --last 5m
```

### 2. Memory Dashboard (In App)
- Real-time memory counts (STM, LTM, Working, Episodic)
- System health indicators  
- Recent consolidation activity
- Performance metrics
- Template usage statistics

### 3. Template Performance Tracking
- Success/failure rates for each template
- Processing times
- Context adaptation effectiveness
- Error rate monitoring

## 🧪 Testing the Integration

### Test Note Creation
1. Create a new note in the app
2. Watch for the processing logs above
3. Check Memory Dashboard for new entries
4. Verify template performance metrics

### Test Different Note Types
- **Personal notes**: Should trigger privacy-focused templates
- **Technical notes**: Should extract technical entities
- **Important notes**: Should be classified as LTM
- **Casual notes**: Should be classified as STM

## 🔧 Debug Tips

### If No Logs Appear
1. Verify Memory Agent is running: Check for startup success log
2. Check notification posting: Look for .newNoteCreated notifications
3. Verify integration: MemoryAgentIntegration should handle notifications

### If Processing Fails
1. Check template availability in PromptManager
2. Verify MemoryPromptResolver template selection
3. Check AI provider availability and configuration
4. Monitor template performance metrics for failures

## 📱 Next Steps

1. **Launch the app** - Memory Agent will now initialize automatically
2. **Create a test note** - Watch for the processing pipeline
3. **Open Memory Dashboard** - Monitor real-time activity
4. **Check logs** - Use Console.app or Xcode console for detailed monitoring

The system is now fully operational with our new prompt management integration! 🚀