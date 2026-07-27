import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../util/video_links.dart';


/// How the movement is counted, in the words a lifter would use.
const _measures = {'Reps': ExerciseMeasure.reps, 'Time held': ExerciseMeasure.time};

/// What the weight column will mean for this movement.
const _weightTypes = {
  'Bar': WeightType.bar,
  'Machine': WeightType.machine,
  'Dumbbell': WeightType.dumbbell,
};

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

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _name = TextEditingController();
  final _video = TextEditingController();
  String _muscle = 'Chest';
  String _equip = 'Barbell';
  String _measure = 'Reps';
  WeightType _weightType = weightTypeForEquipment('Barbell');
  bool _saving = false;

  bool get _isEdit => widget.exerciseId != null;

  /// Whether the existing exercise has been read into the fields yet. Creating
  /// starts ready; editing has a database round trip to wait for.
  late bool _loaded = !_isEdit;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final ex =
        await ref.read(databaseProvider).exerciseById(widget.exerciseId!);
    if (!mounted) return;
    setState(() {
      _name.text = ex.name;
      _video.text = ex.videoUrl ?? '';
      _muscle = kMuscleGroups.contains(ex.muscleGroup) ? ex.muscleGroup : 'Other';
      _equip = kEquipmentTypes.contains(ex.equipment) ? ex.equipment : 'Other';
      _measure = ex.measure == ExerciseMeasure.time ? 'Time held' : 'Reps';
      _weightType = ex.weightType;
      _loaded = true;
    });
  }

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
  void _setEquipment(String v) => setState(() {
        _equip = v;
        _weightType = weightTypeForEquipment(v);
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
        const SnackBar(content: Text('Give the exercise a name first.')),
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
        muscle: _muscle,
        equipment: _equip,
        videoUrl: video,
        measure: _measures[_measure]!,
        weightType: _weightType,
      );
    } else {
      id = await db.createExercise(
        name: name,
        muscle: _muscle,
        equipment: _equip,
        videoUrl: video,
        measure: _measures[_measure]!,
        weightType: _weightType,
      );
    }
    // The saved movement comes back with the pop, so a caller that opened this
    // form to get one — the builder's picker — can go straight on with it
    // instead of sending the user back to hunt for what they just made.
    // Callers that only wanted the form closed ignore it.
    final saved = await db.exerciseById(id);
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit exercise' : 'New exercise'),
      ),
      body: SafeArea(
        top: false,
        child: !_loaded
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _Label('Name'),
            _Field(
              controller: _name,
              hint: 'e.g. Cable Lateral Raise',
              maxLength: kMaxNameLength,
            ),
            const SizedBox(height: 18),
            _Label('Muscle group'),
            _Choices(
              options: kMuscleGroups,
              selected: _muscle,
              onSelect: (v) => setState(() => _muscle = v),
            ),
            const SizedBox(height: 18),
            _Label('Equipment'),
            _Choices(
              options: kEquipmentTypes,
              selected: _equip,
              onSelect: _setEquipment,
            ),
            const SizedBox(height: 18),
            _Label('Loaded as'),
            _Choices(
              options: _weightTypes.keys.toList(),
              selected: _weightType.label,
              onSelect: (v) => setState(() => _weightType = _weightTypes[v]!),
            ),
            const SizedBox(height: 18),
            _Label('Measured in'),
            _Choices(
              options: _measures.keys.toList(),
              selected: _measure,
              onSelect: (v) => setState(() => _measure = v),
            ),
            const SizedBox(height: 6),
            Text(
              _measure == 'Reps'
                  ? 'Counted movements progress by adding load or reps.'
                  : 'Held movements are logged in seconds and progress by '
                      'holding longer.',
              style: kMono.copyWith(
                  fontSize: 11, height: 1.5, color: AppColors.faint),
            ),
            const SizedBox(height: 18),
            _Label('Demo link (optional)'),
            _Field(
              controller: _video,
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save exercise'),
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
        child: Text(text.toUpperCase(),
            style: kMono.copyWith(
                fontSize: 11, letterSpacing: 1.2, color: AppColors.faint)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

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
                color: o == selected
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: o == selected ? AppColors.accent : AppColors.line,
                ),
              ),
              child: Text(o,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: o == selected ? AppColors.accent : AppColors.muted,
                  )),
            ),
          ),
      ],
    );
  }
}
