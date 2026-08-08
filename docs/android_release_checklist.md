# Android release checklist

This app does not contain a backend or deployment container. Android release
work is performed from the Flutter project root.

## Before building

- Confirm `com.calypsosystems.golog` is the permanent Play package name.
- Create a private upload keystore and an ignored `android/key.properties`.
- Supply `BODY_FLOW_AND_GO_FEEDBACK_URL` through the release environment if
  feedback is enabled. Do not put the endpoint or any gateway secret in Git.
- Supply `BODY_FLOW_AND_GO_APP_VERSION` for the release.
- Run `scripts\verify.ps1` or `bash scripts/verify.sh`.

## Build and inspect

```powershell
flutter build appbundle --release `
  --dart-define=BODY_FLOW_AND_GO_FEEDBACK_URL=$env:BODY_FLOW_AND_GO_FEEDBACK_URL `
  --dart-define=BODY_FLOW_AND_GO_APP_VERSION=1.0.0+1
```

Inspect the signed AAB, verify the application label and package ID, test the
one-tap workflow on a physical device, and validate the final artifact's
alignment and Play pre-launch report. Never upload a debug-signed or unsigned
bundle.

## Play Console

Complete the hosted privacy policy, Health Apps declaration, Data Safety form,
content rating, store assets, support contact, and applicable testing track
requirements before production rollout. See the [Data Safety worksheet](google_play_data_safety.md).
