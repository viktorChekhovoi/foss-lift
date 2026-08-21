import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart' show WorkoutItemView;
import '../data/plates.dart';
import '../data/warmup.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../services/workout_shade.dart' show restIsOverLine;
import '../state/active_workout.dart';
import '../state/workout_cue.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';
import '../util/target_label.dart';
import '../util/cardio_units.dart';
import '../util/units.dart';
import '../widgets/board_cells.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/common.dart';
import '../widgets/plate_line.dart';
import '../widgets/workout_items_editor.dart'
    show ItemDraft, itemUpdate, showItemConfigSheet;

const kNextSetKey = ValueKey('next-set');
const kNextWarmupKey = ValueKey('next-warmup');

const _wholeBoard = ScrollCacheExtent.pixels(100000);

const kExerciseGoalKey = ValueKey('exercise-goal');
const kCycleWeekKey = ValueKey('cycle-week');

const kSlotSettingsKey = ValueKey('slot-settings');

const kConsoleToggleKey = ValueKey('console-toggle');
const kConsoleFieldsKey = ValueKey('console-fields');
const kConsoleSummaryKey = ValueKey('console-summary');

bool _showsWeight(ExerciseEntry e) =>
    e.weightType.carriesWeight && e.carriesLoad;

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  ({int exercise, int set})? _holding;
  int _held = 0;
  Timer? _holdTimer;

  // Capture the notifier before dispose; reading ref during teardown is unsafe.
  late final WorkoutScreenVisible _visibility = ref.read(
    workoutScreenVisibleProvider.notifier,
  );

  // ensureVisible needs a renderable element, so this key is attached only while the initial scroll target is being built.
  final _openOn = GlobalKey();

  // Build every row for the initial ensureVisible call, then return to lazy list construction.
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    // Defer the provider update until the first build has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visibility.set(true);
      _openWhereYouAre();
    });
  }

  Widget _openOnRow(Widget row, {required bool marked}) =>
      _opening && marked ? KeyedSubtree(key: _openOn, child: row) : row;

  void _openWhereYouAre() {
    final ctx = _openOn.currentContext;
    if (ctx != null && !_onScreen(ctx)) {
      Scrollable.ensureVisible(ctx, alignment: 0.35);
    }
    setState(() => _opening = false);
  }

  bool _onScreen(BuildContext ctx) {
    final row = ctx.findRenderObject() as RenderBox?;
    final viewport =
        Scrollable.of(ctx).context.findRenderObject() as RenderBox?;
    if (row == null || viewport == null) return true;
    final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top >= 0 && top + row.size.height <= viewport.size.height;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    final visibility = _visibility;
    Future.microtask(() => visibility.set(false));
    super.dispose();
  }

  void _startRest(int seconds, RestPrompt? prompt, RestSetRef forSet) => ref
      .read(activeWorkoutProvider.notifier)
      .startRest(seconds, prompt, forSet: forSet);

  void _skipRest() => ref.read(activeWorkoutProvider.notifier).stopRest();

  void _dropRest() =>
      ref.read(activeWorkoutProvider.notifier).stopRest(tone: false);

  void _restForSet(
    int ei,
    int index, {
    required bool warmup,
    required bool wasDone,
  }) {
    final session = ref.read(activeWorkoutProvider);
    if (session == null) return;
    final e = session.exercises[ei];
    final at = (exercise: ei, set: index, warmup: warmup);
    final nowDone = (warmup ? e.warmups[index] : e.sets[index]).done;
    if (nowDone == wasDone) return;
    if (!nowDone) {
      if (session.restFor == at) _dropRest();
      return;
    }
    final rest = session.restAfter(ei, index, warmup: warmup);
    if (rest.seconds == 0) return;
    _startRest(rest.seconds, rest.prompt, at);
  }

  void _tone() => ref.read(restToneProvider).play();

  void _tapTimed(int ei, int si, SetEntry entry) {
    final h = _holding;
    if (h != null && h.exercise == ei && h.set == si) {
      _stopHold();
      return;
    }
    if (entry.done) {
      ref.read(activeWorkoutProvider.notifier).setLogged(ei, si, null);
      HapticFeedback.selectionClick();
      _restForSet(ei, si, warmup: false, wasDone: true);
      return;
    }
    _startHold(ei, si);
  }

  void _startHold(int ei, int si) {
    if (_holding != null) _stopHold();
    _dropRest();
    HapticFeedback.selectionClick();
    setState(() {
      _holding = (exercise: ei, set: si);
      _held = 0;
    });
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _held++);
    });
  }

  void _stopHold() {
    final h = _holding;
    _holdTimer?.cancel();
    _holdTimer = null;
    if (h == null) return;
    final seconds = _held;
    setState(() {
      _holding = null;
      _held = 0;
    });
    HapticFeedback.selectionClick();
    ref
        .read(activeWorkoutProvider.notifier)
        .setLogged(h.exercise, h.set, seconds);
    _tone();
    final session = ref.read(activeWorkoutProvider);
    if (session != null) {
      final rest = session.restAfter(h.exercise, h.set, warmup: false);
      if (rest.seconds > 0) {
        _startRest(
          rest.seconds,
          rest.prompt,
          (exercise: h.exercise, set: h.set, warmup: false),
        );
      }
    }
  }

  Future<void> _editResult(int ei, int si, SetEntry entry) async {
    final result = await showAppDialog<({int? value})>(
      context,
      keyboard: TextInputType.number,
      builder: (_) => _ResultDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final wasDone = entry.done;
    ref.read(activeWorkoutProvider.notifier).setLogged(ei, si, result.value);
    _restForSet(ei, si, warmup: false, wasDone: wasDone);
  }

  Future<void> _editWarmupResult(int ei, int wi, SetEntry entry) async {
    final result = await showAppDialog<({int? value})>(
      context,
      keyboard: TextInputType.number,
      builder: (_) => _ResultDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final wasDone = entry.done;
    ref
        .read(activeWorkoutProvider.notifier)
        .setWarmupLogged(ei, wi, result.value);
    _restForSet(ei, wi, warmup: true, wasDone: wasDone);
  }

  Future<double?> _askWeight(
    ExerciseEntry e, {
    required String title,
    required double weightKg,
    required double minKg,
    String? subtitle,
  }) => showAppDialog<double>(
    context,
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    builder: (_) => _WeightDialog(
      title: title,
      subtitle: subtitle,
      weightKg: weightKg,
      minKg: minKg,
      unit: e.unit,
    ),
  );

  double _floorFor(ExerciseEntry e) => loadFloorKg(
    type: e.weightType,
    defaultBarKg: ref.read(plateSettingsProvider).barKg,
    barKg: e.barKg,
  );

  Future<void> _editWorkingWeight(int ei) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    if (e == null) return;
    final kg = await _askWeight(
      e,
      title: seededName(AppLocalizations.of(context), e.seedKey, e.name),
      weightKg: e.workingKg ?? 0,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWorkingWeight(ei, kg);
  }

  Widget _withConsole(
    int ei,
    int si,
    SetEntry entry,
    String unit, {
    required bool cardio,
    required Widget row,
  }) {
    if (!cardio) return row;
    return _ConsoleRow(
      key: ValueKey('console-$ei-$si'),
      entry: entry,
      unit: unit,
      onChanged: (m) =>
          ref.read(activeWorkoutProvider.notifier).setConsole(ei, si, m),
      row: row,
    );
  }

  Future<void> _editSlot(int ei) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    final itemId = e?.itemId;
    if (itemId == null) return;
    final db = ref.read(databaseProvider);
    final item = await db.workoutItemById(itemId);
    if (item == null || !mounted) return;
    final exercise = await db.exerciseById(item.exerciseId);
    if (!mounted) return;

    final barKg = ref.read(plateSettingsProvider).barKg;
    final draft = ItemDraft.fromView(WorkoutItemView(item, exercise));
    await showItemConfigSheet(
      context,
      draft: draft,
      unit: e!.unit,
      routineRest: e.restSeconds,
      defaultBarKg: barKg,
      onChanged: () {},
    );
    if (!mounted) return;
    await db.updateWorkoutItem(itemId, itemUpdate(draft, defaultBarKg: barKg));
    await ref.read(activeWorkoutProvider.notifier).reconfigure(ei);
  }

  Future<void> _video(int ei, int si, SetEntry entry) async {
    if (entry.videoPath == null) {
      await context.push('/session/record/$ei/$si');
      return;
    }
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.videocam_rounded, color: AppColors.accent),
              title: Text(l10n.sessionVideoRefilm),
              onTap: () => Navigator.pop(sheet, 'again'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.muted),
              title: Text(l10n.sessionVideoDelete),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'again') {
      await context.push('/session/record/$ei/$si');
    } else if (choice == 'delete') {
      await ref.read(activeWorkoutProvider.notifier).removeVideo(ei, si);
    }
  }

  Future<void> _editSetWeight(int ei, int si) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    if (e == null) return;
    final l10n = AppLocalizations.of(context);
    final kg = await _askWeight(
      e,
      title: l10n.sessionSetTitle(si + 1),
      subtitle: l10n.sessionSetOnly,
      weightKg: e.sets[si].weight,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWeight(ei, si, kg);
  }

  Future<void> _editWarmupWeight(int ei, int wi) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    if (e == null) return;
    final l10n = AppLocalizations.of(context);
    final kg = await _askWeight(
      e,
      title: l10n.sessionWarmupTitle(wi + 1),
      subtitle: l10n.sessionWarmupOnly,
      weightKg: e.warmups[wi].weight,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWarmupWeight(ei, wi, kg);
  }

  Future<void> _finish() async {
    final session = ref.read(activeWorkoutProvider);
    if (session == null) return;
    final unlogged = session.totalSets - session.doneSets;
    if (unlogged > 0 && !await _confirmUnlogged(unlogged)) return;

    final id = await ref.read(activeWorkoutProvider.notifier).finish();
    if (!mounted) return;
    if (id != null) {
      context.pushReplacement('/summary/$id');
    } else {
      context.go('/today');
    }
  }

  Future<bool> _confirmUnlogged(int unlogged) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.sessionFinishUnloggedTitle(unlogged)),
        content: Text(
          l10n.sessionFinishUnloggedBody,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.sessionFinishUnloggedBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            child: Text(l10n.sessionFinishUnloggedConfirm),
          ),
        ],
      ),
    );
    return sure == true && mounted;
  }

  Future<void> _abort() async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.sessionAbortTitle),
        content: Text(
          l10n.sessionAbortBody,
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.sessionAbortKeep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            child: Text(l10n.sessionAbortConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).discard();
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeWorkoutProvider);
    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(activeWorkoutProvider.notifier);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);
    final cue = nextUp(session);
    final next = cue == null || cue.kind == CueKind.finished ? null : cue;
    final restUnit = switch (session.restFor?.exercise) {
      final int ei when ei < session.exercises.length =>
        session.exercises[ei].unit,
      _ => unit,
    };
    final cueUnit = cue == null ? unit : session.unitForCue(cue);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: seededName(l10n, session.seedKey, session.name),
              onFinish: _finish,
              onAbort: _abort,
            ),
            _StatStrip(session: session),
            _LoggingHint(anyTimed: session.exercises.any((e) => e.mode.timed)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        scrollCacheExtent: _opening ? _wholeBoard : null,
                        children: [
                          if (session.notice case final notice?)
                            _SessionNotice(notice: notice),
                          for (final group in session.supersetGroupList)
                            _SupersetBracket(
                              first: group.first,
                              on: group.length > 1,
                              children: [
                                for (final ei in group)
                                  _ExerciseBlock(
                                    index: ei,
                                    exercise: session.exercises[ei],
                                    unit: session.exercises[ei].unit,
                                    plates: plates,
                                    warmupIsNext:
                                        next != null &&
                                        next.warmup &&
                                        next.exerciseIndex == ei,
                                    onWarmupCount: (n) =>
                                        controller.setWarmupCount(ei, n),
                                    onEditWorkingWeight: () => _editWorkingWeight(ei),
                                    onSettings:
                                        session.exercises[ei].itemId == null
                                        ? null
                                        : () => _editSlot(ei),
                                    warmupRowBuilder: (wi) {
                                      final entry = session.exercises[ei].warmups[wi];
                                      final marked =
                                          next != null &&
                                          next.warmup &&
                                          next.exerciseIndex == ei &&
                                          next.setIndex == wi;
                                      return _openOnRow(
                                        marked: marked,
                                        _SetRow(
                                          key: ValueKey(
                                            'w$ei-$wi-${session.exercises[ei].name}',
                                          ),
                                          number: wi + 1,
                                          entry: entry,
                                          unit: session.exercises[ei].unit,
                                          isNext: marked,
                                          perSide: perSideLabel(
                                            l10n: l10n,
                                            weightKg: entry.weight,
                                            type: session
                                                .exercises[ei]
                                                .weightType,
                                            settings: plates,
                                            unit: session.exercises[ei].unit,
                                            barKg: session.exercises[ei].barKg,
                                          ),
                                          onEditWeight: () =>
                                              _editWarmupWeight(ei, wi),
                                          onTap: () {
                                            final wasDone = entry.done;
                                            controller.cycleWarmup(ei, wi);
                                            HapticFeedback.selectionClick();
                                            _restForSet(
                                              ei,
                                              wi,
                                              warmup: true,
                                              wasDone: wasDone,
                                            );
                                          },
                                          onTypeResult: () =>
                                              _editWarmupResult(ei, wi, entry),
                                        ),
                                      );
                                    },
                                    rowBuilder: (si) {
                                      final entry = session.exercises[ei].sets[si];
                                      final marked =
                                          next != null &&
                                          !next.warmup &&
                                          next.exerciseIndex == ei &&
                                          next.setIndex == si;
                                      return _openOnRow(
                                        marked: marked,
                                        _withConsole(
                                          ei,
                                          si,
                                          entry,
                                          session.exercises[ei].unit,
                                          cardio: session
                                              .exercises[ei]
                                              .cardioMachine,
                                          row: _SetRow(
                                          key: ValueKey(
                                            '$ei-$si-${session.exercises[ei].name}',
                                          ),
                                          number: si + 1,
                                          entry: entry,
                                          unit: session.exercises[ei].unit,
                                          isNext: marked,
                                          onEditWeight: () => _editSetWeight(ei, si),
                                          showWeight: _showsWeight(
                                            session.exercises[ei],
                                          ),
                                          holdingSeconds:
                                              _holding?.exercise == ei &&
                                                  _holding?.set == si
                                              ? _held
                                              : null,
                                          onTap: () {
                                            if (entry.timed) {
                                              _tapTimed(ei, si, entry);
                                              return;
                                            }
                                            final wasDone = entry.done;
                                            controller.cycleSet(ei, si);
                                            HapticFeedback.selectionClick();
                                            _restForSet(
                                              ei,
                                              si,
                                              warmup: false,
                                              wasDone: wasDone,
                                            );
                                          },
                                          onTypeResult: () =>
                                              _editResult(ei, si, entry),
                                          onVideo:
                                              ref
                                                  .watch(capabilitiesProvider)
                                                  .setVideos
                                              ? () => _video(ei, si, entry)
                                              : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (session.restLeft > 0 || session.restDone)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight / 2,
                        ),
                        child: _RestBanner(
                          secondsLeft: session.restLeft,
                          prompt: session.restPrompt,
                          done: session.restDone
                              ? restIsOverLine(l10n, cue, cueUnit)
                              : null,
                          unit: restUnit,
                          onSub: () => ref
                              .read(activeWorkoutProvider.notifier)
                              .nudgeRest(-15),
                          onAdd: () => ref
                              .read(activeWorkoutProvider.notifier)
                              .nudgeRest(15),
                          onSkip: _skipRest,
                        ),
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
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onFinish,
    required this.onAbort,
  });
  final String title;
  final VoidCallback onFinish;
  final VoidCallback onAbort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/today'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: l10n.sessionMinimize,
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onAbort,
            icon: Icon(Icons.delete_outline, color: AppColors.muted),
            tooltip: l10n.sessionAbortTooltip,
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.good,
              foregroundColor: const Color(0xFF062015),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            onPressed: onFinish,
            child: Text(l10n.sessionFinish),
          ),
        ],
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.session});
  final ActiveWorkout session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stat(
              label: l10n.sessionStatDuration,
              value: fmtDuration(session.elapsed),
            ),
            VerticalDivider(width: 1, color: AppColors.line),
            _Stat(
              label: l10n.sessionStatSets,
              value: '${session.doneSets}/${session.totalSets}',
              accent: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Text(
              value,
              style: kMono.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: accent ? AppColors.accent : AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              style: kMono.copyWith(
                fontSize: 10,
                letterSpacing: 1.0,
                color: AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.notice});

  final LayoffNotice notice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_down_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)
                  .startWorkoutDeloadNotice(notice.percent, notice.days),
              style: kMono.copyWith(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoggingHint extends StatelessWidget {
  const _LoggingHint({required this.anyTimed});

  final bool anyTimed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Text(
        anyTimed
            ? '${l10n.sessionLoggingHint}\n${l10n.sessionLoggingHintTimed}'
            : l10n.sessionLoggingHint,
        style: kMono.copyWith(
          fontSize: 11,
          height: 1.45,
          color: AppColors.faint,
        ),
      ),
    );
  }
}

class _SupersetBracket extends StatelessWidget {
  const _SupersetBracket({
    required this.first,
    required this.on,
    required this.children,
  });

  final int first;
  final bool on;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!on) return Column(children: children);
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: ValueKey('superset-group-$first'),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.commonSuperset,
            style: kMono.copyWith(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.index,
    required this.exercise,
    required this.unit,
    required this.plates,
    required this.rowBuilder,
    required this.warmupRowBuilder,
    required this.warmupIsNext,
    required this.onWarmupCount,
    required this.onEditWorkingWeight,
    this.onSettings,
  });

  final int index;
  final ExerciseEntry exercise;
  final String unit;
  final PlateSettings plates;
  final Widget Function(int setIndex) rowBuilder;
  final Widget Function(int warmupIndex) warmupRowBuilder;

  final bool warmupIsNext;
  final ValueChanged<int> onWarmupCount;
  final VoidCallback onEditWorkingWeight;

  final VoidCallback? onSettings;

  String? _goal(AppLocalizations l10n) {
    if (exercise.sets.isEmpty) return null;
    final first = exercise.sets.first;
    final sets = exercise.sets.length;
    if (!first.timed &&
        exercise.sets.any((s) =>
            s.goal != first.goal ||
            s.goalMin != first.goalMin ||
            s.amrap != first.amrap)) {
      return joinRowLabels(
        l10n,
        exercise.sets.map((s) => rowLabel(
              l10n,
              reps: s.goalMin,
              repsMax: s.goal,
              amrap: s.amrap,
            )),
      );
    }
    if (!first.timed && first.amrap) {
      return '${l10n.sessionGoalCounted(sets, first.goal)}+';
    }
    return first.timed
        ? l10n.sessionGoalTimed(sets, first.goal)
        : l10n.sessionGoalCounted(sets, first.goal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExerciseHeading(
            name: seededName(l10n, exercise.seedKey, exercise.name),
            subtitle: exercise.cycleWeeks == 0
                ? null
                : cycleWeekLine(l10n, exercise.cycleWeekName,
                    exercise.cycleWeek, exercise.cycleWeeks),
            exerciseId: exercise.exerciseId,
            onSettings: onSettings,
          ),
          if (exercise.hasWarmups)
            _WarmupGroup(
              index: index,
              exercise: exercise,
              unit: unit,
              isNext: warmupIsNext,
              onCount: onWarmupCount,
              rowBuilder: warmupRowBuilder,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Row(
              children: [
                if (exercise.hasWarmups)
                  Flexible(
                    child: Text(
                      l10n.sessionWorkingSets,
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                const Spacer(),
                if (_goal(l10n) case final goal?)
                  Text(
                    goal,
                    key: kExerciseGoalKey,
                    style: kMono.copyWith(fontSize: 13, color: AppColors.muted),
                  ),
                if (_showsWeight(exercise)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      exercise.runsPercentages
                          ? l10n.sessionTrainingMaxShort
                          : '@',
                      style: kMono.copyWith(
                        fontSize: 13,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  WorkingWeight(
                    key: ValueKey('working-weight-$index'),
                    weightKg: exercise.workingKg,
                    unit: unit,
                    onTap: onEditWorkingWeight,
                  ),
                ],
              ],
            ),
          ),
          if (exercise.nextWeight case final w? when _showsWeight(exercise))
            PlateLine(
              weightKg: w,
              type: exercise.weightType,
              settings: plates,
              unit: unit,
              barKg: exercise.barKg,
            ),
          const SizedBox(height: 6),
          BoardColumnHeaders(
            unit: unit,
            timed: exercise.mode.timed,
            showWeight: _showsWeight(exercise),
          ),
          for (var si = 0; si < exercise.sets.length; si++) rowBuilder(si),
        ],
      ),
    );
  }
}

