import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'tutorial_demo.dart';

// ---------------------------------------------------------------------------
// Anchors
// ---------------------------------------------------------------------------
//
// The coach marks point at real widgets, so those widgets carry a GlobalKey the
// overlay can measure. The keys live here (not on the screens) so the step list
// and the screens agree on exactly one key each, and a screen only has to hang
// the right key on the right widget.
//
// Two screens may hold *equivalent* controls — the exercise list of a training
// day is edited both inside the routine builder and on the workout builder's own
// route — and a GlobalKey may only be mounted once. So those get one key each
// and the step names both; see [TutorialStep.anchors].

/// The whole bottom navigation bar. Individual tabs are highlighted by slicing
/// this rect into equal slots — see [TutorialStep.navSlot].
final tutorialNavBarKey = GlobalKey();

/// The current routine's name and the link that switches routine, on Today.
final tutorialTodayRoutineKey = GlobalKey();

/// The current routine's next training day on the Today screen.
final tutorialTodayWorkoutKey = GlobalKey();

/// The lifetime-totals card on the Today screen.
final tutorialLifetimeKey = GlobalKey();

/// "New routine", at the bottom of the Routines tab.
final tutorialNewRoutineKey = GlobalKey();

/// The routine builder's name field, its list of training days, and its Save.
final tutorialRoutineNameKey = GlobalKey();
final tutorialRoutineDaysKey = GlobalKey();
final tutorialRoutineSaveKey = GlobalKey();

/// A training day's exercise list and its Save, on the workout builder's own
/// route (`/workout/:id/edit`).
final tutorialWorkoutItemsKey = GlobalKey();
final tutorialWorkoutSaveKey = GlobalKey();

/// The same two, on the draft screen the routine builder pushes for a day that
/// has not been saved yet. Separate keys because that screen is stacked *over*
/// the routine builder, so both are mounted at once.
final tutorialWorkoutDraftItemsKey = GlobalKey();
final tutorialWorkoutDraftSaveKey = GlobalKey();

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

/// Which stand-in a step draws for the live workout.
///
/// [screen] is the whole session screen at full size — [TutorialSessionDemo] —
/// and every step of the live-workout chapter draws it, differing only in what
/// each one focuses. [shade] is the odd one out: it is about a notification
/// rather than about the screen, so it keeps a notification-sized picture in the
/// middle of a dimmed display.
enum TutorialDemo { screen, shade }

/// One coach mark: a target to spotlight and the text to show beside it.
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.title,
    required this.body,
    this.anchors = const [],
    this.navSlot,
    this.navSlotCount = 4,
    this.demo,
    this.focus = TutorialDemoFocus.none,
    this.tapThrough = false,
  });

  /// Stable, and the same string the catalogue entry is written against. Only
  /// used for reading a failure message back, so it is not translated.
  final String id;

  /// The widgets this step may anchor to, best first. **Empty for a step that
  /// points at nothing** — the closing card is one of those, and so is every
  /// step that brought its own picture.
  ///
  /// More than one because the same control lives on two screens that are never
  /// both in front of you. The first one that is actually laid out and on
  /// screen wins; if none is, the callout is centred instead.
  final List<GlobalKey> anchors;

  /// Which slot of [navSlotCount] to highlight, or null to use the whole widget.
  final int? navSlot;
  final int navSlotCount;

  /// The mock to draw above the callout, for a step about something that only
  /// exists mid-session. A step with one has no anchor: it points at the picture
  /// it brought with it, not at anything behind the scrim.
  final TutorialDemo? demo;

  /// Which part of the mock board this step is about — the ring, for an icon
  /// too small to be found by prose alone.
  final TutorialDemoFocus focus;

  /// Whether the spotlight is a hole in the hit test as well as in the paint.
  ///
  /// True on a step that asks you to do something: the tap reaches the real
  /// widget, the app does what it always does, and the tour moves on with you.
  /// False on a step that is pointing something out — tapping a training-day
  /// card would push a screen the tour has nothing to say about, so that hole
  /// absorbs the tap and just advances.
  final bool tapThrough;

  /// The heading and the prose, **looked up rather than held**.
  ///
  /// The step list is built once, at start-up, and outlives any number of
  /// language switches; a string captured then would still be in the old
  /// language on the next step. So a step carries the way to ask for its text
  /// and the card asks on every build.
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
}

