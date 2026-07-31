import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/routine_code.dart';
import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final shared = ref.watch(sharedRoutineProvider(routineId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.routineShareTitle)),
      body: SafeArea(
        top: false,
        child: shared.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
            child: Text('$e', style: TextStyle(color: AppColors.muted)),
          ),
          data: (routine) => _body(context, l10n, routine),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, AppLocalizations l10n, SharedRoutine routine) {
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
          l10n.routineShareSummary(
              routine.workouts.length, slots, routine.exercises.length),
          style: kMono.copyWith(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        // No QR on the page as well as behind the button. Two of the same
        // symbol on one screen is one too many, and the button is the one the
        // theme screen has.
        shareSectionLabel(l10n.routineShareSendIt),
        const SizedBox(height: 10),
        shareActionRow([
          (
            Icons.qr_code_2,
            l10n.commonShowQr,
            scannable ? () => _showQr(context, l10n, routine, link) : null,
          ),
          (
            Icons.ios_share,
            l10n.commonSendCode,
            () => _shareCode(l10n, routine, code),
          ),
        ]),
      ],
    );
  }

  Future<void> _showQr(BuildContext context, AppLocalizations l10n,
      SharedRoutine routine, String link) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(routine.name),
        content: ShareQr(data: link, caption: l10n.routineShareQrCaption),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
  }

  /// Hands the code to the system share sheet — Quick Share, a chat app, the
  /// clipboard. Nothing is uploaded: the code *is* the routine.
  Future<void> _shareCode(
      AppLocalizations l10n, SharedRoutine routine, String code) {
    return SharePlus.instance.share(
      ShareParams(
          text: code, subject: l10n.routineShareSubject(routine.name)),
    );
  }
}
