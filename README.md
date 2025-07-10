# ProjectOne

A sophisticated SwiftUI iOS/macOS personal AI knowledge system that combines audio recording, real-time transcription, knowledge graph construction, and intelligent memory management.

## Quick Start

### Prerequisites
- Xcode 16+ (Beta)
- iOS 19.0+ (Beta) / macOS 15.4+
- Swift 6.0+

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
- 🎙️ **Audio Recording & Transcription** - Real-time voice-to-text with entity extraction
- 🧠 **Memory System** - STM, LTM, Working Memory, and Episodic Memory architecture
- 🕸️ **Knowledge Graph** - Interactive visualization of entities and relationships  
- 📊 **Memory Analytics** - Dashboard for memory usage and system insights
- 🔧 **Transcription Correction** - User correction system for improving accuracy
- 💾 **Data Export/Import** - Export/import data in JSON, CSV, and Markdown formats
- ⚙️ **AI Integration** - Placeholder engine with planned MLX Swift support

### Architecture Layers
- **UI Layer**: SwiftUI views and interactive components
- **Service Layer**: Gemma3nCore, audio processing, transcription
- **Data Layer**: SwiftData persistence with 11 data models
- **AI/ML Layer**: PlaceholderEngine, future MLX integration

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

**Phase 3 Complete**: Knowledge Graph Visualization  
**Next**: Phase 4 - Advanced AI Integration with MLX Swift

### Recent Updates (2025-07-10)
- ✅ **Legacy Code Integration** - Successfully merged old ProjectOne components
- ✅ **Memory System Complete** - STM, LTM, Working Memory, and Episodic Memory
- ✅ **Knowledge Graph Models** - Entity, Relationship, TemporalEvent, ConceptNode
- ✅ **Audio Pipeline** - AudioRecorder with transcription capabilities
- ✅ **Analytics Dashboard** - Memory analytics and performance tracking
- ✅ **Data Export/Import** - Comprehensive data management system
- ✅ **GitHub Integration** - Issues, labels, and project tracking setup
- ✅ **iOS 19.0 Beta** - Updated for latest iOS beta targeting

## Contributing

1. Check [GitHub Issues](https://github.com/likesjx/ProjectOne/issues) for current bugs and features
2. Review [specifications](docs/specifications/) for planned features
3. Review [architecture docs](docs/architecture/) to understand the system
4. Follow the [implementation guides](docs/guides/) for best practices
5. Check [DEFECTS.md](docs/DEFECTS.md) for technical debt and bug tracking

## Technology Stack

- **Frontend**: SwiftUI, iOS 19.0+ (Beta), macOS 15.4+
- **Backend Services**: Swift 6.0, Gemma3nCore AI engine
- **Database**: SwiftData with 11 data models
- **Audio**: AVFoundation for recording and processing
- **AI/ML**: PlaceholderEngine (current), MLX Swift (planned)
- **Architecture**: MVVM with service layer pattern

## License

[License information here]

---

*For detailed technical documentation, see the [docs](docs/) directory.*