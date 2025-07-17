# ProjectOne

A sophisticated SwiftUI iOS/macOS personal AI knowledge system that combines audio recording, real-time transcription, knowledge graph construction, and intelligent memory management.

## Quick Start

### Prerequisites
- Xcode 26+ (Beta)
- iOS 26+ (Beta) / macOS Tahoe+
- Swift 6.0+
- Liquid Glass Design Language support

### Setup
```bash
git clone <repository-url>
cd ProjectOne
open ProjectOne.xcodeproj
```

### Build & Run
```bash
# iOS Simulator
⌘+R in Xcode (select iOS target)

# macOS
⌘+R in Xcode (select macOS target)
```

## System Overview

ProjectOne is built around the **Gemma3nCore** AI reasoning engine and uses a Titans-inspired memory architecture for intelligent knowledge management.

### Core Features
- 🎙️ **Complete Audio Pipeline** - Recording, playback, and Apple Speech Recognition transcription
- 🎵 **Audio Playback System** - Cross-platform audio player with progress tracking and seek controls
- 🗣️ **Apple Speech Integration** - Real Apple Speech Recognition with proper permission handling
- 🧠 **Memory Agent System** - AI-powered memory management with privacy-first architecture
- 🤖 **MLX Gemma3n Integration** - On-device MLX-based AI provider with local inference capability
- 🔐 **Privacy-First AI** - Automatic routing between MLX on-device and Apple Foundation Models
- 🕸️ **Knowledge Graph** - Interactive visualization of entities and relationships  
- 🧮 **RAG (Retrieval-Augmented Generation)** - Advanced memory retrieval with semantic ranking
- 🤖 **Agentic Framework** - Autonomous memory consolidation and knowledge graph updates
- 📊 **Memory Analytics** - Dashboard for memory usage and system health monitoring
- 🔧 **Transcription Framework** - Dual-engine architecture (Apple Speech + Placeholder simulation)
- 💾 **Data Export/Import** - Export/import data in JSON, CSV, and Markdown formats
- 📱 **Enhanced Recording UI** - Liquid Glass recording rows with playback controls
- ✨ **Liquid Glass UI** - iOS 26 Glass design language throughout the interface

### Architecture Layers
- **UI Layer**: SwiftUI with Liquid Glass design language, NavigationStack, TabView
- **Memory Agent Layer**: Privacy analyzer, RAG retrieval engine, agentic orchestrator
- **Service Layer**: Gemma3nCore, Apple Foundation Models, complete audio pipeline
- **Data Layer**: SwiftData persistence with comprehensive memory models
- **AI/ML Layer**: MLX Gemma3n (primary), Apple Foundation Models, WhisperKit transcription
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

**Phase 4 Complete**: Memory Agent System Implementation  
**Next**: Phase 5 - Advanced MLX Swift Integration and Production Optimization

### Recent Updates (2025-07-16)
- 🤖 **MLX Gemma3n Integration Complete** - Full MLX-based on-device AI provider implementation with Memory Agent integration
- 🧠 **Memory Agent System Complete** - Full AI-powered memory management implementation with real AI providers only
- 🔐 **Privacy-First Architecture** - MLX provider prioritized for on-device processing, automatic routing based on data sensitivity
- 🧮 **RAG Implementation** - Advanced retrieval-augmented generation with semantic ranking and scoring
- 🤖 **Agentic Framework** - Autonomous memory consolidation, entity extraction, and knowledge graph updates
- 🍎 **Apple Foundation Models** - Native integration with Apple's on-device AI capabilities as fallback provider
- 📊 **Memory Analytics Dashboard** - Real-time system health monitoring and memory insights
- ✅ **Mock Providers Removed** - All mock AI providers eliminated, system uses only real providers
- ✅ **Comprehensive Testing** - Complete test suite for all Memory Agent components
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
- **Memory Agent**: Privacy analyzer, RAG retrieval engine, agentic orchestrator
- **AI/ML**: MLX Gemma3n (primary), Apple Foundation Models (fallback), WhisperKit transcription
- **Backend Services**: Swift 6.0, Gemma3nCore AI engine
- **Database**: SwiftData with comprehensive memory models
- **Audio**: AVFoundation for recording and processing
- **Privacy**: On-device/cloud routing based on data sensitivity analysis
- **Architecture**: MVVM with memory agent layer and service pattern
- **Design System**: Apple's Liquid Glass, adaptive materials, refraction effects

## License

[License information here]

---

*For detailed technical documentation, see the [docs](docs/) directory.*