import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// intl also defines a `TextDirection`; hide it so the dart:ui one (with `.ltr`)
// that TextPainter needs stays in scope.
import 'package:intl/intl.dart' hide TextDirection;

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../util/format.dart';

/// A per-exercise progress chart over every finished session. Read-only — it
/// only ever reads the log.
///
/// A weighted movement is plotted as its **top set** — the heaviest weight the
/// session actually held. An estimated 1RM was offered alongside it and taken
/// back out: it is a formula's opinion about a lift you did not do, it moves
/// when the reps move at a constant weight, and two numbers that disagree about
/// whether you are progressing is one number too many.
class ExerciseProgressScreen extends ConsumerWidget {
  const ExerciseProgressScreen({super.key, required this.exerciseId});
  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(exerciseLibraryProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonProgress)),
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
                child: Text(l10n.commonExerciseGone,
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
  bool get _timed => widget.exercise.measure == ExerciseMeasure.time;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(exerciseHistoryProvider(widget.exercise.id));
    // The chart is one movement's history, so it is read in that movement's
    // unit.
    final unit = unitForExercise(
      ref.watch(weightUnitProvider).value ?? 'kg',
      widget.exercise.unitOverride,
    );
    final l10n = AppLocalizations.of(context);

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
            Text(
                seededName(
                    l10n, widget.exercise.seedKey, widget.exercise.name),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(
              points.isEmpty
                  ? l10n.progressNoHistory
                  : l10n.progressSessionsLogged(points.length),
              style: kMono.copyWith(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            if (points.isEmpty)
              _EmptyState(timed: _timed)
            else ...[
              _ChartCard(points: points, timed: _timed, unit: unit),
              const SizedBox(height: 20),
              _LatestReadout(points: points, timed: _timed, unit: unit),
            ],
          ],
        );
      },
    );
  }
}

/// The value the chart and readout show for one session: the top set in the
/// display unit, or the longest hold in seconds.
double _valueOf(ExerciseProgressPoint p, bool timed, String unit) =>
    timed ? p.bestSeconds.toDouble() : toDisplayWeight(p.topWeightKg, unit);

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.points,
    required this.timed,
    required this.unit,
  });
  final List<ExerciseProgressPoint> points;
  final bool timed;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = [
      for (final p in points) (date: p.date, value: _valueOf(p, timed, unit)),
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
          painter: _ChartPainter(values: values, locale: l10n.localeName),
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
  _ChartPainter({required this.values, required this.locale});

  /// The language the axis dates are written in — see `_ChartPainter.paint`.
  /// A painter has no `BuildContext`, so it is handed the name rather than
  /// reaching for `Intl.defaultLocale`.
  final String locale;

  /// The gridline values carry no unit — the readout below the chart says which
  /// one, and repeating it on three axis labels only crowds them.
  final List<({DateTime date, double value})> values;

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

    // First and last dates along the bottom. A skeleton rather than a pattern:
    // "d MMM" is an English ordering, and the locale is entitled to its own.
    final df = DateFormat.MMMd(locale);
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
  bool shouldRepaint(_ChartPainter old) => old.values != values;
}

enum _Align { left, right }

enum _Baseline { top, middle }

/// The most recent session's headline number, and how far it has come from the
/// first logged session.
class _LatestReadout extends StatelessWidget {
  const _LatestReadout({
    required this.points,
    required this.timed,
    required this.unit,
  });
  final List<ExerciseProgressPoint> points;
  final bool timed;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = _valueOf(points.first, timed, unit);
    final last = _valueOf(points.last, timed, unit);
    final delta = last - first;
    final suffix = unitSuffix(l10n, unit);
    final headline = timed
        ? l10n.unitSecondsShort('${last.round()}')
        : l10n.unitWeightShort(fmtWeight(last), suffix);
    final label = timed ? l10n.progressBestHold : l10n.progressLatestTopSet;

    String deltaText;
    Color deltaColor;
    if (points.length < 2 || delta.abs() < 1e-9) {
      deltaText = points.length < 2
          ? l10n.progressFirstSession
          : l10n.progressNoChangeYet;
      deltaColor = AppColors.muted;
    } else {
      // Four whole sentences rather than a sign, a magnitude and a trailing
      // clause glued together: a gain and a loss are not the same sentence
      // with one character swapped once the language has to agree with them.
      final up = delta > 0;
      final mag = delta.abs();
      deltaText = timed
          ? (up
              ? l10n.progressGainTime('${mag.round()}')
              : l10n.progressLossTime('${mag.round()}'))
          : (up
              ? l10n.progressGainWeight(fmtWeight(mag), suffix)
              : l10n.progressLossWeight(fmtWeight(mag), suffix));
      deltaColor = up ? AppColors.good : AppColors.gold;
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
    final l10n = AppLocalizations.of(context);
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
            timed ? l10n.progressEmptyHold : l10n.progressEmptyLift,
            textAlign: TextAlign.center,
            style: kMono.copyWith(
                fontSize: 12.5, height: 1.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
