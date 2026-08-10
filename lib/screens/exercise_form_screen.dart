import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../state/unsaved_work.dart';
import '../theme/app_theme.dart';
import '../util/seed_names.dart';
import '../util/video_links.dart';

/// Form for a custom exercise: creating one, or editing one you already made.
///
/// The same screen either way. Everything on it is a fact you decided when you
/// created the movement, and none of those facts is any less wrong a week
/// later — so the form that set them is the form that changes them, rather than
/// a second screen that would drift out of step with this one.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key, this.exerciseId});

  /// The custom exercise being edited, or null to create a new one.
  final int? exerciseId;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen>
    with TracksUnsavedEdits {
  final _name = TextEditingController();
  final _video = TextEditingController();
  /// The groups the movement trains, in the order they were ticked — the first
  /// is the lead it files under. Never emptied; see [_togglePrimary].
  List<String> _primary = ['Chest'];

  /// The groups it only assists. Shares nothing with [_primary].
  List<String> _secondary = [];

  String _equip = 'Barbell';
  ExerciseMeasure _measure = ExerciseMeasure.reps;
  WeightType _weightType = weightTypeForEquipment('Barbell');
  bool _saving = false;

  bool get _isEdit => widget.exerciseId != null;

  /// Whether the existing exercise has been read into the fields yet. Creating
  /// starts ready; editing has a database round trip to wait for.
  late bool _loaded = !_isEdit;

  @override
  void initState() {
    super.initState();
    // Typing is the commonest edit and the one worth warning about, and both
    // fields are plain controllers — so the listener is the whole of it, rather
    // than an `onChanged` threaded through the two shared field widgets.
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
      // A group the form has no chip for — one that arrived in a routine code —
      // is shown as Other rather than silently kept and invisibly editable.
      final stored = ex.muscles;
      // Other is last in the vocabulary — see [kMuscleGroups].
      _primary = _known(stored.primary, fallback: kMuscleGroups.last);
      _secondary = _known(stored.secondary)
        ..removeWhere(_primary.contains);
      _equip = kEquipmentTypes.contains(ex.equipment) ? ex.equipment : 'Other';
      _measure = ex.measure;
      _weightType = ex.weightType;
      _loaded = true;
    });
    // Filling the fields moved the controllers, which told the listener above
    // that something was edited. Nothing was — this is the saved state arriving
    // on screen — so the mark is taken straight back off.
    markSaved();
  }

  /// The groups of [from] this form can actually show, keeping their order.
  /// [fallback] is what an empty result becomes, for the row that cannot be
  /// empty.
  static List<String> _known(List<String> from, {String? fallback}) {
    final kept = [for (final g in from) if (kMuscleGroups.contains(g)) g];
    if (kept.isEmpty && fallback != null) kept.add(fallback);
    return kept;
  }

  /// What the form is holding, normalised — see [MuscleMap].
  MuscleMap get _muscles =>
      MuscleMap(primary: _primary, secondary: _secondary);

  /// Ticks or unticks [group] as a group the movement trains.
  ///
  /// The last primary stays: a movement that trains nothing is not a movement,
  /// and the alternative — saving it and quietly filing it under Other — is a
  /// classification nobody chose.
  void _togglePrimary(String group) => _edit(() {
    if (_primary.contains(group)) {
      if (_primary.length > 1) _primary.remove(group);
    } else {
      _primary.add(group);
      _secondary.remove(group);
    }
  });

  /// The same for a group it only assists. Claiming one for this row gives up
  /// the claim on the other, so no group is ticked twice.
  void _toggleSecondary(String group) => _edit(() {
    if (_secondary.contains(group)) {
      _secondary.remove(group);
    } else if (_primary.length > 1 || !_primary.contains(group)) {
      _secondary.add(group);
      _primary.remove(group);
    }
  });

  /// The demo link as it should be stored: a YouTube URL reduced to its
  /// canonical short form, anything else left exactly as typed.
  ///
  /// Only YouTube is rewritten because only YouTube is understood. A coach's
  /// own upload or a private clip is not ours to tidy, and it opens from the
  /// exercise screen either way — it simply will not travel with a shared
  /// routine.
  static String? _tidyLink(String text) {
    final typed = text.trim();
    if (typed.isEmpty) return null;
    final id = youTubeVideoId(typed);
    return id == null ? typed : youTubeUrl(id);
  }

  /// Picking the equipment answers the loading question in almost every case,
  /// so it sets the weight type as it goes. Overwriting a choice made earlier
  /// is safe here because the two controls sit in that order on the screen —
  /// and the exceptions (an EZ-bar, a Smith machine) are a tap away below.
  void _setEquipment(String v) => _edit(() {
    _equip = v;
    _weightType = weightTypeForEquipment(v);
  });

  /// Applies a change the user made, and records that there is now something to
  /// lose. Every control on this form is one, so the mark is taken here rather
  /// than repeated at each of them — and `_load` deliberately does not go
  /// through it.
  void _edit(VoidCallback change) {
    markEdited();
    setState(change);
  }

  /// Switching the measure answers the loading question below it too, the same
  /// way picking the equipment does.
  ///
  /// **Held means nothing on it until you say otherwise.** Most holds carry no
  /// load, and a plank left reading "Barbell" because the equipment chip
  /// guessed that before the measure was set is a weight column asking for a
  /// number nobody has. Switching back to counted re-seeds from the equipment,
  /// because a counted barbell movement with no load type is the same mistake
  /// pointing the other way. Either exception — a weighted plank, a bodyweight
  /// chin-up — is the tap below.
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
    // The saved movement comes back with the pop, so a caller that opened this
    // form to get one — the builder's picker — can go straight on with it
    // instead of sending the user back to hunt for what they just made.
    // Callers that only wanted the form closed ignore it.
    final saved = await db.exerciseById(id);
    // In the database now, so there is nothing left to warn about — taken here
    // rather than left to `dispose`, because the form is briefly still mounted
    // behind the pop.
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

  /// The words on a measure chip. The stored value is the enum either way.
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
        // The stored English is what is selected and saved; only the chip's
        // words are translated — the vocabulary is an index in a routine code.
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
        // Measured in comes before Loaded as: whether a movement is counted
        // or held is the more fundamental fact about it, and it is what
        // decides whether the loading question is interesting at all.
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
        // Kept for a held movement rather than hidden — a weighted plank, a
        // loaded carry and a weighted dead hang are all real — but demoted
        // to a quieter line, because most holds carry nothing and the
        // answer above has usually already settled it.
        _Label(
          _measure == ExerciseMeasure.reps
              ? l10n.exerciseFormLoadedAs
              : l10n.exerciseFormLoadedAsOptional,
        ),
        _Choices(
          // [WeightType.none] is not offered: it is what deselecting leaves
          // behind, not a fourth chip.
          options: WeightType.loadable,
          label: (v) => weightTypeLabel(l10n, v),
          // Nothing is selected for a movement that carries nothing, and
          // tapping the selected chip is how you get back there.
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
        // No "12/80" counter. The limit stops typing on its own, and a running
        // tally of a number nobody is approaching is a line of noise under
        // every field.
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

/// A row of chips over one vocabulary.
///
/// Generic in the value so the chips carry what is stored — a muscle group as
/// English, an enum — and [label] alone decides the words. Comparing the value
/// rather than its words is what keeps the selection working in every language.
///
/// [selected] is a set rather than one value because the two muscle rows hold
/// several at once. A row where only one answer makes sense passes the one it
/// has, and the chips behave as they always did.
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
