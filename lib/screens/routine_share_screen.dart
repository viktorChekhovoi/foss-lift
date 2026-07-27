import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/routine_code.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/share_widgets.dart';

/// Hands a routine to someone else: as a QR, a link, a code or a file.
///
/// All four carry the same `FLR1.…` string, and that string *is* the routine —
/// there is no server behind it, nothing to look up and nothing to expire.
/// Nothing here touches the network; even "Send link" only hands text to the
/// system share sheet.
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
        const SizedBox(height: 18),
        Center(
          child: ShareQr(
            data: link,
            caption: 'Point another phone at this. Foss Lift will ask before '
                'adding anything.',
          ),
        ),
        const SizedBox(height: 22),
        shareSectionLabel('SEND IT'),
        const SizedBox(height: 10),
        shareActionRow([
          (
            Icons.qr_code_2,
            'Show QR',
            scannable ? () => _showQr(context, routine, link) : null,
          ),
          (Icons.ios_share, 'Send link', () => _shareLink(routine, link)),
        ]),
        const SizedBox(height: 10),
        shareActionRow([
          (Icons.content_copy, 'Copy code', () => _copyCode(context, code)),
          (Icons.save_alt, 'Save file', () => _saveFile(context, routine, code)),
        ]),
        const SizedBox(height: 22),
        shareSectionLabel('THE CODE'),
        const SizedBox(height: 10),
        ShareCodeBox(code: code),
        const SizedBox(height: 14),
        Text(
          'The code is the whole programme — every day, every set and rep '
          'target, and any custom exercises it needs. Whoever receives it is '
          'shown what it contains and asked before anything is added. None of '
          'this touches the network.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
        ),
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

  /// Hands the link to the system share sheet — Quick Share, a chat app,
  /// wherever. Nothing is uploaded: the link *is* the routine.
  Future<void> _shareLink(SharedRoutine routine, String link) {
    return SharePlus.instance.share(
      ShareParams(text: link, subject: 'Foss Lift routine: ${routine.name}'),
    );
  }

  /// Copies the bare code. Kept separate from the link because chat apps do not
  /// turn a `fosslift://` URL into something tappable, so the code is often the
  /// more useful thing to paste.
  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) saySnack(context, 'Routine code copied');
  }

  /// Writes the code beside the app's documents, one line in a text file. The
  /// code is for sharing now; a file is for keeping, and pastes back in whole.
  Future<void> _saveFile(
      BuildContext context, SharedRoutine routine, String code) async {
    String? path;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final slug = routine.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final file = File(p.join(dir.path, 'foss_lift_routine_$slug.txt'));
      await file.writeAsString('$code\n');
      path = file.path;
    } catch (_) {
      // A filesystem hiccup should report itself, not throw into the button.
    }
    if (!context.mounted) return;
    saySnack(context,
        path == null ? "Couldn't save the file" : 'Saved ${p.basename(path)}');
  }
}
