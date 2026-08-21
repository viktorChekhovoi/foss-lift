import 'package:flutter/material.dart';

import '../data/plates.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../util/format.dart';

class PlateLine extends StatelessWidget {
  const PlateLine({
    super.key,
    required this.weightKg,
    required this.type,
    required this.settings,
    required this.unit,
    this.barKg,
  });

  final double weightKg;
  final WeightType type;
  final PlateSettings settings;
  final String unit;

  final double? barKg;

  @override
  Widget build(BuildContext context) {
    if (!type.loadedPerSide || weightKg <= 0) {
      return const SizedBox.shrink();
    }

    final s = solvePlates(
      targetKg: weightKg,
      barKg: barKg ?? settings.barKg,
      inventory: settings.plates,
    );
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

String plateSummary(AppLocalizations l10n, PlateSolution s, String unit) {
  final u = unitSuffix(l10n, unit);
  String w(double kg) => fmtWeight(toDisplayWeight(kg, unit));

  if (s.belowBar) return l10n.plateLineBelowBar(w(s.barKg), u);

  final parts = <String>[
    if (!s.exact) l10n.plateLineNearest(w(s.achievedKg), u),
  ];
  if (s.plates.isEmpty) {
    parts.add(l10n.plateLineJustBar(w(s.barKg), u));
  } else {
    parts.add(l10n.plateLinePerSide(w(s.perSideKg), u));
    parts.add(plateStackLabel(s.plates, unit));
    parts.add(l10n.plateLineBar(weightWithUnit(l10n, s.barKg, unit)));
  }
  return parts.join(' · ');
}

String plateStackLabel(List<PlateStack> plates, String unit) => plates.map((p) {
      final w = fmtWeight(toDisplayWeight(p.kg, unit));
      return p.count == 1 ? w : '$w×${p.count}';
    }).join(' + ');

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
