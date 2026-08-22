# Google Play Data Safety worksheet

This is an engineering worksheet for preparing the Google Play Data Safety
form. It is not legal advice, a submitted Play Console declaration, or a hosted
user-facing privacy policy. Recheck every answer against the deployed backend,
hosting and proxy logs, Slack configuration, third-party contracts, and the
exact release artifact before submission.

Google defines collection broadly as transmitting user data off the device,
including data processed ephemerally. It also makes the developer responsible
for data handled by libraries and SDKs. Use the current official guidance when
completing the form:

- [Provide information for Google Play's Data Safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311)

## Implemented data flows

### Health records

Urination and bowel-event records, optional record details, notes, settings,
history, and trend calculations are stored and processed locally unless the
user explicitly exports and shares them. The feedback feature does not read
them, and the app does not automatically attach a record, note, trend, database,
or export file to a feedback request.

Google's guidance excludes data that is accessed and processed only on the
device from the Data Safety definition of collected data. On that basis, the
local health records are not a Play Data Safety collection by the current app.
This conclusion must be revisited if sync, remote backup, telemetry, crash
reporting that includes record content, or any other off-device health-data flow
is added.

### Optional feedback

The user must open **Settings > Send feedback**, enter a message, check an
acknowledgement, and tap **Send feedback** before a request is made. The rest of
the app remains usable without submitting feedback.

The HTTPS JSON request contains:

- `email`: the optional reply email entered by the user; it may be empty;
- `subject`: the entered subject, or `Body Flow & Go feedback` when blank;
- `message`: the required free-form feedback message;
- `name`: the fixed value `Anonymous Body Flow & Go user`; and
- `source`: a platform-derived client label, `body-flow-and-go-android` on
  Android or `body-flow-and-go-ios` on iOS.

It also sends `X-AIP-Client` and `X-AIP-App-Version` headers. As with a normal
HTTPS request, the receiving endpoint and its hosting, proxy, CDN, WAF, or
logging services can observe basic request metadata such as source IP address,
timestamps, and HTTP headers. The repository does not establish which of that
metadata is retained, enriched, or forwarded, so the production operator must
verify it.

The request goes to a Calypso Systems endpoint and may be routed through Slack
for review and response. The backend can use a server-side fallback when Slack
is unavailable. The repository contains the app client, not the backend, its
fallback handling, or Slack retention configuration. Users are instructed not
to include health information in feedback.

### Exports

CSV and JSON exports are generated only at the user's request, written to the
app's temporary directory, and passed to the operating system share sheet. The
app does not upload them to its feedback endpoint. A destination selected by the
user controls any subsequent transfer and storage outside the app sandbox.

Before generating an export, the app removes older files in its temporary
directory that exactly match its CSV/JSON export naming pattern. The new export
can remain cached after the share sheet returns, but it is removed before the
next export or when the user runs **Delete all data**. It may also disappear
when the operating system purges the temporary directory or app storage is
cleared or uninstalled. None of these cleanup paths can remove a copy already
sent to another app or saved destination.

## Conservative Data Safety mapping

This is a starting point, not a substitute for reviewing the live processing
chain.

| Play data type | Starting declaration | Optional or required | Likely purpose | Notes to verify |
| --- | --- | --- | --- | --- |
| **Personal info > Email address** | Collected when supplied | Optional | App functionality; developer communications when a reply is requested | The feedback feature works with a blank email. Determine whether possible routing through Slack is sharing under Google's definition or qualifies for a service-provider exception. |
| **App activity > Other user-generated content** | Collected | Optional | App functionality; developer communications | Covers the feedback subject and free-form message. A message is required only if the user chooses to submit feedback; feedback itself is optional. Determine the sharing treatment if Slack receives it. |
| **Device or other IDs** | Conservatively consider collected when applicable | Optional because it accompanies only an optional submission | Fraud prevention, security, and compliance; possibly app functionality | The app does not deliberately send an advertising ID, installation ID, or hardware ID. Confirm whether the endpoint or its providers retain or derive an identifier from IP addresses, request headers, or other network metadata. Include ephemeral processing in the form response as Google directs. |
| **Location > Approximate location** | Conditional, not established by app code | Optional if it occurs only during feedback | Fraud prevention, security, and compliance | Declare it if the backend or a provider uses an IP address to infer location. Merely knowing that an HTTPS connection has an IP address is not enough to settle how the operator uses it. |
| **Health and fitness > Health info** | Not collected by the current app flow | Not applicable | Not applicable | Health records remain on device and no record data is attached to feedback. The form tells users not to include health information. Reassess if the operator begins soliciting, categorizing, retaining, or using health details submitted in free text. |

The fixed anonymous `name` value is not the user's name. The platform-derived
source label and app-version header are not, by themselves, unique device
identifiers. Do not select unrelated categories merely because these values are
present, but do account for identifiers or derived data actually processed by
the production network stack.

## Collection and sharing decisions

- Answer **Yes** to whether the app collects user data: optional feedback is
  transmitted off device to the feedback endpoint.
- Mark the email address and other user-generated content as **optional**. All
  users can use the tracking features without providing either data type.
- Determine the **shared** answer from the real organizational and contractual
  roles. Calypso Systems is first party only if it is the organization presented
  to users as responsible for the app. If feedback reaches Slack, Slack is a
  third party, but the transfer may qualify for Google's service-provider
  exception only when the actual relationship and processing meet Google's
  requirements. If that cannot be established, the conservative answer is to
  disclose sharing.
- Google also lists certain specific user-initiated transfers or transfers made
  after a qualifying prominent disclosure and consent as sharing exceptions.
  The feedback screen is explicit, but do not rely on this exception without
  confirming that the production flow meets every requirement. The same
  analysis applies when a user deliberately sends an export to a destination
  through the system share sheet.
- Use **App functionality** for receiving and handling feedback. Use
  **Developer communications** for an optional email retained and used to reply.
  Use **Fraud prevention, security, and compliance** only for request metadata
  actually processed for those purposes.
- The app enforces an absolute HTTPS URL and disables redirects for its
  app-to-endpoint request. A candidate answer is that app-originated collection
  is encrypted in transit, but verify the exact artifact has no other data flow
  and separately verify secure downstream backend-to-Slack handling.
- Do not claim a feedback retention period, deletion-request process, or
  service-provider exception until the production operator has documented and
  implemented it. Deleting local event data does not delete a previously sent
  feedback message from the backend or Slack.

## Release configuration

The feedback client uses compile-time Dart defines:

| Dart define | Default | Sent or used as |
| --- | --- | --- |
| `BODY_FLOW_AND_GO_FEEDBACK_URL` | Not set; required for feedback | Destination URL injected by the build environment; must be absolute HTTPS |
| `BODY_FLOW_AND_GO_APP_VERSION` | `1.0.3+12` | `X-AIP-App-Version` header |

Production builds derive the source/client label as
`body-flow-and-go-${Platform.operatingSystem}`. This produces
`body-flow-and-go-android` on Android and `body-flow-and-go-ios` on iOS, and is
sent both in the JSON `source` field and `X-AIP-Client` header. Pass the actual
release version through `BODY_FLOW_AND_GO_APP_VERSION` in the release pipeline.

Android's main manifest includes `android.permission.INTERNET` for this flow.
iOS does not require an equivalent permission prompt. The client rejects a
non-HTTPS or relative feedback URL, does not follow redirects, and uses an
eight-second timeout.

## Pre-submission checklist

- Build and inspect the exact Android App Bundle intended for Play.
- Re-audit all production dependencies and SDKs for additional collection or
  sharing; the current source has no advertising, analytics, or crash-reporting
  SDK.
- Confirm which request fields and headers reach Slack and whether any are
  transformed or enriched.
- Document retention, access controls, deletion handling, security-log use, and
  backup behavior for the endpoint, infrastructure providers, and Slack.
- Determine whether IP addresses are retained, used as identifiers, or used to
  infer approximate location.
- Confirm whether Slack and hosting providers meet Google's service-provider
  exception; disclose sharing if they do not or if the status is uncertain.
- Keep the in-app feedback disclosure, Play declaration, store listing, and
  user-facing privacy policy consistent with the deployed behavior.
- Enter the hosted privacy-policy URL in Play Console before release:
  <https://calypsosystemsllc.com/bodyflowandgo/privacy-policy>
