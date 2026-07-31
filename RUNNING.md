# Running Foss Lift on Android

How to build and test the app on a **physical phone** or an **Android
emulator**, from a Linux desktop. Commands are given for Debian/Ubuntu (`apt`)
and Fedora and its derivatives (`dnf`).
Everything else is distro-independent. Run the project commands from the repo root.

## 0. One-time setup

### Install Flutter

The SDK tarball from [flutter.dev](https://docs.flutter.dev/get-started/install/linux)
is the option that works the same everywhere. Unpack it somewhere you own —
`~/development/flutter` and `~/flutter` are both common:

```bash
mkdir -p ~/development && cd ~/development
tar xf ~/Downloads/flutter_linux_*-stable.tar.xz
```

Flutter's own tooling needs a few command-line utilities:

```bash
# Debian/Ubuntu
sudo apt install git curl unzip xz-utils zip libglu1-mesa

# Fedora
sudo dnf install git curl unzip xz zip mesa-libGLU
```

Ubuntu also ships Flutter as a snap (`sudo snap install flutter --classic`).
It works, but it does not bring the Android SDK with it, and its confinement
occasionally trips up tooling that writes outside `$HOME`. If you hit anything
odd, the tarball is the reference install.

### Put Flutter on your PATH

So `flutter` and `dart` work in any shell. Add to `~/.bashrc` (bash) or
`~/.zshrc` (zsh), substituting your install directory:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

Open a new terminal, then check:

```bash
flutter --version
```

### Install the Android SDK

Flutter needs the Android SDK, platform-tools and build-tools. Android Studio
installs all of it plus the emulator, and is the path of least resistance:

```bash
# Any distro: the tarball from https://developer.android.com/studio
tar xf ~/Downloads/android-studio-*-linux.tar.gz -C ~/  &&  ~/android-studio/bin/studio.sh

# Ubuntu
sudo snap install android-studio --classic

# Fedora derivatives that carry it (Nobara's terra repo, for one)
sudo dnf install android-studio

# Or, on any distro
flatpak install flathub com.google.AndroidStudio
```

Launch it once and let the **Setup Wizard** install the SDK. Then in
**Settings → Languages & Frameworks → Android SDK**, make sure these are ticked:

- **Android SDK Platform** (latest, e.g. API 35)
- **Android SDK Platform-Tools**
- **Android SDK Build-Tools**
- **Android Emulator** and one **system image** (e.g. "Google APIs" x86_64)

If you would rather not install the IDE, the
[command-line tools](https://developer.android.com/studio#command-line-tools-only)
package is enough — unpack it to `~/Android/Sdk/cmdline-tools/latest`, add a JDK
(`sudo apt install openjdk-17-jdk` / `sudo dnf install java-17-openjdk-devel`),
and install the components with `sdkmanager`:

```bash
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
```

Point Flutter at the SDK if it cannot find it (the default location is
`~/Android/Sdk`):

```bash
flutter config --android-sdk ~/Android/Sdk
```

### Accept licenses and verify

```bash
flutter doctor --android-licenses    # press y through all of them
flutter doctor                       # "Android toolchain" should now be ✓
```

`flutter doctor` also complains about Linux desktop and Chrome toolchains. This
app targets Android, so those are safe to ignore.

### Get dependencies

From the repo root:

```bash
flutter pub get
```

---

## Option A — A physical phone (fastest)

1. **Enable Developer options**: Settings → About phone → tap **Build number**
   7 times.
2. **Enable USB debugging**: Settings → System → Developer options → **USB
   debugging** (on).
3. Plug the phone into the PC with a **data** USB cable. On the phone, tap
   **Allow** on the "Allow USB debugging?" prompt (tick "always allow").
4. Install `adb` and the udev rules, so the device is visible without root:

   ```bash
   # Debian/Ubuntu — the -common package is the udev rules
   sudo apt install adb android-sdk-platform-tools-common
   sudo usermod -aG plugdev $USER        # log out and back in afterwards

   # Fedora — note it is android-udev-rules, not android-udev
   sudo dnf install android-tools android-udev-rules
   ```

   Then reload the rules and replug the phone:

   ```bash
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```

5. Confirm it is seen:

   ```bash
   flutter devices        # your phone should be listed
   ```

6. Run it, from the repo root:

   ```bash
   flutter run            # builds, installs, and launches on the phone
   ```

### Wireless (no cable, Android 11+)

Once USB debugging works, you can go cable-free: Developer options → **Wireless
debugging** → **Pair device with pairing code**, then:

```bash
adb pair <phone-ip>:<pair-port>      # enter the 6-digit code shown on the phone
adb connect <phone-ip>:<debug-port>
flutter run
```

---

## Option B — An emulator

1. In Android Studio, open **More Actions → Virtual Device Manager** (or
   **Device Manager**).
2. **Create Device** → pick a phone (e.g. Pixel 7) → choose a **system image**
   (download one if prompted) → **Finish**.
3. Start the emulator with the ▶ button, or from the CLI:

   ```bash
   flutter emulators                 # shows created AVDs
   flutter emulators --launch <id>   # boot one
   ```

4. With the emulator running, from the repo root:

   ```bash
   flutter run
   ```

> The emulator needs KVM. If it is slow or will not start:
>
> ```bash
> ls -l /dev/kvm                     # should exist
> sudo usermod -aG kvm $USER         # then log out and back in
> ```
>
> On Debian/Ubuntu the group may be `kvm` or `libvirt` depending on how
> virtualisation was installed; `ls -l /dev/kvm` shows which group owns the
> node. If the file is missing entirely, virtualisation is off in the BIOS.

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

  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

  A schema change also means the on-device data is stale — uninstall the app (or
  `adb uninstall com.fosslift.foss_lift`) to get a fresh seed while pre-release.

- After changing `design/icon/foss-lift.svg`, re-export the PNGs under
  `assets/icon/` and `assets/splash/`, then regenerate the Android resources:

  ```bash
  ./tool/icon_assets.sh            # needs inkscape and ImageMagick 7
  dart run flutter_launcher_icons
  dart run flutter_native_splash:create
  ```

  Both write into `android/app/src/main/res/`, and the result is committed. The
  configuration for each, and the reasoning behind the sizes, is at the bottom
  of `pubspec.yaml`. A launcher icon is cached by the launcher, so reinstall
  rather than hot-restart to see it change.

## Build a shareable APK

To hand someone an installable file (no PC needed on their end):

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

Install it directly to a connected device with:

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

> The release build currently uses Flutter's **debug signing key**, which is
> fine for personal testing and sideloading. A proper upload key is only needed
> to publish on the Play Store (see `android/app/build.gradle.kts`).

## Troubleshooting

- **`flutter devices` is empty (phone)** → bad or charge-only cable, USB
  debugging off, unauthorized prompt not accepted, or missing udev rules (step
  A4). Check `adb devices` — `unauthorized` means re-accept the prompt on the
  phone; empty means udev rules or group membership. `id` should list `plugdev`
  on Debian/Ubuntu; if you just ran `usermod`, log out and back in.
- **"Unable to locate Android SDK"** → `flutter config --android-sdk <path>`,
  then `flutter doctor`.
- **Licenses not accepted** → `flutter doctor --android-licenses`. If it fails
  with a Java error, the SDK's `cmdline-tools` are missing — install them from
  Android Studio's SDK Manager under **SDK Tools**.
- **Emulator will not boot, or is very slow** → KVM (see the note in Option B).
- **Gradle fails on first build** → it is downloading Gradle and dependencies;
  let it finish once, subsequent builds are cached.
- **`flutter` works in one terminal but not another** → the `export PATH` line
  went into a shell rc file your other shell does not read. bash reads
  `~/.bashrc`, zsh reads `~/.zshrc`.
