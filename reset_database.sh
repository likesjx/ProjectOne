#!/bin/bash

# Reset Database Script for ProjectOne
# This script clears all SwiftData/CoreData databases for fresh development

echo "🔄 Resetting ProjectOne Database..."

# Method 1: Reset iOS Simulator (clears all app data)
echo "📱 Shutting down iOS Simulators..."
xcrun simctl shutdown all

echo "🗑️  Erasing all iOS Simulator data..."
xcrun simctl erase all

echo "✅ iOS Simulator reset complete"

# Method 2: Clear specific app data (alternative approach)
# Uncomment these lines if you want to try clearing specific app directories instead

# echo "🗂️  Clearing app-specific data directories..."
# 
# # Find and remove app data for ProjectOne
# APP_SUPPORT_DIRS=$(find ~/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Library/Application\ Support/ -name "default.store*" 2>/dev/null)
# if [ ! -z "$APP_SUPPORT_DIRS" ]; then
#     echo "Found app data directories:"
#     echo "$APP_SUPPORT_DIRS"
#     echo "$APP_SUPPORT_DIRS" | xargs rm -rf
#     echo "✅ App data cleared"
# else
#     echo "ℹ️  No app data found to clear"
# fi

# Method 3: Clear Xcode Derived Data (helps with build issues)
echo "🧹 Clearing Xcode Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "✅ Derived Data cleared"

# Optional: Clean and rebuild
echo "🔨 Cleaning Xcode build..."
cd "$(dirname "$0")"
if [ -f "ProjectOne.xcodeproj/project.pbxproj" ] || [ -f "ProjectOne.xcworkspace" ]; then
    xcodebuild clean -quiet 2>/dev/null || echo "⚠️  Xcode clean failed (project may not be in expected location)"
else
    echo "ℹ️  Run this script from your project directory for automatic clean"
fi

echo ""
echo "🎉 Database reset complete!"
echo ""
echo "Next steps:"
echo "1. Build and run your app"
echo "2. SwiftData will create a fresh database"
echo "3. Default prompt templates will be recreated"
echo ""
echo "If you still have issues, you can also:"
echo "- Reset iOS Simulator manually: Device → Erase All Content and Settings"
echo "- Clear app data: Long press app → Delete App in simulator"
echo ""