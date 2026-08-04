import 'package:flutter/material.dart';

import '../data/plates.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/format.dart';

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
    this.barKg,
  });

  /// The weight to break down, in kg.
  final double weightKg;
  final WeightType type;
  final PlateSettings settings;
  final String unit;

  /// This exercise's own bar, in kg. Null uses the default from settings.
  final double? barKg;

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
      barKg: barKg ?? settings.barKg,
      inventory: settings.plates,
    );
    // The same green/gold the set rows use: green is what you asked for, gold
    // is not. A weight the gym cannot make is the same kind of news as a set
    // that came up short, and it has to be as easy to notice.
    final off = !s.exact || s.belowBar;
    return _line(plateSummary(AppLocalizations.of(context), s, unit),
        off ? AppColors.gold : AppColors.good);
  }

  Widget _line(String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 3, bottom: 4),
        child: Text(
          text,
          style: kMono.copyWith(
              fontSize: 11, height: 1.4, fontWeight: FontWeight.w600, color: color),
        ),
      );
}

/// The plate breakdown as one line of text: what goes on each side, what the
/// bar weighs, and — when the plates cannot make the weight asked for — what
/// they can make instead.
/// The line shouts its labels — they are written that way in the string
/// catalogue — but a unit is a symbol and is not a label, so it is passed
/// through as [unitSuffix] spells it. "KG" mid-line over a rest bar reading
/// "kg" is one number written two ways.
String plateSummary(AppLocalizations l10n, PlateSolution s, String unit) {
  final u = unitSuffix(l10n, unit);
  String w(double kg) => fmtWeight(toDisplayWeight(kg, unit));

  if (s.belowBar) return l10n.plateLineBelowBar(w(s.barKg), u);

  final parts = <String>[
    // Said first, because it changes what every number after it means.
    if (!s.exact) l10n.plateLineNearest(w(s.achievedKg), u),
  ];
  if (s.plates.isEmpty) {
    parts.add(l10n.plateLineJustBar(w(s.barKg), u));
  } else {
    parts.add(l10n.plateLinePerSide(w(s.perSideKg), u));
    parts.add(plateStackLabel(s.plates, unit));
    // The bar is a weight like the others on the line, so it carries its unit
    // like the others. Its key takes one placeholder rather than the pair the
    // sibling keys take, so the pair is joined before it goes in — through the
    // same [weightWithUnit] every other weight in the app goes through.
    parts.add(l10n.plateLineBar(weightWithUnit(l10n, s.barKg, unit)));
  }
  return parts.join(' · ');
}

/// One side of the bar, heaviest plate first: "20×2 + 10 + 1.25".
String plateStackLabel(List<PlateStack> plates, String unit) => plates.map((p) {
      final w = fmtWeight(toDisplayWeight(p.kg, unit));
      return p.count == 1 ? w : '$w×${p.count}';
    }).join(' + ');

/// The short form for a list row: "31.25/side", with a "≈" when the plates
/// cannot quite make the weight the template is asking for. Null when there is
/// nothing to say — anything that is not loaded on a bar, and the empty bar
/// itself, which has nothing on either side to name.
String? perSideLabel({
  required AppLocalizations l10n,
  required double weightKg,
  required WeightType type,
  required PlateSettings settings,
  required String unit,
  double? barKg,
}) {
  if (!type.loadedPerSide) return null;
  final s = solvePlates(
    targetKg: weightKg,
    barKg: barKg ?? settings.barKg,
    inventory: settings.plates,
  );
  if (s.belowBar) return l10n.plateLineUnderBar;
  if (s.plates.isEmpty) return null;
  final per = fmtWeight(toDisplayWeight(s.perSideKg, unit));
  return '${s.exact ? '' : '≈'}${l10n.plateLinePerSideShort(per)}';
}
