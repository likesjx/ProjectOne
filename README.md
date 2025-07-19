# ProjectOne

A sophisticated SwiftUI iOS/macOS personal AI knowledge system featuring production-ready AI providers, comprehensive audio pipeline, and intelligent memory management with iOS 26.0+ Foundation Models integration.

## Quick Start

### Prerequisites
- Xcode 26+ (Beta)
- iOS 26+ (Beta) / macOS Tahoe+
- Swift 6.0+
- Apple Silicon hardware (for MLX Swift support)
- Apple Intelligence enabled (for Foundation Models)

### Setup
```bash
git clone <repository-url>
cd ProjectOne
open ProjectOne.xcodeproj
```

### Build & Run
```bash
# iOS Simulator (iOS 26.0+ required for Foundation Models)
⌘+R in Xcode (select iOS target)

# macOS (Apple Silicon recommended for MLX Swift)
⌘+R in Xcode (select macOS target)
```

## System Overview

ProjectOne features a **dual AI provider architecture** with MLX Swift 0.25.6 for on-device inference and iOS 26.0+ Foundation Models for system-integrated AI capabilities, combined with comprehensive memory management and audio processing.

### Core Features
- 🤖 **Production AI Providers** - MLX Swift 0.25.6 (real models) + iOS 26.0+ Foundation Models
- 🎙️ **Complete Audio Pipeline** - Recording, playback, and Apple Speech Recognition transcription
- 🎵 **Audio Playback System** - Cross-platform audio player with progress tracking and seek controls
- 🗣️ **Apple Speech Integration** - Real Apple Speech Recognition with proper permission handling
- 🧠 **Memory Agent System** - AI-powered memory management with privacy-first architecture
- 🔐 **Dual Provider Architecture** - Automatic routing between on-device MLX and system Foundation Models
- 🕸️ **Knowledge Graph** - Interactive visualization of entities and relationships  
- 🧮 **RAG (Retrieval-Augmented Generation)** - Advanced memory retrieval with semantic ranking
- 🤖 **Agentic Framework** - Autonomous memory consolidation and knowledge graph updates
- 📊 **Memory Analytics** - Dashboard for memory usage and system health monitoring
- 🔧 **Comprehensive Testing** - UnifiedAITestView for concurrent provider testing
- 💾 **Data Export/Import** - Export/import data in JSON, CSV, and Markdown formats
- 📱 **Enhanced Recording UI** - Liquid Glass recording rows with playback controls
- ✨ **Liquid Glass UI** - iOS 26 Glass design language throughout the interface

### Architecture Layers
- **UI Layer**: SwiftUI with Liquid Glass design language, NavigationStack, TabView
- **Memory Agent Layer**: Privacy analyzer, RAG retrieval engine, agentic orchestrator
- **Service Layer**: EnhancedGemma3nCore, dual AI provider routing, complete audio pipeline
- **Data Layer**: SwiftData persistence with comprehensive memory models
- **AI/ML Layer**: MLX Swift 0.25.6 (on-device), iOS 26.0+ Foundation Models (system), Apple Speech
- **Design Layer**: iOS 26 Glass effects, interactive materials, adaptive UI

## Documentation

### 📚 For Developers
- **[Architecture Overview](docs/architecture/)** - System design and component interaction
- **[Implementation Guides](docs/guides/)** - SwiftData, troubleshooting, and fixes
- **[API Documentation](docs/api/)** - Code-level documentation

### 📋 For Planning
- **[Feature Specifications](docs/specifications/)** - Detailed feature requirements and designs
- **[Integration Plans](docs/specifications/)** - MLX Swift and future AI capabilities
- **[Defects & Technical Debt](docs/DEFECTS.md)** - Bug tracking and technical debt management

