Param(
  [switch]$AnalyzeOnly
)

Write-Host "Running dart fix..." -ForegroundColor Cyan
dart fix --apply | Out-Host

Write-Host "Formatting Dart files..." -ForegroundColor Cyan
dart format . | Out-Host

if (-not $AnalyzeOnly) {
  Write-Host "Analyzing project..." -ForegroundColor Cyan
  flutter analyze | Out-Host
}