/// Which tour is running.
///
/// Two are offered on first launch, because "show me everything" and "just show
/// me where things are" are different requests and guessing which one somebody
/// wants is how a tour gets skipped. The third is not about the app in general
/// at all — it walks you through building a routine — so it is never chained
/// onto the other two and is started from Profile when you want it.
enum TutorialTrack { full, quick, builder }

/// One step of the nav bar: the tab named by [slot], which you really do tap.
TutorialStep _tab(
  String id,
  int slot,
  String Function(AppLocalizations) title,
  String Function(AppLocalizations) body,
) =>
    TutorialStep(
      id: id,
      anchors: [tutorialNavBarKey],
      navSlot: slot,
      tapThrough: true,
      title: title,
      body: body,
    );

/// The four tabs, in the order they sit in the bar.
///
/// Both first-run tours open on these: the shape of the app before any one
/// screen of it, so the second half of a tour has somewhere to hang. They are
/// tap-through, so walking them is walking the app rather than watching it.
final List<TutorialStep> _kTabSteps = [
  _tab('tab-today', 0, (l) => l.tutorialTabTodayTitle,
      (l) => l.tutorialTabTodayBody),
  _tab('tab-routines', 1, (l) => l.tutorialRoutinesTitle,
      (l) => l.tutorialRoutinesBody),
  _tab('tab-history', 2, (l) => l.tutorialHistoryTitle,
      (l) => l.tutorialHistoryBody),
  _tab('tab-profile', 3, (l) => l.tutorialProfileTitle,
      (l) => l.tutorialProfileBody),
];

/// What is on Today, up to the training day that starts a session.
///
/// **An anchored step may point below the fold** — the overlay scrolls the
/// anchor into view before spotlighting it, so the lifetime card gets pointed at
/// on a routine with more training days than fit on a screen.
final List<TutorialStep> _kTodaySteps = [
  TutorialStep(
    id: 'today-routine',
    anchors: [tutorialTodayRoutineKey],
    title: (l) => l.tutorialTodayRoutineTitle,
    body: (l) => l.tutorialTodayRoutineBody,
  ),
  TutorialStep(
    id: 'today-next',
    anchors: [tutorialTodayWorkoutKey],
    title: (l) => l.tutorialTodayTitle,
    body: (l) => l.tutorialTodayBody,
  ),
];

/// The rest of Today, once the session chapter has been through and come back.
final TutorialStep _kLifetimeStep = TutorialStep(
  id: 'today-lifetime',
  anchors: [tutorialLifetimeKey],
  title: (l) => l.tutorialLifetimeTitle,
  body: (l) => l.tutorialLifetimeBody,
);

/// The live workout — the one chapter that is still drawn rather than pointed
/// at.
///
/// The board, the rest timer, the note, the clip and the shade are where the app
/// is least like every other tracker, and none of them exists until a session is
/// running. A tour that starts a workout to show you a workout is a tour that
/// leaves you somewhere you did not ask to be, so these steps carry a mock of
/// the thing they describe instead of an anchor.
///
/// **It runs straight off the training-day step**, because that is the order
/// somebody moves in: a card you tap, a screen it opens, the thing you do there.
/// Nothing behind the scrim has actually moved when it starts, so the first step
/// is the one that says why the picture changed.
final List<TutorialStep> _kSessionSteps = [
  TutorialStep(
    id: 'session-open',
    demo: TutorialDemo.screen,
    title: (l) => l.tutorialSessionOpenTitle,
    body: (l) => l.tutorialSessionOpenBody,
  ),
  TutorialStep(
    id: 'session-board',
    demo: TutorialDemo.screen,
    focus: TutorialDemoFocus.nextSet,
    title: (l) => l.tutorialBoardTitle,
    body: (l) => l.tutorialBoardBody,
  ),
  TutorialStep(
    id: 'session-rest',
    demo: TutorialDemo.screen,
    focus: TutorialDemoFocus.rest,
    title: (l) => l.tutorialRestTitle,
    body: (l) => l.tutorialRestBody,
  ),
  TutorialStep(
    id: 'session-note',
    demo: TutorialDemo.screen,
    focus: TutorialDemoFocus.note,
    title: (l) => l.tutorialNoteTitle,
    body: (l) => l.tutorialNoteBody,
  ),
  TutorialStep(
    id: 'session-clip',
    demo: TutorialDemo.screen,
    focus: TutorialDemoFocus.camera,
    title: (l) => l.tutorialVideoTitle,
    body: (l) => l.tutorialVideoBody,
  ),
  TutorialStep(
    id: 'session-shade',
    demo: TutorialDemo.shade,
    title: (l) => l.tutorialShadeTitle,
    body: (l) => l.tutorialShadeBody,
  ),
];

