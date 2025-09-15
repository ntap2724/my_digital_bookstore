param()
$ErrorActionPreference = 'Stop'

Write-Host 'Running import sorter...' -ForegroundColor Cyan
dart run tool/sort_imports.dart

Write-Host 'Formatting code...' -ForegroundColor Cyan
dart format --set-exit-if-changed .

Write-Host 'Checking for print(...) usages...' -ForegroundColor Cyan
dart run tool/no_print_check.dart

Write-Host 'Analyzing project...' -ForegroundColor Cyan
flutter analyze

Write-Host 'Pre-commit checks passed.' -ForegroundColor Green
