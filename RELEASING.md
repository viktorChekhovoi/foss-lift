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

## Foreground service declaration

Foss Lift declares one foreground service type, `specialUse`, for the live
workout. Play asks for a written justification and a demonstration video before
it will accept an app that declares any `FOREGROUND_SERVICE_*` type, and it asks
again on every release where the declaration changes.

The video is not in the repository — record it into
`design/play/foreground-service/` with the scripts there, which its README
covers. Upload it to YouTube as **unlisted** and paste the link into the form;
the Console will not take a file. That README also explains why the subtype
string in the manifest, the text below and the video all have to say the same
thing.

Paste the following into the declaration field, adjusting nothing unless the
service's behaviour has actually changed.

> Foss Lift is an offline workout tracker. The foreground service runs during a
> training session and nothing else.
>
> While a session is running, the app holds it in memory: which sets have been
> logged, the weight for each, and the rest timer counting down between them.
> None of it is written to the database until the user finishes the workout.
> A session shows itself in the notification shade for the whole time it runs,
> with the current exercise and set, and buttons to log that set or to shorten,
> extend or skip the rest.
>
> The service exists because of how the app is used rather than for the
> notification itself. A user starts a set, puts the phone in a pocket or on a
> bench, and comes back to it a minute or two later. The app is in the background
> for most of a workout, which is exactly when Android is free to shut it down.
> Without the service the process is killed mid-session: the rest timer stops,
> and a press on the notification's Done button arrives at a process that no
> longer holds the workout it refers to. There is no way to schedule this work
> instead — the timing is the user's, driven by when they finish each set, and
> the state being kept alive is the session they are in the middle of.
>
> The service starts when a workout starts and stops when the user finishes or
> abandons it. It never runs otherwise. It does no work of its own beyond
> updating that notification: no location, no sensors, no network. The app has no
> network permission at all in a release build.
>
> specialUse rather than an established type: health is the closest in meaning,
> but Android requires one of BODY_SENSORS, ACTIVITY_RECOGNITION or
> HIGH_SAMPLING_RATE_SENSORS alongside it, and this app reads no sensors and
> should not be asking for those permissions. shortService is capped at three
> minutes and a workout is not three minutes. dataSync describes something the
> app does not do, and is capped at six hours a day.
>
> The video shows a session being started, the phone leaving the app, the session
> in the notification shade, a set being logged and the rest adjusted from there
> with the app still in the background, the app being reopened with that set
> already logged, and the service ending when the workout is finished.
