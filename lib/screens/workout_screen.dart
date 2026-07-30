import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/plates.dart';
import '../data/warmup.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart';
import '../state/workout_cue.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';
import '../widgets/plate_line.dart';

/// Marks the set to do now, and the collapsed warm-up group standing in for a
/// rung of one. Exactly one of the two is on the board at a time, and neither
/// is once every set is logged.
///
/// Keys rather than a colour test: what the mark *is* is a design decision that
/// will move, and where it is is not.
const kNextSetKey = ValueKey('next-set');
const kNextWarmupKey = ValueKey('next-warmup');

/// The one place an exercise's goal is stated — beside the weight you can edit.
/// One per exercise on the board, and nowhere on a set row.
const kExerciseGoalKey = ValueKey('exercise-goal');

/// Whether the board says anything about weight for this exercise at all — the
/// working weight, the plate breakdown, the unit column and every row's weight
/// cell, all off the one answer.
///
/// Two ways to have no weight, and neither gets an empty box with a unit
/// hanging off it: the movement carries nothing at all ([WeightType.none] — a
/// push-up, a plank), or it is a hold with nothing on it yet. A cell nobody can
/// fill in is worse than no column, because it invites a number.
bool _showsWeight(ExerciseEntry e) =>
    e.weightType.carriesWeight && e.carriesLoad;

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});
  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// The timed set being held right now, and how long it has been held. A hold
  /// is a stopwatch the user starts and stops, so unlike every other set the
  /// screen owns state for it while it runs.
  ({int exercise, int set})? _holding;
  int _held = 0;
  Timer? _holdTimer;

  /// The resume-overlay's visibility flag, captured up front so `dispose` need
  /// not touch `ref` (unsafe once the element is deactivating).
  late final WorkoutScreenVisible _visibility = ref.read(
    workoutScreenVisibleProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    // Tell the resume overlay this screen is up, so it holds its pill. Deferred
    // off the build frame: flipping the provider synchronously here would mark
    // the overlay (an ancestor, already built this frame) dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _visibility.set(true);
    });
  }

  @override
  void dispose() {
    // The rest clock is not ours to cancel — it belongs to the session and
    // keeps running while this screen is popped. Only the stopwatch is local.
    _holdTimer?.cancel();
    // Leaving — collapsed or finished — lets the pill come back. Deferred so it
    // never notifies listeners while the tree is being torn down.
    final visibility = _visibility;
    Future.microtask(() => visibility.set(false));
    super.dispose();
  }

  /// The rest clock lives on the session — see [ActiveWorkoutController]. These
  /// are the screen's three buttons, forwarded.
  void _startRest(int seconds, RestPrompt? prompt) =>
      ref.read(activeWorkoutProvider.notifier).startRest(seconds, prompt);

  void _stopRest({bool tone = true}) =>
      ref.read(activeWorkoutProvider.notifier).stopRest(tone: tone);

  /// The tone that ends a hold. Always the tone rather than the notification:
  /// this screen being built is what "the app is on screen" means.
  void _tone() => ref.read(restToneProvider).play();

  /// What one tap on a timed set's result cell does.
  ///
  /// A hold is not a count you claim, it is a duration you measure — so the
  /// cell is a stopwatch: tap to start, tap again to stop, and the seconds it
  /// ran are what gets logged. Tapping a hold that is already logged clears it,
  /// which is the same "undo by tapping" the rep cycle ends on.
  void _tapTimed(int ei, int si, SetEntry entry) {
    final h = _holding;
    if (h != null && h.exercise == ei && h.set == si) {
      _stopHold();
      return;
    }
    if (entry.done) {
      ref.read(activeWorkoutProvider.notifier).setLogged(ei, si, null);
      HapticFeedback.selectionClick();
      return;
    }
    _startHold(ei, si);
  }

  /// Starts the stopwatch on one held set.
  ///
  /// Any hold already running is stopped and logged first: you cannot be in two
  /// planks at once, and the one you were in did happen. A rest running when a
  /// hold starts is over — but silently, because the tone means "stop holding"
  /// here and sounding it as you begin would say the opposite.
  void _startHold(int ei, int si) {
    if (_holding != null) _stopHold();
    _stopRest(tone: false);
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

  /// Stops the stopwatch, logs what it read, and starts the rest.
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
      _startRest(
        session.exercises[h.exercise].restSeconds,
        session.restAfterSet(h.exercise, h.set),
      );
    }
  }

  /// The escape hatch for high rep counts, where tapping down from a goal of 20
  /// is absurd, and for timed sets, where the tap cycle only claims the whole
  /// hold. Returns the set to untouched if the field is cleared.
  Future<void> _editResult(int ei, int si, SetEntry entry) async {
    final result = await showDialog<({int? value})>(
      context: context,
      builder: (_) => _ResultDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final wasDone = entry.done;
    ref.read(activeWorkoutProvider.notifier).setLogged(ei, si, result.value);
    if (!wasDone && result.value != null) {
      final session = ref.read(activeWorkoutProvider);
      if (session != null) {
        _startRest(
          session.exercises[ei].restSeconds,
          session.restAfterSet(ei, si),
        );
      }
    }
  }

  /// The same escape hatch for a warm-up row: types a result in, and starts the
  /// rest for that rung if the set was not already logged — see
  /// [ExerciseEntry.restAfterWarmup].
  Future<void> _editWarmupResult(int ei, int wi, SetEntry entry) async {
    final result = await showDialog<({int? value})>(
      context: context,
      builder: (_) => _ResultDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final wasDone = entry.done;
    ref
        .read(activeWorkoutProvider.notifier)
        .setWarmupLogged(ei, wi, result.value);
    if (!wasDone && result.value != null) {
      final session = ref.read(activeWorkoutProvider);
      if (session != null) {
        _startRest(
          session.exercises[ei].restAfterWarmup(wi),
          session.restAfterWarmup(ei, wi),
        );
      }
    }
  }

  /// Asks for a weight in the display unit and hands back kilograms, or null if
  /// the dialog was dismissed. Never less than [minKg] — see [loadFloorKg].
  Future<double?> _askWeight({
    required String title,
    required double weightKg,
    required double minKg,
    String? subtitle,
  }) => showDialog<double>(
    context: context,
    builder: (_) => _WeightDialog(
      title: title,
      subtitle: subtitle,
      weightKg: weightKg,
      minKg: minKg,
      unit: ref.read(weightUnitProvider).value ?? 'kg',
    ),
  );

  /// The lightest this exercise can be loaded: its own bar, or nothing at all
  /// where there is no bar under it.
  double _floorFor(ExerciseEntry e) => loadFloorKg(
    type: e.weightType,
    defaultBarKg: ref.read(plateSettingsProvider).barKg,
    barKg: e.barKg,
  );

  /// The exercise's weight for today. Every set still to come follows it and
  /// the warm-up ramp is rebuilt around it — see
  /// [ActiveWorkoutController.setWorkingWeight].
  Future<void> _editWorkingWeight(int ei) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    if (e == null) return;
    final kg = await _askWeight(
      title: e.name,
      weightKg: e.workingKg ?? 0,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWorkingWeight(ei, kg);
  }

  /// One set's own weight — the deload-to-finish case, and nothing else on the
  /// exercise moves with it.
  /// The camera on a set row. With no clip it goes straight to filming — that
  /// is the whole of what the control is for. With one it offers the two things
  /// left to do with it, because a second tap must not silently overwrite a
  /// take somebody meant to keep.
  Future<void> _video(int ei, int si, SetEntry entry) async {
    if (entry.videoPath == null) {
      await context.push('/session/record/$ei/$si');
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.videocam_rounded, color: AppColors.accent),
              title: const Text('Film it again'),
              subtitle: const Text('Replaces this clip'),
              onTap: () => Navigator.pop(sheet, 'again'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.muted),
              title: const Text('Delete the clip'),
              subtitle: const Text('The set stays'),
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
    final kg = await _askWeight(
      title: 'Set ${si + 1}',
      subtitle: 'This set only',
      weightKg: e.sets[si].weight,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWeight(ei, si, kg);
  }

  Future<void> _editWarmupWeight(int ei, int wi) async {
    final e = ref.read(activeWorkoutProvider)?.exercises[ei];
    if (e == null) return;
    final kg = await _askWeight(
      title: 'Warm-up ${wi + 1}',
      subtitle: 'This rung only',
      weightKg: e.warmups[wi].weight,
      minKg: _floorFor(e),
    );
    if (kg == null || !mounted) return;
    ref.read(activeWorkoutProvider.notifier).setWarmupWeight(ei, wi, kg);
  }

  Future<void> _finish() async {
    final id = await ref.read(activeWorkoutProvider.notifier).finish();
    if (!mounted) return;
    if (id != null) {
      context.pushReplacement('/summary/$id');
    } else {
      context.go('/today');
    }
  }

  /// Throws the session away without writing it. For the workout started by a
  /// misplaced tap — the one whose alternative was finishing a session you
  /// never did, and having the progression believe it.
  ///
  /// Always confirmed, and never the default: it is the one button on this
  /// screen that destroys work, so it asks even when nothing has been logged.
  Future<void> _abort() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Abort this workout?'),
        content: Text(
          'Nothing from it is saved, and no target moves.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
            child: const Text('Abort'),
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
    final controller = ref.read(activeWorkoutProvider.notifier);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final plates = ref.watch(plateSettingsProvider);
    // Where you are, from the same arithmetic the notification uses — the board
    // draws every set at once, so without this the only way to find your place
    // is to scan for the last row that went green. Asked without the rest,
    // because a rest running does not change which set is next; it is the one
    // you are resting *for*.
    final cue = nextUp(session);
    final next = cue == null || cue.kind == CueKind.finished ? null : cue;

    return Scaffold(
      body: SafeArea(
        // A column, not a stack: the rest bar is docked at the bottom and takes
        // real room, so the rows can be scrolled clear of it. Lying over the
        // board it hid whichever set you were trying to read — the same mistake
        // the resume bar made, and the same fix.
        child: Column(
          children: [
            _Header(title: session.name, onFinish: _finish, onAbort: _abort),
            _StatStrip(session: session),
            // Pinned beside the duration and set count rather than scrolled
            // with the rows: it answers "how do I log this?", a question
            // that occurs on whichever exercise you happen to be looking
            // at, not only on the first one.
            _LoggingHint(anyTimed: session.exercises.any((e) => e.mode.timed)),
            // The board and the bar share what the header leaves, and the
            // LayoutBuilder is how the bar's cap gets measured against that
            // rather than against the whole screen — at the top of the text
            // scale the header alone takes more than half of it.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          if (session.notice != null)
                            _SessionNotice(text: session.notice!),
                          for (var ei = 0; ei < session.exercises.length; ei++)
                            _ExerciseBlock(
                              index: ei,
                              exercise: session.exercises[ei],
                              unit: unit,
                              plates: plates,
                              // The ramp is where you are, and it is shut by
                              // default — so the group itself carries the mark.
                              warmupIsNext:
                                  next != null &&
                                  next.warmup &&
                                  next.exerciseIndex == ei,
                              onWarmupCount: (n) =>
                                  controller.setWarmupCount(ei, n),
                              onEditWorkingWeight: () => _editWorkingWeight(ei),
                              warmupRowBuilder: (wi) {
                                final entry = session.exercises[ei].warmups[wi];
                                return _SetRow(
                                  key: ValueKey(
                                    'w$ei-$wi-${session.exercises[ei].name}',
                                  ),
                                  number: wi + 1,
                                  entry: entry,
                                  unit: unit,
                                  isNext:
                                      next != null &&
                                      next.warmup &&
                                      next.exerciseIndex == ei &&
                                      next.setIndex == wi,
                                  onEditWeight: () => _editWarmupWeight(ei, wi),
                                  onTap: () {
                                    final wasDone = entry.done;
                                    controller.cycleWarmup(ei, wi);
                                    HapticFeedback.selectionClick();
                                    if (!wasDone) {
                                      _startRest(
                                        session.exercises[ei].restAfterWarmup(
                                          wi,
                                        ),
                                        session.restAfterWarmup(ei, wi),
                                      );
                                    }
                                  },
                                  onTypeResult: () =>
                                      _editWarmupResult(ei, wi, entry),
                                );
                              },
                              rowBuilder: (si) {
                                final entry = session.exercises[ei].sets[si];
                                return _SetRow(
                                  key: ValueKey(
                                    '$ei-$si-${session.exercises[ei].name}',
                                  ),
                                  number: si + 1,
                                  entry: entry,
                                  unit: unit,
                                  isNext:
                                      next != null &&
                                      !next.warmup &&
                                      next.exerciseIndex == ei &&
                                      next.setIndex == si,
                                  onEditWeight: () => _editSetWeight(ei, si),
                                  showWeight: _showsWeight(
                                    session.exercises[ei],
                                  ),
                                  // A held set is timed, not counted — see
                                  // _tapTimed. It owns its own rest, because the
                                  // rest only starts when the hold stops.
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
                                    // Rest starts when the set is first logged;
                                    // correcting the count afterwards must not
                                    // restart the clock you are already resting on.
                                    if (!wasDone) {
                                      _startRest(
                                        session.exercises[ei].restSeconds,
                                        session.restAfterSet(ei, si),
                                      );
                                    }
                                  },
                                  onTypeResult: () =>
                                      _editResult(ei, si, entry),
                                  onVideo: () => _video(ei, si, entry),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    if (session.restLeft > 0)
                      // Capped, not flexed. A Flexible here claimed an equal
                      // share of the column beside the board's Expanded, and a
                      // bar three lines tall used none of the rest of that
                      // share: the board came out squeezed into the top half of
                      // the screen with a blank strip under the bar. Capped
                      // instead, the bar is the height of its own contents and
                      // the board keeps every pixel it does not take — and
                      // where the contents want more than half of what the
                      // header left, the bar stops at the cap and scrolls.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: box.maxHeight / 2,
                        ),
                        child: _RestBanner(
                          secondsLeft: session.restLeft,
                          prompt: session.restPrompt,
                          unit: unit,
                          // −15s ends a rest with less than that left: below fifteen the
                          // button's only honest readings are "skip" and "do nothing".
                          onSub: () => ref
                              .read(activeWorkoutProvider.notifier)
                              .nudgeRest(-15),
                          onAdd: () => ref
                              .read(activeWorkoutProvider.notifier)
                              .nudgeRest(15),
                          onSkip: _stopRest,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/today'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Minimize',
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          // Deliberately an unfilled icon next to a filled button: the two are
          // one tap apart, and only one of them should look like the way out.
          IconButton(
            onPressed: onAbort,
            icon: Icon(Icons.delete_outline, color: AppColors.muted),
            tooltip: 'Abort workout',
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
            child: const Text('Finish'),
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
            _Stat(label: 'Duration', value: fmtDuration(session.elapsed)),
            VerticalDivider(width: 1, color: AppColors.line),
            _Stat(
              label: 'Sets',
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

/// Said once, at the top of the list, rather than as a legend under every
/// exercise: the tap cycle is quick to demonstrate and tedious to repeat.
/// Why the numbers are not where you left them. Stays for the whole session:
/// the question "why is this lighter?" occurs to people mid-set, not on the way
/// in, and there is nowhere else on this screen to answer it.
class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.text});
  final String text;

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
              text,
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

  /// Whether this session holds anything for time. A held set is tapped to
  /// start and tapped to stop, which is a different instruction from the rep
  /// cycle — and one worth giving only when there is something to use it on.
  final bool anyTimed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Text(
        'Tap a set to log it at the goal · tap again for each rep you fell '
        'short · hold to type'
        '${anyTimed ? '\nA held set times itself: tap to start, tap to stop.' : ''}',
        style: kMono.copyWith(
          fontSize: 11,
          height: 1.45,
          color: AppColors.faint,
        ),
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
  });

  /// Where this exercise sits in the session — only used to key its working
  /// weight, which is the one control on the block that is not inside a row.
  final int index;
  final ExerciseEntry exercise;
  final String unit;
  final PlateSettings plates;
  final Widget Function(int setIndex) rowBuilder;
  final Widget Function(int warmupIndex) warmupRowBuilder;

  /// Whether the next thing to do is one of this exercise's warm-up rungs.
  final bool warmupIsNext;
  final ValueChanged<int> onWarmupCount;
  final VoidCallback onEditWorkingWeight;

  /// What this exercise is aiming at, the way a lifter says it: `3 × 8`, or
  /// `2 × 45s` for a hold. Null when there are no sets to aim at anything.
  ///
  /// The weight is not in here. It is the control beside it, and a goal with an
  /// editable box wedged into the middle of it reads as neither a goal nor a
  /// control.
  String? get _goal {
    if (exercise.sets.isEmpty) return null;
    final first = exercise.sets.first;
    return '${exercise.sets.length} × ${first.goal}${first.timed ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExerciseHeading(
            name: exercise.name,
            exerciseId: exercise.exerciseId,
          ),
          // The warm-up ramp, kept in a group of its own above the working sets
          // so the two are never confused. Only a weight-based slot with a load
          // gets one.
          if (exercise.hasWarmups)
            _WarmupGroup(
              exercise: exercise,
              unit: unit,
              isNext: warmupIsNext,
              onCount: onWarmupCount,
              rowBuilder: warmupRowBuilder,
            ),
          // The label, the goal and the one weight the sets below are done at,
          // on the same line: what the block is, what it is aiming at, and what
          // it is loaded to. **This is the only place the goal is stated.** It
          // used to be reprinted on every row, where the weight cell and the
          // greyed-out result cell beside it were already saying both halves of
          // it.
          //
          // Read across, the line is "three eights at eighty kilos": the goal
          // is a whole goal, the `@` joins it to the load, and the load is the
          // one thing here with a border round it, because it is the one thing
          // you can change.
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: Row(
              children: [
                if (exercise.hasWarmups)
                  // The label gives, never the weight: the weight is the
                  // control on this row and has to stay whole and tappable.
                  Flexible(
                    child: Text(
                      'WORKING SETS',
                      overflow: TextOverflow.ellipsis,
                      style: kMono.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                const Spacer(),
                if (_goal case final goal?)
                  Text(
                    goal,
                    key: kExerciseGoalKey,
                    style: kMono.copyWith(fontSize: 13, color: AppColors.muted),
                  ),
                if (_showsWeight(exercise)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '@',
                      style: kMono.copyWith(
                        fontSize: 13,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  _WorkingWeight(
                    key: ValueKey('working-weight-$index'),
                    weightKg: exercise.workingKg,
                    unit: unit,
                    onTap: onEditWorkingWeight,
                  ),
                ],
              ],
            ),
          ),
          // What to put on the bar for the set you are about to do — it follows
          // you down the exercise as sets get logged, and re-solves the moment
          // you type a different weight.
          if (exercise.nextWeight case final w? when _showsWeight(exercise))
            PlateLine(
              weightKg: w,
              type: exercise.weightType,
              settings: plates,
              unit: unit,
              barKg: exercise.barKg,
            ),
          const SizedBox(height: 6),
          _ColumnHeaders(
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

/// The one weight this exercise is being worked at today.
///
/// Drawn as a control, in the same bordered box the set rows use for a weight:
/// on the goal line it sits beside plain text, and a number with only a
/// hairline under it read as part of the label rather than as the thing you
/// tap. It is still not a text field sitting open — the box holds a value, and
/// touching it opens the editor.
class _WorkingWeight extends StatelessWidget {
  const _WorkingWeight({
    super.key,
    required this.weightKg,
    required this.unit,
    required this.onTap,
  });
  final double? weightKg;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = weightKg;
    // Nothing suggested and nothing chosen: the load is yours to name.
    final value = w == null || w == 0
        ? '—'
        : fmtWeight(toDisplayWeight(w, unit));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
              value,
              style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 3),
            Text(
              unitLabel(unit),
              style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(width: 7),
            Icon(Icons.edit_outlined, size: 13, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

/// The exercise's name and your own note on it, one tap from the set you are
/// about to do.
///
/// **One icon, one tap, whether or not a note exists.** The note used to expand
/// in place and grow a pencil beside it, which made the first tap a disclosure
/// and the second the thing you actually wanted; two icons for one note is one
/// too many. Now the tap brings the note up, where it can be read and changed
/// in the same breath.
///
/// **It is read and written live.** Mid-workout is exactly when you learn the
/// thing worth noting — the seat was wrong, the pin is one lower than you
/// remembered — and by the time you are back on the library screen you have
/// forgotten. So the note comes off [exerciseNoteProvider] rather than out of
/// the session's snapshot, and writing one here writes it to the library.
class _ExerciseHeading extends ConsumerWidget {
  const _ExerciseHeading({required this.name, this.exerciseId});
  final String name;

  /// Null for an ad-hoc entry with no library movement behind it — there is
  /// nowhere to keep a note, so none is offered.
  final int? exerciseId;

  /// Brings the note up, and writes back whatever comes of it.
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
    final id = exerciseId;
    final note = id == null ? null : ref.watch(exerciseNoteProvider(id));

    Widget icon(
      IconData glyph,
      String tooltip,
      VoidCallback onPressed, {
      bool lit = false,
    }) => IconButton(
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
              // The glyph says whether there is a note to read; the tap does
              // the same thing either way — brings it up.
              icon(
                note == null
                    ? Icons.note_add_outlined
                    : Icons.sticky_note_2_outlined,
                note == null ? 'Add a note' : 'My note',
                () => _open(context, ref, id, note),
                lit: note != null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The warm-up ramp for one exercise: a labelled group above the working sets,
/// collapsed by default to a single summary line so it never crowds the work.
/// Tapping the header opens the ramp — the rows, the stepper and a one-line
/// disclaimer. Visually quieter than the working block (dimmer label, no plate
/// breakdowns) so the eye goes to the work.
class _WarmupGroup extends StatefulWidget {
  const _WarmupGroup({
    required this.exercise,
    required this.unit,
    required this.isNext,
    required this.onCount,
    required this.rowBuilder,
  });
  final ExerciseEntry exercise;
  final String unit;

  /// Whether the next thing to do is a rung of this ramp. Shut, the group is
  /// all there is on screen to say so — see [kNextWarmupKey].
  final bool isNext;
  final ValueChanged<int> onCount;
  final Widget Function(int warmupIndex) rowBuilder;

  @override
  State<_WarmupGroup> createState() => _WarmupGroupState();
}

class _WarmupGroupState extends State<_WarmupGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final count = exercise.warmupCount;
    final summary = count == 0
        ? 'None'
        : '$count ${count == 1 ? 'set' : 'sets'}';
    final next = widget.isNext;
    return Container(
      key: next ? kNextWarmupKey : null,
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.fromLTRB(12, 6, 12, _open ? 10 : 6),
      decoration: BoxDecoration(
        color: next
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.surface2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: next
              ? AppColors.accent.withValues(alpha: 0.55)
              : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The header is one tap target that toggles the ramp open and shut.
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    size: 18,
                    color: next ? AppColors.accent : AppColors.faint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'WARM-UP',
                    style: kMono.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: next ? AppColors.accent : AppColors.faint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The summary gives before the label does: "WARM-UP" is what
                  // identifies the group, "· 3 sets" is a detail.
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
                      'Sets',
                      style: kMono.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  _CountStepper(
                    count: count,
                    onSub: count > 0 ? () => widget.onCount(count - 1) : null,
                    onAdd: count < kMaxWarmupSets
                        ? () => widget.onCount(count + 1)
                        : null,
                  ),
                ],
              ),
            ),
            // A ramp asked for but not built: the working weight is too light
            // for anything to sit between the bar and it. Said as the reason it
            // is, because the count above is not the thing to change — and a
            // count of zero needs no line at all, since the stepper beside it
            // already reads 0.
            if (exercise.warmups.isEmpty && count > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Too light to ramp — nothing fits under this weight.',
                  style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
                ),
              ),
            if (exercise.warmups.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ColumnHeaders(unit: widget.unit, timed: false),
              for (var wi = 0; wi < exercise.warmups.length; wi++)
                widget.rowBuilder(wi),
            ],
            const SizedBox(height: 8),
            Text(
              'Suggested to prime the movement — not medical advice. Adjust to '
              'how you feel, and consult a professional.',
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

/// The compact −/+ that dials the warm-up count. A disabled side (null handler)
/// greys out at the ends of the 0..[kMaxWarmupSets] range.
class _CountStepper extends StatelessWidget {
  const _CountStepper({
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

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({
    required this.unit,
    required this.timed,
    this.showWeight = true,
  });
  final String unit;
  final bool timed;

  /// Whether there is a weight column under this at all — see [_showsWeight].
  final bool showWeight;
  @override
  Widget build(BuildContext context) {
    Widget h(String t, {double? width, bool left = false}) {
      final child = Text(
        t.toUpperCase(),
        textAlign: left ? TextAlign.left : TextAlign.center,
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
      // The 5 either side is the set row's own inset — its 4 of padding and the
      // 1 of border it carries when it is the set you are on — so the headings
      // stay over their columns whether or not a row below is marked.
      padding: const EdgeInsets.only(bottom: 4, top: 2, left: 5, right: 5),
      child: Row(
        children: [
          h('Set', width: 40),
          if (showWeight) h(unitLabel(unit)),
          h(timed ? 'Sec held' : 'Reps done'),
        ],
      ),
    );
  }
}

/// One set: a goal it cannot edit, the weight it is being done at, and the tap
/// target that logs it.
///
/// **Neither cell is a text field.** The weight for the exercise is set once
/// above the rows and these follow it; a row's own weight is the exception —
/// dropping the last set to finish it — so it opens an editor on tap rather
/// than sitting open as a box per set. That the row reads its weight straight
/// off the entry on every build is also what keeps it honest when the ramp
/// underneath it is recomputed: there is no controller left holding yesterday's
/// number.
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
  });
  final int number;
  final SetEntry entry;
  final String unit;

  /// Whether this row carries a weight cell — see [_showsWeight]. A movement
  /// done under no load has none, rather than an empty box under an empty
  /// heading.
  final bool showWeight;

  /// Whether this is the set to do now — see [kNextSetKey].
  final bool isNext;
  final VoidCallback onEditWeight;
  final VoidCallback onTap;
  final VoidCallback onTypeResult;

  /// Films this set. Null on a warm-up row: warm-ups are suggestions that are
  /// never saved, so there is no logged set for a clip to belong to. The column
  /// is still reserved on those rows, so the two sections line up.
  final VoidCallback? onVideo;

  /// Seconds elapsed on this set's stopwatch, or null when it is not running.
  /// Only a timed set ever has one — see `_tapTimed`.
  final int? holdingSeconds;

  SetEntry get _entry => entry;

  /// Green for a set that met its goal, gold for one that came up short —
  /// including a set finished at a reduced weight. A hold still running is the
  /// accent: it is neither yet, and it is the thing on screen to look at.
  Color get _tone => holdingSeconds != null
      ? AppColors.accent
      : (_entry.missedGoal ? AppColors.gold : AppColors.good);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: isNext ? kNextSetKey : null,
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      // The set you are on, marked where your eye already is rather than in a
      // margin: the row lifts out of the list on the accent, which is the same
      // colour the app uses everywhere else for "this one".
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
            SizedBox(width: 40, child: Center(child: _setNumber())),
            if (showWeight) Expanded(child: _weightCell()),
            Expanded(child: _resultBox()),
            SizedBox(
              width: 36,
              child: onVideo == null
                  ? const SizedBox.shrink()
                  : Center(child: _cameraCell()),
            ),
          ],
        ),
      ),
    );
  }

  /// Film this set, or deal with the clip it already has.
  ///
  /// Filled and in the accent when there is one, hollow and faint when there is
  /// not — this is also the "a set carrying a clip is visually distinct" marker
  /// on the live board, because a second badge saying the same thing would be
  /// one control and one decoration for one fact.
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

  /// This set's own weight. Quieter than the reps cell it sits beside: it is
  /// normally just the exercise's weight repeated, and only worth touching for
  /// the set you have to come down on.
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
          decoration: BoxDecoration(
            color: done ? _tone.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: done ? _tone.withValues(alpha: 0.30) : AppColors.line,
            ),
          ),
          child: Text(
            fmtWeight(toDisplayWeight(_entry.weight, unit)),
            style: kMono.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: done ? _tone : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  /// Untouched, the cell shows the goal greyed out — the number you are about
  /// to claim. One tap turns that same number green; further taps count it
  /// down in gold. Nothing here can change the goal itself.
  ///
  /// A set that came up short also gets a downward arrow. **Green and gold
  /// differing only in hue is the one pair a colour-blind reader cannot see at
  /// all**, and this column is the app's most-read signal — you glance down it
  /// to see how the session went. The arrow says the same thing the colour
  /// does, without asking anyone to tell two hues apart.
  Widget _resultBox() {
    final holding = holdingSeconds != null;
    final done = _entry.done || holding;
    final value = holding
        ? '${holdingSeconds}s'
        : '${_entry.logged ?? _entry.goal}${_entry.timed ? 's' : ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        key: const ValueKey('set-result'),
        onTap: onTap,
        onLongPress: onTypeResult,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: done ? _tone.withValues(alpha: 0.15) : AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: done ? _tone.withValues(alpha: 0.55) : AppColors.line,
              // A running hold is the one thing on the board actively
              // happening, so it says so with more than a colour.
              width: holding ? 2 : 1,
            ),
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
                style: kMono.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: done ? _tone : AppColors.faint,
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
    );
  }
}

/// Types a weight in — the load for a whole exercise, or one set's own
/// override. Shown and typed in the display unit; the value it returns is
/// canonical kilograms, or null if the dialog was dismissed.
///
/// **A bar-loaded lift has a floor, and the field holds to it.** Fifteen kilos
/// on a twenty-kilo bar is not a light day, it is a load nobody can build, so
/// anything under [minKg] comes back as [minKg] rather than being taken at face
/// value. The floor is named on the way in — see [loadFloorKg], and
/// [PlateSolution.belowBar] for what the plate line still says about a weight
/// that arrived from somewhere else.
class _WeightDialog extends StatefulWidget {
  const _WeightDialog({
    required this.title,
    required this.weightKg,
    required this.unit,
    this.subtitle,
    this.minKg = 0,
  });
  final String title;

  /// What this weight covers, where the title does not already say it — "This
  /// set only" against a set row. Null for the exercise's own weight: the title
  /// is the exercise name, and the dialog is the only place its weight is
  /// typed, so there is nothing left to distinguish it from.
  final String? subtitle;
  final double weightKg;
  final String unit;

  /// The lightest weight this exercise can be set to, in kg. Zero for anything
  /// with no bar under it.
  final double minKg;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _c = TextEditingController(
    text: fmtWeight(toDisplayWeight(widget.weightKg, widget.unit)),
  );

  /// What the field says, with the floor named where there is one: a constraint
  /// on the control belongs beside the control. Null when there is neither a
  /// subtitle nor a floor — an empty line under the field is still a line.
  String? get _said {
    if (widget.minKg <= 0) return widget.subtitle;
    final floor = fmtWeight(toDisplayWeight(widget.minKg, widget.unit));
    final said = 'no lighter than the $floor ${unitLabel(widget.unit)} bar';
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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title),
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
              suffixText: unitLabel(widget.unit),
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
          if (_said case final said?) ...[
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
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Direct entry of what a set actually came to — reps done, or seconds held on
/// a timed set. For the sets where tapping down from a goal of 20 is absurd,
/// and for every plank. An empty field means the set never happened, which is
/// the same thing the Clear button does.
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
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_timed ? 'Seconds held' : 'Reps done'),
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
            'Goal ${widget.entry.goal}${_timed ? 's' : ''}',
            style: kMono.copyWith(fontSize: 12, color: AppColors.faint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(null),
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Finds the rest bar in a test. Its caption is the thing under test in several
/// of them, so it cannot also be what identifies the bar.
const kRestBannerKey = ValueKey('rest-banner');

/// The rest clock, docked as the board's last row.
///
/// **It takes real room rather than lying over the rows**, like the resume bar
/// and for the same reason: floating, it covered whichever set you were trying
/// to read, and the only way to see underneath was to end the rest you were
/// taking. Docked, the list above it simply scrolls.
class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.secondsLeft,
    required this.prompt,
    required this.unit,
    required this.onSub,
    required this.onAdd,
    required this.onSkip,
  });
  final int secondsLeft;

  /// What this rest is for — see [RestPrompt]. Null while a session has not
  /// said, which the banner reads as the plain case.
  final RestPrompt? prompt;
  final String unit;
  final VoidCallback onSub;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  /// One line saying what to do, not what is happening: the clock underneath
  /// already says that. Names the weight about to be lifted, because "set up"
  /// is only useful if it says what to set up to.
  String get _caption {
    final p = prompt;
    if (p == null) return 'Rest, then lift.';
    String weight() {
      final w = p.weightKg;
      return w == null
          ? ''
          : '${fmtWeight(toDisplayWeight(w, unit))} ${unitLabel(unit)}';
    }

    return switch (p.purpose) {
      RestPurpose.anotherWarmup =>
        p.weightKg == null
            ? 'Rest, then lift.'
            : 'Set up ${weight()}, then lift.',
      RestPurpose.theWorkingSet =>
        p.weightKg == null
            ? 'Rest, then lift.'
            : 'Set up ${weight()}, rest, then lift.',
      RestPurpose.anotherSet => 'Rest, then lift.',
      RestPurpose.nextExercise => 'Set up ${p.exercise}, rest, then lift.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: kRestBannerKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      // Docked furniture may not grow without limit: at the top of the text
      // scale a wrapped caption, a stacked clock and a wrapped button row
      // together want more height than the board has to give, and the board is
      // what the screen is for. The bar is handed a share of the column by the
      // Flexible around it and scrolls inside whatever it gets — so nothing is
      // ellipsised and nothing is out of reach.
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pills = [
              for (final (label, onTap) in _controls) _pill(label, onTap),
            ];
            // The caption takes the whole width, on its own line above the clock
            // and the controls. Sharing a row with them left it about eighty
            // pixels on a 390-wide phone, which is not enough for "Rest, then
            // lift." — and cutting the line off is the one thing that defeats
            // the point of having it.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The caption replaces the word "REST": a banner counting down is
                // self-evidently a rest, and the line is worth more spent on what
                // to do with it. It wraps rather than ellipsising — the bar is
                // docked, so a second line costs the board a second line and
                // nothing is hidden by it.
                Text(
                  _caption,
                  style: kMono.copyWith(
                    fontSize: 11,
                    height: 1.3,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                // Side by side while the clock still has room to be read; stacked
                // once the controls have eaten it. At the largest text the app
                // renders, three buttons and a countdown do not fit across a phone
                // — and a squeezed button is worse than a taller bar, because the
                // button is the part you have to hit.
                if (_controlsWidth(context) <=
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
                  // Wrapped rather than a row: at the top of the scale three
                  // buttons do not fit across a narrow phone even with the whole
                  // width to themselves, and one that runs off the edge cannot be
                  // pressed at all.
                  Wrap(spacing: 8, runSpacing: 8, children: pills),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// How long is left. The one number on the bar, and the reason it needs no
  /// label.
  Widget _clock() => Text(
    fmtDuration(secondsLeft),
    maxLines: 1,
    style: kMono.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.good,
    ),
  );

  /// What the banner offers, in the order it offers it. Declared once so the
  /// measurement below and the buttons above cannot drift apart.
  List<(String, VoidCallback)> get _controls => [
    ('−15s', onSub),
    ('+15s', onAdd),
    ('Skip', onSkip),
  ];

  /// The width the three controls need, laid out in a row.
  ///
  /// Measured rather than guessed: the labels are known and the font is
  /// monospaced, so this is exact, and the alternative — a breakpoint on the
  /// text scale — puts a number in the code that has to be re-checked every
  /// time a label or a padding changes.
  double _controlsWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var width = 16.0; // the two 8 px gaps between the three buttons
    for (final (label, _) in _controls) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: kMono.copyWith(fontSize: 12)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      // The label, its 12 px of padding either side, and the 1 px border.
      width += math.max(painter.width + 26, 64);
    }
    return width;
  }

  /// The room the countdown wants beside the controls before it is worth
  /// keeping them on one line. Below this the clock is a column of single
  /// digits and the caption is one word per line.
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
