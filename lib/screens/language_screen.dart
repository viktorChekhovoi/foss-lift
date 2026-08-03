import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/locales.dart';

/// The language picker: the five, one of them always selected.
///
/// There is no "follow the phone" row. First run resolves the phone's language
/// and stores it (see `localeTagProvider`), so by the time anyone opens this
/// screen the question has already been answered with one of these five.
///
/// Every row names its language in that language and nothing else. A row
/// labelled "Ucraniano" is no use to the person who needs it, and a subtitle
/// translating it back into the app's current language is a second thing to
/// read for a decision made from one word.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The language actually being painted, rather than the raw stored tag: on
    // the very first launch the write that stores it may still be in flight,
    // and a picker with nothing ticked would be the one frame where the
    // "always one selected" rule does not hold.
    final chosen = localeTag(ref.watch(activeLocaleProvider));
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            for (final locale in kSupportedLocales) ...[
              if (locale != kSupportedLocales.first) const SizedBox(height: 10),
              _LanguageOption(
                label: kLanguageNames[localeTag(locale)]!,
                selected: chosen == localeTag(locale),
                onTap: () => db.setLocaleTag(localeTag(locale)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.faint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