### 🚀 Quick References
- **[Development Workflow](#development-workflow)** - Build, test, and deployment
- **[Project Structure](#project-structure)** - Code organization
- **[Contributing](#contributing)** - How to contribute to the project

## Development Workflow

### Testing
```bash
# Run tests
⌘+U in Xcode
```

### Linting & Type Checking
```bash
# SwiftLint (if configured)
swiftlint

# Swift type checking
swift build
```

### Git Workflow
1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes and commit: `git commit -m "Add your feature"`
3. Push and create PR: `git push origin feature/your-feature`

## Project Structure

```
ProjectOne/
├── ProjectOne/
│   ├── Models/          # SwiftData models (Entity, Relationship, etc.)
│   ├── Views/           # SwiftUI views and components
│   ├── Services/        # Business logic and AI services
│   └── ContentView.swift
├── docs/
│   ├── architecture/    # System architecture documentation
│   ├── specifications/  # Feature specs and requirements
│   ├── guides/         # Implementation guides and troubleshooting
│   └── api/            # Code documentation
└── README.md
```

## Current Status

**Phase 5 Complete**: Production AI Provider Integration  
**Next**: Enhanced memory management with structured generation

### Recent Updates (2025-07-19)
- 🎯 **Production AI Providers** - Real MLX Swift 0.25.6 and iOS 26.0+ Foundation Models implementation
- 🔗 **WorkingMLXProvider** - Actual MLX Swift APIs with real community models (Qwen3, Gemma2, Llama3.1)
- 🍎 **RealFoundationModelsProvider** - iOS 26.0+ SystemLanguageModel with proper availability checking
- 🧠 **EnhancedGemma3nCore** - Dual provider system with automatic routing and @Generable support
- 🔧 **AppleIntelligenceProvider** - Updated with real device eligibility and feature detection
- 📱 **iOS 26.0+ Target** - Project fully updated for Foundation Models framework requirements
- 🧪 **UnifiedAITestView** - Comprehensive concurrent testing of all AI providers
- ✅ **Real APIs Only** - All placeholder and mock implementations removed
- 🧮 **RAG Implementation** - Advanced retrieval-augmented generation with semantic ranking and scoring
- 🤖 **Agentic Framework** - Autonomous memory consolidation, entity extraction, and knowledge graph updates
- 📊 **Memory Analytics Dashboard** - Real-time system health monitoring and memory insights
- 🎉 **Complete Audio Recording System** - Full implementation with Apple Speech Recognition
- 🎵 **AudioPlayer Integration** - Cross-platform playback with AVAudioPlayer and progress controls
- 🗣️ **AppleSpeechEngine** - Real Apple Speech Recognition replacing placeholder transcription
- 📱 **Enhanced Recording UI** - Interactive playback controls in LiquidGlassRecordingRow
- 💾 **RecordingItem Model** - SwiftData persistence for audio metadata and transcriptions
- 🔧 **Dual Engine Architecture** - Toggle between Apple Speech and Placeholder engines
- ✅ **Build System Fixed** - All compilation errors resolved, project builds successfully
- ✅ **Liquid Glass Integration** - Complete iOS 26 Glass design language implementation
- ✅ **Voice Memo UI Redesign** - Glass-enhanced audio recording interface
- ✅ **NavigationStack Migration** - Proper iOS 26 navigation architecture
- ✅ **TabView Glass Effects** - Native tab bar with glass materials
- ✅ **Interactive Glass Elements** - Buttons, panels, and controls with glass effects
- ✅ **Legacy Code Integration** - Successfully merged old ProjectOne components
- ✅ **Memory System Complete** - STM, LTM, Working Memory, and Episodic Memory
- ✅ **Knowledge Graph Models** - Entity, Relationship, TemporalEvent, ConceptNode
- ✅ **Analytics Dashboard** - Memory analytics and performance tracking
- ✅ **Data Export/Import** - Comprehensive data management system
- ✅ **GitHub Integration** - Issues, labels, and project tracking setup
- ✅ **iOS 26 Beta** - Updated for latest iOS 26 beta with Glass support
- ✅ **Cross-Platform Build** - Fixed iOS/macOS compatibility with Xcode Beta 3

## Contributing

1. Check [GitHub Issues](https://github.com/likesjx/ProjectOne/issues) for current bugs and features
2. Review [specifications](docs/specifications/) for planned features
3. Review [architecture docs](docs/architecture/) to understand the system
4. Follow the [implementation guides](docs/guides/) for best practices
5. Check [DEFECTS.md](docs/DEFECTS.md) for technical debt and bug tracking

## Technology Stack

- **Frontend**: SwiftUI with Liquid Glass design language, iOS 26+ (Beta), macOS Tahoe+
- **Navigation**: NavigationStack, TabView with glass materials
- **UI Framework**: iOS 26 Glass APIs (.glassEffect, GlassEffectContainer, .interactive)
- **AI Providers**: MLX Swift 0.25.6 (on-device), iOS 26.0+ Foundation Models (system)
- **AI Framework**: EnhancedGemma3nCore with dual provider routing and @Generable support
- **Memory Agent**: Privacy analyzer, RAG retrieval engine, agentic orchestrator
- **Backend Services**: Swift 6.0, MLXLMCommon for model loading and inference
- **Database**: SwiftData with comprehensive memory models
- **Audio**: AVFoundation for recording, Apple Speech Recognition for transcription
- **Privacy**: Automatic routing based on data sensitivity and provider availability
- **Architecture**: MVVM with dual AI provider layer and service pattern
- **Design System**: Apple's Liquid Glass, adaptive materials, refraction effects
- **Testing**: UnifiedAITestView for concurrent provider validation

## License

[License information here]

---

*For detailed technical documentation, see the [docs](docs/) directory.*