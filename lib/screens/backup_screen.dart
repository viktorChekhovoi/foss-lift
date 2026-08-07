/// Saving everything to a file, and reading one back.
///
/// The service does the work — see `services/backup_service.dart`; this is the
/// screen, and the three decisions on it that are the user's rather than the
/// app's: whether clips travel, whether a file that size is worth making, and
/// whether replacing everything is really what was meant.
///
/// **Restore is behind a confirmation, and nothing else here is.** Saving a
/// backup cannot hurt anybody, so it is one tap. Restoring throws away the
/// phone's data on purpose, which is a thing to be asked about in those words.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_archive.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// What a backup would come to, with clips and without.
///
/// Both at once, because the checkbox switches between them and re-measuring a
/// folder of clips on every tick would make the number arrive late each time.
typedef BackupSize = ({int bare, int withClips});

/// Measured, not guessed — see [BackupService.size].
final backupSizeProvider = FutureProvider<BackupSize>((ref) async {
  final service = ref.watch(backupServiceProvider);
  return (
    bare: await service.size(clips: false),
    withClips: await service.size(clips: true),
  );
});

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// Off by default: the useful backup is the one that fits in a message.
  bool _clips = false;

  /// While a file is being written or read. Both are slow enough with a reel of
  /// clips in them to need saying, and neither should be startable twice.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = ref.watch(backupSizeProvider).value;
    final bytes = size == null ? null : (_clips ? size.withClips : size.bare);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(l10n.backupSaveHeading, style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _Note(bytes == null ? '…' : l10n.backupSize(fmtBytes(bytes))),
            CheckboxListTile(
              value: _clips,
              onChanged: _busy ? null : (on) => setState(() => _clips = on ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.backupIncludeVideos,
                  style: const TextStyle(fontSize: 15)),
            ),
            // The omission, said before the file is made rather than found out
            // when a restore has no clips in it.
            if (!_clips) _Note(l10n.backupVideosLeftOut),
            if (_clips && (bytes ?? 0) > kBackupLargeBytes)
              _Note(l10n.backupTooBig, warn: true),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _save(l10n),
              child: Text(l10n.backupSave),
            ),
            const SizedBox(height: 32),
            Text(l10n.backupRestoreHeading, style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _Note(l10n.backupRestoreReplaces),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _restore(l10n),
              child: Text(l10n.backupChooseFile),
            ),
          ],
        ),
      ),
    );
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Builds the file and hands it to the phone's share sheet. The app keeps no
  /// copy: a backup in app storage goes with the uninstall it exists for.
  Future<void> _save(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final file = await ref.read(backupServiceProvider).save(clips: _clips);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      debugPrint('BackupScreen: could not write the backup ($e)');
      _say(l10n.backupSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Picks a file, asks, and replaces everything.
  ///
  /// The live session is checked first and by hand: it is in memory and is not
  /// history until Finish, so replacing the database under it would throw a
  /// workout away as a side effect of a button that says nothing about workouts.
  Future<void> _restore(AppLocalizations l10n) async {
    if (ref.read(activeWorkoutProvider) != null) {
      _say(l10n.backupFinishWorkoutFirst);
      return;
    }
    // No type filter: a picker's filters go by extension and MIME, and a backup
    // that has been through a cloud drive may have neither intact. What says a
    // file is a backup is the manifest inside it.
    final picked = await openFile();
    if (picked == null || !mounted) return;
    final path = picked.path;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.backupReplaceTitle),
        content: Text(l10n.backupReplaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.backupReplaceConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    BackupRefusal? refusal;
    try {
      refusal = await ref.read(backupServiceProvider).restore(File(path));
    } catch (e) {
      debugPrint('BackupScreen: could not read the backup ($e)');
      refusal = BackupRefusal.notABackup;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    switch (refusal) {
      case BackupRefusal.notABackup:
        _say(l10n.backupNotABackup);
      case BackupRefusal.fromANewerVersion:
        _say(l10n.backupFromNewerVersion);
      case null:
        // Everything reading the old database is now reading a file that is no
        // longer there. Rebuilding the database provider rebuilds the lot.
        ref.invalidate(databaseProvider);
        _say(l10n.backupRestored);
    }
  }
}

/// A line under a control: the size, the omission, the warning.
class _Note extends StatelessWidget {
  const _Note(this.text, {this.warn = false});
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: kMono.copyWith(
            fontSize: 12,
            color: warn ? AppColors.gold : AppColors.faint,
          ),
        ),
      );
}
