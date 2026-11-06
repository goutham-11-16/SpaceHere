#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SpaceHERE Android Production Build Pipeline"
echo "=========================================="

echo "[1/2] Cleaning previous artifacts..."
flutter clean
flutter pub get

echo "[2/2] Building optimized release APK (arm64-v8a target)..."
flutter build apk --release --target-platform android-arm64 --split-per-abi

echo "=========================================="
echo "✅ Android APK ready in build/app/outputs/flutter-apk/"
echo "=========================================="