class _ExerciseHeading extends ConsumerWidget {
  const _ExerciseHeading({
    required this.name,
    this.subtitle,
    this.exerciseId,
    this.onSettings,
  });
  final String name;

  final String? subtitle;

  final int? exerciseId;

  final VoidCallback? onSettings;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    int id,
    String? note,
  ) async {
    final written = await askNote(context, title: name, initial: note);
    if (written == null || !context.mounted) return;
    await ref.read(databaseProvider).setExerciseNotes(id, written);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = exerciseId;
    final note = id == null ? null : ref.watch(exerciseNoteProvider(id));

    Widget icon(
      IconData glyph,
      String tooltip,
      VoidCallback onPressed, {
      bool lit = false,
      Key? key,
    }) => IconButton(
      key: key,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(
        glyph,
        size: 18,
        color: lit ? AppColors.accent : AppColors.muted,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (id != null)
              icon(
                note == null
                    ? Icons.note_add_outlined
                    : Icons.sticky_note_2_outlined,
                note == null ? l10n.sessionAddNote : l10n.sessionMyNote,
                () => _open(context, ref, id, note),
                lit: note != null,
              ),
            if (onSettings case final open?)
              icon(
                Icons.tune,
                l10n.sessionSlotSettings,
                open,
                key: kSlotSettingsKey,
              ),
          ],
        ),
        if (subtitle case final line?)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 2),
            child: Text(
              line,
              key: kCycleWeekKey,
              style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}

