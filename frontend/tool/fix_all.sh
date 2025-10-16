#!/usr/bin/env bash
set -euo pipefail

echo "Running dart fix..."
dart fix --apply

echo "Formatting Dart files..."
dart format .

echo "Analyzing project..."
flutter analyze

