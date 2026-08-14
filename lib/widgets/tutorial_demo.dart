import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/format.dart';
import 'board_cells.dart';
import 'common.dart' show ScreenHeader;
import 'routine_add_menu.dart' show RoutineAddChoice, RoutineAddRow;
import 'builder_widgets.dart'
    show
        BuilderField,
        NumberStepper,
        builderCard,
        builderGrid,
        builderInput,
        builderLabel;

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

/// Which part of the drawn screen the current step is talking about. The ring is
/// the tour's own pointer for something too small to spotlight — the icon at the
/// end of a row.
///
/// The first group belongs to the live session, the second to the builder. They
/// share one enum because a step has one subject, whichever screen it is on.
enum TutorialDemoFocus {
  none,
  nextSet,
  weight,
  rest,
  note,
  camera,
  routinesTab,
  addRoutine,
  library,
  newRoutine,
  importRoutine,
  name,
  days,
  exercises,
  slot,
  superset,
  saveDay,
  save,
}

/// The five screens the builder chapter is drawn on.
enum _BuilderScreen { routines, addMenu, routine, day, slot }

/// Which of them [focus] is about. The routines list is the fallback, so a
/// focus belonging to the session cannot draw a blank screen.
_BuilderScreen _screenFor(TutorialDemoFocus focus) => switch (focus) {
      TutorialDemoFocus.name ||
      TutorialDemoFocus.days ||
      TutorialDemoFocus.save =>
        _BuilderScreen.routine,
      TutorialDemoFocus.exercises || TutorialDemoFocus.saveDay =>
        _BuilderScreen.day,
      // Two steps against one picture: the numbers on the sheet, then the
      // checkbox under them.
      TutorialDemoFocus.slot || TutorialDemoFocus.superset =>
        _BuilderScreen.slot,
      // Three steps against one picture: the three rows of the sheet the + in
      // the corner opens.
      TutorialDemoFocus.library ||
      TutorialDemoFocus.newRoutine ||
      TutorialDemoFocus.importRoutine =>
        _BuilderScreen.addMenu,
      _ => _BuilderScreen.routines,
    };

/// The note icon on the mock exercise heading.
const kTutorialDemoNoteKey = ValueKey('tutorial-demo-note');

/// A camera cell on a mock set row. One per row, so this matches several.
const kTutorialDemoCameraKey = ValueKey('tutorial-demo-camera');

/// The weight the mock exercise is being worked at, on its goal line.
const kTutorialDemoWeightKey = ValueKey('tutorial-demo-weight');

/// The weight cell of a mock set row. One per row, so this matches several.
const kTutorialDemoSetWeightKey = ValueKey('tutorial-demo-set-weight');

/// The + in the corner of the drawn Routines tab.
const kTutorialDemoAddKey = ValueKey('tutorial-demo-add');

/// The Ready-made routines row on the drawn add sheet.
const kTutorialDemoLibraryKey = ValueKey('tutorial-demo-library');

/// The Import a routine row on the same sheet.
const kTutorialDemoImportKey = ValueKey('tutorial-demo-import');

/// The checkbox that joins a drawn slot to the one above it.
const kTutorialDemoSupersetKey = ValueKey('tutorial-demo-superset');

/// The accent ring the tour draws around what a step is about. One at a time,
/// except on the weight step: it is about the difference between the exercise's
/// weight and one set's, so it rings both.
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