class _WarmupGroup extends StatefulWidget {
  const _WarmupGroup({
    required this.index,
    required this.exercise,
    required this.unit,
    required this.isNext,
    required this.onCount,
    required this.rowBuilder,
  });

  final int index;
  final ExerciseEntry exercise;
  final String unit;

  final bool isNext;
  final ValueChanged<int> onCount;
  final Widget Function(int warmupIndex) rowBuilder;

  @override
  State<_WarmupGroup> createState() => _WarmupGroupState();
}

class _WarmupGroupState extends State<_WarmupGroup> {
  late bool _open = widget.exercise.warmupCount > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exercise = widget.exercise;
    final count = exercise.warmupCount;
    final built = exercise.warmups.length;
    final ranOut = built < count;
    final summary = l10n.sessionWarmupSummary(built);
    final marked = widget.isNext && !_open;
    return Container(
      key: ValueKey('warmup-${widget.index}'),
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.fromLTRB(12, 6, 12, _open ? 10 : 6),
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              key: marked ? kNextWarmupKey : null,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: marked ? AppColors.accent : AppColors.faint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sessionWarmupLabel,
                    style: kMono.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: marked ? AppColors.accent : AppColors.faint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '· $summary',
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sessionWarmupSets,
                      style: kMono.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  _CountStepper(
                    key: ValueKey('warmup-count-${widget.index}'),
                    count: built,
                    onSub: built > 0 || count > 0
                        ? () => widget.onCount(built > 0 ? built - 1 : 0)
                        : null,
                    onAdd: !ranOut && built < kMaxWarmupSets
                        ? () => widget.onCount(built + 1)
                        : null,
                  ),
                ],
              ),
            ),
            if (built == 0 && count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.sessionWarmupTooLight,
                  style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
                ),
              ),
            if (built > 0) ...[
              const SizedBox(height: 4),
              BoardColumnHeaders(unit: widget.unit, timed: false),
              for (var wi = 0; wi < built; wi++) widget.rowBuilder(wi),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.sessionWarmupDisclaimer,
              style: kMono.copyWith(
                fontSize: 9.5,
                height: 1.4,
                color: AppColors.faint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({
    super.key,
    required this.count,
    required this.onSub,
    required this.onAdd,
  });
  final int count;
  final VoidCallback? onSub;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    Widget btn(String glyph, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.surface2 : AppColors.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          glyph,
          style: kMono.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.faint : AppColors.text,
          ),
        ),
      ),
    );

    return Row(
      children: [
        btn('−', onSub),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$count',
            style: kMono.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        btn('+', onAdd),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.entry,
    required this.unit,
    required this.onEditWeight,
    required this.onTap,
    required this.onTypeResult,
    this.isNext = false,
    this.showWeight = true,
    this.onVideo,
    this.holdingSeconds,
    this.perSide,
  });
  final int number;
  final SetEntry entry;
  final String unit;

  final String? perSide;

  final bool showWeight;

  final bool isNext;
  final VoidCallback onEditWeight;
  final VoidCallback onTap;
  final VoidCallback onTypeResult;

  final VoidCallback? onVideo;

  final int? holdingSeconds;

  SetEntry get _entry => entry;

  Color get _tone => holdingSeconds != null
      ? AppColors.accent
      : (_entry.missedGoal ? AppColors.gold : AppColors.good);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: isNext ? kNextSetKey : null,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: isNext
          ? BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.45),
              ),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: kSetNumberColumnWidth,
              child: Center(child: _setNumber()),
            ),
            if (showWeight)
              Expanded(flex: kWeightColumnFlex, child: _weightCell()),
            Expanded(
              flex: kResultColumnFlex,
              child: _resultBox(AppLocalizations.of(context)),
            ),
            SizedBox(
              width: kSetTrailingColumnWidth,
              child: onVideo == null
                  ? const SizedBox.shrink()
                  : Center(child: _cameraCell()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraCell() {
    final has = _entry.videoPath != null;
    return GestureDetector(
      key: const ValueKey('set-video'),
      onTap: onVideo,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Icon(
          has ? Icons.videocam_rounded : Icons.videocam_outlined,
          size: 20,
          color: has ? AppColors.accent : AppColors.faint,
        ),
      ),
    );
  }

  Widget _setNumber() {
    final done = _entry.done;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? _tone.withValues(alpha: 0.15) : AppColors.surface3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$number',
        style: kMono.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: done ? _tone : AppColors.muted,
        ),
      ),
    );
  }

  Widget _weightCell() {
    final done = _entry.done;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        key: const ValueKey('set-weight'),
        onTap: onEditWeight,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: boardCellDecoration(
            primary: false,
            done: done,
            tone: _tone,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtWeightValue(_entry.weight, unit),
                style: boardCellTextStyle(
                  primary: false,
                  done: done,
                  tone: _tone,
                ),
              ),
              if (perSide case final label?)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kMono.copyWith(fontSize: 9.5, color: AppColors.faint),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultBox(AppLocalizations l10n) {
    final holding = holdingSeconds != null;
    final done = _entry.done || holding;
    final seconds = holdingSeconds ?? _entry.logged ?? _entry.goal;
    final value = holding || _entry.timed
        ? l10n.unitSecondsShort('$seconds')
        : '${_entry.logged ?? _entry.goal}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        key: const ValueKey('set-result'),
        onTap: onTap,
        onLongPress: onTypeResult,
        behavior: HitTestBehavior.opaque,
        child: BoardPulse(
          on: isNext && !done,
          builder: (context, pulse) => Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: boardCellDecoration(
              primary: true,
              done: done,
              tone: _tone,
              pulse: pulse,
              emphasised: holding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (holding) ...[
                  Icon(Icons.stop_rounded, size: 13, color: _tone),
                  const SizedBox(width: 3),
                ],
                Text(
                  value,
                  style: boardCellTextStyle(
                    primary: true,
                    done: done,
                    tone: _tone,
                  ),
                ),
                if (_entry.missedGoal && !holding) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_downward_rounded, size: 13, color: _tone),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsoleRow extends StatefulWidget {
  const _ConsoleRow({
    super.key,
    required this.entry,
    required this.unit,
    required this.onChanged,
    required this.row,
  });

  final SetEntry entry;
  final String unit;
  final ValueChanged<ConsoleMetrics> onChanged;

  final Widget row;

  @override
  State<_ConsoleRow> createState() => _ConsoleRowState();
}

class _ConsoleRowState extends State<_ConsoleRow> {
  late bool _open = widget.entry.hasConsole;

  ConsoleMetrics get _m => widget.entry.console;

  void _write({
    double? Function()? speed,
    double? Function()? incline,
    int? Function()? resistance,
    double? Function()? distance,
  }) => widget.onChanged((
    speedKph: speed == null ? _m.speedKph : speed(),
    inclinePercent: incline == null ? _m.inclinePercent : incline(),
    resistanceLevel: resistance == null ? _m.resistanceLevel : resistance(),
    distanceKm: distance == null ? _m.distanceKm : distance(),
  ));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = cardioSummary(l10n, _m, unit: widget.unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.row,
        Padding(
          padding: const EdgeInsets.only(left: kSetNumberColumnWidth, bottom: 2),
          child: Row(
            children: [
              GestureDetector(
                key: kConsoleToggleKey,
                onTap: () => setState(() => _open = !_open),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _open
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 16,
                        color: AppColors.faint,
                      ),
                      Text(
                        l10n.sessionConsoleDetails,
                        style: kMono.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_open && summary != null)
                Expanded(
                  child: Text(
                    summary,
                    key: kConsoleSummaryKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kMono.copyWith(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_open)
          Padding(
            key: kConsoleFieldsKey,
            padding: const EdgeInsets.only(
              left: kSetNumberColumnWidth,
              bottom: 8,
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _ConsoleField(
                  label: l10n.sessionConsoleSpeed,
                  suffix: speedSuffix(l10n, widget.unit),
                  value: _m.speedKph == null
                      ? null
                      : toDisplaySpeed(_m.speedKph!, widget.unit),
                  onChanged: (v) => _write(
                    speed: () =>
                        v == null ? null : speedToKph(v, widget.unit),
                  ),
                ),
                _ConsoleField(
                  label: l10n.sessionConsoleIncline,
                  suffix: '%',
                  value: _m.inclinePercent,
                  onChanged: (v) => _write(incline: () => v),
                ),
                _ConsoleField(
                  label: l10n.sessionConsoleResistance,
                  value: _m.resistanceLevel?.toDouble(),
                  decimals: false,
                  onChanged: (v) => _write(resistance: () => v?.round()),
                ),
                _ConsoleField(
                  label: l10n.sessionConsoleDistance,
                  suffix: distanceSuffix(l10n, widget.unit),
                  value: _m.distanceKm == null
                      ? null
                      : toDisplayDistance(_m.distanceKm!, widget.unit),
                  onChanged: (v) => _write(
                    distance: () =>
                        v == null ? null : distanceToKm(v, widget.unit),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConsoleField extends StatefulWidget {
  const _ConsoleField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.decimals = true,
  });

  final String label;
  final String? suffix;
  final double? value;
  final bool decimals;
  final ValueChanged<double?> onChanged;

  @override
  State<_ConsoleField> createState() => _ConsoleFieldState();
}

class _ConsoleFieldState extends State<_ConsoleField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value == null ? '' : fmtUpTo(widget.value!, 2),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _report(String text) {
    final trimmed = text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final v = double.tryParse(trimmed);
    if (v == null) return;
    widget.onChanged(v < 0 ? 0 : v);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.decimals,
        ),
        style: kMono.copyWith(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.label,
          labelStyle: TextStyle(fontSize: 11, color: AppColors.muted),
          suffixText: widget.suffix,
          suffixStyle: kMono.copyWith(fontSize: 11, color: AppColors.faint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.line),
          ),
        ),
        onChanged: _report,
      ),
    );
  }
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.weightKg,
    required this.unit,
    this.subtitle,
    this.minKg = 0,
  });
  final String title;

  final String? subtitle;
  final double weightKg;
  final String unit;

  final double minKg;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _c = TextEditingController(
    text: fmtWeight(toDisplayWeight(widget.weightKg, widget.unit)),
  );

  String? _said(AppLocalizations l10n) {
    if (widget.minKg <= 0) return widget.subtitle;
    final said = l10n.sessionWeightFloor(
      weightWithUnit(l10n, widget.minKg, widget.unit),
    );
    return widget.subtitle == null ? said : '${widget.subtitle} · $said';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null) return Navigator.pop(context);
    final kg = toKg(v < 0 ? 0 : v, widget.unit);
    Navigator.pop(context, kg < widget.minKg ? widget.minKg : kg);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: AppColors.surface2,
              suffixText: unitSuffix(l10n, widget.unit),
              suffixStyle: kMono.copyWith(color: AppColors.muted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_said(l10n) case final said?) ...[
            const SizedBox(height: 10),
            Text(
              said,
              textAlign: TextAlign.center,
              style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.entry});
  final SetEntry entry;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late final TextEditingController _c = TextEditingController(
    text: '${widget.entry.logged ?? widget.entry.goal}',
  );

  bool get _timed => widget.entry.timed;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pop(int? value) =>
      Navigator.pop<({int? value})>(context, (value: value));

  void _save() {
    final v = int.tryParse(_c.text.trim());
    _pop(v == null ? null : (v < 0 ? 0 : v));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      title: _timed
          ? l10n.sessionResultSecondsTitle
          : l10n.sessionResultRepsTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: kMono.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              filled: true,
              fillColor: AppColors.surface2,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Text(
            _timed
                ? l10n.sessionResultGoalSeconds(widget.entry.goal)
                : l10n.sessionResultGoalReps(widget.entry.goal),
            style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(null),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: Text(l10n.sessionResultClear),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

const kRestBannerKey = ValueKey('rest-banner');

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.secondsLeft,
    required this.prompt,
    this.done,
    required this.unit,
    required this.onSub,
    required this.onAdd,
    required this.onSkip,
  });
  final int secondsLeft;

  final RestPrompt? prompt;

  final String? done;
  final String unit;
  final VoidCallback onSub;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  String _caption(AppLocalizations l10n) {
    if (done case final line?) return line;
    final p = prompt;
    if (p == null) return l10n.sessionRestPlain;
    String weight() => weightWithUnit(l10n, p.weightKg, unit);

    return switch (p.purpose) {
      RestPurpose.anotherWarmup =>
        p.weightKg == null
            ? l10n.sessionRestPlain
            : l10n.sessionRestSetUp(weight()),
      RestPurpose.theWorkingSet =>
        p.weightKg == null
            ? l10n.sessionRestPlain
            : l10n.sessionRestSetUpThenRest(weight()),
      RestPurpose.anotherSet => p.weightKg == null
          ? l10n.sessionRestPlain
          : l10n.sessionRestSetUp(weight()),
      RestPurpose.nextExercise => l10n.sessionRestNextExercise(
          seededName(l10n, p.exerciseSeedKey, p.exercise ?? ''),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: kRestBannerKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final over = done != null;
            final pills = [
              if (!over)
                for (final (label, onTap) in _controls(l10n))
                  _pill(label, onTap),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _caption(l10n),
                  style: kMono.copyWith(
                    fontSize: over ? 13 : 11,
                    height: 1.3,
                    fontWeight: over ? FontWeight.w700 : null,
                    color: over ? AppColors.good : AppColors.muted,
                  ),
                ),
                if (!over) ...[
                  const SizedBox(height: 4),
                  if (_controlsWidth(context, l10n) <=
                      constraints.maxWidth - _kClockRoom)
                    Row(
                      children: [
                        _clock(),
                        const Spacer(),
                        for (final pill in pills) ...[
                          const SizedBox(width: 8),
                          pill,
                        ],
                      ],
                    )
                  else ...[
                    _clock(),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: pills),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _clock() => Text(
    fmtDuration(secondsLeft),
    maxLines: 1,
    style: kMono.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.good,
    ),
  );

  List<(String, VoidCallback)> _controls(AppLocalizations l10n) => [
    (l10n.sessionRestMinus, onSub),
    (l10n.sessionRestPlus, onAdd),
    (l10n.sessionRestSkip, onSkip),
  ];

  double _controlsWidth(BuildContext context, AppLocalizations l10n) {
    final scaler = MediaQuery.textScalerOf(context);
    var width = 16.0; // the two 8 px gaps between the three buttons
    for (final (label, _) in _controls(l10n)) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: kMono.copyWith(fontSize: 12)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      width += math.max(painter.width + 26, 64);
    }
    return width;
  }

  static const _kClockRoom = 96.0;

  Widget _pill(String label, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      child: Text(label, style: kMono.copyWith(fontSize: 12)),
    );
  }
}
