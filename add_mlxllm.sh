#!/bin/bash

# Add MLXLLM package to Xcode project
echo "Adding mlx-swift-examples package dependency..."

# Use xed to open Xcode with the project
# Then manually add the package through Xcode UI

echo "Please add the following package in Xcode:"
echo "URL: https://github.com/ml-explore/mlx-swift-examples/"
echo "Branch: main"
echo "Product: MLXLLM"
echo ""
echo "1. Open File > Add Package Dependencies"
echo "2. Enter URL: https://github.com/ml-explore/mlx-swift-examples/"
echo "3. Select 'Branch: main'"
echo "4. Click 'Add Package'"
echo "5. Select 'MLXLLM' product"
echo "6. Add to ProjectOne target"

# Open Xcode
xed ProjectOne.xcodeproj