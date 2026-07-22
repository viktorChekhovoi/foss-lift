# Running FossLift on Android

How to build and test the app on a **physical phone** or an **Android Studio
emulator**. Written for this Nobara/Fedora machine, where Flutter lives at
`~/development/flutter`.

## 0. One-time setup

### Put Flutter on your PATH
So `flutter`/`dart` work in any shell. Add to `~/.zshrc`:

```zsh
export PATH="$HOME/development/flutter/bin:$PATH"
```

Then `source ~/.zshrc` (or open a new terminal) and check:

```zsh
flutter --version
```

### Install the Android SDK (via Android Studio)
Flutter needs the Android SDK + platform-tools + build-tools. The simplest way
to get all of it (and the emulator) is Android Studio:

```zsh
sudo dnf install android-studio                     # packaged in Nobara's terra repo
# or: flatpak install flathub com.google.AndroidStudio
# or: download the tarball from https://developer.android.com/studio
```

Launch Android Studio once and let the **Setup Wizard** install the SDK. Then in
**Settings → Languages & Frameworks → Android SDK**, make sure these are ticked:
- **Android SDK Platform** (latest, e.g. API 35)
- **Android SDK Platform-Tools**
- **Android SDK Build-Tools**
- **Android Emulator** + one **system image** (e.g. "Google APIs" ARM/x86_64)

If `flutter` can't find the SDK, point it at the install location (usually
`~/Android/Sdk`):

```zsh
flutter config --android-sdk ~/Android/Sdk
```

### Accept licenses & verify

```zsh
flutter doctor --android-licenses    # press y through all of them
flutter doctor                       # "Android toolchain" should now be ✓
```

### Get dependencies (from the repo root)

```zsh
cd ~/repos/foss-lift
flutter pub get
```

---

## Option A — Your physical phone (fastest)

1. **Enable Developer options**: Settings → About phone → tap **Build number**
   7 times.
2. **Enable USB debugging**: Settings → System → Developer options → **USB
   debugging** (on).
3. Plug the phone into the PC with a **data** USB cable. On the phone, tap
   **Allow** on the "Allow USB debugging?" prompt (tick "always allow").
4. On Fedora/Nobara you need `adb` and (usually) udev rules so the device is
   visible without root:
   ```zsh
   sudo dnf install android-tools android-udev-rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
   (Replug the phone after this. On Fedora/Nobara the package is
   `android-udev-rules` — *not* `android-udev`.)
5. Confirm it's seen:
   ```zsh
   flutter devices        # your phone should be listed
   ```
6. Run it:
   ```zsh
   cd ~/repos/foss-lift
   flutter run            # builds, installs, and launches on the phone
   ```

### Wireless (no cable, Android 11+)
Once USB debugging works, you can go cable-free: Developer options → **Wireless
debugging** → **Pair device with pairing code**, then:

```zsh
adb pair <phone-ip>:<pair-port>      # enter the 6-digit code shown on the phone
adb connect <phone-ip>:<debug-port>
flutter run
```

---

## Option B — Android Studio emulator

1. In Android Studio, open **More Actions → Virtual Device Manager** (or
   **Device Manager**).
2. **Create Device** → pick a phone (e.g. Pixel 7) → choose a **system image**
   (download one if prompted) → **Finish**.
3. Start the emulator with the ▶ button (or list it and boot from the CLI):
   ```zsh
   flutter emulators                 # shows created AVDs
   flutter emulators --launch <id>   # boot one
   ```
4. With the emulator running:
   ```zsh
   cd ~/repos/foss-lift
   flutter run
   ```

> On Linux the emulator wants KVM. If it's slow or won't start:
> ```zsh
> ls -l /dev/kvm                     # should exist
> sudo usermod -aG kvm $USER         # then log out/in
> ```

---

## Day-to-day

While `flutter run` is attached, use these keys in the terminal:

| Key | Action |
|-----|--------|
| `r` | **Hot reload** — apply Dart changes in ~1s, keep app state |
| `R` | **Hot restart** — rebuild from scratch, reset state |
| `q` | Quit |

- Multiple devices connected? `flutter run -d <device-id>`.
- After changing the DB schema in `data/database.dart`, regenerate first:
  ```zsh
  dart run build_runner build
  ```
  A schema change also means the on-device data is stale — uninstall the app (or
  `adb uninstall com.fosslift.foss_lift`) to get a fresh seed while pre-release.

## Build a shareable APK

To hand someone an installable file (no PC needed on their end):

```zsh
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Install it directly to a connected device with:

```zsh
adb install build/app/outputs/flutter-apk/app-release.apk
```

> The release build currently uses Flutter's **debug signing key**, which is
> fine for personal testing and sideloading. A proper upload key is only needed
> to publish on the Play Store (see `android/app/build.gradle.kts`).

## Troubleshooting

- **`flutter devices` is empty (phone)** → bad/charge-only cable, USB debugging
  off, unauthorized prompt not accepted, or missing udev rules (step A4). Check
  `adb devices` — `unauthorized` means re-accept the prompt; empty means udev.
- **"Unable to locate Android SDK"** → run `flutter config --android-sdk <path>`
  then `flutter doctor`.
- **Licenses not accepted** → `flutter doctor --android-licenses`.
- **Emulator won't boot / very slow** → KVM not enabled (see the KVM note above).
- **Gradle fails on first build** → it's downloading Gradle/deps; let it finish
  once, subsequent builds are cached.
