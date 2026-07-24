import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// intl also defines a `TextDirection`; hide it so the dart:ui one (with `.ltr`)
// that TextPainter needs stays in scope.
import 'package:intl/intl.dart' hide TextDirection;

import '../data/database.dart';
import '../providers/providers.dart';
import '../state/active_workout.dart' show fmtWeight;
import '../theme/app_theme.dart';
import '../util/units.dart';

/// Which number the chart plots for a weighted movement.
enum _Metric {
  est1RM('Est 1RM'),
  topSet('Top set');

  const _Metric(this.label);
  final String label;
}

/// A per-exercise progress chart over every finished session. Read-only — it
/// only ever reads the log.
class ExerciseProgressScreen extends ConsumerWidget {
  const ExerciseProgressScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        top: false,
        child: library.when(
          loading: () => Center(
              child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: AppColors.muted))),
          data: (all) {
            Exercise? ex;
            for (final e in all) {
              if (e.id == exerciseId) {
                ex = e;
                break;
              }
            }
            if (ex == null) {
              return Center(
                child: Text('This exercise no longer exists.',
                    style: TextStyle(color: AppColors.muted)),
              );
            }
            return _Body(exercise: ex);
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.exercise});
  final Exercise exercise;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  _Metric _metric = _Metric.est1RM;

  bool get _timed => widget.exercise.measure == ExerciseMeasure.time;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(exerciseHistoryProvider(widget.exercise.id));
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';

    return history.when(
      loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: AppColors.muted))),
      data: (sets) {
        final points = progressPoints(sets);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(widget.exercise.name,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(
              points.isEmpty
                  ? 'No history yet'
                  : '${points.length} session${points.length == 1 ? '' : 's'} logged',
              style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            if (points.isEmpty)
              _EmptyState(timed: _timed)
            else ...[
              if (!_timed) ...[
                _MetricToggle(
                  value: _metric,
                  onChanged: (m) => setState(() => _metric = m),
                ),
                const SizedBox(height: 16),
              ],
              _ChartCard(points: points, metric: _metric, timed: _timed, unit: unit),
              const SizedBox(height: 20),
              _LatestReadout(
                  points: points, metric: _metric, timed: _timed, unit: unit),
            ],
          ],
        );
      },
    );
  }
}

/// The value the chart and readout show for one session, in the display unit
/// (weight metrics) or in seconds (a held movement).
double _valueOf(
    ExerciseProgressPoint p, _Metric metric, bool timed, String unit) {
  if (timed) return p.bestSeconds.toDouble();
  final kg = metric == _Metric.est1RM ? p.est1RMKg : p.topWeightKg;
  return toDisplayWeight(kg, unit);
}

class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.value, required this.onChanged});
  final _Metric value;
  final ValueChanged<_Metric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final m in _Metric.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: m == value
                        ? AppColors.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    m.label,
                    textAlign: TextAlign.center,
                    style: kMono.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: m == value ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.points,
    required this.metric,
    required this.timed,
    required this.unit,
  });
  final List<ExerciseProgressPoint> points;
  final _Metric metric;
  final bool timed;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final p in points)
        (date: p.date, value: _valueOf(p, metric, timed, unit)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: SizedBox(
        height: 220,
        child: CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(
            values: values,
            suffix: timed ? 's' : unitLabel(unit),
          ),
        ),
      ),
    );
  }
}

