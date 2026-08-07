/// What the app says when the browser will not promise to keep the database.
///
/// Two situations, and they are not the same size, so they do not get the same
/// treatment:
///
/// - **[StorageDurability.ephemeral]** — there is nowhere durable to write at
///   all. Everything logged is gone on reload. This is the one that has to be
///   read *before* somebody trains a session into it, so it sits at the top of
///   Today, it stays there, and there is nothing to put it away with.
/// - **[StorageDurability.evictable]** — the storage is real, but the browser
///   refused to exempt it from being reclaimed under pressure. Probably fine,
///   and a refusal is ordinary rather than a fault — Chrome says no to a site
///   you have just opened as a matter of course. So it is a note, and it can be
///   dismissed.
///
/// Off the web neither exists: `storageHealthProvider` resolves to
/// [StorageHealth.native] and this builds nothing.
///
/// **The dismissal lasts for the session, not for ever.** Putting it somewhere
/// durable would mean a column in the settings table and a migration rung, and
/// the thing being remembered is a preference about a warning in one browser —
/// which is itself in the storage the warning is about. It comes back on the
/// next load; the note is one line and it stops being shown the moment the
/// browser grants the exemption.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Finds the warning in a test.
const storageWarningKey = ValueKey('storage-warning');

/// Whether the evictable note has been put away, for this run of the app.
class _Dismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final _dismissedProvider = NotifierProvider<_Dismissed, bool>(_Dismissed.new);

class StorageWarning extends ConsumerWidget {
  const StorageWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the probe is in flight there is nothing to say. It is one round
    // trip on launch, and guessing "fragile" and then taking it back would be a
    // warning that flashes on every cold load of a perfectly good browser.
    final health = ref.watch(storageHealthProvider).value;
    if (health == null || !health.isFragile) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final permanent = health.durability == StorageDurability.ephemeral;
    if (!permanent && ref.watch(_dismissedProvider)) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: storageWarningKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permanent
                          ? l10n.storageEphemeralWarning
                          : l10n.storageEvictableNotice,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    if (!permanent)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () =>
                              ref.read(_dismissedProvider.notifier).dismiss(),
                          child: Text(
                            l10n.commonDismiss,
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
