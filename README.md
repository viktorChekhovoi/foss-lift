# Foss Lift

A feature-rich workout tracker for Android (and a planned iOS release). 

## Getting started

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart
SDK ^3.12.2) and an Android device or emulator. There is no `ios/` directory
yet; the port is planned, not started.

```bash
flutter pub get
flutter run                    # launch on a connected device/emulator
flutter test                   # the feature tests
flutter analyze                # lints

dart run build_runner build --delete-conflicting-outputs   # after schema changes
```

[`RUNNING.md`](RUNNING.md) covers device and emulator setup.
[`RELEASING.md`](RELEASING.md) covers signing and uploading to Play.


## Contributing

Pull requests and forks are welcome.

Foss Lift follows two important conventions:
1. **Every behavior is documented.** Every feature starts as a catalogue entry that serves as reference for any coding agent working on the code; write the behaviour into `features/catalogue/*.yaml` and validate it with
   `dart run tool/features.dart --check`
2. **Robust test coverage.** Foss Lift deliberately avoids birttle tests that focus on implementation details. Tests should cover the feature described in the catalogue.

See [`README.md`](features/README.md) for more details on cataloguing features.

## Privacy

Foss Lift makes no network connections and collects nothing. See
[`PRIVACY.md`](PRIVACY.md).

## License

[GNU AGPL-3.0-or-later](LICENSE) © 2026 Viktor Chekhovoi

Foss Lift is free software: you can redistribute it and/or modify it under the
terms of the GNU Affero General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It comes with no warranty; see the licence for details.

## Name and branding

The licence covers the code. It does **not** grant any right to the name *Foss
Lift*, the icon, or the branding.
