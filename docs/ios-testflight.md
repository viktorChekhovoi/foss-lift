# iOS and private TestFlight testing

The iOS app uses bundle ID `com.fosslift.fosslift`, requires iOS 14 or later, and uses the same training screens and local SQLite database as Android. The camera supports QR scanning and silent set videos. Android foreground notification controls, background rest alerts, and scheduled reminders are hidden on iOS. These features need a separate iOS implementation before they can be offered there.

## Builds already automated

The **Build iOS** GitHub Actions workflow runs on macOS 26. It builds a simulator app and a release device app, then keeps both in the `ios-apps` artifact. The device build is unsigned: it proves compilation and can be used as a build reference, but cannot be installed through TestFlight. No Apple signing material is committed.

The first release still needs a physical-device check: start and resume a workout, background and reopen it, finish it, scan a routine, film a silent set, and save and restore a local file backup. Check the smallest supported iPhone at a large text size. The unsigned CI build does not substitute for these checks.

## What to do in Apple's consoles

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) and accept any outstanding agreements in App Store Connect. A free personal development team cannot distribute through TestFlight.
2. In **Certificates, Identifiers & Profiles → Identifiers**, register an explicit App ID for `com.fosslift.fosslift`. Do not use the Android identifier containing an underscore; Apple's bundle identifier uses the spelling above.
3. In **App Store Connect → Apps → + → New App**, choose iOS, the name **Foss Lift**, the matching Bundle ID, a primary language, and a private SKU such as `foss-lift-ios`. The SKU is an internal identifier.
4. On a Mac, install a supported stable Xcode. Apple currently requires [Xcode 26 or later and the iOS 26 SDK or later](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) for App Store Connect uploads. In the repository run `dart tool/l10n.dart`, `flutter pub get`, and `open ios/Runner.xcworkspace`.
5. In Xcode select **Runner → Signing & Capabilities**, select your paid Developer team, and enable **Automatically manage signing**. Confirm the bundle ID matches the App Store Connect record. Let Xcode create the signing certificate and provisioning profile.
6. Build a signed distribution archive with `flutter build ipa --release --build-number=29` (use a new number for every upload), or select **Any iOS Device → Product → Archive** in Xcode. In Organizer choose **Validate App**, then **Distribute App → App Store Connect**. Use a distribution option eligible for external testing; an internal-only upload cannot later be used for external testers.
7. In **App Store Connect → Foss Lift → TestFlight → Test Information**, enter a beta description, feedback email, review contact, and what to test. Use `https://foss-lift.pages.dev/privacy/` for the privacy policy. The native iOS app does not require an account; say that in review notes rather than supplying invented login credentials. Answer export-compliance and age-rating questions truthfully. `ITSAppUsesNonExemptEncryption` is false because this build does not implement non-exempt encryption.
8. Wait for the uploaded build to finish processing. Add it to a TestFlight group. For friends and other people who are not App Store Connect team members, create an **External Testing** group and submit the first build for **Beta App Review**. After approval, invite testers by email. Keep public invitations disabled for a private beta.
9. Testers install Apple's **TestFlight** app and accept the invitation. Builds expire after 90 days. Upload a new build number when updating the beta.

Apple calls private beta distribution **TestFlight**, rather than a closed testing track. Internal testing is for up to 100 App Store Connect users with access to the app; external testing supports up to 10,000 testers. The first external build requires review, and subsequent builds may also require review. See [Apple's TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

No iOS cloud sign-in is advertised in this release. The optional server backup currently uses browser cookies in the web app. If native cloud support is added later, revise the App Privacy answers and policy before uploading that version.
