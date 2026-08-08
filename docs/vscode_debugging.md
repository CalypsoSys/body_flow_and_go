# VS Code debugging

Body Flow & Go includes checked-in VS Code launch profiles modeled on the
`aip_food_lookup` Flutter workflow. Body Flow & Go is entirely local, so these
profiles do not start a backend. The standard profiles do not load an
environment file; an optional profile can load private feedback configuration.

## Prerequisites

1. Open the repository root in VS Code, not a parent folder.
2. Install the recommended Dart and Flutter extensions when VS Code prompts.
3. Confirm that Flutter is installed at `C:\dev\flutter`. If it is elsewhere,
   update `.vscode/settings.json` and the command paths in
   `.vscode/tasks.json`.
4. Connect an Android or iOS target and confirm that Flutter can see it:

   ```console
   flutter devices
   ```

Body Flow & Go currently contains Android and iOS platform projects. Do not
select a Windows or browser target unless those platforms are added to the
project.

## Start a debug session

Open **Run and Debug** (`Ctrl+Shift+D`), select a profile, and press `F5`:

- **Body Flow & Go: Debug (selected device)** uses the Android or iOS device
  selected in the VS Code status bar.
- **Body Flow & Go: Debug + sample data (selected device)** also passes
  `GOLOG_SEED_DATA=true`.
- **Body Flow & Go: Debug (Galaxy S23)** targets the same physical S23 serial
  used by the `aip_food_lookup` workspace: `RFCWC06KQGF`.
- **Body Flow & Go: Debug + sample data (Galaxy S23)** combines that fixed
  device with development seeding.
- **Body Flow & Go: Debug + local feedback config** loads the ignored
  `.vscode/body-flow-and-go.local.env` file. Use this only after copying
  `.vscode/body-flow-and-go.local.env.example` and replacing its placeholder.

Every profile runs `flutter pub get` first, launches `lib/main.dart` from the
repository root, and supports normal Flutter breakpoints, stepping, hot reload,
and hot restart.

If the S23 serial changes, use a selected-device profile or update `deviceId`
in `.vscode/launch.json` after checking `flutter devices`.

## Private local defines

Copy the example file without adding it to Git:

```powershell
Copy-Item .vscode\body-flow-and-go.local.env.example .vscode\body-flow-and-go.local.env
```

Edit the ignored file with the HTTPS feedback endpoint and a development app
version. Do not put Slack webhooks, gateway credentials, or health data in it.

## Sample-data behavior

The sample-data profiles seed synthetic events only when the event table is
empty. They never replace or mix into an existing database. To see a fresh
seed, delete all event data in Body Flow & Go Settings or clear/uninstall the
debug app, then launch the sample-data profile again.

## Useful tasks

Run **Tasks: Run Task** from the Command Palette for:

- `flutter: pub get`
- `flutter: analyze`
- `flutter: test`
- `flutter: test one-tap workflow`
- `flutter: build debug apk`

`Ctrl+Shift+B` runs the default debug APK build task. The default VS Code test
task runs the complete Flutter test suite.

## Troubleshooting

- If VS Code reports no device, enable USB debugging, accept the device trust
  prompt, and rerun `flutter devices`.
- If the fixed S23 profile says the device is unavailable, select the generic
  profile and choose a connected Android device from the status bar.
- If imports remain unresolved after checkout, run the `flutter: pub get` task
  or reload the VS Code window.
- Run `flutter doctor` in a terminal to diagnose Android SDK, Xcode, or device
  setup problems.
