# Private iPhone testing with TestFlight

Foss Lift can build a signed distribution IPA on a GitHub-hosted Mac and optionally upload it to App Store Connect. You can do the setup from Linux or Windows. The owner's paid Apple Developer membership, signing credentials, and App Store Connect app record are required. The automatic **Build iOS** workflow still produces unsigned apps for compilation checks; use the manual **iOS TestFlight** workflow for distribution.

Use a private external TestFlight group for friends. They install TestFlight and accept email invitations. They do not need access to your App Store Connect team, paid developer memberships, registered device UDIDs, or a public App Store release.

## Project values to use

| Field | Value |
| --- | --- |
| Bundle ID | `com.fosslift.fosslift` |
| App display name | Foss Lift |
| Version | `0.5.10` |
| Suggested next signed build number | `31`, if not already uploaded |
| Minimum app deployment target | iOS 15 |
| Privacy policy | `https://foss-lift.pages.dev/privacy/` |
| Suggested App Store Connect SKU | `foss-lift-ios` |
| App login required | No |

Use the bundle ID above consistently in the Developer portal, Xcode, signing profile, and App Store Connect. The Android identifier contains an underscore and is different. Once the Apple app record is created and builds are uploaded, changing identity is more involved than changing the display name.

## Build and upload without a Mac

