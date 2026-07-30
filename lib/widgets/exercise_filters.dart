import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/exercise_filter.dart';
import '../theme/app_theme.dart';

/// Finds one of the two dimension buttons in a test — `muscle` or `equipment`.
ValueKey<String> filterButtonKey(String dimension) =>
    ValueKey('filter-button-$dimension');

/// Finds one value inside the sheet a dimension button opens. Keyed by dimension
/// as well as label for two reasons: the words are also the words under every
/// exercise in the list behind the sheet, and "Other" is a value in *both*
/// vocabularies.
ValueKey<String> filterChipKey(String dimension, String label) =>
    ValueKey('filter-$dimension-$label');

/// Finds the control that lets every filter go.
const kFilterClearKey = ValueKey('filter-clear');

/// Finds the way out of a dimension sheet.
const kFilterSheetDoneKey = ValueKey('filter-sheet-done');

/// The filter control: one line — a **Muscle** button, an **Equipment** button,
/// and a **Clear** while anything is on.
///
/// **A button per dimension, not a chip per value.** Fifteen chips laid out in
/// the open — nine muscle groups over six equipment kinds — cost four lines of a
/// phone screen and read as two undifferentiated blocks of pills, with nothing
/// on them saying which block was which. The two buttons say it in one line, and
/// naming the dimension on the button settles the one collision in the
/// vocabulary as well: `Other` is both a kind of equipment and a muscle group,
/// and which is which is written above the ticks.
///
/// **The button is the summary.** Until something is ticked it reads "Muscle";
/// after, it reads the choices themselves — "Legs, Arms" — so what the list is
/// narrowed to is legible without opening anything. That was the one virtue of
/// the wall of chips, and it survives.
///
/// **The sheet applies as it is ticked.** The list behind it narrows on every
/// tap rather than on the way out, because the list is the feedback; **Done** is
/// a way out, not a commit.
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
    return Container(
      // Full width and left-aligned, or the buttons float in the middle of the
      // screen under a search box that runs edge to edge.
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      // Wrapped rather than a plain row: at 2× text three controls do not fit
      // across a phone, and a second line is better than a squeezed target.
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterFacetButton(
            key: filterButtonKey('muscle'),
            dimension: 'muscle',
            fallback: 'Muscle',
            title: 'Muscle group',
            values: kMuscleGroups,
            chosen: filter.muscles,
            onToggle: (group) => onChanged(filter.toggleMuscle(group)),
          ),
          FilterFacetButton(
            key: filterButtonKey('equipment'),
            dimension: 'equipment',
            fallback: 'Equipment',
            title: 'Equipment',
            values: kEquipmentTypes,
            chosen: filter.equipment,
            onToggle: (kind) => onChanged(filter.toggleEquipment(kind)),
          ),
          // Only while there is something to undo, and it undoes the buttons
          // alone — the search text is not a chip.
          if (filter.facetCount > 0)
            _ClearButton(onTap: () => onChanged(filter.withoutFacets)),
        ],
      ),
    );
  }
}

/// One dimension: a button that names what it is narrowed to, and the sheet it
/// opens.
class FilterFacetButton extends StatelessWidget {
  const FilterFacetButton({
    super.key,
    required this.dimension,
    required this.fallback,
    required this.title,
    required this.values,
    required this.chosen,
    required this.onToggle,
  });

  /// `muscle` or `equipment` — what the keys are scoped by.
  final String dimension;

  /// What the button reads while nothing is ticked: the question itself.
  final String fallback;

  /// The heading over the ticks, which is the long form of [fallback].
  final String title;
  final List<String> values;
  final Set<String> chosen;
  final ValueChanged<String> onToggle;

  /// The choices, in the vocabulary's own order rather than the order they were
  /// tapped in — a button whose words move about as you tick them is a button
  /// you have to re-read.
  String get _said =>
      chosen.isEmpty ? fallback : values.where(chosen.contains).join(', ');

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
            // Ellipsised rather than wrapped: every choice is also visible in
            // the sheet a tap away, and a button that grows to three lines
            // costs the list more than the words are worth.
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
      chosen: chosen,
      onToggle: onToggle,
    ),
  );
}

/// The ticks behind one dimension button.
///
/// Rebuilt from the filter on every tap — it is handed the chosen set and a way
/// to toggle one value, and owns no copy of its own. So the sheet, the button
/// under it and the list behind it cannot disagree about what is on.
class FilterFacetSheet extends StatelessWidget {
  const FilterFacetSheet({
    super.key,
    required this.dimension,
    required this.title,
    required this.values,
    required this.chosen,
    required this.onToggle,
  });

  final String dimension;
  final String title;
  final List<String> values;
  final Set<String> chosen;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    // Half the screen at most, and scrolling inside that: seven ticks fit on
    // any phone at an ordinary text size, and none of them do at the top of the
    // scale — where the list behind still has to be worth seeing.
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
                    child: const Text('Done'),
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
                      label: value,
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

/// One value in a sheet: a box, a word, and the whole row as the target.
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

/// Letting both dimensions go. Quieter than the two buttons beside it: it is the
/// way back to no filter at all, not a third thing to narrow by.
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
              'Clear',
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
