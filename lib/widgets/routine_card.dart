import 'package:flutter/material.dart';

import '../data/database.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// A tappable routine row: colour swatch, name, workout count.
///
/// When [onSetCurrent] is given the row also offers a "make this the current
/// routine" control, and marks itself when [isCurrent].
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.data,
    required this.onTap,
    this.isCurrent = false,
    this.onSetCurrent,
  });
  final RoutineWithCount data;
  final VoidCallback onTap;
  final bool isCurrent;
  final VoidCallback? onSetCurrent;

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
            border: Border.all(
              color: isCurrent ? hexColor(r.colorHex) : AppColors.line,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          _CurrentBadge(color: hexColor(r.colorHex)),
                        ],
                      ],
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
                    // Only when there is one: a line reading "No fixed days" on
                    // every unscheduled routine is noise about a setting most
                    // of them will never use.
                    if (r.scheduleDays != kNoScheduleMask) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            r.reminderMinutes == null
                                ? Icons.event_outlined
                                : Icons.notifications_active_outlined,
                            size: 12,
                            color: AppColors.faint,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              scheduleLabel(r.scheduleDays),
                              overflow: TextOverflow.ellipsis,
                              style: kMono.copyWith(
                                  fontSize: 11.5, color: AppColors.faint),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onSetCurrent != null)
                IconButton(
                  tooltip: isCurrent ? 'Current routine' : 'Make current',
                  visualDensity: VisualDensity.compact,
                  onPressed: isCurrent ? null : onSetCurrent,
                  icon: Icon(
                    isCurrent
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: isCurrent ? hexColor(r.colorHex) : AppColors.muted,
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

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'CURRENT',
        style: kMono.copyWith(
          fontSize: 9,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
