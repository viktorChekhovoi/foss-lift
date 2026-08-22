import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../widgets/common.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pagedHistoryProvider);
    final total = ref.watch(sessionCountProvider).value;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: history.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: AppColors.muted)),
        ),
        data: (page) {
          final list = page.sessions;
          return NotificationListener<ScrollNotification>(
            onNotification: (notice) {
              if (notice.metrics.extentAfter < 400 && page.hasMore) {
                ref.read(pagedHistoryProvider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.isEmpty ? 2 : list.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ScreenHeader(
                    eyebrow: list.isEmpty
                        ? l10n.historyNoSessionsYet
                        : l10n.historySessionCount(
                            total != null && total > page.total
                                ? total
                                : page.total,
                          ),
                    title: l10n.historyTitle,
                  );
                }
                if (list.isEmpty) return const _EmptyHistory();
                final row = index - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: row == 0 ? const Radius.circular(18) : Radius.zero,
                        bottom: row == list.length - 1
                            ? const Radius.circular(18)
                            : Radius.zero,
                      ),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _HistoryRow(
                          session: list[row],
                          last: row == list.length - 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session, required this.last});
  final Session session;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => context.push('/summary/${session.id}?from=history'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(
                    DateFormat.d(l10n.localeName).format(session.startedAt),
                    style: kMono.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat.MMM(
                      l10n.localeName,
                    ).format(session.startedAt).toUpperCase(),
                    style: kMono.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.0,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seededName(l10n, session.seedKey, session.name),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat.Hm(l10n.localeName).format(session.startedAt)} · '
                    '${l10n.commonSetCount(session.setsCompleted)}',
                    style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded, size: 44, color: AppColors.faint),
          const SizedBox(height: 16),
          Text(
            l10n.historyEmptyTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.historyEmptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
