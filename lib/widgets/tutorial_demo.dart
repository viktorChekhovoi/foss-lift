import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/format.dart';

/// The stand-ins the tour shows for the live workout.
///
/// **These are pictures, not the board.** The real board and rest bar in
/// `workout_screen.dart` are driven by an [ActiveWorkout]; drawing them would
/// mean the tour starting a session nobody asked for, on a phone whose owner
/// has not built a routine yet. So the tour paints a fixed example of each and
/// talks about that. Nothing here reads or writes session state, and nothing
/// here takes a tap — the overlay puts them behind an [IgnorePointer] so a tap
/// on the mock is a tap on the tour.
///
/// They are *pictures*, not screenshots: theme colours and the display unit
/// come from the app, so what the tour shows is what the phone in the reader's
/// hand will look like.

/// Which part of the mock board the current step is talking about. The ring is
/// the tour's own pointer for something too small to spotlight — the icon at the
/// end of a row.
enum TutorialDemoFocus { none, nextSet, note, camera }

/// The note icon on the mock exercise heading.
const kTutorialDemoNoteKey = ValueKey('tutorial-demo-note');

/// A camera cell on a mock set row. One per row, so this matches several.
const kTutorialDemoCameraKey = ValueKey('tutorial-demo-camera');

/// The example: one barbell lift, three working sets, the first one logged.
///
/// The lift is named from the starter library rather than spelled out here, so
/// the tour shows the movement under the name the library screen would give it.
/// Everything else the mock says is its own — see the note on this file.
const _kDemoWeightKg = 80.0;
const _kDemoGoal = 8;
const _kDemoSets = 3;

/// A miniature of the live board — the exercise, its note icon, and the set
/// rows with the one you are on outlined.
class TutorialBoardDemo extends ConsumerWidget {
  const TutorialBoardDemo({super.key, this.focus = TutorialDemoFocus.none});

