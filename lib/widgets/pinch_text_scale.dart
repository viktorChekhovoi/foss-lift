/// Pinch anywhere in the app to change how big its text is.
///
/// **This scales text, not the canvas.** Zooming the whole surface — the way a
/// gallery zooms a photo — is the gesture people ask for, and it is the wrong
/// one for an app that is a column of scrolling lists: a zoomed canvas has to be
/// panned, and panning fights the scroll it is drawn over on the same axis. What
/// somebody pinching a workout log actually wants is bigger words, and bigger
/// words are a setting this app already has. So the gesture writes that setting:
/// the layout keeps reflowing, the list keeps scrolling, and the result is the
/// same one the chips on Appearance produce.
///
/// The gesture is mounted once, above every route, so it works on any screen
/// rather than on the one screen somebody thought to add it to.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/text_scale.dart';

/// How far the distance between two fingers must change before the pinch takes
/// over, in logical pixels.
///
/// Above Flutter's own touch slop: two fingers resting on a list and dragging it
/// are a scroll, and the span between them wanders by a few pixels while they do
/// it. Below this the gesture is nobody's intent.
const double kPinchSlop = 24;

/// Applies the app's text scale to [child], and lets a two-finger pinch change
/// it.
///
/// Owns the [MediaQuery] the whole app renders under: the scale being dragged
/// has to reach the tree on the frame it changes, and it cannot wait for the
/// database write to come back round through a provider.
class PinchTextScale extends ConsumerStatefulWidget {
  const PinchTextScale({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PinchTextScale> createState() => _PinchTextScaleState();
}

class _PinchTextScaleState extends ConsumerState<PinchTextScale> {
  /// The nudge the fingers are currently on, or null when none are down.
  double? _live;

  /// The nudge the last gesture ended on, held until the write it triggered
  /// comes back through the provider. Without it the text snaps back to the old
  /// value for the frames between lifting a finger and the database answering.
  double? _pending;

  /// The stored value at the moment [_pending] was written, so "the write has
  /// landed" can be told from "nothing has happened yet".
  double? _seenStored;

  /// Where the gesture in progress started from.
  double _startedAt = 1.0;

  /// The value the tree is rendering at, for a handler that has no build
  /// context to read it from.
  double _chosen = 1.0;
  double _stored = 1.0;

  Timer? _hide;
  bool _showReadout = false;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _onStart() {
    _startedAt = _chosen;
    _hide?.cancel();
    setState(() => _showReadout = true);
  }

  void _onUpdate(double ratio) {
    setState(() => _live = clampTextNudge(_startedAt * ratio));
  }

  void _onEnd() {
    final landed = _live;
    setState(() {
      _live = null;
      if (landed != null) {
        _pending = landed;
        _seenStored = _stored;
      }
    });
    if (landed != null) unawaited(ref.read(databaseProvider).setTextScale(landed));
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showReadout = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    _stored = ref.watch(textScaleProvider).value ?? 1.0;
    // The write has come back round, or something else has moved the setting —
    // either way the stored value is the truth again.
    if (_pending != null && _stored != _seenStored) {
      _pending = null;
      _seenStored = null;
    }
    _chosen = _live ?? _pending ?? _stored;

    return RawGestureDetector(
      gestures: {
        _PinchRecognizer:
            GestureRecognizerFactoryWithHandlers<_PinchRecognizer>(
          _PinchRecognizer.new,
          (r) => r
            ..onStart = _onStart
            ..onUpdate = _onUpdate
            ..onEnd = _onEnd,
        ),
      },
      child: Stack(
        children: [
          MediaQuery(
            // The phone's text size, nudged by the user's own and held inside
            // the range every screen is swept at — see util/text_scale.dart.
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(resolveTextScale(
                system: MediaQuery.textScalerOf(context).scale(1),
                chosen: _chosen,
              )),
            ),
            child: widget.child,
          ),
          // Outside the MediaQuery above on purpose: a readout that grew with
          // the thing it is reporting would be its own worst illustration.
          if (_showReadout)
            Positioned.fill(
              child: IgnorePointer(child: _ScaleReadout(scale: _chosen)),
            ),
        ],
      ),
    );
  }
}

/// What scale the pinch is on, while it is on it.
///
/// A percentage of the phone's own size, which is what the setting is — 100%
/// means "whatever the phone says", the same thing Default means on Appearance.
class _ScaleReadout extends StatelessWidget {
  const _ScaleReadout({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          NumberFormat.percentPattern().format(scale),
          style: kMono.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Two fingers moving apart or together, and nothing else.
///
/// Not Flutter's [ScaleGestureRecognizer], which also claims a one-finger pan:
/// mounted above every route, that would take every scroll in the app. This one
/// never looks at a lone pointer, and only enters the arena at all once the span
/// between two of them has moved past [kPinchSlop] — so a scroll that happens to
/// be made with two fingers still scrolls, and a pinch stops it the moment it
/// becomes a pinch.
class _PinchRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onStart;

  /// The span now, over the span the gesture started at.
  ValueChanged<double>? onUpdate;
  VoidCallback? onEnd;

  final Map<int, Offset> _points = {};

  /// The span the current ratio is measured against.
  double? _baseline;
  double _ratio = 1;
  bool _active = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _points[event.pointer] = event.position;
    _rebase();
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _points[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _points.remove(event.pointer);
      _rebase();
      stopTrackingPointer(event.pointer);
    }

    if (_points.length < 2) {
      _finish();
      return;
    }
    final span = _span();
    // A finger arriving or leaving mid-gesture must not move the text: the
    // baseline moves with it so the ratio stays where it was.
    _baseline ??= span / _ratio;
    _ratio = span / _baseline!;

    if (!_active) {
      if ((span - _baseline!).abs() < kPinchSlop) return;
      _active = true;
      // Only now, so anything else that wanted these pointers has had them
      // until the gesture actually became a pinch.
      resolve(GestureDisposition.accepted);
      onStart?.call();
    }
    onUpdate?.call(_ratio);
  }

  /// Forgets the span, so the next two-pointer event measures a fresh one
  /// against the ratio already reached.
  void _rebase() => _baseline = null;

  double _span() {
    final points = _points.values.toList();
    // The mean distance from the centroid: with two fingers this is half the
    // gap between them, and with three it is still a size rather than a pair.
    final centroid = points.reduce((a, b) => a + b) / points.length.toDouble();
    var total = 0.0;
    for (final p in points) {
      total += (p - centroid).distance;
    }
    return total / points.length;
  }

  void _finish() {
    _baseline = null;
    if (!_active) return;
    _active = false;
    _ratio = 1;
    onEnd?.call();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _points.clear();
    _finish();
  }

  @override
  String get debugDescription => 'pinch to scale text';
}
