# AI Providers Directory

Comprehensive AI model interfaces organized by type and capability with settings-based configuration and revolutionary direct audio understanding.

## Directory Structure

```
ProjectOne/Agents/AI/
├── README.md                           # This file
├── BaseAIProvider.swift               # Base class for all AI providers
├── AIModelProvider.swift              # Core AI model provider interface
├── MemoryAgentModelProvider.swift     # Memory agent model routing
├── WorkingMLXProvider.swift           # Working MLX implementation
├── MLXLLMProvider.swift               # MLX Language Model provider
├── MLXVLMProvider.swift               # MLX Vision-Language Model provider
├── Foundation/
│   └── AppleFoundationModelsProvider.swift  # Apple Intelligence Foundation Models
├── Transcription/
│   ├── SpeechTranscriptionProtocol.swift    # Core transcription interface
│   ├── AppleSpeechTranscriber.swift         # Apple Speech Recognition
│   ├── WhisperKitTranscriber.swift          # WhisperKit CoreML implementation
│   ├── SpeechEngineFactory.swift            # Transcription orchestration
│   └── AudioProcessor.swift                 # Audio preprocessing utilities
└── External/
    ├── ExternalAIProvider.swift             # Base for external API providers
    ├── ExternalProviderFactory.swift        # Factory for managing external providers
    ├── OpenAIProvider.swift                 # OpenAI API integration
    ├── OpenRouterProvider.swift             # OpenRouter API integration
    ├── OllamaProvider.swift                 # Local Ollama integration
    ├── MLXProvider.swift                    # Real MLX Swift integration
    └── MLXAudioProvider.swift              # 🆕 Direct audio understanding VLM

Settings/
├── AIProviderSettings.swift            # Secure settings management
└── Views/
    └── AIProviderSettingsView.swift    # Settings UI interface

Features/Memory/Agents/
└── AudioMemoryAgent.swift              # 🆕 Audio-aware memory agent
```

## Revolutionary Audio Understanding Architecture

### 🎧 **MLX Audio VLM: Beyond Transcription**

**Traditional Approach:** Audio → Transcription → Text Processing → Understanding
**Our Approach:** Audio → **Direct VLM Understanding** → Rich Context

#### **Key Innovation:**
- **MLXAudioProvider** uses Gemma3n VLM to understand audio **meaning and context** directly
- **AudioMemoryAgent** creates memories with full audio understanding
- **No information loss** through transcription bottlenecks

#### **Rich Audio Context Captured:**
```swift
AudioUnderstandingResult {
    content: "Full semantic understanding"
    audioMetadata: AudioMetadata
    emotionalTone: .confident/.frustrated/.excited
    speakerCharacteristics: SpeakerCharacteristics
    environmentalContext: EnvironmentalContext
    processingTime: TimeInterval
}
```

## Provider Categories

### Foundation Models (On-Device, Privacy-First)
- **AppleFoundationModelsProvider**: Apple Intelligence Foundation Models (iOS 26.0+)
  - Uses `@Generable` for guided generation
  - Supports tool calling and structured output
  - Highest privacy with on-device processing

### Revolutionary Audio Providers
- **🆕 MLXAudioProvider**: Direct audio understanding with VLM
  - Bypasses transcription for richer context
  - Emotional tone and speaker analysis
  - Environmental context recognition
  - Quality-based processing decisions

### Traditional Transcription Providers (Fallback)
Real AI-powered speech-to-text interfaces:
- **AppleSpeechTranscriber**: Apple Speech Recognition framework
- **WhisperKitTranscriber**: WhisperKit CoreML models
- **SpeechEngineFactory**: Intelligent provider selection and fallbacks
- **AudioProcessor**: Audio preprocessing and optimization

### External API Providers
Unified interface for external AI services with settings-based configuration:
- **OpenAIProvider**: OpenAI API (GPT-4, GPT-4o, GPT-3.5-Turbo)
- **OpenRouterProvider**: Multiple providers via OpenRouter API
- **OllamaProvider**: Local models via Ollama server
- **MLXProvider**: Real MLX Swift models on Apple Silicon