/// The three tours, each an ordered list of steps.
///
/// Not `const`: the anchors are runtime [GlobalKey] instances.
final Map<TutorialTrack, List<TutorialStep>> kTutorialTracks = {
  TutorialTrack.full: [
    ..._kTabSteps,
    // The fourth tab step left you on Profile. Coming back is a tap like the
    // others rather than a jump the tour makes on your behalf.
    _tab('tab-back-to-today', 0, (l) => l.tutorialBackToTodayTitle,
        (l) => l.tutorialBackToTodayBody),
    ..._kTodaySteps,
    ..._kSessionSteps,
    _kLifetimeStep,
    TutorialStep(
      id: 'done',
      title: (l) => l.tutorialDoneTitle,
      body: (l) => l.tutorialDoneBody,
    ),
  ],
  TutorialTrack.quick: [
    ..._kTabSteps,
    TutorialStep(
      id: 'done-quick',
      title: (l) => l.tutorialDoneTitle,
      body: (l) => l.tutorialDoneQuickBody,
    ),
  ],
  TutorialTrack.builder: [
    _tab('build-open', 1, (l) => l.tutorialBuildOpenTitle,
        (l) => l.tutorialBuildOpenBody),
    TutorialStep(
      id: 'build-new',
      anchors: [tutorialNewRoutineKey],
      tapThrough: true,
      title: (l) => l.tutorialBuildNewTitle,
      body: (l) => l.tutorialBuildNewBody,
    ),
    TutorialStep(
      id: 'build-name',
      anchors: [tutorialRoutineNameKey],
      tapThrough: true,
      title: (l) => l.tutorialBuildNameTitle,
      body: (l) => l.tutorialBuildNameBody,
    ),
    TutorialStep(
      id: 'build-days',
      anchors: [tutorialRoutineDaysKey],
      tapThrough: true,
      title: (l) => l.tutorialBuildDaysTitle,
      body: (l) => l.tutorialBuildDaysBody,
    ),
    TutorialStep(
      id: 'build-exercises',
      // The draft screen first: it is pushed over the routine builder, so when
      // both are mounted it is the one in front of you.
      anchors: [tutorialWorkoutDraftItemsKey, tutorialWorkoutItemsKey],
      tapThrough: true,
      title: (l) => l.tutorialBuildExercisesTitle,
      body: (l) => l.tutorialBuildExercisesBody,
    ),
    // The per-slot settings live in a modal sheet the tour does not follow you
    // into — a coach mark over a sheet that is still animating up points at a
    // moving target. So this step says what each of them means and lets you
    // read it with the sheet open behind, or before you open it.
    TutorialStep(
      id: 'build-slot',
      title: (l) => l.tutorialBuildSlotTitle,
      body: (l) => l.tutorialBuildSlotBody,
    ),
    TutorialStep(
      id: 'build-save',
      anchors: [
        tutorialWorkoutDraftSaveKey,
        tutorialWorkoutSaveKey,
        tutorialRoutineSaveKey,
      ],
      tapThrough: true,
      title: (l) => l.tutorialBuildSaveTitle,
      body: (l) => l.tutorialBuildSaveBody,
    ),
    TutorialStep(
      id: 'build-done',
      title: (l) => l.tutorialBuildDoneTitle,
      body: (l) => l.tutorialBuildDoneBody,
    ),
  ],
};

// ---------------------------------------------------------------------------
// Controller — in-memory, like the live-session visibility flag
// ---------------------------------------------------------------------------

/// Whether a tour is on screen, which one, and how far through. Purely
/// in-memory; the "already seen it" fact is the persisted `tutorialSeen` flag.
class TutorialState {
  const TutorialState({
    this.active = false,
    this.track,
    this.step = 0,
    this.hint = false,
  });

  final bool active;

