# Body Flow & Go repository guidelines

## Scope

This repository contains the Flutter mobile app. It intentionally does not
contain the Go API, Docker deployment, web frontend, or Slack webhook secret
from the `aip_food_lookup` workspace.

## Project structure

- `lib/` contains the feature-based Flutter application.
- `lib/core/database/` contains SQLite opening and ordered migrations.
- `lib/features/*/domain/` contains typed models, rules, calculations, and
  repository contracts.
- `lib/features/*/data/` contains local-storage and platform adapters.
- `test/` contains repository, calculation, export, feedback, and widget tests.
- `android/` and `ios/` contain platform projects.
- `.vscode/` contains safe launch profiles and task definitions.

## Required verification

Run from the repository root:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1`
on Windows or `bash scripts/verify.sh` on a Unix-like system to perform the
same checks. If Gitleaks is installed, the
scripts scan repository files while skipping oversized generated artifacts.

Review dependency updates with
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dependency-audit.ps1`
or `bash scripts/dependency-audit.sh`; Dependabot also watches pub packages and
GitHub Actions.

## Configuration and secrets

- Never commit `android/key.properties`, keystores, `.env` files, or private
  Dart-define files.
- Never put Slack webhook URLs, API keys, passwords, tokens, or health records
  in source, tests, tracked VS Code files, or issue reports.
- Use `.vscode/body-flow-and-go.local.env.example` as the shape for an ignored
  local define file.

## Data and privacy boundaries

Health records remain local. Do not add analytics, advertising, crash-reporting
payloads, remote sync, or automatic health-data uploads without updating the
privacy documentation, tests, and Play Data Safety review.

## Change discipline

Keep the one-tap logging path fast and accessible. Prefer small feature-scoped
changes, typed null-safe Dart, repository interfaces in UI code, and migration
tests for schema changes. Do not add backend or deployment files to this
mobile-only repository.
