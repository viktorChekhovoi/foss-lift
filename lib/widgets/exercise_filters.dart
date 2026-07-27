import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/exercise_filter.dart';
import '../theme/app_theme.dart';

/// Finds one filter chip in a test. Keyed by dimension as well as label for two
/// reasons: the words on these chips are also the words under every exercise in
/// the list beneath them, and "Other" is a value in *both* vocabularies.
ValueKey<String> filterChipKey(String dimension, String label) =>
    ValueKey('filter-$dimension-$label');

/// Finds the chip that lets every filter go.
const kFilterClearKey = ValueKey('filter-clear');

/// The filter control: two rows of chips, muscle groups over equipment, each
/// scrolling sideways on its own.
///
/// **Two rows rather than one long strip.** Six equipment chips already fill a
/// phone's width, so a single run would put the entire muscle vocabulary
/// off-screen to the right — and "a movement for legs" is the commoner way to
/// browse, so it must not be the half that is hidden. Muscle leads for the same
/// reason. Splitting them also settles the one place the vocabularies collide:
/// "Other" is both a kind of equipment and a muscle group, and which is which
/// is now a matter of which row it is in.
///
/// The rows sit in the open rather than behind a Filters button: hidden filters
/// are filters nobody uses, and the whole complaint was that finding a movement
/// meant knowing its name first.
class ExerciseFilterChips extends StatelessWidget {
  const ExerciseFilterChips({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final ExerciseFilter filter;
  final ValueChanged<ExerciseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Run(children: [
          for (final group in kMuscleGroups)
            _Chip(
              key: filterChipKey('muscle', group),
              label: group,
              selected: filter.muscles.contains(group),
              onTap: () => onChanged(filter.toggleMuscle(group)),
            ),
        ]),
        _Run(children: [
          // Riding at the head of the second row rather than getting a line of
          // its own: it only exists while something is lit.
          if (filter.facetCount > 0)
            _Chip(
              key: kFilterClearKey,
              label: 'Clear',
              icon: Icons.close_rounded,
              selected: false,
              onTap: () => onChanged(filter.withoutFacets),
            ),
          for (final kind in kEquipmentTypes)
            _Chip(
              key: filterChipKey('equipment', kind),
              label: kind,
              selected: filter.equipment.contains(kind),
              onTap: () => onChanged(filter.toggleEquipment(kind)),
            ),
        ]),
      ],
    );
  }
}

/// One scrolling row of chips.
///
/// A scroll view around a Row, not a horizontal ListView: the handful of chips
/// all build anyway, and another ListView on a screen whose point is its list
/// is one ListView too many for anything looking for "the list".
class _Run extends StatelessWidget {
  const _Run({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: children),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = selected ? AppColors.accent : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: tone),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