/// A hand-rolled line chart: no dependency, no allocation beyond the paints it
/// needs, so it stays cheap enough to sit in a scrolling list. Points are
/// placed along x in proportion to their date, and y is scaled to the data's
/// own range (not zero-based) so a plateau still shows its wobble.
class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.values, required this.suffix});

  final List<({DateTime date, double value})> values;
  final String suffix;

  static const _leftPad = 44.0;
  static const _rightPad = 8.0;
  static const _topPad = 10.0;
  static const _bottomPad = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final plotLeft = _leftPad;
    final plotRight = size.width - _rightPad;
    final plotTop = _topPad;
    final plotBottom = size.height - _bottomPad;
    final plotW = plotRight - plotLeft;
    final plotH = plotBottom - plotTop;

    var minV = values.first.value;
    var maxV = values.first.value;
    for (final v in values) {
      if (v.value < minV) minV = v.value;
      if (v.value > maxV) maxV = v.value;
    }
    // A flat series would divide by zero; give it a band to sit inside.
    if (maxV - minV < 1e-9) {
      final pad = maxV.abs() < 1e-9 ? 1.0 : maxV.abs() * 0.1;
      minV -= pad;
      maxV += pad;
    } else {
      final headroom = (maxV - minV) * 0.12;
      minV -= headroom;
      maxV += headroom;
    }

    double xAt(int i) {
      if (values.length == 1) return plotLeft + plotW / 2;
      final first = values.first.date.millisecondsSinceEpoch.toDouble();
      final last = values.last.date.millisecondsSinceEpoch.toDouble();
      final span = last - first;
      if (span <= 0) {
        return plotLeft + plotW * (i / (values.length - 1));
      }
      final t = (values[i].date.millisecondsSinceEpoch - first) / span;
      return plotLeft + plotW * t;
    }

    double yAt(double v) => plotBottom - plotH * ((v - minV) / (maxV - minV));

    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    // Three gridlines with their values down the left edge.
    for (var g = 0; g <= 2; g++) {
      final t = g / 2;
      final y = plotTop + plotH * t;
      canvas.drawLine(Offset(plotLeft, y), Offset(plotRight, y), grid);
      final v = maxV - (maxV - minV) * t;
      _label(canvas, _fmtValue(v), Offset(plotLeft - 6, y),
          align: _Align.right, baseline: _Baseline.middle);
    }

    // The line.
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final o = Offset(xAt(i), yAt(values[i].value));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // The dots.
    final dotFill = Paint()..color = AppColors.accent;
    final dotRing = Paint()..color = AppColors.ground;
    for (var i = 0; i < values.length; i++) {
      final o = Offset(xAt(i), yAt(values[i].value));
      canvas.drawCircle(o, 4.5, dotRing);
      canvas.drawCircle(o, 3, dotFill);
    }

    // First and last dates along the bottom.
    final df = DateFormat('d MMM');
    _label(canvas, df.format(values.first.date),
        Offset(plotLeft, plotBottom + 6),
        align: _Align.left, baseline: _Baseline.top);
    if (values.length > 1) {
      _label(canvas, df.format(values.last.date),
          Offset(plotRight, plotBottom + 6),
          align: _Align.right, baseline: _Baseline.top);
    }
  }

  String _fmtValue(double v) {
    if (v.abs() >= 1000) return v.round().toString();
    return fmtWeight(v);
  }

  void _label(Canvas canvas, String text, Offset at,
      {required _Align align, required _Baseline baseline}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: kMono.copyWith(fontSize: 10, color: AppColors.faint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    var dy = at.dy;
    if (align == _Align.right) dx -= tp.width;
    if (baseline == _Baseline.middle) dy -= tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values || old.suffix != suffix;
}

enum _Align { left, right }

enum _Baseline { top, middle }

/// The most recent session's headline number, and how far it has come from the
/// first logged session.
class _LatestReadout extends StatelessWidget {
  const _LatestReadout({
    required this.points,
    required this.metric,
    required this.timed,
    required this.unit,
  });
  final List<ExerciseProgressPoint> points;
  final _Metric metric;
  final bool timed;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final first = _valueOf(points.first, metric, timed, unit);
    final last = _valueOf(points.last, metric, timed, unit);
    final delta = last - first;
    final suffix = timed ? 's' : unitLabel(unit);
    final headline = timed
        ? '${last.round()}s'
        : '${fmtWeight(last)} $suffix';
    final label = timed
        ? 'Best hold'
        : (metric == _Metric.est1RM ? 'Latest est. 1RM' : 'Latest top set');

    String deltaText;
    Color deltaColor;
    if (points.length < 2 || delta.abs() < 1e-9) {
      deltaText = points.length < 2 ? 'first session' : 'no change yet';
      deltaColor = AppColors.muted;
    } else {
      final sign = delta > 0 ? '+' : '−';
      final mag = timed ? '${delta.abs().round()}s' : '${fmtWeight(delta.abs())} $suffix';
      deltaText = '$sign$mag since the start';
      deltaColor = delta > 0 ? AppColors.good : AppColors.gold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: kMono.copyWith(
                        fontSize: 10.5,
                        letterSpacing: 1.1,
                        color: AppColors.faint)),
                const SizedBox(height: 4),
                Text(deltaText,
                    style: kMono.copyWith(fontSize: 12, color: deltaColor)),
              ],
            ),
          ),
          Text(headline,
              style: kMono.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.timed});
  final bool timed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(Icons.show_chart, color: AppColors.faint, size: 30),
          const SizedBox(height: 12),
          Text(
            timed
                ? 'Finish a session with this hold logged and the curve starts here.'
                : 'Finish a session with this lift logged and the curve starts here.',
            textAlign: TextAlign.center,
            style: kMono.copyWith(
                fontSize: 12.5, height: 1.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