  /// Null while the opening card is asking which tour to take.
  final TutorialTrack? track;
  final int step;

  /// The one line saying where the tour can be replayed from, shown after
  /// skipping or declining and cleared on its own.
  final bool hint;

  List<TutorialStep> get steps =>
      track == null ? const [] : kTutorialTracks[track]!;
}

class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  /// Puts the opening card up without committing to a tour. The first-run
  /// auto-start does this; Profile asks the same question in a sheet instead.
  void offer() => state = const TutorialState(active: true);

  /// Begins [track] at its first step.
  void start(TutorialTrack track) =>
      state = TutorialState(active: true, track: track);

  /// Advances, ending the tour after the last step. Returns true if it ended.
  bool next() {
    if (state.step + 1 >= state.steps.length) {
      stop();
      return true;
    }
    state = TutorialState(
        active: true, track: state.track, step: state.step + 1);
    return false;
  }

  void back() {
    if (state.step > 0) {
      state = TutorialState(
          active: true, track: state.track, step: state.step - 1);
    }
  }

  void stop() => state = const TutorialState();

  /// Leaves the tour early and raises the line saying where to find it again.
  void skip() => state = const TutorialState(hint: true);

  void clearHint() {
    if (state.hint) state = const TutorialState();
  }
}

final tutorialProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);

// ---------------------------------------------------------------------------
// Overlay
// ---------------------------------------------------------------------------

