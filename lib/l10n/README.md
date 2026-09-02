# Localization sources

Edit `short/app_<locale>.arb` for labels of up to three visible words. These are suitable for machine-generated translation drafts.

Edit `long/app_<locale>.arb` for sentences, help text, descriptions, and other copy that needs deliberate writing. Moving a message between the two files does not change its localization key.

Run `dart run tool/l10n.dart` after editing either source. It checks that no key exists in both files and rebuilds the flat `app_<locale>.arb` catalogues required by Flutter. Then run `flutter gen-l10n` to rebuild the generated Dart API.

`dart run tool/l10n.dart --split` reclassifies every message from the flat English catalogue using the three-word boundary. It is a bulk maintenance command, not the normal editing workflow; manual placement wins until that command is deliberately run again.
