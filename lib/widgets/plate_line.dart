import 'package:flutter/material.dart';

import '../data/plates.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';

/// What the number in the weight column comes to in the real world: the plates
/// on each side of a bar.
///
/// Only a bar gets a line. A machine's number is the number, and a dumbbell's
/// is whatever is in your hand — there is no arrangement to work out, and a
/// line saying "per dumbbell, not the pair" would be wrong for every one-arm
/// row and goblet squat.
///
/// One line under an exercise rather than one per set. Every set of an exercise
/// is normally loaded the same way, and four identical plate breakdowns down a
/// column is noise you stop reading — which defeats the point of printing it.
class PlateLine extends StatelessWidget {
  const PlateLine({
    super.key,
    required this.weightKg,
    required this.type,
    required this.settings,
    required this.unit,
  });

  /// The weight to break down, in kg.
  final double weightKg;
  final WeightType type;
  final PlateSettings settings;
  final String unit;

  @override
  Widget build(BuildContext context) {
    // Nothing to break down unless it is a bar, and nothing to say about a
    // weight nobody has picked yet — an unloaded bar exercise is a slot waiting
    // for a number, not a warning that the bar is heavier than it.
    if (!type.loadedPerSide || weightKg <= 0) {
      return const SizedBox.shrink();
    }

    final s = solvePlates(
      targetKg: weightKg,
      barKg: settings.barKg,
      inventory: settings.plates,
    );
    // Gold is what the rest of the app uses for "this is not what you asked
    // for": a missed set, a deloaded target, and now a weight the gym cannot
    // actually make.
    final off = !s.exact || s.belowBar;
    return _line(plateSummary(s, unit), off ? AppColors.gold : AppColors.faint);
  }

  Widget _line(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Text(
          text,
          style: kMono.copyWith(fontSize: 10.5, height: 1.4, color: color),
        ),
      );
}

/// The plate breakdown as one line of text: what goes on each side, what the
/// bar weighs, and — when the plates cannot make the weight asked for — what
/// they can make instead.
String plateSummary(PlateSolution s, String unit) {
  final u = unitLabel(unit).toUpperCase();
  String w(double kg) => fmtPlateWeight(toDisplayWeight(kg, unit));

  if (s.belowBar) {
    return 'LIGHTER THAN THE BAR — THE BAR ALONE IS ${w(s.barKg)} $u';
  }

  final parts = <String>[
    // Said first, because it changes what every number after it means.
    if (!s.exact) 'NEAREST YOU CAN LOAD: ${w(s.achievedKg)} $u',
  ];
  if (s.plates.isEmpty) {
    parts.add('JUST THE BAR (${w(s.barKg)} $u)');
  } else {
    parts.add('${w(s.perSideKg)} $u/SIDE');
    parts.add(plateStackLabel(s.plates, unit));
    parts.add('BAR ${w(s.barKg)}');
  }
  return parts.join(' · ');
}

/// One side of the bar, heaviest plate first: "20×2 + 10 + 1.25".
String plateStackLabel(List<PlateStack> plates, String unit) => plates.map((p) {
      final w = fmtPlateWeight(toDisplayWeight(p.kg, unit));
      return p.count == 1 ? w : '$w×${p.count}';
    }).join(' + ');

/// The short form for a list row: "31.25/side", with a "≈" when the plates
/// cannot quite make the weight the template is asking for. Null when there is
/// nothing to say — anything that is not loaded on a bar.
String? perSideLabel({
  required double weightKg,
  required WeightType type,
  required PlateSettings settings,
  required String unit,
}) {
  if (!type.loadedPerSide) return null;
  final s = solvePlates(
    targetKg: weightKg,
    barKg: settings.barKg,
    inventory: settings.plates,
  );
  if (s.belowBar) return 'under the bar';
  final per = fmtPlateWeight(toDisplayWeight(s.perSideKg, unit));
  return '${s.exact ? '' : '≈'}$per/side';
}
