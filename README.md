# Body Flow & Go

Body Flow & Go is a calm, private Flutter app for recording urination and bowel
movements with one tap. Events are timestamped immediately, stored in SQLite
on the device, and can be undone for a few seconds. Health records stay local
unless the user explicitly exports and shares them. The app has no account,
advertising, or analytics. A separate, optional feedback form uses the network
only after the user reviews its disclosure and explicitly submits it.

> Body Flow & Go is a personal tracking tool, not a medical device or
> diagnostic tool.
> It is not a substitute for advice from a qualified healthcare professional.

## Features

- One-tap urination and bowel movement logging from split **Awake** and
  **Woke from sleep** controls, with visual and optional haptic confirmation
- Five-second confirmation with exact-entry undo and an optional **Add details**
  action
- Today counts, time since the last event of each type, and recent entries
- Manual entry for an earlier time, plus edit and delete support
- Date-grouped history with type and inclusive date-range filters
- 7-, 30-, 90-day, and custom trends
- Daily totals and averages, hour-of-day charts, weekly/monthly charts,
  nocturia counts, and urination interval statistics
- Sleep context for either event type, plus configurable optional fields for
  amount, urgency, leakage, Bristol type, and notes
- System, light, and dark themes
- Deterministic CSV and JSON exports through the native share sheet
- Optional feedback form with an explicit transmission disclosure and
  acknowledgement
- Local delete-all control and plain-language privacy information

## Requirements

- Flutter 3.44 or another current stable Flutter release compatible with Dart
  3.12
- Android Studio with an Android SDK and emulator/device, or Xcode with an iOS
  simulator/device
- iOS builds require macOS and Xcode

Check the installed toolchain:

```console
flutter doctor
```

## Setup and run

From the repository root:

```console
flutter pub get
flutter run
```

Choose a target explicitly when needed:

```console
flutter devices
flutter run -d <device-id>
```

## VS Code debugging

The checked-in `.vscode` configuration provides selected-device and Galaxy S23
debug profiles, optional development seed data, and common Flutter test,
analysis, and build tasks. See
[docs/vscode_debugging.md](docs/vscode_debugging.md) for the F5 workflow and
troubleshooting guidance.

Repository tooling includes `AGENTS.md`, `SECURITY.md`, an MIT `LICENSE`,
optional Gitleaks pre-commit scanning, Dependabot configuration, and GitHub
Actions for Flutter quality, dependency review, and secret scanning. Backend,
Docker, and web-frontend workflows from `aip_food_lookup` are intentionally not
included.

### Development sample data

Sample events are opt-in and intended only for screenshots and development.
They are relative to the current date and are inserted only when the event
table is empty:

```console
flutter run --dart-define=GOLOG_SEED_DATA=true
```

Normal runs never seed data. Seeded rows have a `developmentSeed` marker in the
future-compatible extra-details JSON column.

### Optional feedback configuration

**Settings > Send feedback** opens an optional form. Nothing is transmitted
until the user enters a message, checks the acknowledgement, and taps **Send
feedback**. The request sends the user-entered reply email (which may be blank),
subject, and message over HTTPS to a Calypso Systems endpoint, where it is
processed and may be routed through Slack. The request also carries a
platform-derived client/source label and the configured app version. Making the
request exposes normal network metadata such as the source IP address,
timestamp, and request headers to the endpoint and its infrastructure, which
may process or retain it for delivery and security. No event, note, trend,
database, or export file is attached automatically. Users are told not to put
health information in the message.

The production app uses the dedicated Body Flow & Go API route below. The
public endpoint is safe to include in the client; Slack webhook credentials
remain server-side in the API service. A build-time override remains available
for local development or a controlled test environment.

| Dart define | Default | Purpose |
| --- | --- | --- |
| `BODY_FLOW_AND_GO_FEEDBACK_URL` | `https://api.calypsosystemsllc.com/v1/feedback/body-flow-and-go` | Optional absolute HTTPS override; non-HTTPS or relative values are rejected |
| `BODY_FLOW_AND_GO_APP_VERSION` | `1.0.2+7` | Version label shown in About and sent in the `X-AIP-App-Version` request header |

For example:

```console
flutter run --dart-define=BODY_FLOW_AND_GO_FEEDBACK_URL=https://api.calypsosystemsllc.com/v1/feedback/body-flow-and-go --dart-define=BODY_FLOW_AND_GO_APP_VERSION=1.0.2+7
```

