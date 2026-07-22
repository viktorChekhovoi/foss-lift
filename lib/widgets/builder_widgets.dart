import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Shared chrome for the routine and workout builders.

InputDecoration builderInput(String hint) => InputDecoration(
      hintText: hint,
      // Set explicitly, not just via the theme: a field with its own `style`
      // would otherwise lend the hint its weight and size and make the
      // placeholder look like entered text.
      hintStyle: const TextStyle(
        color: AppColors.faint,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );

/// A small uppercase field caption.
Widget builderLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        t.toUpperCase(),
        style: kMono.copyWith(
            fontSize: 11, letterSpacing: 1.2, color: AppColors.faint),
      ),
    );

/// A compact "− value + " stepper.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.suffix = '',
    this.badge,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(badge!.toUpperCase(),
                style: kMono.copyWith(
                    fontSize: 9, letterSpacing: 0.8, color: AppColors.faint)),
          ),
        _btn(Icons.remove,
            value > min ? () => onChanged(_clamp(value - step)) : null),
        Container(
          constraints: const BoxConstraints(minWidth: 54),
          alignment: Alignment.center,
          child: Text('$value$suffix',
              style: kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        _btn(Icons.add,
            value < max ? () => onChanged(_clamp(value + step)) : null),
      ],
    );
  }

  int _clamp(int v) => v < min ? min : (v > max ? max : v);

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColors.surface : AppColors.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 18,
              color: onTap == null ? AppColors.faint : AppColors.text),
        ),
      ),
    );
  }
}

/// Small round move-up / move-down / remove buttons used by builder rows.
Widget builderIconButton(IconData icon, VoidCallback? onTap,
    {bool danger = false}) {
  return IconButton(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    onPressed: onTap,
    icon: Icon(icon,
        size: 20,
        color: onTap == null
            ? AppColors.faint.withValues(alpha: 0.4)
            : (danger ? const Color(0xFFFF5D5D) : AppColors.muted)),
  );
}

/// Searchable library picker shown as a bottom sheet; pops the chosen exercise.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});
  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(exerciseLibraryProvider);
    final height = MediaQuery.of(context).size.height * 0.8;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SheetGrabber(),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: builderInput('Search exercises…').copyWith(
                prefixIcon: const Icon(Icons.search, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: library.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(
                    child:
                        Text('$e', style: const TextStyle(color: AppColors.muted))),
                data: (all) {
                  final q = _query.trim().toLowerCase();
                  final list = q.isEmpty
                      ? all
                      : all
                          .where((e) =>
                              e.name.toLowerCase().contains(q) ||
                              e.muscleGroup.toLowerCase().contains(q))
                          .toList();
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (_, i) {
                      final e = list[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('${e.muscleGroup} · ${e.equipment}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                        trailing: const Icon(Icons.add, color: AppColors.accent),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The little drag handle at the top of a bottom sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Opens the exercise picker sheet and returns the chosen exercise.
Future<Exercise?> pickExercise(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const ExercisePicker(),
  );
}
