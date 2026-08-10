import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/schedule_labels.dart';
import '../util/seed_names.dart';
import 'common.dart';

/// A tappable routine row: colour swatch, name, workout count.
///
/// When [onSetCurrent] is given the row also offers a "make this the current
/// routine" control, and marks itself when [isCurrent].
///
/// It takes the fields rather than the row so the routine library can draw a
/// program it has not written yet — see [RoutineCard.program]. A program in the
/// library and a routine in your list are the same thing to look at; what
/// separates them is only that one of them is not yours yet.
class RoutineCard extends StatelessWidget {
  RoutineCard({
    super.key,
    required RoutineWithCount data,
    required this.onTap,
    this.isCurrent = false,
    this.onSetCurrent,
  })  : name = data.routine.name,
        seedKey = data.routine.seedKey,
        colorHex = data.routine.colorHex,
        workoutCount = data.workoutCount,
        scheduleDays = data.routine.scheduleDays,
        hasReminder = data.routine.reminderMinutes != null;

  /// A program out of the routine library, which has no row and no reminder, is
  /// nobody's current routine, and cannot be made one until it is added.
  const RoutineCard.program({
    super.key,
    required this.name,
    required this.seedKey,
    required this.colorHex,
    required this.workoutCount,
    required this.scheduleDays,
    required this.onTap,
  })  : isCurrent = false,
        onSetCurrent = null,
        hasReminder = false;

  /// The canonical English name, rendered through [seedKey] — see
  /// `util/seed_names.dart`.
  final String name;
  final String? seedKey;
  final String colorHex;
  final int workoutCount;
  final int scheduleDays;

  /// Whether the schedule line should say a reminder is set rather than only
  /// which days the routine is trained on.
  final bool hasReminder;

  final VoidCallback onTap;
  final bool isCurrent;
  final VoidCallback? onSetCurrent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
              color: isCurrent ? hexColor(colorHex) : AppColors.line,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  color: hexColor(colorHex),
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
                            seededName(l10n, seedKey, name),
                            // Wraps rather than being cut, for the same reason
                            // the headings do: a routine name is how you tell
                            // one program from another.
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          _CurrentBadge(color: hexColor(colorHex)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.routineCardWorkoutCount(workoutCount),
                      style: kMono.copyWith(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    // Only when there is one: a line reading "No fixed days" on
                    // every unscheduled routine is noise about a setting most
                    // of them will never use.
                    if (scheduleDays != kNoScheduleMask) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            hasReminder
                                ? Icons.notifications_active_outlined
                                : Icons.event_outlined,
                            size: 12,
                            color: AppColors.faint,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              scheduleLabel(l10n, scheduleDays),
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
                  tooltip: isCurrent
                      ? l10n.routineCardCurrentTooltip
                      : l10n.routineCardMakeCurrent,
                  visualDensity: VisualDensity.compact,
                  onPressed: isCurrent ? null : onSetCurrent,
                  icon: Icon(
                    isCurrent
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: isCurrent ? hexColor(colorHex) : AppColors.muted,
                  ),
                ),
              Icon(Icons.chevron_right, color: AppColors.faint),
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
        AppLocalizations.of(context).routineCardCurrent,
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
