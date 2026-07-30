# Releasing to Google Play

Play signs the app itself. You generate an **upload key**, sign the bundle with
it, and Google re-signs the APKs it serves with an **app signing key** it holds
and never gives you. That split is why losing the upload key is recoverable —
Play support resets it — while the app signing key it protects cannot change for
the lifetime of the listing.

The upload key lives outside the repository. `android/.gitignore` already
excludes `key.properties`, `*.jks` and `*.keystore`; when they are absent the
release build falls back to the debug key, so `flutter run --release` keeps
working on a fresh clone.

## One-time setup

1. Create the keystore somewhere outside the working tree — a keystore inside it
   is one `git add -A` away from being public:

   ```bash
   keytool -genkeypair -v \
     -keystore ~/keys/foss-lift-upload.jks \
     -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```

   `keytool` asks for a store password and a name for the certificate. The name
   fields are cosmetic — Play shows none of them. Answer the password prompt
   with something you can retrieve later; there is no recovery for the file
   itself.

2. Write `android/key.properties` with that password:

   ```properties
   storeFile=/home/you/keys/foss-lift-upload.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

   `keyPassword` equals `storePassword` unless you gave the key its own.
   `storeFile` is resolved relative to `android/`, so an absolute path is
   simplest.

3. Back up the keystore and both passwords to somewhere that survives this
   machine dying. Not the repository.

## Each release

1. Bump `version:` in `pubspec.yaml`. The part after `+` is the Play version
   code and must increase on every upload — Play rejects a code it has already
   seen, even from a deleted draft.
2. Build the bundle:

   ```bash
   flutter build appbundle --release
   ```

   The result is `build/app/outputs/bundle/release/app-release.aab`.
3. Confirm it used the upload key rather than the debug fallback:

   ```bash
   cd android && ./gradlew :app:signingReport | grep -A2 'Variant: release'
   ```

   `Config: upload` means the bundle is signed for Play. `Config: debug` means
   `key.properties` was missing or unreadable, and Play will reject the upload.
4. Upload the `.aab` to the Play Console. The first upload is what enrols the
   app in Play App Signing; nothing about it needs configuring here.

The listing assets Play asks for — icon, feature graphic, screenshots — are in
`design/play/`, with regeneration steps in its README.
