import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/format.dart';
import 'board_cells.dart';

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

/// Which part of the mock session the current step is talking about. The ring is
/// the tour's own pointer for something too small to spotlight — the icon at the
/// end of a row.
enum TutorialDemoFocus { none, nextSet, rest, note, camera }

/// The note icon on the mock exercise heading.
const kTutorialDemoNoteKey = ValueKey('tutorial-demo-note');

/// A camera cell on a mock set row. One per row, so this matches several.
const kTutorialDemoCameraKey = ValueKey('tutorial-demo-camera');

/// The accent ring the tour draws around the icon a step is about. At most one
/// is on screen at a time.
const kTutorialDemoRingKey = ValueKey('tutorial-demo-ring');

/// The set row behind you, and the one you are on. Both are drawn only by the
/// step about the set rows — see [TutorialBoardDemo].
const kTutorialDemoDoneRowKey = ValueKey('tutorial-demo-done-row');
const kTutorialDemoNextRowKey = ValueKey('tutorial-demo-next-row');

/// The example: a push day of two barbell lifts, three working sets each, the
/// first set of the first lift logged.
///
/// The lifts are named from the starter library rather than spelled out here, so
/// the tour shows them under the names the library screen would give them.
/// Everything else the mock says is its own — see the note on this file.
const _kDemoWeightKg = 80.0;
const _kDemoSecondWeightKg = 45.0;
const _kDemoGoal = 8;
const _kDemoSets = 3;

/// The whole session screen, as the tour draws it: the day's header, its
/// exercises, and the rest bar when the step is about resting.
///
/// **Full size, not a thumbnail.** This is what somebody is about to be looking
/// at for the length of a workout, and a card in the middle of a dimmed screen
/// teaches the card. The callout the overlay puts over it sits at whichever end
/// leaves [focus] uncovered — see `_demoLayout` in `tutorial.dart`.
class TutorialSessionDemo extends ConsumerWidget {
  const TutorialSessionDemo({super.key, this.focus = TutorialDemoFocus.none});