/// Wraps the whole app (mounted in `MaterialApp.router`'s builder, above the
/// resume bar) so the coach marks can spotlight the bottom nav as readily as a
/// card on Today. On a genuine first run — the persisted `tutorialSeen` flag
/// still false — it offers itself once; otherwise it only runs when replayed
/// from Profile.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  /// Guards the auto-start so it fires at most once per launch — the window
  /// between declining and the `tutorialSeen` write propagating would otherwise
  /// re-trigger it.
  bool _autoStartConsidered = false;

  /// The step whose anchor has already been brought into view.
  int? _revealed;

  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  /// Skipping or declining: stop, remember, and say where it lives.
  void _dismiss() {
    ref.read(databaseProvider).setTutorialSeen(true);
    ref.read(tutorialProvider.notifier).skip();
  }

  void _advance() {
    final ended = ref.read(tutorialProvider.notifier).next();
    if (ended) ref.read(databaseProvider).setTutorialSeen(true);
  }

  void _choose(TutorialTrack track) {
    ref.read(databaseProvider).setTutorialSeen(true);
    ref.read(tutorialProvider.notifier).start(track);
  }

  /// Scrolls [step]'s anchor into view, once per step.
  ///
  /// This is what lets a step point at something below the fold. It is a no-op
  /// for an anchor with no scrollable ancestor — the nav bar — and for one that
  /// is on screen already, so the common case costs nothing.
  void _revealAnchor(int index, BuildContext? ctx) {
    if (_revealed == index || ctx == null) return;
    _revealed = index;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// The first of [step]'s anchors that is laid out and actually on screen.
  ///
  /// Both halves matter. A key belonging to a screen nobody is on has no
  /// context at all; a key belonging to a tab that is alive but not showing has
  /// one, and measures to a rectangle nowhere near the viewport. Either way the
  /// step is better off centred than cutting a hole nobody can see.
  BuildContext? _anchorContext(TutorialStep step, Size screen) {
    for (final key in step.anchors) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      if (_isOffstage(box)) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.isEmpty) continue;
      if (!rect.overlaps(Offset.zero & screen)) continue;
      return ctx;
    }
    return null;
  }

  /// Whether [box] is inside a subtree that is laid out but not painted.
  ///
  /// This is the tab case. `StatefulShellRoute` keeps every branch alive behind
  /// an [Offstage], so a key hung on the Today tab still has a context, still
  /// has a size, and still measures to a rectangle in the middle of the screen
  /// while History is what you are looking at. Nothing about the box itself
  /// says so, so the ancestors have to be asked.
  bool _isOffstage(RenderObject box) {
    for (RenderObject? node = box; node != null; node = node.parent) {
      if (node is RenderOffstage && node.offstage) return true;
    }
    return false;
  }

  Rect? _targetRect(TutorialStep step, BuildContext? ctx) {
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final base = box.localToGlobal(Offset.zero) & box.size;
    if (step.navSlot == null) return base;
    final slotW = base.width / step.navSlotCount;
    return Rect.fromLTWH(
        base.left + slotW * step.navSlot!, base.top, slotW, base.height);
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(tutorialSeenProvider).value;
    final tut = ref.watch(tutorialProvider);

    // Genuine first run: the flag has loaded as false and nothing has run yet.
    if (!_autoStartConsidered && seen == false && !tut.active) {
      _autoStartConsidered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !ref.read(tutorialProvider).active) {
          ref.read(tutorialProvider.notifier).offer();
        }
      });
    }

    if (!tut.active) _revealed = null;

    if (tut.hint && _hintTimer == null) {
      _hintTimer = Timer(const Duration(seconds: 4), () {
        _hintTimer = null;
        if (mounted) ref.read(tutorialProvider.notifier).clearHint();
      });
    }

    return Stack(
      children: [
        // While the tour is up, anything that scrolls underneath moves the
        // anchor the spotlight is cut around — including the tour's own
        // scroll-into-view — so the overlay re-measures as it happens.
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            if (ref.read(tutorialProvider).active) _remeasure();
            return false;
          },
          child: widget.child,
        ),
        if (tut.active && tut.track == null) _buildChooser(context),
        if (tut.active && tut.track != null) _buildCoach(context, tut),
        if (tut.hint) _buildHint(context),
      ],
    );
  }

  /// Rebuilds after the frame in flight, so [_targetRect] reads the anchor's
  /// settled position rather than the one it is moving away from.
  void _remeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  // ------------------------------------------------------------ the chooser

  /// The opening card: which tour, or neither.
  Widget _buildChooser(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(340.0, size.width - 32);
    return Positioned.fill(
      child: Stack(
        children: [
          // Absorbing, not advancing: the question has two answers and a third
          // way out, and a stray tap on the dimmed screen must not count as any
          // of them.
          Positioned.fill(
            child: AbsorbPointer(
              child: CustomPaint(
                painter: _SpotlightPainter(hole: null, scrim: _kScrim),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: width,
                child: _card(
                  title: l10n.tutorialChooseTitle,
                  body: l10n.tutorialChooseBody,
                  counter: null,
                  // Stacked, not side by side: they are long labels in a card
                  // narrower than either the phone or the font can be relied on
                  // to be. And neither is styled as the recommendation — the
                  // choice is between two descriptions, not a default and an
                  // opt-out.
                  actions: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TrackButton(
                        label: l10n.tutorialTrackFull,
                        hint: l10n.tutorialTrackFullHint,
                        onTap: () => _choose(TutorialTrack.full),
                      ),
                      const SizedBox(height: 8),
                      _TrackButton(
                        label: l10n.tutorialTrackQuick,
                        hint: l10n.tutorialTrackQuickHint,
                        onTap: () => _choose(TutorialTrack.quick),
                      ),
                      TextButton(
                        onPressed: _dismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.faint,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(l10n.tutorialNotNow),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- the hint

  /// One line at the bottom of the screen after skipping, saying where the tour
  /// can be found again. It fades on its own — a button to dismiss it would be
  /// one more thing to dismiss.
  Widget _buildHint(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 24,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            l10n.tutorialReplayHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- the coach mark

  Widget _buildCoach(BuildContext context, TutorialState tut) {
    final steps = tut.steps;
    final index = tut.step.clamp(0, steps.length - 1);
    final step = steps[index];
    final size = MediaQuery.sizeOf(context);
    final ctx = _anchorContext(step, size);
    final rect = _targetRect(step, ctx);

    // Bring it into view first: a step may point at something below the fold,
    // and a spotlight on an off-screen rectangle is a dimmed screen with no
    // hole in it. After the frame, because scrolling during build is not
    // allowed.
    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealAnchor(index, ctx);
      });
    }

    // The target may not be laid out on the frame the tour opens (a fresh tab,
    // a card still building). Try again next frame rather than guess a spot —
    // but only when there is a target to wait for, or a step that points at
    // nothing would re-schedule itself for ever.
    if (rect == null && step.anchors.isNotEmpty) _remeasure();

    final padding = MediaQuery.paddingOf(context);

    return Positioned.fill(
      child: Stack(
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: _SpotlightPainter(hole: rect, scrim: _kScrim),
            ),
          ),
          ..._scrimTargets(step, rect, size),
          if (step.demo != null)
            _demoLayout(context, step, index, tut, size)
          else
            _callout(context, step, index, tut, size, padding, rect),
        ],
      ),
    );
  }

  /// The parts of the screen that take a tap while a coach mark is up.
  ///
  /// Everything outside the spotlight absorbs it and advances — a forgiving way
  /// through that cannot poke the app mid-sentence. The spotlight itself is the
  /// interesting half: on a [TutorialStep.tapThrough] step it is a `Listener`,
  /// which hears the tap without claiming it, so the real widget underneath
  /// gets it too and the tour moves on with whatever the app just did.
  List<Widget> _scrimTargets(TutorialStep step, Rect? rect, Size size) {
    final advance = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _advance,
      child: const SizedBox.expand(),
    );
    if (rect == null) return [Positioned.fill(child: advance)];

    final hole = rect.inflate(6);
    final top = hole.top.clamp(0.0, size.height);
    final bottom = hole.bottom.clamp(0.0, size.height);
    final left = hole.left.clamp(0.0, size.width);
    final right = hole.right.clamp(0.0, size.width);

    return [
      Positioned(left: 0, top: 0, right: 0, height: top, child: advance),
      Positioned(left: 0, top: bottom, right: 0, bottom: 0, child: advance),
      Positioned(
          left: 0, top: top, width: left, height: bottom - top, child: advance),
      Positioned(
          left: right,
          top: top,
          right: 0,
          height: bottom - top,
          child: advance),
      Positioned(
        left: left,
        top: top,
        width: right - left,
        height: bottom - top,
        child: step.tapThrough
            ? Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (_) => _advance(),
                child: const SizedBox.expand(),
              )
            : advance,
      ),
    ];
  }

  /// A step that brought its own picture.
  ///
  /// Two shapes, because the two mocks are different sizes of thing. The session
  /// screen is a *screen*: it fills the display, and the callout floats over it
  /// at whichever end leaves the step's subject uncovered. The shade is a
  /// notification, so it stays a card in the middle of a dimmed display with the
  /// callout under it.
  ///
  /// Either way the mock ignores pointers and the layout around it advances the
  /// tour, so the one thing on screen that looks tappable is the one thing that
  /// is not: tapping it moves the tour on, exactly as tapping the scrim does.
  Widget _demoLayout(
    BuildContext context,
    TutorialStep step,
    int index,
    TutorialState tut,
    Size size,
  ) {
    final width = math.min(340.0, size.width - 32);
    // Under a Material like the rest of the app: text with no Material above it
    // paints in the unstyled red-on-yellow the framework uses to say "nobody
    // gave me a style".
    Widget dressed(Widget mock) => Material(
          color: Colors.transparent,
          textStyle: TextStyle(color: AppColors.text),
          child: mock,
        );

    if (step.demo == TutorialDemo.screen) {
      // The rest bar is docked at the bottom, so its step reads from the top;
      // everything else on the board is near the top, so those read from the
      // bottom. Either way the callout never sits on what it is describing.
      final atTop = step.focus == TutorialDemoFocus.rest;
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: dressed(TutorialSessionDemo(focus: step.focus)),
                ),
              ),
              Align(
                alignment: atTop ? Alignment.topCenter : Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: width,
                      // Scrolls only when it has to: at the top of the text
                      // scale a five-line callout with three buttons under it
                      // is taller than the phone, and a card that runs off the
                      // screen takes its Next button with it.
                      child: SingleChildScrollView(
                        child: _calloutCard(step, index, tut),
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

    return Positioned.fill(
      // The layout covers the scrim, so it carries the scrim's job: a tap
      // anywhere that is not one of the callout's own buttons advances.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: SafeArea(
          child: Center(
            // Scrolls rather than overflows: at the top of the text scale the
            // mock and the callout together are taller than a short phone.
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    child: SizedBox(
                      width: width,
                      child: dressed(const TutorialShadeDemo()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: width, child: _calloutCard(step, index, tut)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _callout(
    BuildContext context,
    TutorialStep step,
    int index,
    TutorialState tut,
    Size size,
    EdgeInsets padding,
    Rect? rect,
  ) {
    final width = math.min(320.0, size.width - 32);
    final centerX = rect?.center.dx ?? size.width / 2;
    final left =
        (centerX - width / 2).clamp(16.0, size.width - 16 - width).toDouble();

    // Below the target when there is room, otherwise above it. With no target
    // yet, sit it in the middle.
    final spaceBelow = rect == null ? 0.0 : size.height - rect.bottom;
    final placeBelow = rect == null ? false : spaceBelow > 220;

    double? top;
    double? bottom;
    if (rect == null) {
      top = size.height / 2 - 90;
    } else if (placeBelow) {
      top = rect.bottom + 14;
    } else {
      bottom = size.height - rect.top + 14;
    }
    if (top != null) top = top.clamp(padding.top + 8, size.height - 120);
    if (bottom != null) {
      bottom = bottom.clamp(padding.bottom + 8, size.height - 120);
    }

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      width: width,
      child: _calloutCard(step, index, tut),
    );
  }

  /// The card itself: the step's title, its text, and the way on. Positioned by
  /// its caller — beside an anchor, or under a mock.
  Widget _calloutCard(TutorialStep step, int index, TutorialState tut) {
    final l10n = AppLocalizations.of(context);
    final total = tut.steps.length;
    final isLast = index == total - 1;

    return _card(
      title: step.title(l10n),
      body: step.body(l10n),
      counter: '${index + 1}/$total',
      // A Wrap rather than a Row with a Spacer in it. On one line the two
      // groups sit at the two ends, which is the Row's layout exactly; at the
      // top of the text scale three labels no longer fit across a callout, and
      // Skip drops to a line of its own rather than pushing Next off the card.
      actions: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          // Always available, at every step: the way out of the tour.
          TextButton(
            onPressed: _dismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.faint,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.tutorialSkip),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (index > 0)
                TextButton(
                  onPressed: () => ref.read(tutorialProvider.notifier).back(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.tutorialBack),
                ),
              FilledButton(
                onPressed: _advance,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: Text(isLast ? l10n.commonDone : l10n.tutorialNext),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The one card shape the tour draws — the opening choice and every coach
  /// mark. Written once so a step and the chooser cannot drift apart.
  Widget _card({
    required String title,
    required String body,
    required String? counter,
    required Widget actions,
  }) =>
      Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (counter != null)
                    Text(
                      counter,
                      style: kMono.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: AppColors.faint),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                    fontSize: 13.5, height: 1.35, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              actions,
            ],
          ),
        ),
      );
}

const _kScrim = Color(0xB80B0E13);

/// One of the tours on offer: its name, and the line saying what is in it.
class _TrackButton extends StatelessWidget {
  const _TrackButton({
    required this.label,
    required this.hint,
    required this.onTap,
  });
  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.centerLeft,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// The sheet Profile's "Help & tour" entry opens: the three tours, each with
/// the line that says what is in it.
///
/// It lives here rather than on the Profile screen because the tracks and their
/// descriptions are the tour's business, and a second list of them somewhere
/// else is a second list to keep in step.
Future<void> showTutorialPicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final chosen = await showModalBottomSheet<TutorialTrack>(
    context: context,
    backgroundColor: AppColors.ground,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tutorialReplayTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          for (final (track, label, hint) in [
            (TutorialTrack.full, l10n.tutorialTrackFull,
                l10n.tutorialTrackFullHint),
            (TutorialTrack.quick, l10n.tutorialTrackQuick,
                l10n.tutorialTrackQuickHint),
            (TutorialTrack.builder, l10n.tutorialTrackBuilder,
                l10n.tutorialTrackBuilderHint),
          ]) ...[
            _TrackButton(
              label: label,
              hint: hint,
              onTap: () => Navigator.pop(ctx, track),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );
  if (chosen != null) ref.read(tutorialProvider.notifier).start(chosen);
}

/// Dims the whole screen and punches a rounded hole around the target so the
/// eye lands on the thing the callout is talking about.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.scrim});
  final Rect? hole;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrimPaint = Paint()..color = scrim;

    if (hole == null) {
      canvas.drawRect(full, scrimPaint);
      return;
    }

    final cut = RRect.fromRectAndRadius(
      hole!.inflate(6),
      const Radius.circular(14),
    );
    final overlay = Path()..addRect(full);
    final window = Path()..addRRect(cut);
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlay, window),
      scrimPaint,
    );
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.scrim != scrim;
}
