import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

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

/// One coach mark: a target to spotlight and the text to show beside it.
class TutorialStep {
  const TutorialStep({
    required this.key,
    required this.title,
    required this.body,
    this.navSlot,
    this.navSlotCount = 1,
  });

  /// The widget to anchor to. When [navSlot] is set this is the nav bar and the
  /// highlight is one equal slice of it.
  final GlobalKey key;

  /// Which slot of [navSlotCount] to highlight, or null to use the whole widget.
  final int? navSlot;
  final int navSlotCount;

  final String title;
  final String body;
}

/// The first-run tour, in order. Five high-value targets, all reachable on the
/// Today tab (the tab bar is always up, the workout and lifetime cards are on
/// Today itself), so the tour never has to drive navigation to keep up.
///
/// Not `const`: the anchors are runtime [GlobalKey] instances.
final List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    key: tutorialTodayWorkoutKey,
    title: 'Your next workout',
    body: 'This training day is queued up next. Tap it to see the exercises, '
        'then Start when you are ready to lift.',
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
/// resume pill) so the coach marks can spotlight the bottom nav as readily as a
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

  Rect? _targetRect(TutorialStep step) {
    final ctx = step.key.currentContext;
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

    return Stack(
      children: [
        widget.child,
        if (tut.active) _buildCoach(context, tut.step),
      ],
    );
  }

  Widget _buildCoach(BuildContext context, int stepIndex) {
    final index = stepIndex.clamp(0, kTutorialSteps.length - 1);
    final step = kTutorialSteps[index];
    final rect = _targetRect(step);

    // The target may not be laid out on the frame the tour opens (a fresh tab,
    // a card still building). Try again next frame rather than guess a spot.
    if (rect == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

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
          _callout(context, step, index, size, padding, rect),
        ],
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

    final isLast = index == kTutorialSteps.length - 1;

    return Positioned(
      left: left,
      top: top,
      bottom: bottom,
      width: width,
      child: Material(
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
                      style: const TextStyle(
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
                style: const TextStyle(
                    fontSize: 13.5, height: 1.35, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
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
