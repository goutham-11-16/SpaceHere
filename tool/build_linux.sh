#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SpaceHERE Linux Desktop Build Pipeline"
echo "=========================================="

echo "[1/2] Verifying Linux toolchain..."
if ! command -v clang >/dev/null 2>&1 || ! command -v ninja >/dev/null 2>&1; then
    echo "⚠️ Warning: clang or ninja is not installed."
    echo "Please run: sudo apt update && sudo apt install -y clang ninja-build libgtk-3-dev pkg-config"
    exit 1
fi

echo "[2/2] Building release bundle for Linux..."
flutter build linux --release

echo "=========================================="
echo "✅ Linux build ready in build/linux/x64/release/bundle/"
echo "=========================================="