Complete portal steps 1–3 below, then use [Actions → iOS TestFlight](https://github.com/viktorChekhovoi/foss-lift/actions/workflows/testflight.yml). The hosted `macos-26` runner provides Xcode; you do not need to install macOS locally. Steps 4–6 are an alternative for someone using a Mac directly.

The repository needs these encrypted **Actions secrets** under **Settings → Secrets and variables → Actions**:

| Secret | Contents |
| --- | --- |
| `IOS_DISTRIBUTION_P12_BASE64` | Base64 of the Apple Distribution certificate and its private key in a password-protected `.p12`. |
| `IOS_P12_PASSWORD` | The `.p12` export password, which can differ from the original PEM private-key password. |
| `IOS_PROVISION_PROFILE_BASE64` | Base64 of the matching App Store Connect distribution `.mobileprovision` for `com.fosslift.fosslift`. |
| `ASC_API_PRIVATE_KEY` | The raw contents of the team API key's `.p8` file, including its PEM header and footer. |
| `ASC_API_KEY_ID` | The API key's Key ID. |
| `ASC_API_ISSUER_ID` | The API key's Issuer ID, a UUID from App Store Connect. |

The team and profile IDs are read from the provisioning profile. The API key authorizes upload; it does not replace the certificate/private key or provisioning profile. Create the team API key in **App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys** with **Developer** access. Download it once and keep a secure backup. Do not commit signing files or paste passwords and private keys into chat. See [Apple's API-key instructions](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) and [GitHub's signing guide](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).

After storing the secrets:

1. Open **iOS TestFlight → Run workflow** and select branch **main**.
2. Choose **check** once to test profile validation, temporary keychain import, app signing configuration, a signed fixture IPA, certificate mismatch rejection, and cleanup using generated dummy credentials. This operation does not read production signing secrets or upload an app.
3. Choose **build**, enter an unused positive build number such as `31`, and run it. The default operation builds without uploading. Download **signed-ipa-31** from the completed run's **Artifacts** section. A distribution IPA is intended for Apple upload; downloading it does not install it on an iPhone.
4. When ready to send the app to Apple, run the workflow with **upload** and the intended build number. This builds, verifies, keeps the IPA artifact, and uploads it. Use a new number for every accepted Apple upload. Build `31` can be uploaded if it was only built and never uploaded. Build `29` has already been accepted by Apple and must not be reused for an upload.
5. Continue with step 7 below after Apple processes the upload. The workflow does not submit beta review, create groups, invite testers, or publish an App Store release.

The same explicit operations work from the GitHub CLI:

```sh
gh workflow run testflight.yml --ref main -f operation=check
gh workflow run testflight.yml --ref main -f operation=build -f build_number=31
# Run this separately when ready to upload:
gh workflow run testflight.yml --ref main -f operation=upload -f build_number=31
```

Signing and upload jobs run only from `main` through manual dispatch. Pushes and pull requests do not invoke them. The signing preflight rejects missing credentials, a different app's profile, expired profiles, development/ad hoc/enterprise profiles, and a certificate that does not match the profile. Xcode then validates Apple signing while archiving and exporting. The workflow verifies the archive and exported IPA signatures, certificate, bundle ID, embedded profile, build number, and a minimum iOS version of 15.0 or later before saving the artifact. Missing, malformed, or older deployment targets fail verification. Temporary keychain, profiles, extracted signing files, and upload key are removed after the job; artifact retention is 14 days.

If **Prepare temporary signing credentials** fails with `p12_import`, re-enter the export password with `gh secret set IOS_P12_PASSWORD --repo viktorChekhovoi/foss-lift`. If a profile is expired or tied to an old certificate, renew the certificate/profile in the Developer portal and replace the corresponding secrets. A rejected upload's log explains whether the app record, API permissions, agreements, build number, or binary need attention. An upload accepted by the tool still needs Apple processing and any required beta review.

### Verified build

On 2026-10-28, source commit `0d9940f` passed [all eight macOS signing integration checks](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40777271616) and produced [signed build 0.5.10 (29)](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40777419623). The IPA uses `com.fosslift.fosslift`, Xcode 26.6, the iOS 26.5 SDK, and an iOS 14 deployment target. Archive and IPA signatures, certificate identity, embedded profile, bundle ID, build number, and cleanup passed. The App Store Connect key and existing app record were checked through read-only API calls. The run used **build**, so Apple upload, processing, beta review, and installation on a real iPhone remain to be done.

The downloaded `foss_lift.ipa` is 27,946,518 bytes; its SHA-256 is `dec788b408a703a643f86d7df3b5d05fc4970f96e9749697843db4e1b8506c99`. The run retains its **signed-ipa-29** artifact for 14 days; later builds have their own artifacts and hashes.

On 2026-10-29, [build 29 was uploaded successfully](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40882556308). Apple accepted it with warning 90068 about the iOS 15 minimum for uploads starting in April 2027. The owner confirmed there are no iOS 14 users and authorized raising the target now. New builds target iOS 15; the previous iOS 14 artifact and its review remain separate from this source change.

Source commit `00a5432` passed [all nine macOS signing integration checks](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40885311631) and produced [signed build 0.5.10 (30)](https://github.com/viktorChekhovoi/foss-lift/actions/runs/40885436076). The exported IPA declares `MinimumOSVersion = 15.0`; signature, certificate, profile, app identity, build number, deployment-target validation, and cleanup passed. This run used **build**, so uploading build 30 remains a separate manual action. Its IPA is 25,264,305 bytes with SHA-256 `41e0a19bee1bc824271d7b6104f0cebf1e0786fd80538a33b5671b3a09a86ab9`.

Source commit `66e62f1` produced [signed build 0.5.10 (31)](https://github.com/viktorChekhovoi/foss-lift/actions/runs/41161978207), including the beta feedback fixes: workout duration and rest refresh immediately on foreground return, held sets count elapsed time between callbacks, and the exercise editor clearly separates primary muscles from optional secondary muscles. The exported IPA retains `com.fosslift.fosslift` and iOS 15.0; signature, certificate, profile, identity, build number, and cleanup checks passed. Upload was skipped. Its IPA is 25,310,006 bytes with SHA-256 `aff8e6fe5a89040cf2400973e2dbedb533b54bd5c3904f83b3c509df6213e0ca`. Database schema 18, stored muscle classifications, and routine-code formats are unchanged.

The regression changes followed catalogue → failing integration tests → implementation. The local full Flutter suite passes 1,745 tests with 18 existing skips, and analysis is clean. The final [web workflow](https://github.com/viktorChekhovoi/foss-lift/actions/runs/41162416673) passes analysis, the full test suite, both browser renderers, local-storage persistence checks, and static deployment. The [unsigned iOS workflow](https://github.com/viktorChekhovoi/foss-lift/actions/runs/41162416667) also passes simulator and device compilation. The phone checks below remain necessary to verify real iOS suspension and interaction.

## 1. Activate the developer membership

Sign in at [Apple Developer](https://developer.apple.com/account/) using the Apple Account that will own the app. Enable two-factor authentication. If already enrolled, use the existing team. Otherwise [enroll in the Apple Developer Program](https://developer.apple.com/programs/enroll/) and finish identity verification, agreements, and payment. The US price is **99 USD per membership year**; local pricing can differ.

Individual enrollment uses your legal name as the App Store seller. Organization enrollment requires legal-entity verification and usually a D-U-N-S Number. Choose the account type that matches the actual owner. Wait until membership is active before trying distribution signing.

## 2. Register the App ID in the Developer portal

Open [Certificates, Identifiers & Profiles → Identifiers](https://developer.apple.com/account/resources/identifiers/list).

1. Press **+**, choose **App IDs**, and continue with the App type.
2. Enter **Foss Lift** as the description.
3. Select an **Explicit** Bundle ID and enter `com.fosslift.fosslift`.
4. Leave optional services such as CloudKit, HealthKit, Push Notifications, and Sign in with Apple off; this build does not use them. Camera permission is already declared in the app's `Info.plist`.
5. Continue, check the identifier, and register it. Reuse the existing entry if your team already registered this exact ID.

See [Apple's App ID instructions](https://developer.apple.com/help/account/identifiers/register-an-app-id/).

## 3. Create the App Store Connect record

Open [App Store Connect → Apps](https://appstoreconnect.apple.com/apps), press **+ → New App**, and fill these fields:

| Field | Enter |
| --- | --- |
| Platform | iOS |
| Name | Foss Lift, or an available store name if that name is taken |
| Primary language | English (US), unless another supported language is your intended store default |
| Bundle ID | Select `com.fosslift.fosslift` |
| SKU | `foss-lift-ios` — an internal identifier |
| User access | Your team's access policy; Full Access is straightforward for a solo owner |

Create the record. If the Bundle ID is missing, check that both portals are using the same developer team and that step 2 is complete. Complete any required account agreements shown by Apple. [Apple's new-app reference](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app).

## 4. Alternative: prepare a Mac for signing

Install a supported stable Xcode and its iOS platform tools. Launch it once to finish setup. Apple currently requires [Xcode 26 or later with an iOS 26 SDK or later](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) for uploads. The app's deployment target is iOS 15.0; this is the minimum OS supported by the app and is separate from the build SDK version.

Use Flutter **3.44.8**, matching CI, and install CocoaPods if `flutter doctor -v` reports it missing. From the repository root:

```sh
flutter doctor -v
dart tool/l10n.dart
flutter pub get
flutter gen-l10n
(cd ios && pod install)
open ios/Runner.xcworkspace
```

Open the **workspace**, which includes the CocoaPods dependencies. In **Xcode → Settings → Accounts**, sign in with the owner/team Apple Account.

## 5. Set the signing team in Xcode

Select the blue **Runner** project, then the **Runner** app target, then **Signing & Capabilities**.

- Enable **Automatically manage signing**.
- Select the **paid developer team**, rather than a free Personal Team.
- Confirm the Bundle Identifier is `com.fosslift.fosslift`.
- Let Xcode create or select the certificates and profiles. Resolve signing errors shown here before archiving.

Automatic signing on this Mac avoids manually exporting a certificate and uploading it to CI. The repository deliberately contains no signing credentials.

## 6. Build and upload a signed archive

From the repository root, after saving the signing settings:

```sh
flutter build ipa --release --build-number=31
```

Use a build number not previously uploaded for this version. The command generates an archive under `build/ios/archive/` and an IPA under `build/ios/ipa/`. The version remains `0.5.10`; the build number distinguishes uploads. [Flutter's distribution instructions](https://docs.flutter.dev/deployment/ios).

Upload by either of these routes:

- Open `build/ios/archive/Runner.xcarchive` in Xcode Organizer, choose **Validate App**, then **Distribute App**, and use the App Store Connect/TestFlight distribution option.
- Open Apple's **Transporter** Mac app and upload the signed IPA from `build/ios/ipa/`.

For a GUI archive instead, choose the **Runner** scheme and a generic iOS device destination, then **Product → Archive**. Selecting a simulator destination prevents a distribution archive.

**Use the normal App Store Connect distribution route. Do not choose “TestFlight Internal Only”: those uploads cannot be added to external groups.** Uploading an eligible build does not itself publish a public App Store version.

## 7. Check processing, privacy, and compliance

Return to **App Store Connect → Foss Lift → TestFlight → iOS**. Wait for the build to finish processing. Check the version and build number. Follow any processing-failure email or status detail before retrying; an already accepted build number cannot be uploaded again.

Set the privacy-policy URL to `https://foss-lift.pages.dev/privacy/` where Apple requests it. The current iOS app stores training data on the device, has no backend, and embeds no analytics or advertising SDK. **Data Not Collected** describes that native build's app-data handling; revisit the answers if the actual distributed binary or its services change. [Apple's privacy-question reference](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

Complete the current age-rating questionnaire from the app's actual content if prompted. For encryption, `ITSAppUsesNonExemptEncryption` is already `false`: this build does not implement non-exempt encryption. If Apple still requests export-compliance information, answer for the actual binary rather than changing the flag just to dismiss a prompt.

## 8. Create an internal group and test the build yourself

Under **TestFlight → Internal Testing**, press **+**, name the group **Internal QA**, add the processed build, and add your own eligible App Store Connect user as a tester. Install TestFlight on your iPhone and accept the invitation.

Apple's [current external-testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) require an internal group to exist before creating an external group. Internal testing supports up to 100 App Store Connect users and does not require the external beta review. Use it for your first device check.

## 9. Enter the beta test information

Open **TestFlight → Additional → Test Information**. Enter the beta description and feedback address, then supply the beta review contact details where prompted. [Apple's Test Information reference](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

| Field | Suggested content |
| --- | --- |
| Beta App Description | Offline workout tracker with routines, set logging, progression, training history, QR sharing, and local backups. |
| Feedback Email | A monitored inbox; the app currently lists `birdie.software.studios@gmail.com`. |
| Review contact | Your real name, reachable phone number, and email. |
| Sign-in required / demo account | No sign-in is required. Leave demo credentials empty. |
| Privacy policy, if requested here | `https://foss-lift.pages.dev/privacy/` |

Suggested review notes:

> Foss Lift works offline and does not require an account. On the first-run tour, choose Not now. Open Ready-made routines, choose GZCLP, and add it. From Today, start a workout, log sets, and finish it to see History. Camera permission is used only when scanning a QR code or recording a silent set video. Android notification controls and background rest alerts are not offered in this iOS build.

Supply the contact fields yourself; the reviewer may need to reach you. The beta description and review information can differ from the eventual public store listing.

## 10. Create the private external group

In **TestFlight → External Testing**, create a group called **Private beta**. Add the processed build and enter **What to Test**. Submit it for **TestFlight App Review** when prompted. The first external build requires review; later builds may also require it.

Keep **Create Public Link** unused. After approval, add testers by email under the group's **Testers → +** control. Enable automatic notification when adding the build, or use **Notify Testers / Start Testing** after approval. Testers install Apple's TestFlight app and accept their invitation. See [Apple's external tester instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

Suggested What to Test:

> Add a ready-made routine, edit a workout, log and finish sets, and check History. Resume an unfinished workout after closing and reopening the app. Test kg/lb, themes, and larger text. Scan a routine QR code, record and play a silent set video, then export and restore a local file backup. Report device model, iOS version, and steps for any failure.

Each uploaded beta build expires after 90 days. Upload the next build with a new number, such as `31`, and add it to the group. Testers do not need new app records for updates. The service allows up to 10,000 external testers; a small private group is sufficient. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Device checks before inviting friends

Verify that a workout starts, survives backgrounding/reopening, logs sets, and finishes correctly. Test QR scanning, silent video capture/playback, and file backup/restore on a real iPhone. Check the smallest available phone at a large text size. New builds require iOS 15 or later, and the installed TestFlight client must also support the tester's OS.

- Start a workout and a rest, lock the phone for a minute, then reopen the app. Duration should immediately include the minute away; rest should show its actual remainder or end once if its deadline passed. Repeat with a timed hold, then stop it before another second ticks: the logged hold should include time spent away.
- Open **Library → +**. **Primary muscles** is shown and **Secondary muscles** starts collapsed. Expand the secondary picker, choose a group, collapse it, and save. Reopen the custom exercise with its pencil: the saved secondary choices should be visible and selected.

Android foreground notification controls, background rest alerts, and scheduled reminders are hidden on iOS. The CI builds prove compilation; these device checks verify the platform behavior.