/// One of those weights as the gym counting in [unit] would have it.
///
/// The constants are kilograms, and a kilogram pushed straight through
/// [toDisplayWeight] reads 176.37 lb — a bar nobody sets. So the mock snaps to
/// the step the unit counts by rather than carrying a second set of pounds
/// constants: one number, and it stays right if that step ever changes.
///
/// The coarse step rather than the board's own [snapToFineGrid], which is the
/// one place the mock deliberately parts company with the real screen. A real
/// target keeps the arithmetic that made it, tail and all, because a percentage
/// is an instruction; a made-up example has no arithmetic behind it to keep, and
/// a demo board reading 176.25 lb teaches an oddity instead of a bar.
double _demoWeight(double kg, String unit) => snapToUnitStep(kg, unit);

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
            // The board and the bar share what the header leaves, and the
            // LayoutBuilder is how the bar's cap gets measured against that
            // rather than against the whole screen — the same shape the real
            // screen uses, and for the same reason.
            //
            // The bar is *capped*, not [Flexible]: two flex children of one
            // column divide the space between them, which put the bar halfway
            // up the screen with the board squeezed into the top half.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Expanded(
                      child: ListView(
                        // Nothing scrolls it — the mock takes no gestures — but
                        // a list is what keeps a long day off the bottom of a
                        // short phone.
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          TutorialBoardDemo(focus: focus),
                          const SizedBox(height: 12),
                          // A second lift, so the mock reads as a training day
                          // rather than as one movement somebody was shown in
                          // isolation. It is never the subject of a step, so it
                          // is never focused.
                          TutorialBoardDemo(
                            name: l10n.exerciseOverheadPress,
                            weightKg: _kDemoSecondWeightKg,
                          ),
                        ],
                      ),
                    ),
                    if (focus == TutorialDemoFocus.rest)
                      // No padding around it: the bar is docked to the screen
                      // edge, while the board above keeps the list's own inset.
                      ConstrainedBox(
                        // Docked furniture may not grow without limit: at the
                        // top of the text scale the caption, the clock and the
                        // pills together want more height than the board has to
                        // give, and the board is what the screen is for. It
                        // scrolls inside whatever it gets, so nothing is cut.
                        constraints:
                            BoxConstraints(maxHeight: box.maxHeight * 0.45),
                        child: const TutorialRestDemo(ringed: true),
                      ),
                  ],
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
    final landed = _demoWeight(weightKg, unit);
    final weight = fmtWeight(toDisplayWeight(landed, unit));

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
          _goalLine(l10n, unit, landed),
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
              // Likewise for the weight column — and the step that rings it
              // rings the goal line's weight too, because what it is about is
              // the difference between the two.
              ringWeight: focus == TutorialDemoFocus.weight && i == 1,
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
  Widget _goalLine(AppLocalizations l10n, String unit, double landed) => Wrap(
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
          // The board's own weight control, like everything else on this mock
          // — with no tap behind it, since a still life takes none.
          _ring(
            on: focus == TutorialDemoFocus.weight,
            child: WorkingWeight(
              key: kTutorialDemoWeightKey,
              weightKg: landed,
              unit: unit,
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
    final weight = weightWithUnit(l10n, _demoWeight(_kDemoWeightKg, unit), unit);

    return Container(
      key: ringed ? kTutorialDemoRingKey : null,
      // Edge to edge and square-cornered, because that is how the real bar is
      // docked: it is the last row of the screen rather than a card floating
      // above it, so it has a hairline along its top and no side of its own.
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: ringed
            ? Border.all(color: AppColors.accent, width: 2)
            : Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      // Inside the bar rather than around it, as the real one has it: what
      // scrolls when the contents outgrow the cap is the contents, and the
      // background and padding stay put behind them.
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionRestSetUpThenRest(weight),
              style: kMono.copyWith(
                  fontSize: 11, height: 1.3, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            // The clock at one end and the buttons at the other, dropping to
            // two lines when they no longer fit across. The real bar measures
            // its labels to decide; a picture cannot reach that measurement,
            // and a [Wrap] arrives at the same two layouts without one.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                Text(
                  l10n.tutorialDemoRestSeconds,
                  style: kMono.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.good,
                  ),
                ),
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
          ],
        ),
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

/// The routine builder, as the tour draws it: whichever of its three screens
/// [focus] is on, at full size, with the control in question ringed.
///
/// **Drawn rather than driven.** Pointing at the real builder meant marching
/// somebody through four screens the tour does not own — Routines, the routine
/// builder, the day it pushes, and back — waiting on each to mount before a
/// callout could measure anything. Every step was one badly-timed frame away
/// from spotlighting a rectangle that had moved, and the highlight around the
/// name field routinely landed beside it. A picture has none of those failure
/// modes, and the chapter now runs wherever you are standing and leaves you
/// there.
///
/// It is a *picture*, not a screenshot: the fields, lists and rows are the
/// builders' own widgets under the app's own theme, so a change to the real
/// screen shows up here rather than drifting away from it.
class TutorialBuilderDemo extends ConsumerWidget {
  const TutorialBuilderDemo({super.key, required this.focus});

  final TutorialDemoFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    return ColoredBox(
      color: AppColors.ground,
      child: SafeArea(
        child: switch (_screenFor(focus)) {
          _BuilderScreen.routines => _routines(l10n),
          _BuilderScreen.addMenu => _addMenu(l10n),
          _BuilderScreen.routine => _routine(l10n),
          _BuilderScreen.day => _day(l10n, unit),
          _BuilderScreen.slot => _slot(l10n),
        },
      ),
    );
  }

  /// The Routines tab as a fresh install has it: an empty list saying so, and
  /// the + that changes that.
  ///
  /// It used to draw a routine card, from when the app wrote five programs into
  /// every new install. It no longer does, so a card here would be a picture of
  /// somebody else's phone — and the chapter's whole subject is the empty list
  /// the reader is looking at.
  Widget _routines(AppLocalizations l10n) => Column(
        children: [
          Expanded(
            // Scrollable so the header can clip rather than overflow: at the top
            // of the text scale in the longest language, a two-line title and a
            // navigation bar are taller than the room a docked callout leaves.
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                // The screen's own header widget, so a change to it shows up
                // here. The + beside it is drawn rather than borrowed: the real
                // button opens a sheet, and nothing on a picture is wired to
                // anything.
                ScreenHeader(
                  eyebrow: l10n.routinesEyebrow,
                  title: l10n.routinesTitle,
                  trailing: _ringed(
                    on: focus == TutorialDemoFocus.addRoutine,
                    child: KeyedSubtree(
                      key: kTutorialDemoAddKey,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.add, color: AppColors.accent),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.todayNoRoutinesTitle,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          // The only one of the drawn screens that has a navigation bar — the
          // rest are pushed or laid over it — and the reason it is drawn at all:
          // the chapter arrives from the Today steps with nothing on the phone
          // having moved, so the picture has to say which tab it is.
          _navBar(l10n),
        ],
      );

  /// The same tab with the sheet the + opens laid over it, one row ringed.
  ///
  /// The rows are the app's own [RoutineAddRow] with no callback behind them,
  /// so the picture cannot drift from the sheet and cannot be tapped into
  /// anything either.
  Widget _addMenu(AppLocalizations l10n) => Stack(
        fit: StackFit.expand,
        children: [
          _routines(l10n),
          // What a modal sheet puts over the screen behind it, navigation bar
          // included.
          const ColoredBox(color: Colors.black54),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: AppColors.surface,
              // A list rather than a column: at the top of the text scale three
              // rows of wrapped labels are taller than the room a docked callout
              // leaves, and a picture that clips its last row reads better than
              // one that overflows.
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  for (final (choice, key, on) in [
                    (
                      RoutineAddChoice.library,
                      kTutorialDemoLibraryKey,
                      TutorialDemoFocus.library
                    ),
                    (RoutineAddChoice.build, null, TutorialDemoFocus.newRoutine),
                    (
                      RoutineAddChoice.import,
                      kTutorialDemoImportKey,
                      TutorialDemoFocus.importRoutine
                    ),
                  ])
                    _ringed(
                      on: focus == on,
                      child: KeyedSubtree(
                        key: key,
                        child: RoutineAddRow(choice: choice),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );

  /// The bottom navigation bar, with the Routines tab lit.
  Widget _navBar(AppLocalizations l10n) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            for (final (icon, label, on) in [
              (Icons.today_outlined, l10n.navToday, false),
              (Icons.list_alt, l10n.navRoutines, true),
              (Icons.history, l10n.navHistory, false),
              (Icons.person_outline, l10n.navProfile, false),
            ])
              Expanded(
                child: _ringed(
                  on: on && focus == TutorialDemoFocus.routinesTab,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 20,
                          color: on ? AppColors.accent : AppColors.faint),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: on ? AppColors.accent : AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  /// The routine builder: its name field, its training days, and Save.
  Widget _routine(AppLocalizations l10n) => Column(
        children: [
          _bar(l10n.routineEditNewTitle),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                builderLabel(l10n.commonName),
                _ringed(
                  on: focus == TutorialDemoFocus.name,
                  child: TextField(
                    // Never focused and never typed into: it is a picture of a
                    // field, and a keyboard rising over the tour would be the
                    // mock reaching out of its frame.
                    enabled: false,
                    controller: TextEditingController(
                        text: l10n.seedRoutinePushPullLegs),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: builderInput(l10n.routineEditNameHint),
                  ),
                ),
                const SizedBox(height: 20),
                _ringed(
                  on: focus == TutorialDemoFocus.days,
                  child: _list(
                    caption: l10n.routineEditWorkouts,
                    addLabel: l10n.routineEditAddWorkout,
                    rows: [
                      (l10n.seedDayPush, '5'),
                      (l10n.seedDayPull, '5'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _dock(_ringed(
            on: focus == TutorialDemoFocus.save,
            child: _filled(l10n.routineEditSave),
          )),
        ],
      );

  /// One training day: the exercises in it, and the day's own Save.
  Widget _day(AppLocalizations l10n, String unit) => Column(
        children: [
          _bar(l10n.seedDayPush),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                _ringed(
                  on: focus == TutorialDemoFocus.exercises,
                  child: _list(
                    caption: l10n.itemEditorCaption,
                    addLabel: l10n.itemEditorAdd,
                    rows: [
                      (
                        l10n.exerciseBenchPress,
                        _slotSummary(l10n, _kDemoWeightKg, unit)
                      ),
                      (
                        l10n.exerciseOverheadPress,
                        _slotSummary(l10n, _kDemoSecondWeightKg, unit)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _dock(_ringed(
            on: focus == TutorialDemoFocus.saveDay,
            child: _filled(l10n.workoutEditSave),
          )),
        ],
      );

  /// What one row of the day's list says under the movement's name: the target
  /// and the weight, in the shape and the separator `draftSummary` uses. The
  /// weight carries its unit and is landed like every other one the tour draws
  /// — a bare "80" is a kilogram figure shown to a gym counting in pounds.
  String _slotSummary(AppLocalizations l10n, double kg, String unit) =>
      '$_kDemoSets × $_kDemoGoal · '
      '${weightWithUnit(l10n, _demoWeight(kg, unit), unit)}';

  /// One exercise's settings, as the sheet that opens on tapping its row.
  ///
  /// The step about it used to draw the day's list with the row ringed and
  /// describe the sheet in prose — which is a callout naming five fields
  /// against a picture of none of them. The sheet is the subject, so the sheet
  /// is what is drawn. Nothing is ringed on the step about the numbers, for the
  /// same reason: the whole picture is what those words are about. The step after
  /// it rings the one control on the sheet that is not a number.
  ///
  /// **It is the day's second exercise**, because the first has nothing above it
  /// to be joined to and so no superset checkbox — the real sheet leaves the row
  /// out entirely there.
  ///
  /// The cards, the grid and the steppers are the builder's own, so the fields
  /// sit where they sit in the app and read what they read there.
  Widget _slot(AppLocalizations l10n) => Container(
        decoration: BoxDecoration(
          color: AppColors.ground,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.exerciseOverheadPress,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(l10n.muscleShoulders,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(Icons.close, size: 20, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 14),
            builderCard(l10n.itemEditorTarget, [
              builderGrid([
                _field(l10n.itemEditorSets, _kDemoSets),
                _field(l10n.itemEditorReps, _kDemoGoal),
                _field(l10n.itemEditorRest, 90,
                    suffix: l10n.itemEditorSecondsSuffix),
              ]),
              // At the foot of the Target card, where the real sheet has it,
              // and unticked — the step is about what ticking it would do.
              //
              // Only on that step, the way the rest bar is drawn only on the
              // step about resting: the sheet is taller than a short phone with
              // a callout docked under it, and the step before this one names
              // five fields that all have to be on the picture.
              if (focus == TutorialDemoFocus.superset) ...[
                const SizedBox(height: 16),
                _ringed(
                  on: true,
                  child: _check(
                    key: kTutorialDemoSupersetKey,
                    label: l10n.itemEditorSupersetWith(l10n.exerciseBenchPress),
                    tooltip: l10n.itemEditorSupersetWhat,
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            builderCard(l10n.itemEditorProgression, [
              builderGrid([
                _field(l10n.itemEditorStepUpBy, 2, suffix: '.5'),
                _field(l10n.itemEditorCleanSessions, 1),
                _field(l10n.itemEditorBackOffBy, 5),
                _field(l10n.itemEditorMisses, 2),
              ]),
            ]),
          ],
        ),
      );

  /// The drawn checkbox row: the box, what ticking it would do, and the icon
  /// that says what a superset is. Nothing behind any of them — a still life
  /// takes no taps — so the callout beside it is the only explanation on offer
  /// while the tour is up.
  Widget _check({
    required Key key,
    required String label,
    required String tooltip,
  }) =>
      KeyedSubtree(
        key: key,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: false,
                onChanged: (_) {},
                activeColor: AppColors.accent,
                side: BorderSide(color: AppColors.line, width: 1.5),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15)),
            ),
            Tooltip(
              message: tooltip,
              child: Icon(Icons.info_outline,
                  size: 20, color: AppColors.accent),
            ),
          ],
        ),
      );

  /// One captioned number on the drawn sheet. The stepper is the builder's own
  /// and is never pressed — the overlay puts the whole picture behind an
  /// [IgnorePointer].
  Widget _field(String label, int value, {String suffix = ''}) => BuilderField(
        label: label,
        child: NumberStepper(
          value: value,
          suffix: suffix,
          onChanged: (_) {},
        ),
      );

  /// A screen's top bar: a back chevron and the title, as the real ones have.
  Widget _bar(String title) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_back, size: 20, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  /// The docked Save at the foot of both builders.
  Widget _dock(Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: child,
      );

  /// A reorderable list as the builders draw one, minus the reordering: the
  /// caption, the rows and the add button under them.
  Widget _list({
    required String caption,
    required String addLabel,
    required List<(String, String)> rows,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          builderLabel(caption),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _row(rows[i].$1, rows[i].$2),
          ],
          const SizedBox(height: 10),
          _outlined(addLabel),
        ],
      );

  /// One row of such a list: the drag grip, the name, its summary, the bin.
  Widget _row(String title, String subtitle) => Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, size: 20, color: AppColors.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close, size: 18, color: AppColors.faint),
          ],
        ),
      );

  Widget _outlined(String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
      );

  Widget _filled(String label) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.onAccent),
        ),
      );

  /// The accent frame around whatever the current step is about. Drawn *around*
  /// the control rather than as a hole in a scrim, because there is no scrim to
  /// cut — the whole screen is the tour's.
  Widget _ringed({required bool on, required Widget child}) => Container(
        key: on ? kTutorialDemoRingKey : null,
        padding: const EdgeInsets.all(6),
        decoration: on
            ? BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent, width: 2),
              )
            : null,
        child: child,
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
    final weight = weightWithUnit(l10n, _demoWeight(_kDemoWeightKg, unit), unit);

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
            l10n.shadeSetWeightReps(weight, _kDemoGoal),
            style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          // A [Wrap], because these are two words in whatever language the app
          // is in, upper-cased, in a card narrower than the phone — and at the
          // top of the text scale the pair is wider than that card in every
          // language but the one they were written in.
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final label in [l10n.shadeDone, l10n.shadeMissed])
                Text(
                  label.toUpperCase(),
                  style: kMono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.accent,
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
    required this.ringWeight,
  });

  final int number;
  final String weight;
  final _RowState state;
  final int goal;
  final bool highlightNext;
  final bool ringCamera;
  final bool ringWeight;

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
              child: _ring(
                on: ringWeight,
                child: KeyedSubtree(
                  key: kTutorialDemoSetWeightKey,
                  child: _cell(weight, tone, primary: false),
                ),
              ),
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
/// drawn when it is not, so only what a step names is ever ringed.
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
