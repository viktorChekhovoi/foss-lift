library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/text_scale.dart';

const double kPinchSlop = 24;

/// Applies the user's pinch-adjusted text scale without changing page layout.
class PinchTextScale extends ConsumerStatefulWidget {
  const PinchTextScale({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PinchTextScale> createState() => _PinchTextScaleState();
}

class _PinchTextScaleState extends ConsumerState<PinchTextScale> {
  double? _live;

  double? _pending;

  double? _seenStored;

  double _startedAt = 1.0;

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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(resolveTextScale(
                system: MediaQuery.textScalerOf(context).scale(1),
                chosen: _chosen,
              )),
            ),
            child: widget.child,
          ),
          if (_showReadout)
            Positioned.fill(
              child: IgnorePointer(child: _ScaleReadout(scale: _chosen)),
            ),
        ],
      ),
    );
  }
}

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

class _PinchRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onStart;

  ValueChanged<double>? onUpdate;
  VoidCallback? onEnd;

  final Map<int, Offset> _points = {};

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
    _baseline ??= span / _ratio;
    _ratio = span / _baseline!;

    if (!_active) {
      if ((span - _baseline!).abs() < kPinchSlop) return;
      _active = true;
      resolve(GestureDisposition.accepted);
      onStart?.call();
    }
    onUpdate?.call(_ratio);
  }

  void _rebase() => _baseline = null;

  double _span() {
    final points = _points.values.toList();
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
