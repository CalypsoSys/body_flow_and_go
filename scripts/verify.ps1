$ErrorActionPreference = 'Stop'

Write-Host 'Checking Dart formatting'
dart format --output=none --set-exit-if-changed lib test

Write-Host 'Analyzing Flutter project'
flutter analyze

Write-Host 'Running Flutter tests'
flutter test

if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
    Write-Host 'Scanning files with Gitleaks'
    gitleaks dir --redact --no-banner --max-target-megabytes 10 .
} else {
    Write-Warning 'Gitleaks is not installed; skipping local secret scan.'
}

Write-Host 'Verification passed.'
