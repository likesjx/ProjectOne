#!/bin/bash

echo "💥 Nuclear Xcode Cleanup Script"
echo "================================"
echo ""

echo "😤 I understand your frustration with Xcode!"
echo "This script will completely clean everything and give you a fresh start."
echo ""

echo "🚨 WARNING: This will delete all Xcode caches and derived data"
echo "This is safe but will make Xcode rebuild everything from scratch."
echo ""

read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled. No changes made."
    exit 1
fi

echo ""
echo "🧹 Cleaning Xcode caches..."

# Clean derived data
echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectOne-*
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean build artifacts
echo "🗑️  Removing build artifacts..."
rm -rf .build/
rm -rf build/

# Clean package caches
echo "🗑️  Cleaning package caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm/
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/

# Clean Xcode caches
echo "🗑️  Cleaning Xcode caches..."
rm -rf ~/Library/Developer/Xcode/UserData/IDEPackageSupport/
rm -rf ~/Library/Developer/Xcode/UserData/IDEWorkspaceChecks.plist

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Close Xcode completely"
echo "2. Reopen ProjectOne.xcodeproj"
echo "3. Remove swift-argument-parser from Package Dependencies"
echo "4. Build the project (⌘+B)"
echo ""
echo "💪 You got this! Xcode won't beat you today!"
