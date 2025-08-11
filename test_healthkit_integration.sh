#!/bin/bash

# HealthKit Integration Testing Script
# This script launches the app in iOS Simulator and provides testing instructions

set -e

echo "🏃‍♂️ HealthKit Integration Testing Script"
echo "======================================="

# Check if Xcode command line tools are available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: xcodebuild not found. Please install Xcode command line tools."
    exit 1
fi

# Check if iOS Simulator is available
if ! command -v xcrun &> /dev/null; then
    echo "❌ Error: xcrun not found. Please install Xcode."
    exit 1
fi

echo "📱 Starting iOS Simulator..."

# Boot iPhone 16 simulator (or create it if it doesn't exist)
DEVICE_NAME="iPhone 16"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-0"

# Check if the device exists, if not create it
DEVICE_ID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "📱 Creating iPhone 16 simulator..."
    DEVICE_ID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")
fi

echo "🚀 Booting simulator (Device ID: $DEVICE_ID)..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

# Wait for simulator to boot
echo "⏳ Waiting for simulator to boot..."
xcrun simctl bootstatus "$DEVICE_ID" -b

echo "🔧 Building and installing app..."

# Build and install the app
xcodebuild -project ProjectOne.xcodeproj \
    -scheme ProjectOne \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath build \
    install

# Get the app bundle path
APP_BUNDLE_PATH="$HOME/Library/Developer/Xcode/DerivedData/ProjectOne-*/Build/Products/Debug-iphonesimulator/ProjectOne.app"
APP_BUNDLE_PATH=$(eval echo $APP_BUNDLE_PATH)

if [ ! -d "$APP_BUNDLE_PATH" ]; then
    echo "❌ Error: App bundle not found at $APP_BUNDLE_PATH"
    exit 1
fi

echo "📲 Installing app on simulator..."
xcrun simctl install "$DEVICE_ID" "$APP_BUNDLE_PATH"

echo "🚀 Launching ProjectOne app..."
xcrun simctl launch "$DEVICE_ID" com.jaredlikes.ProjectOne

echo ""
echo "✅ App launched successfully!"
echo ""
echo "🧪 TESTING INSTRUCTIONS:"
echo "========================"
echo ""
echo "1. 📱 HEALTH DASHBOARD ACCESS:"
echo "   → Look for 'Health Dashboard' in the app navigation"
echo "   → Tap to open the Health Dashboard"
echo ""
echo "2. 🔐 HEALTH PERMISSIONS:"
echo "   → You should see a 'Health Integration' card"
echo "   → Tap 'Connect Health Data' button"
echo "   → This will show iOS's HealthKit permission dialog"
echo "   → Grant permissions for the health data types you want to test"
echo ""
echo "3. 📊 HEALTH DATA SIMULATION (since simulator has no real health data):"
echo "   → Open the Health app in simulator"
echo "   → Go to Health Data > Health Records"
echo "   → Add sample data for:"
echo "     • Heart Rate (Health Data > Vitals > Heart Rate)"
echo "     • Steps (Health Data > Activity > Steps)"
echo "     • Sleep (Health Data > Sleep)"
echo ""
echo "4. 🔄 REFRESH HEALTH DATA:"
echo "   → Return to ProjectOne app"
echo "   → Pull down to refresh the Health Dashboard"
echo "   → You should see your sample health data displayed"
echo ""
echo "5. 🎤 VOICE MEMO CORRELATION TESTING:"
echo "   → Create a voice memo in the app"
echo "   → Look for the 'Health Correlation Available' section"
echo "   → Tap 'Analyze Health Data' to see correlations"
echo ""
echo "6. 🧠 KNOWLEDGE GRAPH INTEGRATION:"
echo "   → Navigate to Knowledge Graph view"
echo "   → Look for health-related entities and relationships"
echo "   → Health metrics should appear as nodes connected to dates and activities"
echo ""
echo "🔍 WHAT TO LOOK FOR:"
echo "==================="
echo "✅ Health permission prompts appear"
echo "✅ Health metrics display in dashboard"
echo "✅ Health trends and insights show up"
echo "✅ Voice memo health correlation works"
echo "✅ Knowledge graph shows health entities"
echo "✅ No crashes or errors in console"
echo ""
echo "🐛 TROUBLESHOOTING:"
echo "==================="
echo "• If no health data shows: Add sample data in iOS Health app first"
echo "• If permissions fail: Check Settings > Privacy & Security > Health"
echo "• If app crashes: Check Xcode console for error messages"
echo "• If knowledge graph is empty: Create voice memos first, then analyze health data"
echo ""
echo "📱 Simulator is running. Test the HealthKit integration!"
echo "   Press Ctrl+C to stop this script when done testing."

# Keep script running so user can see instructions
echo ""
echo "⏳ Monitoring app... (Press Ctrl+C to exit)"
trap 'echo "🛑 Testing session ended."; exit 0' INT
while true; do
    sleep 10
done