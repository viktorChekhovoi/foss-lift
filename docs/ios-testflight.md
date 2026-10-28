# Private iPhone testing with TestFlight

Foss Lift's iOS project and unsigned CI builds are ready. The remaining distribution steps need the owner's paid Apple Developer membership and Apple signing. The current `FossLift-unsigned-device.zip` cannot be uploaded to TestFlight; it contains an unsigned `.app`, not a signed distribution IPA.

Use a private external TestFlight group for friends. They install TestFlight and accept email invitations. They do not need access to your App Store Connect team, paid developer memberships, registered device UDIDs, or a public App Store release.

## Project values to use

| Field | Value |
| --- | --- |
| Bundle ID | `com.fosslift.fosslift` |
| App display name | Foss Lift |
| Version | `0.5.10` |
| Suggested first signed build number | `29`, if not already uploaded |
| Minimum app deployment target | iOS 14 |
| Privacy policy | `https://foss-lift.pages.dev/privacy/` |
| Suggested App Store Connect SKU | `foss-lift-ios` |
| App login required | No |

Use the bundle ID above consistently in the Developer portal, Xcode, signing profile, and App Store Connect. The Android identifier contains an underscore and is different. Once the Apple app record is created and builds are uploaded, changing identity is more involved than changing the display name.

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

## 4. Prepare a Mac for signing

Install a supported stable Xcode and its iOS platform tools. Launch it once to finish setup. Apple currently requires [Xcode 26 or later with an iOS 26 SDK or later](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) for uploads. That SDK requirement is separate from the app's iOS 14 deployment target; keep the deployment target at 14.

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
flutter build ipa --release --build-number=29
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

Each uploaded beta build expires after 90 days. Upload the next build with a new number, such as `30`, and add it to the group. Testers do not need new app records for updates. The service allows up to 10,000 external testers; a small private group is sufficient. [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## Device checks before inviting friends

Verify that a workout starts, survives backgrounding/reopening, logs sets, and finishes correctly. Test QR scanning, silent video capture/playback, and file backup/restore on a real iPhone. Check the smallest available phone at a large text size. The app requires iOS 14 or later, and the installed TestFlight client must also support the tester's OS.

Android foreground notification controls, background rest alerts, and scheduled reminders are hidden on iOS. The CI builds prove compilation; these device checks verify the platform behavior.

## If you do not have a Mac

The Developer portal and App Store Connect steps work from Linux or Windows. Signing and archiving must run on macOS, either a local/remote Mac or a hosted macOS CI runner.

The current GitHub **Build iOS** workflow only produces unsigned simulator and device apps. A conventional signed CI upload would additionally need the Apple **Team ID**, an **Apple Distribution certificate with its private key** (usually a password-protected `.p12`), a matching **App Store Connect distribution provisioning profile**, and an **App Store Connect API key** (`.p8`, Key ID, Issuer ID) for unattended upload. The upload API key does not replace the signing certificate and profile. Store these as CI secrets, never in source control or chat. This workflow does not currently sign or upload.

For the hosted-runner setup, see [GitHub's certificate/profile installation guide](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications) and [Apple's API-key guide](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api).
