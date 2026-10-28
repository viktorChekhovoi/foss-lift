library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_archive.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

typedef BackupSize = ({int bare, int withClips});

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
  bool _clips = false;

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
            if (_clips && (bytes ?? 0) > kBackupLargeBytes)
              _Note(
                l10n.backupTooBig(fmtBytes(kBackupLargeBytes)),
                warn: true,
              ),
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
            const SizedBox(height: 36),
            Text(l10n.backupResetHeading, style: sectionLabelStyle()),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => _reset(l10n),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.55)),
              ),
              child: Text(l10n.backupResetProfile),
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

  Future<void> _restore(AppLocalizations l10n) async {
    if (ref.read(activeWorkoutProvider) != null) {
      _say(l10n.backupFinishWorkoutFirst);
      return;
    }
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
        ref.invalidate(databaseProvider);
        _say(l10n.backupRestored);
    }
  }

  Future<void> _reset(AppLocalizations l10n) async {
    if (ref.read(activeWorkoutProvider) != null) {
      _say(l10n.backupFinishWorkoutFirst);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.backupResetTitle),
        content: Text(l10n.backupResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.backupResetConfirm,
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).resetEverything();
      if (ref.read(capabilitiesProvider).setVideos) {
        await ref.read(setVideoStoreProvider).deleteEverything();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    context.go('/today');
    _say(l10n.backupResetDone);
  }
}

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
