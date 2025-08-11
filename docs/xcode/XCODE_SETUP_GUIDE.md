# Xcode Project Setup Guide

## 🎯 Quick Start

1. **Open the project in Xcode:**
   ```bash
   open ProjectOne.xcodeproj
   ```

2. **Add Swift Package Dependencies:**
   - In Xcode, go to **File** → **Add Package Dependencies**
   - Add the following packages:

   ### Required Dependencies
   - **MLX Swift**: `https://github.com/ml-explore/mlx-swift.git` (Version: 0.25.6)
   - **WhisperKit**: `https://github.com/argmaxinc/WhisperKit.git` (Version: 0.13.0)
   - **Swift Collections**: `https://github.com/apple/swift-collections.git` (Version: 1.2.0)
   - **Sentry**: `https://github.com/getsentry/sentry-cocoa.git` (Version: 8.53.2)
   - **Swift Transformers**: `https://github.com/huggingface/swift-transformers.git` (Version: 0.1.22)
   - **Argument Parser**: `https://github.com/apple/swift-argument-parser.git` (Version: 1.4.0)
   - **Swift Numerics**: `https://github.com/apple/swift-numerics` (Version: 1.0.3)
   - **Swift Atomics**: `https://github.com/apple/swift-atomics.git` (Version: 1.2.0)
   - **GzipSwift**: `https://github.com/1024jp/GzipSwift` (Version: 6.0.1)
   - **Jinja**: `https://github.com/johnmai-dev/Jinja` (Version: 1.2.1)

3. **Configure Target:**
   - Select the **ProjectOne** target
   - Set **Deployment Target** to iOS 26.0+ or macOS 26.0+
   - Ensure **Swift Language Version** is set to Swift 6.0

4. **Build and Run:**
   - Select your target device (iOS Simulator or Mac)
   - Press `⌘+R` to build and run

## 🔧 Manual Configuration Steps

### Step 1: Add Package Dependencies
1. In Xcode, select your project in the navigator
2. Select the **ProjectOne** target
3. Go to **Package Dependencies** tab
4. Click **+** to add each package listed above

### Step 2: Configure Build Settings
1. Select the **ProjectOne** target
2. Go to **Build Settings** tab
3. Search for and configure:
   - **iOS Deployment Target**: 26.0
   - **Swift Language Version**: Swift 6.0
   - **Enable Bitcode**: No

### Step 3: Configure Info.plist
The Info.plist is already configured with:
- Microphone usage description
- Speech recognition usage description
- Supported orientations
- App transport security settings

### Step 4: Configure Entitlements
The ProjectOne.entitlements file is already configured with:
- App sandbox enabled
- Network client access

## 🚨 Troubleshooting

### Common Issues:
1. **Build Errors**: Make sure all package dependencies are added
2. **MLX Swift Issues**: Requires Apple Silicon hardware (M1/M2/M3)
3. **iOS 26+ Required**: Make sure you're using Xcode 26+ Beta
4. **Swift 6.0**: Ensure Swift Language Version is set to 6.0

### If you encounter issues:
1. Clean build folder: **Product** → **Clean Build Folder**
2. Reset package caches: **File** → **Packages** → **Reset Package Caches**
3. Delete derived data: **Window** → **Organizer** → **Projects** → **Delete**

## 📱 Running the App

### iOS Simulator:
1. Select an iOS 26+ simulator (iPhone 16 Pro or newer)
2. Press `⌘+R` to build and run
3. The app will initialize with the unified system manager

### macOS:
1. Select **My Mac** as the target
2. Press `⌘+R` to build and run
3. Note: MLX Swift requires Apple Silicon Mac

## 🎉 Success!

Once the app is running, you should see:
- System initialization screen
- Main interface with Liquid Glass design
- AI provider testing capabilities
- Memory management system
- Knowledge graph visualization

For more information, see the [README.md](README.md) file.
