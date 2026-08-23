# Android release checklist

This app does not contain a backend or deployment container. Android release
work is performed from the Flutter project root.

## Before building

- Confirm `com.calypsosystems.golog` is the permanent Play package name.
- Create a private upload keystore and an ignored `android/key.properties`.
- Confirm the production build uses the dedicated public endpoint
  `https://api.calypsosystemsllc.com/v1/feedback/body-flow-and-go`; never put a
  Slack webhook or gateway secret in Git or the app.
- Supply `BODY_FLOW_AND_GO_APP_VERSION` for the release.
- Run `scripts\verify.ps1` or `bash scripts/verify.sh`.

## Build and inspect

```powershell
flutter build appbundle --release `
  --dart-define=BODY_FLOW_AND_GO_APP_VERSION=1.0.3+13
```

The production endpoint is compiled into the app.

Inspect the signed AAB, verify the application label and package ID, test the
one-tap workflow on a physical device, and validate the final artifact's
alignment and Play pre-launch report. Never upload a debug-signed or unsigned
bundle.

## Play Console

Complete the hosted privacy policy at
<https://calypsosystemsllc.com/bodyflowandgo/privacy-policy>, the Health Apps declaration, Data Safety form,
content rating, store assets, support contact, and applicable testing track
requirements before production rollout. See the [Data Safety worksheet](google_play_data_safety.md).