  final TutorialDemoFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final weight = fmtWeight(toDisplayWeight(_kDemoWeightKg, unit));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(l10n),
          const SizedBox(height: 12),
          _goalLine(l10n, weight, unit),
          const SizedBox(height: 8),
          _columnHeaders(l10n, unit),
          for (var i = 1; i <= _kDemoSets; i++)
            _SetRowDemo(
              number: i,
              weight: weight,
              // The first is behind you, the second is the one to do now, the
              // rest are still ahead — the three states the column ever has.
              state: switch (i) {
                1 => _RowState.done,
                2 => _RowState.next,
                _ => _RowState.todo,
              },
              goal: _kDemoGoal,
              highlightNext: focus == TutorialDemoFocus.nextSet,
              highlightCamera: focus == TutorialDemoFocus.camera,
            ),
        ],
      ),
    );
  }

  Widget _heading(AppLocalizations l10n) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              l10n.exerciseBenchPress,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          _ring(
            on: focus == TutorialDemoFocus.note,
            child: Padding(
              key: kTutorialDemoNoteKey,
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 18,
                color: focus == TutorialDemoFocus.note
                    ? AppColors.accent
                    : AppColors.muted,
              ),
            ),
          ),
        ],
      );

  /// What the exercise is aiming at and what it is loaded to, the way the board
  /// says it: `3 × 8 @ 80 kg`.
  Widget _goalLine(AppLocalizations l10n, String weight, String unit) => Row(
        children: [
          const Spacer(),
          Text(
            '$_kDemoSets × $_kDemoGoal',
            style: kMono.copyWith(fontSize: 13, color: AppColors.muted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '@',
              style: kMono.copyWith(fontSize: 13, color: AppColors.faint),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(9, 5, 7, 5),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weight,
                  style:
                      kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 3),
                Text(
                  unitSuffix(l10n, unit),
                  style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(width: 7),
                Icon(Icons.edit_outlined, size: 13, color: AppColors.faint),
              ],
            ),
          ),
        ],
      );

  Widget _columnHeaders(AppLocalizations l10n, String unit) {
    Widget h(String t, {double? width}) {
      final child = Text(
        t.toUpperCase(),
        textAlign: TextAlign.center,
        style: kMono.copyWith(
          fontSize: 10,
          letterSpacing: 0.9,
          color: AppColors.faint,
        ),
      );
      return width != null
          ? SizedBox(width: width, child: child)
          : Expanded(child: child);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 5, right: 5),
      child: Row(
        children: [
          h(l10n.sessionColSet, width: 40),
          h(unitSuffix(l10n, unit)),
          h(l10n.sessionColRepsDone),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// The docked rest bar, counting down, with the three things it offers.
class TutorialRestDemo extends ConsumerWidget {
  const TutorialRestDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final weight = fmtWeight(toDisplayWeight(_kDemoWeightKg, unit));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionRestSetUpThenRest(
                l10n.unitWeightShort(weight, unitSuffix(l10n, unit))),
            style:
                kMono.copyWith(fontSize: 11, height: 1.3, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          // Stacked rather than measured-and-maybe-stacked like the real bar:
          // the mock is narrower than the screen it sits on, and one layout is
          // one layout to keep honest.
          Text(
            l10n.tutorialDemoRestSeconds,
            style: kMono.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.good,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in [
                l10n.sessionRestMinus,
                l10n.sessionRestPlus,
                l10n.sessionRestSkip,
              ])
                _pill(label),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          style: kMono.copyWith(fontSize: 12, color: AppColors.text),
        ),
      );
}

/// The workout as the notification shade shows it: where you are, the set to
/// do, and the two buttons that log it without unlocking the phone.
class TutorialShadeDemo extends ConsumerWidget {
  const TutorialShadeDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final weight = fmtWeight(toDisplayWeight(_kDemoWeightKg, unit));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                l10n.commonAppName,
                style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // The two lines the shade actually writes — see shadeTitle and
          // shadeText. Kept to the same shape so the tour is not teaching a
          // notification nobody will recognise.
          Text(
            l10n.shadeWhereExerciseSet(l10n.exerciseBenchPress, 2, _kDemoSets),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.shadeSetWeightReps(
                l10n.unitWeightShort(weight, unitSuffix(l10n, unit)),
                _kDemoGoal),
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final label in [l10n.shadeDone, l10n.shadeMissed])
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Text(
                    label.toUpperCase(),
                    style: kMono.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where a mock set sits relative to the one you are on.
enum _RowState { done, next, todo }

class _SetRowDemo extends StatelessWidget {
  const _SetRowDemo({
    required this.number,
    required this.weight,
    required this.state,
    required this.goal,
    required this.highlightNext,
    required this.highlightCamera,
  });

  final int number;
  final String weight;
  final _RowState state;
  final int goal;
  final bool highlightNext;
  final bool highlightCamera;

  bool get _done => state == _RowState.done;
  bool get _isNext => state == _RowState.next;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.good;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: _isNext
          ? BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent
                    .withValues(alpha: highlightNext ? 0.9 : 0.45),
                width: highlightNext ? 2 : 1,
              ),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 40, child: Center(child: _number(tone))),
            Expanded(child: _cell(weight, tone, filled: _done, bold: false)),
            Expanded(child: _cell('$goal', tone, filled: _done, bold: true)),
            SizedBox(
              width: 36,
              child: Center(
                // Ringed on the logged set only: three rings for one icon
                // would point at the column rather than at the thing, and the
                // filmed set is the one carrying a clip anyway.
                child: _ring(
                  on: highlightCamera && _done,
                  child: Padding(
                    key: kTutorialDemoCameraKey,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Icon(
                      _done ? Icons.videocam_rounded : Icons.videocam_outlined,
                      size: 20,
                      color: _done ? AppColors.accent : AppColors.faint,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _number(Color tone) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _done ? tone.withValues(alpha: 0.15) : AppColors.surface3,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$number',
          style: kMono.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _done ? tone : AppColors.muted,
          ),
        ),
      );

  Widget _cell(String value, Color tone, {
    required bool filled,
    required bool bold,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: filled
                ? tone.withValues(alpha: bold ? 0.15 : 0.10)
                : (bold ? AppColors.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: filled
                  ? tone.withValues(alpha: bold ? 0.55 : 0.30)
                  : AppColors.line,
            ),
          ),
          child: Text(
            value,
            style: kMono.copyWith(
              fontSize: 15,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: filled ? tone : (bold ? AppColors.faint : AppColors.muted),
            ),
          ),
        ),
      );
}

/// Rings [child] in the accent when the current step is about it. Nothing is
/// drawn when it is not, so the ring is only ever on one thing at a time.
Widget _ring({required bool on, required Widget child}) => Container(
      decoration: on
          ? BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent, width: 2),
            )
          : null,
      child: child,
    );
