import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'tutorial_demo.dart';

// Anchors are measured by the coach-mark overlay, so each target needs a GlobalKey shared between the tour and the screen that renders it.
final tutorialNavBarKey = GlobalKey();

final tutorialTodayEmptyKey = GlobalKey();

final tutorialTodayRoutineKey = GlobalKey();

final tutorialLifetimeKey = GlobalKey();

enum TutorialDemo { screen, builder, shade }

TutorialStep _drawn(
  String id,
  TutorialDemoFocus focus,
  String Function(AppLocalizations) title,
  String Function(AppLocalizations) body,
) =>
    TutorialStep(
      id: id,
      demo: TutorialDemo.builder,
      focus: focus,
      title: title,
      body: body,
    );

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

  final String id;

  // Multiple anchors support equivalent controls on different screens.
  final List<GlobalKey> anchors;

  final int? navSlot;
  final int navSlotCount;

  final TutorialDemo? demo;

  final TutorialDemoFocus focus;

  // Interactive steps let the tap reach the underlying widget.
  final bool tapThrough;

  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
}

enum TutorialTrack { full, quick, builder }

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

final List<TutorialStep> _kTodaySteps = [
  TutorialStep(
    id: 'today-get-a-routine',
    anchors: [tutorialTodayEmptyKey, tutorialTodayRoutineKey],
    title: (l) => l.tutorialTodayRoutineTitle,
    body: (l) => l.tutorialTodayRoutineBody,
  ),
];

final TutorialStep _kLifetimeStep = TutorialStep(
  id: 'today-lifetime',
  anchors: [tutorialLifetimeKey],
  title: (l) => l.tutorialLifetimeTitle,
  body: (l) => l.tutorialLifetimeBody,
);

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
    id: 'session-weight',
    demo: TutorialDemo.screen,
    focus: TutorialDemoFocus.weight,
    title: (l) => l.tutorialWeightTitle,
    body: (l) => l.tutorialWeightBody,
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

final List<TutorialStep> _kBuilderSteps = [
  _kBuildOpenStep,
  _kBuildAddStep,
  _kBuildLibraryStep,
  _kBuildNewStep,
  _kBuildImportStep,
  _drawn('build-name', TutorialDemoFocus.name, (l) => l.tutorialBuildNameTitle,
      (l) => l.tutorialBuildNameBody),
  _drawn('build-days', TutorialDemoFocus.days, (l) => l.tutorialBuildDaysTitle,
      (l) => l.tutorialBuildDaysBody),
  _drawn('build-exercises', TutorialDemoFocus.exercises,
      (l) => l.tutorialBuildExercisesTitle,
      (l) => l.tutorialBuildExercisesBody),
  _drawn('build-slot', TutorialDemoFocus.slot, (l) => l.tutorialBuildSlotTitle,
      (l) => l.tutorialBuildSlotBody),
  _drawn('build-superset', TutorialDemoFocus.superset,
      (l) => l.tutorialBuildSupersetTitle,
      (l) => l.tutorialBuildSupersetBody),
  _drawn('build-save-day', TutorialDemoFocus.saveDay,
      (l) => l.tutorialBuildSaveDayTitle, (l) => l.tutorialBuildSaveDayBody),
  _kBuildSaveStep,
];

final List<TutorialStep> _kQuickBuilderSteps = [
  _kBuildOpenStep,
  _kBuildAddStep,
  _kBuildLibraryStep,
  _kBuildNewStep,
  _drawn('build-quick', TutorialDemoFocus.days,
      (l) => l.tutorialBuildQuickTitle, (l) => l.tutorialBuildQuickBody),
  _kBuildSaveStep,
];

final TutorialStep _kBuildOpenStep = _drawn(
    'build-open',
    TutorialDemoFocus.routinesTab,
    (l) => l.tutorialBuildOpenTitle,
    (l) => l.tutorialBuildOpenBody);

final TutorialStep _kBuildAddStep = _drawn(
    'build-add',
    TutorialDemoFocus.addRoutine,
    (l) => l.tutorialBuildAddTitle,
    (l) => l.tutorialBuildAddBody);

final TutorialStep _kBuildLibraryStep = _drawn(
    'build-library',
    TutorialDemoFocus.library,
    (l) => l.tutorialBuildLibraryTitle,
    (l) => l.tutorialBuildLibraryBody);

final TutorialStep _kBuildNewStep = _drawn(
    'build-new',
    TutorialDemoFocus.newRoutine,
    (l) => l.tutorialBuildNewTitle,
    (l) => l.tutorialBuildNewBody);

