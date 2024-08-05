#!/bin/bash
set -e

# Build Rust libraries
cargo +1.69.0 build --target=aarch64-linux-android
cargo +1.69.0 build --target=aarch64-linux-android --release

# Get Flutter dependencies
flutter pub get

# Build the APK
flutter build apk --release

echo "Build completed. APK should be at /root/repo/build/app/outputs/flutter-apk/app-release.apk"