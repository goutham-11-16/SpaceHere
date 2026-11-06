#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "SpaceHERE Automated Test & Analysis Suite"
echo "=========================================="

echo "[1/3] Checking code formatting..."
dart format --output=none --set-exit-if-changed lib test

echo "[2/3] Running static analysis..."
flutter analyze

echo "[3/3] Running automated tests..."
flutter test --coverage

echo "=========================================="
echo "✅ All checks and tests passed successfully!"
echo "=========================================="