### Local MLX Providers
Apple Silicon optimized on-device AI:
- **WorkingMLXProvider**: Production MLX implementation
- **MLXLLMProvider**: Language models via MLX Swift
- **MLXVLMProvider**: Vision-language models via MLX Swift

## Settings-Based Configuration System

### 🔐 **Secure Configuration Management**
All provider settings are now managed through a comprehensive settings system:

- **API Keys**: Stored securely in Keychain (never plain text)
- **Privacy Modes**: Maximum (on-device only), Balanced, Performance
- **Provider Preferences**: User-configurable through Settings UI
- **Auto-Configuration**: Providers initialize from settings automatically

### **Settings Architecture:**
```swift
AIProviderSettings {
    // Privacy & Control
    privacyMode: PrivacyMode
    preferredProvider: String
    enabledProviders: Set<String>
    
    // API Provider Settings (keys in Keychain)
    openAI: {model, organization, baseURL}
    openRouter: {model, routePreference, appInfo}
    anthropic: {model, baseURL}
    
    // Local Provider Settings
    ollama: {baseURL, model, autoDownload}
    mlx: {modelPath, modelName, quantization}
    
    // 🆕 Audio VLM Settings
    mlxAudio: {
        modelPath, modelName,
        qualityThreshold, maxDuration,
        enableDirectProcessing
    }
}
```

## Usage Examples

### Settings-Based Configuration

```swift
// User configures providers in Settings UI
let settings = AIProviderSettings()

// Factory auto-configures from settings
let factory = ExternalProviderFactory(settings: settings)
await factory.configureFromSettings()

// All providers ready based on user preferences!
let provider = factory.getBestProviderFor(.coding)
```

### Direct Audio Understanding

```swift
// Revolutionary audio processing
let audioConfig = MLXAudioProvider.AudioConfiguration(
    modelPath: settings.mlxAudioModelPath,
    audioSampleRate: 16000,
    enablePreprocessing: true
)

let audioProvider = MLXAudioProvider(audioConfiguration: audioConfig)
let audioAgent = AudioMemoryAgent(
    mlxAudioProvider: audioProvider,
    fallbackMemoryAgent: memoryAgent
)

// Direct audio → understanding (no transcription!)
let result = try await audioAgent.processAudioMemory(
    audioData, 
    context: "meeting discussion"
)

// Rich context preserved
print("Content: \(result.understandingResult.content)")
print("Emotion: \(result.analysisResult?.emotionalTone)")
print("Speaker: \(result.analysisResult?.speakerCharacteristics)")
print("Environment: \(result.analysisResult?.environmentalContext)")
```

### Privacy-First Provider Selection

```swift
// Automatic selection based on privacy mode
let memoryAgent = MemoryAgent(
    modelContext: modelContext,
    knowledgeGraphService: knowledgeGraphService
)

// Respects user's privacy preferences
let response = try await memoryAgent.processQuery(
    "What did we discuss in yesterday's meeting?"
)
// Uses: Apple Foundation Models → MLX Audio → Ollama → External APIs
```

## Architecture Benefits

### 🎯 **User Experience Revolution**
1. **Settings-Based**: No hardcoded API keys, all user-configurable
2. **Privacy-First**: Clear on-device vs. cloud processing indicators
3. **Intelligent Fallbacks**: Automatic degradation when providers unavailable
4. **Direct Audio Understanding**: Preserves emotional and contextual richness

### 🛡️ **Security & Privacy**
- **Keychain Storage**: API keys never stored in plain text
- **Privacy Modes**: User controls data sharing preferences
- **On-Device Priority**: Local providers preferred for sensitive data
- **Transparent Processing**: Users know which provider is being used

