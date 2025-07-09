# ProjectOne

A sophisticated SwiftUI iOS/macOS personal AI knowledge system that combines audio recording, real-time transcription, knowledge graph construction, and intelligent memory management.

## Quick Start

### Prerequisites
- Xcode 16+ 
- iOS 18.4+ / macOS 15.4+
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
- 🕸️ **Knowledge Graph** - Interactive visualization of entities and relationships  
- 📊 **Memory Analytics** - Dashboard for memory usage and system insights
- 🧠 **AI Integration** - Placeholder engine with future MLX Swift support
- 💾 **Data Export** - Export knowledge graph data in multiple formats

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

### Recent Updates
- Memory analytics dashboard implementation
- Knowledge graph visualization system
- SwiftData persistence improvements
- MLX Swift integration planning

## Contributing

1. Check the [specifications](docs/specifications/) for planned features
2. Review [architecture docs](docs/architecture/) to understand the system
3. Follow the [implementation guides](docs/guides/) for best practices
4. Create issues for bugs or feature requests

## Technology Stack

- **Frontend**: SwiftUI, iOS 18.4+, macOS 15.4+
- **Backend Services**: Swift 6.0, Gemma3nCore AI engine
- **Database**: SwiftData with 11 data models
- **Audio**: AVFoundation for recording and processing
- **AI/ML**: PlaceholderEngine (current), MLX Swift (planned)
- **Architecture**: MVVM with service layer pattern

## License

[License information here]

---

*For detailed technical documentation, see the [docs](docs/) directory.*