The endpoint is public routing configuration rather than a secret, so the
production default is compiled into the app. Set the version define from the
actual release version in automated release builds rather than relying
indefinitely on the source default. The client does not follow HTTP redirects
and uses an eight-second network timeout.

For local development, copy `.vscode/body-flow-and-go.local.env.example` to
`.vscode/body-flow-and-go.local.env` and use the matching VS Code profile. The
copied file is ignored by Git.

## Verification

```console
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Or run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1`
on Windows or `bash scripts/verify.sh` on a Unix-like system. The scripts also
run Gitleaks when it is installed.

Review available dependency updates with
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dependency-audit.ps1`
or `bash scripts/dependency-audit.sh`.

The test suite covers schema creation and ordered migrations, model validation,
repository CRUD and filters, seed behavior, settings persistence, trend date
boundaries and calculations, CSV/JSON encoding, export sharing, one-tap
logging, undo, optional-detail navigation, export-cache cleanup, feedback
validation and submission, acknowledgement gating, and large text scaling.

## Release builds

Android:

```console
flutter build appbundle --release
```

For Play Store signing, create an untracked `android/key.properties` containing
the usual `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` values.
Release tasks fail with a clear error when that file is absent, preventing an
accidental debug-signed Play artifact. Debug builds remain available without
release credentials. Never commit the keystore or its passwords.

iOS, on macOS:

```console
flutter build ipa --release
```

Select the appropriate Apple development team and signing identity for the
`com.calypsosystems.golog` Runner target in Xcode.

For the no-Mac Codemagic and TestFlight workflow, see
[docs/apple_release_checklist.md](docs/apple_release_checklist.md).

## Architecture

Body Flow & Go follows the lightweight feature-based structure used by the
`aip_food_lookup` Flutter template, with local-first health-record storage,
Riverpod state management, and one narrowly scoped optional feedback client:

```text
lib/
  app/                         app shell, themes, Riverpod composition
  core/
    database/                  SQLite opening and ordered migrations
    time/                      recorded calendar-date value type
  features/
    events/
      domain/                  typed models, validation, repository contract
      data/                    SQLite repository and development seeder
      presentation/            manual/add/edit/delete form
    home/presentation/         one-tap workflow and today snapshot
    history/presentation/      grouping and filters
    trends/
      domain/                  pure calculations and summary models
      presentation/            range selection, cards, and charts
    settings/
      domain/                  immutable preferences and repository contract
      data/                    SharedPreferences adapter
      presentation/            controls, privacy, and feedback entry point
    export/
      domain/                  deterministic CSV/JSON encoder
      data/                    temporary-file and native share adapters
    feedback/
      domain/                  validated draft and repository contract
      data/                    HTTPS transport and compile-time configuration
      presentation/            disclosure, acknowledgement, and form
  shared/presentation/         reusable event formatting and tiles