final TutorialStep _kBuildImportStep = _drawn(
    'build-import',
    TutorialDemoFocus.importRoutine,
    (l) => l.tutorialBuildImportTitle,
    (l) => l.tutorialBuildImportBody);

final TutorialStep _kBuildSaveStep = _drawn('build-save',
    TutorialDemoFocus.save, (l) => l.tutorialBuildSaveTitle,
    (l) => l.tutorialBuildSaveBody);

final Map<TutorialTrack, List<TutorialStep>> kTutorialTracks = {
  TutorialTrack.full: [
    ..._kTabSteps,
    _tab('tab-back-to-today', 0, (l) => l.tutorialBackToTodayTitle,
        (l) => l.tutorialBackToTodayBody),
    ..._kTodaySteps,
    ..._kSessionSteps,
    _kLifetimeStep,
    ..._kBuilderSteps,
    TutorialStep(
      id: 'done',
      title: (l) => l.tutorialDoneTitle,
      body: (l) => l.tutorialDoneBody,
    ),
  ],
  TutorialTrack.quick: [
    ..._kTabSteps,
    ..._kQuickBuilderSteps,
    TutorialStep(
      id: 'done-quick',
      title: (l) => l.tutorialDoneTitle,
      body: (l) => l.tutorialDoneQuickBody,
    ),
  ],
  TutorialTrack.builder: [
    ..._kBuilderSteps,
    TutorialStep(
      id: 'build-done',
      title: (l) => l.tutorialBuildDoneTitle,
      body: (l) => l.tutorialBuildDoneBody,
    ),
  ],
};


class TutorialState {
  const TutorialState({
    this.active = false,
    this.track,
    this.step = 0,
    this.hint = false,
  });

  final bool active;

  final TutorialTrack? track;
  final int step;

  final bool hint;

  List<TutorialStep> get steps =>
      track == null ? const [] : kTutorialTracks[track]!;
}

class TutorialController extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  void offer() => state = const TutorialState(active: true);

  void start(TutorialTrack track) =>
      state = TutorialState(active: true, track: track);

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

  void skip() => state = const TutorialState(hint: true);

  void clearHint() {
    if (state.hint) state = const TutorialState();
  }
}

final tutorialProvider =
    NotifierProvider<TutorialController, TutorialState>(TutorialController.new);


class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  bool _autoStartConsidered = false;

  int? _revealed;

  Timer? _hintTimer;

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

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

  void _remeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }


  Widget _buildChooser(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(340.0, size.width - 32);
    return Positioned.fill(
      child: Stack(
        children: [
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
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _dismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.text,
                          minimumSize: const Size(0, 44),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
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


  Widget _buildCoach(BuildContext context, TutorialState tut) {
    final steps = tut.steps;
    final index = tut.step.clamp(0, steps.length - 1);
    final step = steps[index];
    final size = MediaQuery.sizeOf(context);
    final ctx = _anchorContext(step, size);
    final rect = _targetRect(step, ctx);

    if (ctx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealAnchor(index, ctx);
      });
    }

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

  Widget _demoLayout(
    BuildContext context,
    TutorialStep step,
    int index,
    TutorialState tut,
    Size size,
  ) {
    final width = math.min(340.0, size.width - 32);
    Widget dressed(Widget mock) => Material(
          color: Colors.transparent,
          textStyle: TextStyle(color: AppColors.text),
          child: mock,
        );

    if (step.demo != TutorialDemo.shade) {
      final atTop = const {
        TutorialDemoFocus.rest,
        TutorialDemoFocus.save,
        TutorialDemoFocus.saveDay,
        TutorialDemoFocus.library,
        TutorialDemoFocus.newRoutine,
        TutorialDemoFocus.importRoutine,
      }.contains(step.focus);

      final callout = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.5),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: _calloutCard(step, index, tut),
              ),
            ),
          ),
        ),
      );
      final mock = Expanded(
        child: IgnorePointer(
          child: dressed(step.demo == TutorialDemo.screen
              ? TutorialSessionDemo(focus: step.focus)
              : TutorialBuilderDemo(focus: step.focus)),
        ),
      );

      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: ColoredBox(
            color: AppColors.ground,
            child: Column(
              children: atTop ? [callout, mock] : [mock, callout],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: ColoredBox(
          color: AppColors.ground,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Widget _calloutCard(TutorialStep step, int index, TutorialState tut) {
    final l10n = AppLocalizations.of(context);
    final total = tut.steps.length;
    final isLast = index == total - 1;

    return _card(
      title: step.title(l10n),
      body: step.body(l10n),
      counter: '${index + 1}/$total',
      actions: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
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
