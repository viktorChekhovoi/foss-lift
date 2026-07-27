import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Form for creating a custom exercise that joins the library.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key});

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _name = TextEditingController();
  final _instructions = TextEditingController();
  final _video = TextEditingController();
  String _muscle = 'Chest';
  String _equip = 'Barbell';
  String _measure = 'Reps';
  WeightType _weightType = weightTypeForEquipment('Barbell');
  bool _saving = false;

  /// The demo link as it should be stored: a YouTube URL reduced to its
  /// canonical short form, anything else left exactly as typed.
  ///
  /// Only YouTube is rewritten because only YouTube is understood. A coach's
  /// own upload or a private clip is not ours to tidy, and it opens from the
  /// exercise screen either way — it simply will not travel with a shared
  /// routine, which the field says out loud rather than leaving to be
  /// discovered later.
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
    _instructions.dispose();
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
    await ref.read(databaseProvider).createExercise(
          name: name,
          muscle: _muscle,
          equipment: _equip,
          instructions: _instructions.text.trim(),
          videoUrl: video,
          measure: _measures[_measure]!,
          weightType: _weightType,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New exercise')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _Label('Name'),
            _Field(controller: _name, hint: 'e.g. Cable Lateral Raise'),
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
            _Label('How to (optional)'),
            _Field(
              controller: _instructions,
              hint: 'A short form cue…',
              maxLines: 4,
            ),
            const SizedBox(height: 18),
            _Label('Demo link (optional)'),
            _Field(
              controller: _video,
              hint: 'https://…',
              keyboardType: TextInputType.url,
              // Rebuilds the note below as the link is typed or pasted.
              onChanged: (_) => setState(() {}),
            ),
            _LinkNote(text: _video.text),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save exercise'),
              ),
            ),
          ],
        ),
      ),
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
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
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

/// What will become of the demo link, said before it is saved rather than
/// discovered on the other phone.
///
/// Three things a link can be: a video we can name (and will tidy), a YouTube
/// page with no video behind it, or somebody else's site. Only the first
/// travels with a shared routine, and the difference is invisible unless the
/// form says so.
class _LinkNote extends StatelessWidget {
  const _LinkNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final typed = text.trim();
    if (typed.isEmpty) return const SizedBox(height: 0);

    final id = youTubeVideoId(typed);
    final message = id != null
        ? 'Saved as youtu.be/$id, and travels with a shared routine.'
        : "Kept as typed. It won't travel when you share a routine — only a "
            'link to a specific video does.';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: kMono.copyWith(
          fontSize: 11,
          height: 1.5,
          color: id != null ? AppColors.muted : AppColors.faint,
        ),
      ),
    );
  }
}
