import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../util/seed_names.dart';
import '../util/units.dart';
import '../widgets/builder_widgets.dart';

class TrainingMaxScreen extends ConsumerStatefulWidget {
  const TrainingMaxScreen({super.key, required this.routineId});
  final int routineId;

  @override
  ConsumerState<TrainingMaxScreen> createState() => _TrainingMaxScreenState();
}

const ValueKey<String> trainingMaxButtonKey =
    ValueKey('routine-training-maxes');

ValueKey<String> trainingMaxFieldKey(String base) =>
    ValueKey('tm-field-$base');

const ValueKey<String> trainingMaxSaveKey = ValueKey('tm-save');

class _TrainingMaxScreenState extends ConsumerState<TrainingMaxScreen> {
  final Map<String, TextEditingController> _fields = {};

  final Set<String> _seeded = {};

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(TrainingMaxGroup group, String unit) {
    final field = _fields.putIfAbsent(group.base, TextEditingController.new);
    if (_seeded.add(group.base)) {
      final kg = group.weightKg;
      field.text = kg == null ? '' : fmtWeight(toDisplayWeight(kg, unit));
    }
    return field;
  }

  Future<void> _save(List<TrainingMaxGroup> groups, String unit) async {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);
    for (final group in groups) {
      final typed = _fields[group.base]?.text.trim() ?? '';
      if (typed.isEmpty) continue;
      final value = double.tryParse(typed.replaceAll(',', '.'));
      if (value == null || value <= 0) continue;
      await db.setTrainingMax(widget.routineId, group.base, toKg(value, unit));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.trainingMaxSaved)));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider).value ?? 'kg';
    final groups =
        ref.watch(trainingMaxGroupsProvider(widget.routineId)).value ??
            const <TrainingMaxGroup>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trainingMaxTitle)),
      body: SafeArea(
        top: false,
        child: groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.trainingMaxEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      l10n.trainingMaxLead,
                      style: TextStyle(
                          fontSize: 14, height: 1.4, color: AppColors.muted),
                    ),
                  ),
                  for (final group in groups) ...[
                    _TrainingMaxField(
                      group: group,
                      unit: unit,
                      controller: _controllerFor(group, unit),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(height: 4),
                  FilledButton(
                    key: trainingMaxSaveKey,
                    onPressed: () => _save(groups, unit),
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TrainingMaxField extends StatelessWidget {
  const _TrainingMaxField({
    required this.group,
    required this.unit,
    required this.controller,
  });

  final TrainingMaxGroup group;
  final String unit;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final covers = l10n.trainingMaxCovers(
      group.members.entries
          .map((e) => l10n.trainingMaxCoversOne(
              seededName(l10n, kSeedExerciseKeys[e.key], e.key), e.value))
          .join(l10n.trainingMaxCoversSeparator),
    );

    return builderCard(
      '${seededName(l10n, kSeedExerciseKeys[group.base], group.base)} '
      '(${unitSuffix(l10n, unit)})',
      [
        TextField(
          key: trainingMaxFieldKey(group.base),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(isDense: true),
        ),
        const SizedBox(height: 8),
        Text(
          covers,
          style: kMono.copyWith(fontSize: 11.5, color: AppColors.muted),
        ),
        if (group.weightKg == null) ...[
          const SizedBox(height: 6),
          Text(
            l10n.trainingMaxMixed,
            style: TextStyle(fontSize: 12, color: AppColors.gold),
          ),
        ],
      ],
    );
  }
}
