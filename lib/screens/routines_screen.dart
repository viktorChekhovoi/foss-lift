import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/routine_add_menu.dart';
import '../widgets/routine_card.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final routines = ref.watch(routinesProvider);
    final currentId = ref.watch(currentRoutineProvider)?.routine.id;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ScreenHeader(
            eyebrow: l10n.routinesEyebrow,
            title: l10n.routinesTitle,
            // Every way to get a routine is behind this one button. Laid out
            // under the list, the three of them sank a card further down the
            // screen with each routine added, until adding a fourth meant
            // scrolling past three.
            trailing: const AddRoutineButton(),
          ),
          const SizedBox(height: 4),
          routines.when(
            loading: () => Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('$e', style: TextStyle(color: AppColors.muted)),
            ),
            data: (list) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (list.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.todayNoRoutinesTitle,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else
                    for (final r in list) ...[
                      RoutineCard(
                        data: r,
                        isCurrent: r.routine.id == currentId,
                        onSetCurrent: () => ref
                            .read(databaseProvider)
                            .setActiveRoutineId(r.routine.id),
                        onTap: () => context.push(
                            linkPath(context, '/routine/${r.routine.id}')),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