```

The UI imports repository interfaces rather than SQLite. Riverpod composes the
production implementations and exposes overridable clocks, repositories,
settings, exports, feedback, and haptics for deterministic widget tests.
Successful mutations bump a small revision provider, causing
home/history/trends queries to refresh without coupling screens to the
database.

The internal Dart package, bundle identifiers, seed-data define, preferences
key, and database filename retain the original `golog` slug so renaming the
visible product does not break imports, upgrades, or existing local data.

### Time handling

Each event stores the exact UTC instant, the UTC offset at which it was
recorded, and its recorded local calendar date. History grouping and hour bins
therefore remain attached to the original wall time after travel or daylight
saving changes. Elapsed-time and interval calculations use UTC instants.

Preset ranges are inclusive calendar ranges: "Last 7 days" means today plus
the previous six local calendar dates, rather than a rolling 168-hour window.

The home-screen sleep context is always chosen explicitly. **Awake** means the
event happened while the user was already awake; **Woke from sleep** means the
event caused the user to wake from nighttime sleep; and **Woke from nap** is
available for urination events that followed a nap. Body Flow & Go never
guesses this from the clock time. Nap wakeups contribute to total urination,
but not nocturia. Nocturia counts nighttime wakeups between 8 PM and the first
next-day urination marked **Awake**. Trend event averages skip calendar days
with no logged events, since those days are unobserved rather than confirmed
zero-event days; a logged day with no nocturia still counts as a zero.

## Database schema and migrations

The database is `golog.sqlite`. Migration code lives in
`lib/core/database/database_migrations.dart`; opening and dependency injection
live in `lib/core/database/app_database.dart`.

Schema version 1 creates `events` with:

| Column | SQLite type | Purpose |
| --- | --- | --- |
| `id` | INTEGER PRIMARY KEY | Stable event identifier |
| `event_type` | TEXT NOT NULL | Future-extensible type discriminator |
| `occurred_at_utc` | INTEGER NOT NULL | Exact instant in UTC microseconds |
| `utc_offset_minutes` | INTEGER NOT NULL | Offset when the event was recorded |
| `local_date` | TEXT NOT NULL | Recorded `yyyy-MM-dd` day |
| `amount` | TEXT | Optional small/medium/large value |
| `urgency` | TEXT | Optional urgency value |
| `leakage` | TEXT | Optional urination leakage value |
| `bristol_type` | INTEGER | Optional bowel type from 1 through 7 |
| `notes` | TEXT | Optional user note |
| `created_at_utc` | INTEGER NOT NULL | Creation audit timestamp |
| `updated_at_utc` | INTEGER NOT NULL | Last-update audit timestamp |

Indexes support descending time queries, event-type/time queries, and local
date/type filters. Version 2 adds nullable `extra_details_json TEXT`, allowing
later optional metadata without rebuilding the core table. Version 3 adds
nullable `woke_from_sleep INTEGER` with a null/0/1 constraint. A null value
means the user did not record an answer, while `0` and `1` preserve explicit
No and Yes responses for either event type. Fresh installs run each migration
in order; upgrades never assume that version 1 is the final schema. Migration
tests verify fresh, v1, and v2 paths and data preservation.

## Data export

CSV files use RFC 4180 escaping and this exact header order:

```text
Date,Time,Event type,Woke from sleep,Amount,Urgency,Leakage,Bristol type,Notes
```

Recorded times include seconds and the stored UTC offset. JSON exports contain
a versioned envelope and every current event field, including audit timestamps
and extra details. Rows are sorted deterministically from oldest to newest.

Exports are first written to the app's temporary directory and then handed to
the operating system share sheet. Body Flow & Go does not upload them. Once the
user shares or saves a file elsewhere, that copy is outside Body Flow & Go's
private sandbox. Before creating a new export, the app removes its older cached
CSV and JSON exports. The newly generated temporary copy can remain until the
next export, **Delete all data**, an operating-system cache purge, or app-storage
clearing or uninstall. These cleanup paths cannot remove a copy already sent to
another app or saved destination.

## Privacy and security scope

- Events are stored in the operating system's private app sandbox.
- There is no account, advertising SDK, or analytics SDK. Health records are
  not sent to the feedback service or any other server by the app.
- Android requests the `INTERNET` permission for the optional feedback form.
- Feedback is sent only after an explicit acknowledgement and submit action.
  It contains the user-entered reply email, subject, and message plus app and
  network request metadata. Calypso Systems receives it, and it may be routed
  through Slack. No stored record or export is attached automatically.
- Body Flow & Go does not currently add application-level database encryption.
  Device passcode and platform storage protections remain important.
- Deleting all data clears event records while keeping non-health preferences.
  It also removes Body Flow & Go export files still in the app's temporary
  directory, but cannot remove shared destination copies or submitted feedback.
- Android cloud/full backup is disabled for event privacy. iOS uninstall and
  device-backup behavior remains controlled by iOS and the user's device
  settings.

Before a Google Play release, review the conservative
[Data Safety worksheet](docs/google_play_data_safety.md) against the deployed
feedback backend, hosting logs, Slack configuration, third-party terms, and the
exact release artifact. The hosted privacy policy is available at
<https://calypsosystemsllc.com/bodyflowandgo/privacy-policy>.

## Sensible future enhancements

- Optional encrypted database and app lock
- Home-screen widgets, shortcuts, or carefully configurable reminders
- Import and encrypted backup/restore
- Clinician-friendly PDF summaries selected by the user
- Additional symptom, fluid-intake, medication, or custom event fields
- Localization and expanded accessibility audits
- User-controlled end-to-end encrypted sync, remaining off by default

These are intentionally outside version 1 so the primary logging path stays
fast, reliable, and private.