  final TutorialDemoFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.ground,
      child: SafeArea(
        // A column with the bar docked at the bottom, exactly as the real
        // screen has it — the bar takes room rather than lying over the rows.
        child: Column(
          children: [
            _header(l10n),
            Expanded(
              child: ListView(
                // Nothing scrolls it — the mock takes no gestures — but a list
                // is what keeps a long day off the bottom of a short phone.
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TutorialBoardDemo(focus: focus),
                  const SizedBox(height: 12),
                  // A second lift, so the mock reads as a training day rather
                  // than as one movement somebody was shown in isolation. It is
                  // never the subject of a step, so it is never focused.
                  TutorialBoardDemo(
                    name: l10n.exerciseOverheadPress,
                    weightKg: _kDemoSecondWeightKg,
                  ),
                ],
              ),
            ),
            if (focus == TutorialDemoFocus.rest)
              // Capped and scrollable, as the real bar is: docked furniture may
              // not grow without limit, and at the top of the text scale the
              // caption, the clock and the pills together want more height than
              // the screen has under the board.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SingleChildScrollView(
                    child: TutorialRestDemo(ringed: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The session header: the day being trained, and the way out of it.
  Widget _header(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.seedDayPush,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              l10n.sessionFinish,
              style: kMono.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      );
}

/// A miniature of the live board — the exercise, its note icon, and its set
/// rows.
///
/// The board shows only what [focus] is about. A session under way (one set
/// logged, the next outlined) is the subject of one step, so only that step
/// draws it; the note and camera steps get the board at rest with a single ring
/// on the icon they are describing.
class TutorialBoardDemo extends ConsumerWidget {
  const TutorialBoardDemo({
    super.key,
    this.focus = TutorialDemoFocus.none,
    this.name,
    this.weightKg = _kDemoWeightKg,
  });

  final TutorialDemoFocus focus;

  /// The movement, or null for the day's first lift. Named from the starter
  /// library by the caller, so the tour shows what the library screen would.
  final String? name;
  final double weightKg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final weight = fmtWeight(toDisplayWeight(weightKg, unit));

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
          // The board's own headers, not a copy of them: the tour is a still
          // life of the real thing, and a second implementation is how it came
          // to show columns the app had already moved.
          BoardColumnHeaders(unit: unit, timed: false),
          for (var i = 1; i <= _kDemoSets; i++)
            _SetRowDemo(
              number: i,
              weight: weight,
              // Mid-session only on the step that is about the rows: the first
              // is behind you, the second is the one to do now, the rest are
              // still ahead. Every other step leaves the board at rest, so the
              // one ringed icon is the only thing on it asking to be looked at.
              state: focus == TutorialDemoFocus.nextSet
                  ? switch (i) {
                      1 => _RowState.done,
                      2 => _RowState.next,
                      _ => _RowState.todo,
                    }
                  : _RowState.todo,
              goal: _kDemoGoal,
              highlightNext: focus == TutorialDemoFocus.nextSet,
              // One ring, on the first row: three rings for one icon would
              // point at the column rather than at the thing.
              ringCamera: focus == TutorialDemoFocus.camera && i == 1,
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
              name ?? l10n.exerciseBenchPress,
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
  /// A [Wrap] rather than a [Row]: at the top of the text scale the goal, the
  /// "@" and the weight together are wider than a phone, and the weight is the
  /// part that has to stay whole.
  Widget _goalLine(AppLocalizations l10n, String weight, String unit) => Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            '$_kDemoSets × $_kDemoGoal',
            style: kMono.copyWith(fontSize: 13, color: AppColors.muted),
          ),
          Text(
            '@',
            style: kMono.copyWith(fontSize: 13, color: AppColors.faint),
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

}

/// The docked rest bar, counting down, with the three things it offers.
///
/// [ringed] draws the accent border the step about it wants: docked at the
/// bottom of a whole screen it is one band among several, and the ring is what
/// says which one the callout is talking about.
class TutorialRestDemo extends ConsumerWidget {
  const TutorialRestDemo({super.key, this.ringed = false});

  final bool ringed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final weight = fmtWeight(toDisplayWeight(_kDemoWeightKg, unit));

    return Container(
      key: ringed ? kTutorialDemoRingKey : null,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ringed ? AppColors.accent : AppColors.line,
          width: ringed ? 2 : 1,
        ),
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
    required this.ringCamera,
  });

  final int number;
  final String weight;
  final _RowState state;
  final int goal;
  final bool highlightNext;
  final bool ringCamera;

  bool get _done => state == _RowState.done;
  bool get _isNext => state == _RowState.next;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.good;
    return Container(
      key: switch (state) {
        _RowState.done => kTutorialDemoDoneRowKey,
        _RowState.next => kTutorialDemoNextRowKey,
        _RowState.todo => null,
      },
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
            SizedBox(
              width: kSetNumberColumnWidth,
              child: Center(child: _number(tone)),
            ),
            Expanded(
              flex: kWeightColumnFlex,
              child: _cell(weight, tone, primary: false),
            ),
            Expanded(
              flex: kResultColumnFlex,
              // The demo pulses where the board does: on the step about the
              // rows, the cell that logs the set you are on.
              child: BoardPulse(
                on: _isNext && highlightNext,
                builder: (context, pulse) =>
                    _cell('$goal', tone, primary: true, pulse: pulse),
              ),
            ),
            SizedBox(
              width: kSetTrailingColumnWidth,
              child: Center(
                // The accent is the ring's, not the row's: a camera lit up on
                // the logged set drew the eye away from whatever step was
                // running.
                child: _ring(
                  on: ringCamera,
                  child: Padding(
                    key: kTutorialDemoCameraKey,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Icon(
                      ringCamera
                          ? Icons.videocam_rounded
                          : Icons.videocam_outlined,
                      size: 20,
                      color: ringCamera ? AppColors.accent : AppColors.faint,
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

  /// A mock of one cell, wearing the board's own decoration and type.
  Widget _cell(
    String value,
    Color tone, {
    required bool primary,
    double pulse = 0,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: boardCellDecoration(
            primary: primary,
            done: _done,
            tone: tone,
            pulse: pulse,
          ),
          child: Text(
            value,
            style: boardCellTextStyle(
              primary: primary,
              done: _done,
              tone: tone,
            ),
          ),
        ),
      );
}

/// Rings [child] in the accent when the current step is about it. Nothing is
/// drawn when it is not, so the ring is only ever on one thing at a time.
Widget _ring({required bool on, required Widget child}) => Container(
      key: on ? kTutorialDemoRingKey : null,
      decoration: on
          ? BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent, width: 2),
            )
          : null,
      child: child,
    );
