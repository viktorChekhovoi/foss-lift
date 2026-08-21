import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/exercise_filter.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';

ValueKey<String> filterButtonKey(String dimension) =>
    ValueKey('filter-button-$dimension');

ValueKey<String> filterChipKey(String dimension, String label) =>
    ValueKey('filter-$dimension-$label');

const kFilterClearKey = ValueKey('filter-clear');

const kFilterSheetDoneKey = ValueKey('filter-sheet-done');

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
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterFacetButton(
            key: filterButtonKey('muscle'),
            dimension: 'muscle',
            fallback: l10n.filtersMuscle,
            title: l10n.filtersMuscleGroup,
            values: kMuscleGroups,
            label: (group) => muscleGroupLabel(l10n, group),
            chosen: filter.muscles,
            onToggle: (group) => onChanged(filter.toggleMuscle(group)),
          ),
          FilterFacetButton(
            key: filterButtonKey('equipment'),
            dimension: 'equipment',
            fallback: l10n.filtersEquipment,
            title: l10n.filtersEquipment,
            values: kEquipmentTypes,
            label: (kind) => equipmentLabel(l10n, kind),
            chosen: filter.equipment,
            onToggle: (kind) => onChanged(filter.toggleEquipment(kind)),
          ),
          if (filter.facetCount > 0)
            _ClearButton(onTap: () => onChanged(filter.withoutFacets)),
        ],
      ),
    );
  }
}

class FilterFacetButton extends StatelessWidget {
  const FilterFacetButton({
    super.key,
    required this.dimension,
    required this.fallback,
    required this.title,
    required this.values,
    required this.label,
    required this.chosen,
    required this.onToggle,
  });

  final String dimension;

  final String fallback;

  final String title;

  final List<String> values;

  final String Function(String) label;
  final Set<String> chosen;
  final ValueChanged<String> onToggle;

  String get _said => chosen.isEmpty
      ? fallback
      : values.where(chosen.contains).map(label).join(', ');

  @override
  Widget build(BuildContext context) {
    final on = chosen.isNotEmpty;
    final tone = on ? AppColors.accent : AppColors.muted;
    return GestureDetector(
      onTap: () => _open(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: on
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? AppColors.accent : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _said,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: tone),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => FilterFacetSheet(
      dimension: dimension,
      title: title,
      values: values,
      label: label,
      chosen: chosen,
      onToggle: onToggle,
    ),
  );
}

class FilterFacetSheet extends StatelessWidget {
  const FilterFacetSheet({
    super.key,
    required this.dimension,
    required this.title,
    required this.values,
    required this.label,
    required this.chosen,
    required this.onToggle,
  });

  final String dimension;
  final String title;
  final List<String> values;
  final String Function(String) label;
  final Set<String> chosen;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: kMono.copyWith(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.faint,
                      ),
                    ),
                  ),
                  TextButton(
                    key: kFilterSheetDoneKey,
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).commonDone),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (final value in values)
                    _Tick(
                      key: filterChipKey(dimension, value),
                      label: label(value),
                      selected: chosen.contains(value),
                      onTap: () => onToggle(value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.line,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.onAccent,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.accent : AppColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: kFilterClearKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).filtersClear,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
