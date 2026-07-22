import 'package:flutter/material.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// A tappable routine row: colour swatch, name, workout count.
class RoutineCard extends StatelessWidget {
  const RoutineCard({super.key, required this.data, required this.onTap});
  final RoutineWithCount data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = data.routine;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: hexColor(r.colorHex),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${data.workoutCount} '
                      '${data.workoutCount == 1 ? 'workout' : 'workouts'}',
                      style: kMono.copyWith(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
