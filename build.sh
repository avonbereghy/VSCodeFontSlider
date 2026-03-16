#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Generate Xcode project
xcodegen generate

# Build release
xcodebuild -project FontDial.xcodeproj -scheme FontDial -configuration Release -derivedDataPath build

# Deploy to ~/Applications
rm -rf ~/Applications/FontDial.app
cp -R build/Build/Products/Release/FontDial.app ~/Applications/FontDial.app

echo "Deployed to ~/Applications/FontDial.app"
open ~/Applications/FontDial.app
