import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/routine_code.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/share_widgets.dart';

/// Hands a routine to someone else, as a QR or as a code.
///
/// Both carry the same `FLR1.…` string, and that string *is* the routine —
/// there is no server behind it, nothing to look up and nothing to expire.
/// Nothing here touches the network; even "Send code" only hands text to the
/// system share sheet.
///
/// The QR wraps it in a `fosslift://routine/…` link, so a phone's own camera
/// can open the import screen without the recipient knowing this app has a
/// scanner. The share sheet does not: a chat app leaves a custom scheme as plain
/// unclickable text, so the link only added a prefix to paste around.
class RoutineShareScreen extends ConsumerWidget {
  const RoutineShareScreen({super.key, required this.routineId});
  final int routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(sharedRoutineProvider(routineId));

    return Scaffold(
      appBar: AppBar(title: const Text('Share routine')),
      body: SafeArea(
        top: false,
        child: shared.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.muted)),
          ),
          data: (routine) => _body(context, routine),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SharedRoutine routine) {
    // Two payloads for the same routine: the symbol carries the link, the share
    // sheet carries the code. The capacity question is about the longer one.
    final code = RoutineCode.encode(routine);
    final link = RoutineCode.link(routine);
    final scannable = RoutineCode.fitsQr(link);
    final slots =
        routine.workouts.fold(0, (sum, w) => sum + w.items.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(routine.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          '${routine.workouts.length} '
          '${routine.workouts.length == 1 ? 'workout' : 'workouts'} · '
          '$slots ${slots == 1 ? 'exercise slot' : 'exercise slots'} · '
          '${routine.exercises.length} '
          '${routine.exercises.length == 1 ? 'exercise' : 'exercises'}',
          style: kMono.copyWith(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        // No QR on the page as well as behind the button. Two of the same
        // symbol on one screen is one too many, and the button is the one the
        // theme screen has.
        shareSectionLabel('SEND IT'),
        const SizedBox(height: 10),
        shareActionRow([
          (
            Icons.qr_code_2,
            'Show QR',
            scannable ? () => _showQr(context, routine, link) : null,
          ),
          (Icons.ios_share, 'Send code', () => _shareCode(routine, code)),
        ]),
      ],
    );
  }

  Future<void> _showQr(
      BuildContext context, SharedRoutine routine, String link) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(routine.name),
        content: ShareQr(
          data: link,
          caption: 'Point another phone at this. Foss Lift will ask before '
              'adding anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Hands the code to the system share sheet — Quick Share, a chat app, the
  /// clipboard. Nothing is uploaded: the code *is* the routine.
  Future<void> _shareCode(SharedRoutine routine, String code) {
    return SharePlus.instance.share(
      ShareParams(text: code, subject: 'Foss Lift routine: ${routine.name}'),
    );
  }
}
