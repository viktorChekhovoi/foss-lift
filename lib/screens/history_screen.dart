import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return SafeArea(
      child: history.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) =>
            Center(child: Text('$e', style: TextStyle(color: AppColors.muted))),
        data: (list) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ScreenHeader(
                eyebrow: list.isEmpty
                    ? 'No sessions yet'
                    : '${list.length} ${list.length == 1 ? 'session' : 'sessions'}',
                title: 'History',
              ),
              if (list.isEmpty)
                const _EmptyHistory()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++)
                          _HistoryRow(
                            session: list[i],
                            last: i == list.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(DateFormat('d').format(session.startedAt),
                    style: kMono.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(DateFormat('MMM').format(session.startedAt).toUpperCase(),
                    style: kMono.copyWith(fontSize: 10, letterSpacing: 1.0, color: AppColors.faint)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  // The time of day, not just the date: whether you train
                  // mornings or late evenings is the pattern history is being
                  // read for as often as the date is.
                  '${DateFormat('HH:mm').format(session.startedAt)} · '
                  '${session.setsCompleted} ${session.setsCompleted == 1 ? 'set' : 'sets'}',
                  style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.faint),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        children: [
          Icon(Icons.fitness_center_rounded, size: 44, color: AppColors.faint),
          SizedBox(height: 16),
          Text('No workouts logged yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Finish a session and it will show up here.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
