#!/bin/bash

echo "🧹 ProjectOne Dependency Cleanup Script"
echo "========================================"
echo ""

# Check current state
echo "📋 Current Dependency Status:"
echo ""

if [ -f "Package.swift" ]; then
    echo "✅ Package.swift exists"
else
    echo "❌ Package.swift not found"
fi

if [ -d "ProjectOne.xcodeproj" ]; then
    echo "✅ Xcode project exists"
else
    echo "❌ Xcode project not found"
fi

echo ""
echo "🔍 Analysis:"
echo "You have dependencies defined in both Package.swift and the Xcode project."
echo "This creates confusion and potential conflicts."
echo ""

echo "🎯 Recommended Cleanup Options:"
echo ""
echo "Option 1: Use Xcode Project Dependencies (Recommended)"
echo "  - Delete Package.swift"
echo "  - Manage all dependencies in Xcode"
echo "  - Better for iOS app development"
echo ""
echo "Option 2: Use Package.swift (Alternative)"
echo "  - Remove dependencies from Xcode project"
echo "  - Add Package.swift as dependency to Xcode project"
echo "  - Better for library development"
echo ""

echo "📝 Instructions for Option 1 (Recommended):"
echo "1. Delete Package.swift: rm Package.swift"
echo "2. Open ProjectOne.xcodeproj in Xcode"
echo "3. Go to File → Add Package Dependencies"
echo "4. Add these packages:"
echo "   - MLX Swift: https://github.com/ml-explore/mlx-swift.git (0.25.6)"
echo "   - WhisperKit: https://github.com/argmaxinc/WhisperKit.git (0.13.0)"
echo "   - Swift Collections: https://github.com/apple/swift-collections.git (1.2.0)"
echo "   - Sentry: https://github.com/getsentry/sentry-cocoa.git (8.53.2)"
echo "   - Swift Transformers: https://github.com/huggingface/swift-transformers.git (0.1.22)"
echo "   - Argument Parser: https://github.com/apple/swift-argument-parser.git (1.4.0)"
echo "   - Swift Numerics: https://github.com/apple/swift-numerics (1.0.3)"
echo "   - Swift Atomics: https://github.com/apple/swift-atomics.git (1.2.0)"
echo "   - GzipSwift: https://github.com/1024jp/GzipSwift (6.0.1)"
echo "   - Jinja: https://github.com/johnmai-dev/Jinja (1.2.1)"
echo ""
echo "5. Add source files to project"
echo "6. Build and test"
echo ""

echo "📝 Instructions for Option 2 (Alternative):"
echo "1. Keep Package.swift"
echo "2. Remove all Swift Package Dependencies from Xcode project"
echo "3. Add Package.swift as a dependency to Xcode project"
echo "4. Reference the library target from Package.swift"
echo ""

echo "🚨 Important Notes:"
echo "- Choose ONE approach (Xcode project OR Package.swift)"
echo "- Don't mix both approaches"
echo "- Clean build folder after changes: Product → Clean Build Folder"
echo "- Reset package caches if needed: File → Packages → Reset Package Caches"
echo ""

echo "✅ Ready to proceed with cleanup!"
