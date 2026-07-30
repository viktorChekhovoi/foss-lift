import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The current routine's next training day on the Today screen.
final tutorialTodayWorkoutKey = GlobalKey();

/// The lifetime-totals card on the Today screen.
final tutorialLifetimeKey = GlobalKey();

/// The whole bottom navigation bar. Individual tabs are highlighted by slicing
/// this rect into equal slots — see [TutorialStep.navSlot].
final tutorialNavBarKey = GlobalKey();

// ---------------------------------------------------------------------------
// Steps
// ---------------------------------------------------------------------------

/// Which stand-in a step draws for the live workout — see
/// [TutorialBoardDemo] and [TutorialRestDemo].
enum TutorialDemo { board, restBar, shade }

/// One coach mark: a target to spotlight and the text to show beside it.
class TutorialStep {
  const TutorialStep({
    this.key,
    required this.title,
    required this.body,
    this.navSlot,
    this.navSlotCount = 1,
    this.demo,
    this.focus = TutorialDemoFocus.none,
  });

  /// The widget to anchor to, or **null for a step that points at nothing**.
  /// The welcome card is the one of those: it is about the app rather than
  /// about a control, so it sits in the middle of a plain dimmed screen.
  ///
  /// When [navSlot] is set this is the nav bar and the highlight is one equal
  /// slice of it.
  final GlobalKey? key;

  /// Which slot of [navSlotCount] to highlight, or null to use the whole widget.
  final int? navSlot;
  final int navSlotCount;

  /// The mock to draw above the callout, for a step about something that only
  /// exists mid-session. A step with one has no [key]: it points at the picture
  /// it brought with it, not at anything behind the scrim.
  final TutorialDemo? demo;

  /// Which part of the mock board this step is about — the ring, for an icon
  /// too small to be found by prose alone.
  final TutorialDemoFocus focus;

  final String title;
  final String body;
}

/// The first-run tour, in order: a greeting, then the high-value targets.
///
/// **An anchored step may point anywhere on the Today tab, including below the
/// fold** — the overlay scrolls the anchor into view before spotlighting it, so
/// the lifetime card gets pointed at on a routine with more training days than
/// fit on a screen. What the tour will not do is move between tabs: the steps
/// about the other three describe them and highlight their tab button, which
/// leaves you where you started.
///
/// **The workout itself is drawn, not pointed at.** The board, the rest timer,
/// the note and the clip are where the app is least like every other tracker —
/// but none of them exists until a session is running, and a tour that starts a
/// workout to show you a workout is a tour that leaves you somewhere you did
/// not ask to be. Those steps carry a mock of the thing they describe instead
/// of an anchor, so there is something to look at while the callout talks.
///
/// **It opens on the greeting, not on a coach mark.** Arriving straight into an
/// arrow pointing at something, before the app has said what it is or that a
/// tour is happening, reads as a malfunction rather than an introduction.
///
/// Not `const`: the anchors are runtime [GlobalKey] instances.
final List<TutorialStep> kTutorialSteps = [
  const TutorialStep(
    title: 'Welcome to Foss Lift',
    body: 'Plan a routine, log your lifts, watch the numbers move. '
        'Here is where it all is.',
  ),
  TutorialStep(
    key: tutorialTodayWorkoutKey,
    title: 'Your next workout',
    body: 'This training day is queued up next. Tap it to see the exercises, '
        'then Start when you are ready to lift.',
  ),
  // The five steps below are about a screen the tour cannot point at: the board
  // only exists while a workout is running, and starting one to show it off
  // would leave somebody mid-session they did not ask for. So each draws the
  // mock instead and talks about that — see lib/widgets/tutorial_demo.dart.
  const TutorialStep(
    demo: TutorialDemo.board,
    focus: TutorialDemoFocus.nextSet,
    title: 'While you lift',
    body: 'The set you are on is outlined. Tap its reps to log the goal, tap '
        'again for each rep you missed, or hold to type a number.',
  ),
  const TutorialStep(
    demo: TutorialDemo.restBar,
    title: 'The rest timer',
    body: 'Logging a set starts it, and it keeps running if you leave the '
        'screen. Longer, shorter or skip; it sounds when it is up.',
  ),
  const TutorialStep(
    demo: TutorialDemo.board,
    focus: TutorialDemoFocus.note,
    title: 'Your note on a movement',
    body: 'The seat height, the pin, the cue that worked. Tap the note icon to '
        'write it mid-set; it is kept on the exercise, so it is there next '
        'time you train it.',
  ),
  const TutorialStep(
    demo: TutorialDemo.board,
    focus: TutorialDemoFocus.camera,
    title: 'Film a set',
    body: 'The camera on a logged set records a silent clip of it. Watch it '
        'back at quarter speed, or line the movement up over months from the '
        'exercise in your library. Clips never leave the phone.',
  ),
  const TutorialStep(
    demo: TutorialDemo.shade,
    title: 'In your notifications',
    body: 'The workout sits in your notification shade: the set you are on, '
        'Done and Missed to log it, and the rest counting down with Skip.',
  ),
  TutorialStep(
    key: tutorialLifetimeKey,
    title: 'Lifetime totals',
    body: 'Every session you finish adds to your volume, sets and reps here.',
  ),
  TutorialStep(
    key: tutorialNavBarKey,
    navSlot: 1,
    navSlotCount: 4,
    title: 'Routines',
    body: 'Build a new programme, or switch which routine Today follows.',
  ),
  TutorialStep(
    key: tutorialNavBarKey,
    navSlot: 2,
    navSlotCount: 4,
    title: 'History',
    body: 'Every workout you finish is logged here to look back on.',
  ),
  TutorialStep(
    key: tutorialNavBarKey,
    navSlot: 3,
    navSlotCount: 4,
    title: 'Profile & help',
    body: 'Settings, the exercise library, and this tour all live here — replay '
        'it any time from “Help & tour”.',
  ),
];

