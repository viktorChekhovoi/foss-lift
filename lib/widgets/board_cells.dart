import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';


const int kWeightColumnFlex = 2;
const int kResultColumnFlex = 3;

const double kSetNumberColumnWidth = 40;
const double kSetTrailingColumnWidth = 36;

const Duration kBoardPulsePeriod = Duration(milliseconds: 1100);

BoxDecoration boardCellDecoration({
  required bool primary,
  required bool done,
  required Color tone,
  double pulse = 0,
  bool emphasised = false,
}) {
  final Color fill;
  final Color edge;
  if (done) {
    fill = tone.withValues(alpha: primary ? 0.15 : 0.10);
    edge = tone.withValues(alpha: primary ? 0.55 : 0.30);
  } else if (primary) {
    fill = Color.lerp(
      AppColors.surface3,
      AppColors.accent.withValues(alpha: 0.22),
      pulse,
    )!;
    edge = Color.lerp(
      AppColors.surface3,
      AppColors.accent.withValues(alpha: 0.85),
      pulse,
    )!;
  } else {
    fill = Colors.transparent;
    edge = AppColors.line;
  }
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(9),
    border: Border.all(color: edge, width: emphasised ? 2 : 1),
  );
}

TextStyle boardCellTextStyle({
  required bool primary,
  required bool done,
  required Color tone,
}) =>
    kMono.copyWith(
      fontSize: primary ? 16 : 14,
      fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
      color: done ? tone : AppColors.muted,
    );

class BoardPulse extends StatefulWidget {
  const BoardPulse({super.key, required this.on, required this.builder});

  final bool on;

  final Widget Function(BuildContext context, double pulse) builder;

  @override
  State<BoardPulse> createState() => _BoardPulseState();
}

class _BoardPulseState extends State<BoardPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: kBoardPulsePeriod);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    if (widget.on) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BoardPulse old) {
    super.didUpdateWidget(old);
    if (widget.on == old.on) return;
    if (widget.on) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.builder(context, 0);
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, 1);
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => widget.builder(context, _t.value),
    );
  }
}

class WorkingWeight extends StatelessWidget {
  const WorkingWeight({
    super.key,
    required this.weightKg,
    required this.unit,
    this.onTap,
  });

  final double? weightKg;
  final String unit;

  final VoidCallback? onTap;

  Widget _label(AppLocalizations l10n) {
    final text = weightWithUnit(l10n, weightKg, unit);
    final number = kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
    final symbol = unitSuffix(l10n, unit);
    final at = text.indexOf(symbol);
    if (at < 0) return Text(text, style: number);
    final before = text.substring(0, at).trim();
    final after = text.substring(at + symbol.length).trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      textBaseline: TextBaseline.alphabetic,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      children: [
        if (before.isNotEmpty) ...[
          Text(before, style: number),
          const SizedBox(width: 3),
        ],
        Text(
          symbol,
          style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
        ),
        if (after.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(after, style: number),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              _label(AppLocalizations.of(context)),
              const SizedBox(width: 7),
              Icon(Icons.edit_outlined, size: 13, color: AppColors.faint),
            ],
          ),
        ),
      );
}

class BoardColumnHeaders extends StatelessWidget {
  const BoardColumnHeaders({
    super.key,
    required this.unit,
    required this.timed,
    this.showWeight = true,
  });

  final String unit;
  final bool timed;

  final bool showWeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget h(String t, {double? width, int flex = 1, bool shout = true}) {
      final child = Text(
        shout ? t.toUpperCase() : t,
        textAlign: TextAlign.center,
        style: kMono.copyWith(
          fontSize: 10,
          letterSpacing: 0.9,
          color: AppColors.faint,
        ),
      );
      return width != null
          ? SizedBox(width: width, child: child)
          : Expanded(flex: flex, child: child);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2, left: 5, right: 5),
      child: Row(
        children: [
          h(l10n.sessionColSet, width: kSetNumberColumnWidth),
          if (showWeight)
            h(unitSuffix(l10n, unit), flex: kWeightColumnFlex, shout: false),
          h(
            timed ? l10n.sessionColSecHeld : l10n.sessionColRepsDone,
            flex: kResultColumnFlex,
          ),
          const SizedBox(width: kSetTrailingColumnWidth),
        ],
      ),
    );
  }
}