### 🏗️ **Developer Benefits**
- **Unified Interface**: All providers implement BaseAIProvider
- **Settings Integration**: Automatic configuration from user preferences
- **Rich Audio Context**: Access to emotional and speaker characteristics
- **Intelligent Selection**: Quality-based audio processing decisions

## Provider Selection Strategy

The system automatically selects the best available provider based on:

1. **Privacy Mode Settings** (user-configured)
2. **Data Sensitivity** (personal content uses on-device processing)
3. **Audio Quality** (high-quality audio → direct VLM, low-quality → transcription)
4. **Device capabilities** (Apple Silicon, available memory)
5. **Network connectivity** (local vs. remote)
6. **User preferences** (preferred provider setting)

### **Selection Hierarchy:**

#### **Maximum Privacy Mode:**
1. **Apple Foundation Models** (iOS 26.0+)
2. **MLX Audio VLM** (direct audio understanding)
3. **MLX Local Models** (text processing)
4. **Ollama Local** (if configured)

#### **Balanced Mode:**
1. **Apple Foundation Models** (for sensitive data)
2. **MLX Audio VLM** (high-quality audio)
3. **OpenRouter/OpenAI** (with user consent)
4. **Transcription fallback** (low-quality audio)

#### **Performance Mode:**
1. **Best available external API** (OpenAI, OpenRouter)
2. **MLX Audio VLM** (for audio understanding)
3. **Apple Foundation Models** (fallback)

## Configuration Management

### **Environment Variables (Optional)**
```bash
# API Keys (also configurable in Settings UI)
OPENAI_API_KEY=your_openai_key
OPENROUTER_API_KEY=your_openrouter_key
ANTHROPIC_API_KEY=your_anthropic_key

# Local Services  
OLLAMA_BASE_URL=http://localhost:11434
MLX_MODELS_DIR=~/mlx-models
MLX_AUDIO_MODELS_DIR=~/mlx-models/audio
```

### **Settings UI Features**
- **Provider Status Overview**: See what's configured and available
- **Secure API Key Input**: Dedicated sheets with setup instructions
- **Privacy Mode Selection**: Visual indicators for data processing location
- **Audio Quality Controls**: Sliders for quality threshold and max duration
- **Real-time Configuration**: Changes apply immediately
- **Export/Import**: Backup and restore configurations (keys excluded)

## Adding New Providers

1. **Extend ExternalAIProvider** for API-based services
2. **Add configuration to AIProviderSettings**
3. **Update settings UI in AIProviderSettingsView**
4. **Add to ExternalProviderFactory configuration**

Example:
```swift
// 1. Create Provider
public class CustomProvider: ExternalAIProvider {
    public init(configuration: Configuration) {
        super.init(configuration: configuration, providerType: .custom(name: "Custom", identifier: "custom"))
    }
}

// 2. Add Settings
@Published public var customAPIKey: String = ""
@Published public var customModel: String = "custom-model"

// 3. Add UI Configuration
APIProviderRow(
    provider: .custom,
    settings: settings,
    onConfigureTapped: { configureCustomProvider() }
)

// 4. Add Factory Support
if let config = configurations.custom {
    await configureCustom(config)
}
```

## Performance Monitoring & Analytics

All providers include built-in metrics accessible through settings:
- **Response Time Tracking**: Real-time performance monitoring
- **Token Usage Monitoring**: Cost tracking for API providers  
- **Quality Scoring**: Audio processing quality metrics
- **Error Rate Analysis**: Reliability monitoring
- **Memory Usage Optimization**: Device resource management
- **Privacy Compliance**: Data processing location tracking

## Migration from Hardcoded Configuration

Existing installations automatically migrate to settings-based configuration:
1. **Settings Detection**: Check for existing hardcoded API keys
2. **Migration Prompt**: Offer to import keys to secure storage
3. **Default Configuration**: Reasonable defaults for new installations
4. **Fallback Support**: Graceful degradation if settings unavailable

The new architecture provides a **revolutionary approach to audio understanding** while maintaining **user control and privacy** through comprehensive settings management.