// ---------------------------------------------------------------------------
// Controller — in-memory, like the live-session visibility flag
// ---------------------------------------------------------------------------

/// Whether the tour is on screen and which step it is showing. Purely
/// in-memory; the "already seen it" fact is the persisted `tutorialSeen` flag.
class TutorialState {
  const TutorialState({this.active = false, this.step = 0});
  final bool active;
  final int step;
}

class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  /// Begins the tour at the first step. Used both by the first-run auto-start
  /// and by the Help entry on the Profile screen.
  void start() => state = const TutorialState(active: true, step: 0);

  /// Advances, ending the tour after the last step. Returns true if it ended.
  bool next() {
    if (state.step + 1 >= kTutorialSteps.length) {
      stop();
      return true;
    }
    state = TutorialState(active: true, step: state.step + 1);
    return false;
  }

  void back() {
    if (state.step > 0) {
      state = TutorialState(active: true, step: state.step - 1);
    }
  }

  void stop() => state = const TutorialState();
}

final tutorialProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);

// ---------------------------------------------------------------------------
// Overlay
// ---------------------------------------------------------------------------

/// Wraps the whole app (mounted in `MaterialApp.router`'s builder, above the
/// resume bar) so the coach marks can spotlight the bottom nav as readily as a
/// card on Today. On a genuine first run — the persisted `tutorialSeen` flag
/// still false — it starts itself once; otherwise it only runs when replayed
/// from the help menu.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  /// Guards the auto-start so it fires at most once per launch — the window
  /// between skipping and the `tutorialSeen` write propagating would otherwise
  /// re-trigger it.
  bool _autoStartConsidered = false;

  void _dismiss() {
    // Skipping or finishing both mean "don't run again on its own".
    ref.read(databaseProvider).setTutorialSeen(true);
    ref.read(tutorialProvider.notifier).stop();
  }

  void _advance() {
    final ended = ref.read(tutorialProvider.notifier).next();
    if (ended) ref.read(databaseProvider).setTutorialSeen(true);
  }

  /// The step whose anchor has already been brought into view.
  int? _revealed;

  /// Scrolls [step]'s anchor into view, once per step.
  ///
  /// This is what lets a step point at something below the fold. It is a no-op
  /// for an anchor with no scrollable ancestor — the nav bar — and for one that
  /// is on screen already, so the common case costs nothing.
  void _revealAnchor(int index, TutorialStep step) {
    if (_revealed == index) return;
    final ctx = step.key?.currentContext;
    if (ctx == null) return; // not laid out yet; the retry frame will come back
    _revealed = index;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Rect? _targetRect(TutorialStep step) {
    // A step with no anchor points at nothing on purpose — see TutorialStep.key.
    final ctx = step.key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final base = box.localToGlobal(Offset.zero) & box.size;
    if (step.navSlot == null) return base;
    final slotW = base.width / step.navSlotCount;
    return Rect.fromLTWH(base.left + slotW * step.navSlot!, base.top, slotW,
        base.height);
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
          ref.read(tutorialProvider.notifier).start();
        }
      });
    }

    if (!tut.active) _revealed = null;

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
        if (tut.active) _buildCoach(context, tut.step),
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

  Widget _buildCoach(BuildContext context, int stepIndex) {
    final index = stepIndex.clamp(0, kTutorialSteps.length - 1);
    final step = kTutorialSteps[index];
    final rect = _targetRect(step);

    // Bring it into view first: a step may point at something below the fold,
    // and a spotlight on an off-screen rectangle is a dimmed screen with no
    // hole in it. After the frame, because scrolling during build is not
    // allowed.
    if (step.key != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealAnchor(index, step);
      });
    }

    // The target may not be laid out on the frame the tour opens (a fresh tab,
    // a card still building). Try again next frame rather than guess a spot —
    // but only when there is a target to wait for, or the anchorless welcome
    // step would re-schedule itself for ever.
    if (rect == null && step.key != null) _remeasure();

    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const scrim = Color(0xB80B0E13);

    return Positioned.fill(
      child: Stack(
        children: [
          // The dimmed backdrop with a hole cut around the target. Tapping it
          // advances — a forgiving way through — and absorbs the tap so the app
          // underneath is never poked mid-tour.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: CustomPaint(
                painter: _SpotlightPainter(hole: rect, scrim: scrim),
              ),
            ),
          ),
          if (step.demo != null)
            _demoLayout(context, step, index, size)
          else
            _callout(context, step, index, size, padding, rect),
        ],
      ),
    );
  }

  /// A step that brought its own picture: the mock, and the callout under it,
  /// in the middle of a plain dimmed screen.
  ///
  /// The mock ignores pointers and the layout around it advances the tour, so
  /// the one thing on screen that looks tappable is the one thing that is not:
  /// tapping it moves the tour on, exactly as tapping the scrim does.
  Widget _demoLayout(
    BuildContext context,
    TutorialStep step,
    int index,
    Size size,
  ) {
    final width = math.min(340.0, size.width - 32);
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
                      // Under a Material like the rest of the app: text with no
                      // Material above it paints in the unstyled red-on-yellow
                      // the framework uses to say "nobody gave me a style".
                      child: Material(
                        color: Colors.transparent,
                        textStyle: TextStyle(color: AppColors.text),
                        child: switch (step.demo!) {
                          TutorialDemo.board =>
                            TutorialBoardDemo(focus: step.focus),
                          TutorialDemo.restBar => const TutorialRestDemo(),
                          TutorialDemo.shade => const TutorialShadeDemo(),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: width, child: _calloutCard(step, index)),
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
      child: _calloutCard(step, index),
    );
  }

  /// The card itself: the step's title, its text, and the way on. Positioned by
  /// its caller — beside an anchor, or under a mock.
  Widget _calloutCard(TutorialStep step, int index) {
    final isLast = index == kTutorialSteps.length - 1;
    // The greeting asks a question the rest of the tour does not: whether to
    // have one at all. So its buttons answer that, rather than reading as
    // navigation through something already under way.
    final isWelcome = index == 0;

    return Material(
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
                      step.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    '${index + 1}/${kTutorialSteps.length}',
                    style: kMono.copyWith(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: AppColors.faint),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step.body,
                style: TextStyle(
                    fontSize: 13.5, height: 1.35, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              // The greeting stacks its two answers — a full-width "yes" over a
              // quiet "no" — because side by side they are two long labels in a
              // callout narrower than either the phone or the font can be
              // relied on to be. Every later step is a short Skip/Back/Next and
              // fits across.
              if (isWelcome)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: _advance,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Take the tour'),
                    ),
                    TextButton(
                      onPressed: _dismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.faint,
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Not now'),
                    ),
                  ],
                )
              else
                Row(
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
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  if (index > 0)
                    TextButton(
                      onPressed: () =>
                          ref.read(tutorialProvider.notifier).back(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _advance,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF1A0E07),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: Text(isLast ? 'Done' : 'Next'),
                  ),
                ],
                ),
            ],
          ),
        ),
      );
  }
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
