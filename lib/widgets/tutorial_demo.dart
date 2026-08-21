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

enum _BuilderScreen { routines, addMenu, routine, day, slot }

_BuilderScreen _screenFor(TutorialDemoFocus focus) => switch (focus) {
      TutorialDemoFocus.name ||
      TutorialDemoFocus.days ||
      TutorialDemoFocus.save =>
        _BuilderScreen.routine,
      TutorialDemoFocus.exercises || TutorialDemoFocus.saveDay =>
        _BuilderScreen.day,
      TutorialDemoFocus.slot || TutorialDemoFocus.superset =>
        _BuilderScreen.slot,
      TutorialDemoFocus.library ||
      TutorialDemoFocus.newRoutine ||
      TutorialDemoFocus.importRoutine =>
        _BuilderScreen.addMenu,
      _ => _BuilderScreen.routines,
    };

const kTutorialDemoNoteKey = ValueKey('tutorial-demo-note');

const kTutorialDemoCameraKey = ValueKey('tutorial-demo-camera');

const kTutorialDemoWeightKey = ValueKey('tutorial-demo-weight');

const kTutorialDemoSetWeightKey = ValueKey('tutorial-demo-set-weight');

const kTutorialDemoAddKey = ValueKey('tutorial-demo-add');

const kTutorialDemoLibraryKey = ValueKey('tutorial-demo-library');

const kTutorialDemoImportKey = ValueKey('tutorial-demo-import');

const kTutorialDemoSupersetKey = ValueKey('tutorial-demo-superset');

const kTutorialDemoRingKey = ValueKey('tutorial-demo-ring');

const kTutorialDemoDoneRowKey = ValueKey('tutorial-demo-done-row');
const kTutorialDemoNextRowKey = ValueKey('tutorial-demo-next-row');

const _kDemoWeightKg = 80.0;
const _kDemoSecondWeightKg = 45.0;
const _kDemoGoal = 8;
const _kDemoSets = 3;

double _demoWeight(double kg, String unit) => snapToUnitStep(kg, unit);

class TutorialSessionDemo extends ConsumerWidget {
  const TutorialSessionDemo({super.key, this.focus = TutorialDemoFocus.none});

  final TutorialDemoFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.ground,
      child: SafeArea(
        child: Column(
          children: [
            _header(l10n),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          TutorialBoardDemo(focus: focus),
                          const SizedBox(height: 12),
                          TutorialBoardDemo(
                            name: l10n.exerciseOverheadPress,
                            weightKg: _kDemoSecondWeightKg,
                          ),
                        ],
                      ),
                    ),
                    if (focus == TutorialDemoFocus.rest)
                      ConstrainedBox(
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

class TutorialBoardDemo extends ConsumerWidget {
  const TutorialBoardDemo({
    super.key,
    this.focus = TutorialDemoFocus.none,
    this.name,
    this.weightKg = _kDemoWeightKg,
  });

  final TutorialDemoFocus focus;

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
          BoardColumnHeaders(unit: unit, timed: false),
          for (var i = 1; i <= _kDemoSets; i++)
            _SetRowDemo(
              number: i,
              weight: weight,
              state: focus == TutorialDemoFocus.nextSet
                  ? switch (i) {
                      1 => _RowState.done,
                      2 => _RowState.next,
                      _ => _RowState.todo,
                    }
                  : _RowState.todo,
              goal: _kDemoGoal,
              highlightNext: focus == TutorialDemoFocus.nextSet,
              ringCamera: focus == TutorialDemoFocus.camera && i == 1,
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
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: ringed
            ? Border.all(color: AppColors.accent, width: 2)
            : Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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

  Widget _routines(AppLocalizations l10n) => Column(
        children: [
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
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
          _navBar(l10n),
        ],
      );

  Widget _addMenu(AppLocalizations l10n) => Stack(
        fit: StackFit.expand,
        children: [
          _routines(l10n),
          const ColoredBox(color: Colors.black54),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: AppColors.surface,
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

  String _slotSummary(AppLocalizations l10n, double kg, String unit) =>
      '$_kDemoSets × $_kDemoGoal · '
      '${weightWithUnit(l10n, _demoWeight(kg, unit), unit)}';

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

  Widget _field(String label, int value, {String suffix = ''}) => BuilderField(
        label: label,
        child: NumberStepper(
          value: value,
          suffix: suffix,
          onChanged: (_) {},
        ),
      );

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

  Widget _dock(Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: child,
      );

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
              child: BoardPulse(
                on: _isNext && highlightNext,
                builder: (context, pulse) =>
                    _cell('$goal', tone, primary: true, pulse: pulse),
              ),
            ),
            SizedBox(
              width: kSetTrailingColumnWidth,
              child: Center(
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
