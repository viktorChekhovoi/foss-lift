import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/set_video_recorder.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// How set clips are filmed, how much space they take, and how to get it back.
///
/// The reclaim controls are the price of the app's retention policy, which is
/// that **nothing is ever deleted automatically**. Every automatic rule bins
/// the oldest clip first, and the oldest clip is the one worth keeping — the
/// whole point of filming a set is to hold it up against the same lift six
/// months later. So the app shows the number and puts the bin in reach instead
/// of choosing on the user's behalf.
class VideoSettingsScreen extends ConsumerWidget {
  const VideoSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final setting = ref.watch(videoSettingProvider).value;
    final height = resolveVideoHeight(setting?.height);
    final maxSeconds = resolveVideoMaxSeconds(setting?.maxSeconds);
    final clips = ref.watch(videoPathsProvider).value ?? const <String>[];
    final used = ref.watch(videoUsageProvider).value;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoSettingsTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(l10n.videoSettingsQuality,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _Choices(
              values: kVideoHeights,
              chosen: height,
              label: l10n.videoSettingsHeight,
              onSelect: db.setVideoHeight,
            ),
            const SizedBox(height: 22),
            Text(l10n.videoSettingsMaxLength,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _Choices(
              values: kVideoMaxSeconds,
              chosen: maxSeconds,
              label: (v) => v < 60
                  ? l10n.videoSettingsSeconds(v)
                  : l10n.videoSettingsMinutes(v ~/ 60),
              onSelect: db.setVideoMaxSeconds,
            ),
            const SizedBox(height: 28),
            Text(l10n.videoSettingsStorage,
                style: sectionLabelStyle()),
            const SizedBox(height: 10),
            _UsageRow(
              label: l10n.commonClipCount(clips.length),
              value: used == null ? '…' : fmtBytes(used),
            ),
            const SizedBox(height: 10),
            if (clips.isNotEmpty)
              OutlinedButton(
                onPressed: () =>
                    _confirmDeleteAll(context, l10n, ref, clips.length),
                child: Text(l10n.videoSettingsDeleteAll),
              ),
          ],
        ),
      ),
    );
  }

  /// The blunt instrument, behind a confirmation that says the size of what is
  /// about to go. Per-exercise reclaim lives on the exercise itself, which is
  /// where somebody deciding they no longer need six months of bench press
  /// actually is.
  Future<void> _confirmDeleteAll(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.videoSettingsDeleteTitle(count)),
        content: Text(l10n.videoSettingsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).clearAllSetVideos();
    await ref.read(setVideoStoreProvider).sweepOrphans(const {},
        grace: Duration.zero);
    ref.invalidate(videoUsageProvider);
  }
}

/// What the clips are costing. Read-only, so it is not a [SettingRow]: a row
/// that looks tappable and is not is worse than a plain one.
class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Text(value,
              style: kMono.copyWith(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// A row of exclusive choices, the shape Settings already uses for text size.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.chosen,
    required this.label,
    required this.onSelect,
  });
  final List<int> values;
  final int chosen;
  final String Function(int) label;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == chosen
                      ? AppColors.accent.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: v == chosen ? AppColors.accent : AppColors.line,
                    width: v == chosen ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label(v),
                  style: kMono.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: v == chosen ? AppColors.accent : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
