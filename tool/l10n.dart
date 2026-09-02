// Splits localization copy by writing length, then rebuilds the flat ARB files Flutter expects.

import 'dart:convert';
import 'dart:io';

const _locales = ['en', 'es', 'pt', 'pt_BR', 'uk'];
const _shortDirectory = 'lib/l10n/short';
const _longDirectory = 'lib/l10n/long';

Future<void> main(List<String> arguments) async {
  if (arguments.length > 1 ||
      (arguments.isNotEmpty && arguments.single != '--split')) {
    stderr.writeln('usage: dart run tool/l10n.dart [--split]');
    exitCode = 64;
    return;
  }

  if (arguments.contains('--split')) {
    await _split();
  }
  await _merge();
}

Future<Map<String, Object?>> _read(String path) async {
  final decoded = jsonDecode(await File(path).readAsString());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$path is not a JSON object');
  }
  return decoded;
}

Future<void> _write(String path, Map<String, Object?> values) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(values)}\n',
  );
}

Iterable<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

Future<void> _split() async {
  final english = await _read('lib/l10n/app_en.arb');
  final shortKeys = _messageKeys(
    english,
  ).where((key) => _visibleWordCount(english[key] as String) <= 3).toSet();

  for (final locale in _locales) {
    final input = await _read('lib/l10n/app_$locale.arb');
    final short = <String, Object?>{'@@locale': locale};
    final long = <String, Object?>{'@@locale': locale};
    for (final key in _messageKeys(english)) {
      if (!input.containsKey(key)) {
        throw FormatException('app_$locale.arb is missing $key');
      }
      final target = shortKeys.contains(key) ? short : long;
      target[key] = input[key];
      final metadataKey = '@$key';
      if (input.containsKey(metadataKey)) {
        target[metadataKey] = input[metadataKey];
      }
    }
    await _write('$_shortDirectory/app_$locale.arb', short);
    await _write('$_longDirectory/app_$locale.arb', long);
  }
  stdout.writeln(
    'split ${shortKeys.length} short labels and '
    '${_messageKeys(english).length - shortKeys.length} longer strings',
  );
}

int _visibleWordCount(String message) {
  final withoutPlaceholders = message.replaceAll(RegExp(r'\{[^{}]*\}'), ' ');
  return RegExp(
    r"[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*",
    unicode: true,
  ).allMatches(withoutPlaceholders).length;
}

Future<void> _merge() async {
  for (final locale in _locales) {
    final short = await _read('$_shortDirectory/app_$locale.arb');
    final long = await _read('$_longDirectory/app_$locale.arb');
    final overlap = _messageKeys(
      short,
    ).toSet().intersection(_messageKeys(long).toSet());
    if (overlap.isNotEmpty) {
      throw FormatException(
        'app_$locale has keys in both sources: ${overlap.join(', ')}',
      );
    }
    final merged = <String, Object?>{'@@locale': locale};
    for (final source in [short, long]) {
      for (final entry in source.entries) {
        if (entry.key != '@@locale') merged[entry.key] = entry.value;
      }
    }
    await _write('lib/l10n/app_$locale.arb', merged);
  }
  stdout.writeln('rebuilt ${_locales.length} Flutter ARB catalogues');
}
