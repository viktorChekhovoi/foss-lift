import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/unsaved_work.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/video_links.dart';

class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.exerciseId});

  final int? exerciseId;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen>
    with TracksUnsavedEdits {
  final _name = TextEditingController();
  final _video = TextEditingController();
  List<String> _primary = ['Chest'];

  List<String> _secondary = [];

  String _equip = 'Barbell';
  ExerciseMeasure _measure = ExerciseMeasure.reps;
  WeightType _weightType = weightTypeForEquipment('Barbell');
  bool _saving = false;

  bool get _isEdit => widget.exerciseId != null;

  late bool _loaded = !_isEdit;

  @override
  void initState() {
    super.initState();
    _name.addListener(markEdited);
    _video.addListener(markEdited);
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final ex = await ref
        .read(databaseProvider)
        .exerciseById(widget.exerciseId!);
    if (!mounted) return;
    setState(() {
      _name.text = ex.name;
      _video.text = ex.videoUrl ?? '';
      final stored = ex.muscles;
      _primary = _known(stored.primary, fallback: kMuscleGroups.last);
      _secondary = _known(stored.secondary)
        ..removeWhere(_primary.contains);
      _equip = kEquipmentTypes.contains(ex.equipment) ? ex.equipment : 'Other';
      _measure = ex.measure;
      _weightType = ex.weightType;
      _loaded = true;
    });
    markSaved();
  }

  static List<String> _known(List<String> from, {String? fallback}) {
    final kept = [for (final g in from) if (kMuscleGroups.contains(g)) g];
    if (kept.isEmpty && fallback != null) kept.add(fallback);
    return kept;
  }

  MuscleMap get _muscles =>
      MuscleMap(primary: _primary, secondary: _secondary);

  void _togglePrimary(String group) => _edit(() {
    if (_primary.contains(group)) {
      if (_primary.length > 1) _primary.remove(group);
    } else {
      _primary.add(group);
      _secondary.remove(group);
    }
  });

  void _toggleSecondary(String group) => _edit(() {
    if (_secondary.contains(group)) {
      _secondary.remove(group);
    } else if (_primary.length > 1 || !_primary.contains(group)) {
      _secondary.add(group);
      _primary.remove(group);
    }
  });

  static String? _tidyLink(String text) {
    final typed = text.trim();
    if (typed.isEmpty) return null;
    final id = youTubeVideoId(typed);
    return id == null ? typed : youTubeUrl(id);
  }

  void _setEquipment(String v) => _edit(() {
    _equip = v;
    _weightType = weightTypeForEquipment(v);
  });

  void _edit(VoidCallback change) {
    markEdited();
    setState(change);
  }

  void _setMeasure(ExerciseMeasure v) => _edit(() {
    _measure = v;
    _weightType = v == ExerciseMeasure.reps
        ? weightTypeForEquipment(_equip)
        : WeightType.none;
  });

  @override
  void dispose() {
    _name.dispose();
    _video.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).exerciseFormNameRequired),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final video = _tidyLink(_video.text);
    final db = ref.read(databaseProvider);
    int id;
    if (_isEdit) {
      id = widget.exerciseId!;
      await db.updateCustomExercise(
        id,
        name: name,
        muscles: _muscles,
        equipment: _equip,
        videoUrl: video,
        measure: _measure,
        weightType: _weightType,
      );
    } else {
      id = await db.createExercise(
        name: name,
        muscles: _muscles,
        equipment: _equip,
        videoUrl: video,
        measure: _measure,
        weightType: _weightType,
      );
    }
    final saved = await db.exerciseById(id);
    markSaved();
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.exerciseFormEditTitle : l10n.exerciseFormNewTitle,
        ),
      ),
      body: SafeArea(
        top: false,
        child: !_loaded
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _form(l10n),
      ),
    );
  }

  String _measureLabel(AppLocalizations l10n, ExerciseMeasure m) =>
      switch (m) {
        ExerciseMeasure.reps => l10n.exerciseFormMeasureReps,
        ExerciseMeasure.time => l10n.exerciseFormMeasureTime,
      };

  Widget _form(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _Label(l10n.commonName),
        _Field(
          controller: _name,
          hint: l10n.exerciseFormNameHint,
          maxLength: kMaxNameLength,
        ),
        const SizedBox(height: 18),
        _Label(l10n.exerciseMusclesTrained),
        _Choices(
          options: kMuscleGroups,
          label: (v) => muscleGroupLabel(l10n, v),
          selected: _primary.toSet(),
          onSelect: _togglePrimary,
        ),
        const SizedBox(height: 18),
        _Label(l10n.exerciseMusclesAssisted),
        _Choices(
          options: kMuscleGroups,
          label: (v) => muscleGroupLabel(l10n, v),
          selected: _secondary.toSet(),
          onSelect: _toggleSecondary,
        ),
        const SizedBox(height: 18),
        _Label(l10n.exerciseFormEquipment),
        _Choices(
          options: kEquipmentTypes,
          label: (v) => equipmentLabel(l10n, v),
          selected: {_equip},
          onSelect: _setEquipment,
        ),
        const SizedBox(height: 18),
        _Label(l10n.exerciseFormMeasuredIn),
        _Choices(
          options: ExerciseMeasure.values,
          label: (v) => _measureLabel(l10n, v),
          selected: {_measure},
          onSelect: _setMeasure,
        ),
        const SizedBox(height: 6),
        Text(
          _measure == ExerciseMeasure.reps
              ? l10n.exerciseFormRepsNote
              : l10n.exerciseFormTimeNote,
          style: kMono.copyWith(
            fontSize: 11,
            height: 1.5,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(height: 18),
        _Label(
          _measure == ExerciseMeasure.reps
              ? l10n.exerciseFormLoadedAs
              : l10n.exerciseFormLoadedAsOptional,
        ),
        _Choices(
          options: WeightType.loadable,
          label: (v) => weightTypeLabel(l10n, v),
          selected: {_weightType},
          onSelect: (v) => _edit(() {
            _weightType = v == _weightType ? WeightType.none : v;
          }),
        ),
        if (_measure != ExerciseMeasure.reps) ...[
          const SizedBox(height: 6),
          Text(
            l10n.exerciseFormHoldLoadNote,
            style: kMono.copyWith(
              fontSize: 11,
              height: 1.5,
              color: AppColors.faint,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _Label(l10n.exerciseFormDemoLink),
        _Field(
          controller: _video,
          hint: l10n.exerciseFormDemoLinkHint,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? l10n.commonSaving : l10n.exerciseFormSave,
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      text.toUpperCase(),
      style: kMono.copyWith(
        fontSize: 11,
        letterSpacing: 1.2,
        color: AppColors.faint,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLength,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.label,
    required this.selected,
    required this.onSelect,
  });
  final List<T> options;
  final String Function(T) label;
  final Set<T> selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onSelect(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: selected.contains(o)
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      selected.contains(o) ? AppColors.accent : AppColors.line,
                ),
              ),
              child: Text(
                label(o),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color:
                      selected.contains(o) ? AppColors.accent : AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
