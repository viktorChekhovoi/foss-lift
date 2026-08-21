library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

const storageWarningKey = ValueKey('storage-warning');

class _Dismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final _dismissedProvider = NotifierProvider<_Dismissed, bool>(_Dismissed.new);

/// Reports web storage that may be lost on reload; native builds stay empty.
class StorageWarning extends ConsumerWidget {
  const StorageWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
