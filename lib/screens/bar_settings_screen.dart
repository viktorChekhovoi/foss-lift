import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

/// The bars the gym racks, and which of them every barbell lift falls back to.
///
/// Add the odd bar your gym owns, rename and re-weigh the ones you added, and
/// take any of them off the rack. **The six standard bars cannot be renamed or
/// re-weighed** — an Olympic bar weighs 20 kg everywhere, and a name and a
/// weight that other phones resolve shared routines against are not a
/// preference. See [Bars]. Deleting one is still allowed, because a gym may
/// genuinely not rack a trap bar.
///
/// Tapping a bar makes it the app-wide default — an exercise can still carry its
/// own (Exercise → Bar weight), and this is what the rest of them use.
/// Finds one bar's pencil in a test. By name, because the list is the gym's and
/// the ids are not stable across a seeded install.
ValueKey<String> barEditKey(String name) => ValueKey('bar-edit-$name');

/// Finds one bar's cross in a test.
ValueKey<String> barRemoveKey(String name) => ValueKey('bar-remove-$name');

class BarSettingsScreen extends ConsumerWidget {
  const BarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final bars = ref.watch(barsProvider).value ?? const [];
    final setup = ref.watch(plateSettingsProvider);
    final db = ref.read(databaseProvider);
    final u = unitLabel(unit);
    // Which row carries the tick: the bar the default weight resolves to. With
    // nothing chosen that is the standard bar for the unit, which is normally a
    // bar on this list.
    final chosen = bars.atWeight(setup.barKg);

    // A bar is referred to by its weight, so two of them on one list cannot
    // weigh the same. The writer refuses and returns false; saying nothing would
    // read as a save that did not stick.
    void refused(double kg) {
      if (!context.mounted) return;
      final w = '${fmtPlateWeight(toDisplayWeight(kg, unit))} $u';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('You already have a $w bar.')));
    }

    Future<void> addBar() async {
      final draft = await askBarEdit(context, title: 'Add a bar', unit: unit);
      if (draft == null) return;
      if (!await db.addBar(unit: unit, name: draft.name, kg: draft.kg)) {
        refused(draft.kg);
      }
    }

    Future<void> editBar(Bar bar) async {
      final draft = await askBarEdit(
        context,
        title: 'Bar',
        unit: unit,
        name: bar.name,
        kg: bar.weightKg,
      );
      if (draft == null) return;
      if (!await db.editBar(bar.id, name: draft.name, kg: draft.kg)) {
        refused(draft.kg);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Bars · $u')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            builderLabel('Default bar'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  if (bars.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No bars. Barbell lifts count '
                        '${fmtPlateWeight(toDisplayWeight(setup.barKg, unit))} '
                        '$u until you add one.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  for (final bar in bars)
                    _BarRow(
                      bar: bar,
                      unit: unit,
                      selected: bar.id == chosen?.id,
                      onSelect: () => db.setBarWeight(bar.weightKg),
                      // No pencil on a standard bar — see the class comment.
                      onEdit: bar.isCustom ? () => editBar(bar) : null,
                      onRemove: () => db.deleteBar(bar.id),
                    ),
                  Divider(height: 1, color: AppColors.line),
                  InkWell(
                    onTap: addBar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18, color: AppColors.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Add a bar',
                              style: kMono.copyWith(
                                fontSize: 13,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Every barbell lift uses the ticked bar unless the exercise '
              'carries its own.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar: tap it to make it the default, the pencil — on a bar of your own
/// only — to rename or re-weigh it, the cross to take it off the rack.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.bar,
    required this.unit,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onRemove,
  });
  final Bar bar;
  final String unit;
  final bool selected;
  final VoidCallback onSelect;

  /// Null for a standard bar, which is fixed. The row is otherwise the same:
  /// there is no second kind of bar, only one you may rewrite.
  final VoidCallback? onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: selected ? AppColors.accent : AppColors.faint,
                    ),
                    const SizedBox(width: 10),
                    // The weight sits under the name rather than beside it: at
                    // 2× text a name, a weight and two icon buttons cannot share
                    // a phone's width, and a weight is the one thing here that
                    // must not be ellipsised.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bar.name,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${fmtPlateWeight(toDisplayWeight(bar.weightKg, unit))} '
                            '${unitLabel(unit)}',
                            style: kMono.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (onEdit case final edit?)
            builderIconButton(
              Icons.edit_outlined,
              edit,
              key: barEditKey(bar.name),
            ),
          builderIconButton(
            Icons.close,
            onRemove,
            danger: true,
            key: barRemoveKey(bar.name),
          ),
        ],
      ),
    );
  }
}
