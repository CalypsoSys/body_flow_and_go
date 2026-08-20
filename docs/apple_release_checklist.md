# Apple release checklist

This checklist describes the supported no-Mac release path for Body Flow & Go:
GitHub -> Codemagic -> App Store Connect -> TestFlight.

The repository contains an iOS target for iPhone and iPad. The current bundle
identifier is `com.calypsosystems.golog`, and the minimum iOS deployment target
is 13.0.

## Apple Developer account

Use the existing Calypso Systems LLC Apple Developer organization. Do not create
a separate personal Apple Developer membership if the app should be sold under
Calypso Systems LLC.

The organization account requires:

- An Apple Account with two-factor authentication.
- Apple Developer Program enrollment ($99/year, subject to Apple’s current
  regional pricing).
- The legal organization name, D-U-N-S number, company website, and authority
  to bind the organization to Apple’s agreements.

If the organization is already enrolled, the Account Holder should add team
members through App Store Connect rather than having them enroll separately.

## Register the app with Apple

1. In Apple Developer, open **Certificates, Identifiers & Profiles >
   Identifiers**.
2. Create an **App ID** of type **App**, using an explicit Bundle ID:

   ```text
   Description: Body Flow and Go
   Bundle ID: com.calypsosystems.golog
   ```

3. In App Store Connect, open **My Apps > + > New App**.
4. Create an **iOS** app with:

   ```text
   Name: Body Flow and Go
   Primary language: English (U.S.)
   Bundle ID: com.calypsosystems.golog
   SKU: body-flow-and-go-ios
   ```

The App Store display name may use `and` instead of `&`; this does not affect
the Flutter project name or Bundle ID.

The Account Holder must accept current Apple agreements before an app record
can be created.

## Codemagic setup

1. Sign in to Codemagic with the GitHub account that can access
   `CalypsoSys/body_flow_and_go`.
2. Install the Codemagic GitHub integration for only this repository.
3. Open the repository and configure the default workflow.
4. Select **iOS** and **Release**. Leave Android unchecked when building iOS
   only.
5. Leave Shorebird disabled; it is not used by this app.
6. Choose the macOS M2 build machine.

### App Store Connect API key

Create a dedicated key in **App Store Connect > Users and Access >
Integrations > App Store Connect API**.

Use:

```text
Name: Codemagic BFG Distribution
Access: App Manager
```

Download the `.p8` private key immediately; Apple only allows the private key
to be downloaded once. Add the key to Codemagic’s Apple Developer Portal
integration using the Issuer ID, Key ID, and `.p8` file.

Never commit the `.p8` file, Issuer ID, Key ID, certificates, or provisioning
profiles to Git.

### iOS code signing

In the workflow’s **iOS code signing** section:

- Select **Automatic**.
- Select the Codemagic App Store Connect API key.
- Select provisioning profile type **App Store**.
- Use Bundle ID `com.calypsosystems.golog`.

Do not select **Development** for a TestFlight/App Store build. Development
profiles require registered test devices. App Store profiles use a distribution
certificate and do not require device registration.

### Publishing

For an IPA-only build, leave App Store Connect publishing disabled and download
the IPA from the build artifacts.

For automatic TestFlight delivery:

- Enable **App Store Connect publishing**.
- Select the App Manager API key.
- Leave **Publish even if tests fail** unchecked.
- Leave **Submit to TestFlight beta review** unchecked for internal testing.
- Leave **Submit to App Store review** unchecked.
- Optionally distribute to an existing internal beta group.

## Build and upload

Start a build from the `main` branch. A successful release build should produce
an IPA such as:

```text
Body_Flow__Go.ipa
```

An artifact named `Runner.app.zip` alone usually indicates a debug build or an
unsigned/non-distribution workflow. The release configuration should produce an
`.ipa`.

The version comes from `pubspec.yaml`:

```text
version: 1.0.2+8
```

The marketing version is `1.0.2`; the Apple build number is `8`. Every later
upload must use a higher build number.

## TestFlight internal testing

1. Wait for Apple to finish processing the uploaded build.
2. Under the build’s **Missing Compliance** status, complete the export
   compliance questions. This app does not implement custom encryption
   algorithms; answer according to the current Apple questionnaire.
3. Create an **Internal Testing** group, for example `Internal Testers`.
4. Add App Store Connect users to the group and assign the processed build.
5. Testers install Apple’s TestFlight app and accept the invitation using the
   same Apple Account email that was invited.

Internal testing does not require external beta review. External testers do
require the Beta App Information and Beta App Review Information, including a
feedback email and contact details.

## Troubleshooting

### Codemagic requests a Shorebird token

Select **Disabled** for Shorebird. This app does not use Shorebird.

### Development profile cannot be created

Change the profile type from **Development** to **App Store**. A development
profile requires at least one registered iOS device.

### Apple returns HTTP 403 when creating a distribution certificate

Use a dedicated App Store Connect API key with **App Manager** access. Replace
the older Codemagic API key in Codemagic’s integration after generating the new
key. Do not revoke the old key until the replacement has been saved and tested.

### Build uploads but does not appear in the tester group

Wait for Apple processing to finish, clear Missing Compliance, then add the
processed build to the group’s **Builds** tab. A tester group can exist with
zero builds assigned.

### Android shows a Google Play error

This is not an iOS signing issue. First uninstall any sideloaded or cloned
Android installation and reinstall the app from its Google Play testing link.

## Final release checklist

- [ ] Apple Developer organization membership is active.
- [ ] Bundle ID is registered as `com.calypsosystems.golog`.
- [ ] App Store Connect app record exists for **Body Flow and Go**.
- [ ] Codemagic uses an App Manager API key.
- [ ] iOS signing is Automatic with an App Store profile.
- [ ] Build mode is Release.
- [ ] The build produces an `.ipa`.
- [ ] Apple processing and export compliance are complete.
- [ ] Internal testers have the build assigned.
- [ ] App metadata, privacy policy, screenshots, age rating, and review notes
      are complete before App Store submission.
