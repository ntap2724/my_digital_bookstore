#!/usr/bin/env bash
set -euo pipefail

echo "Running import sorter..."
dart run tool/sort_imports.dart

echo "Formatting code..."
dart format --set-exit-if-changed .

echo "Checking for print(...) usages..."
dart run tool/no_print_check.dart

echo "Analyzing project..."
flutter analyze

echo "Pre-commit checks passed."
