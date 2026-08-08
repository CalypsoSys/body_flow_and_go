$ErrorActionPreference = 'Stop'

Write-Host 'Checking Dart and Flutter dependency status'
flutter pub outdated
