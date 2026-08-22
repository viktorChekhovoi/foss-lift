import 'package:flutter/material.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/schedule_labels.dart';
import '../util/seed_names.dart';
import 'common.dart';

class RoutineCard extends StatelessWidget {
  RoutineCard({
    super.key,
    required RoutineWithCount data,
    required this.onTap,
    this.isCurrent = false,
    this.onSetCurrent,
  }) : experienceLabel = null,
       name = data.routine.name,
       seedKey = data.routine.seedKey,
       colorHex = data.routine.colorHex,
       workoutCount = data.workoutCount,
       scheduleDays = data.routine.scheduleDays,
       hasReminder = data.routine.reminderMinutes != null;

  const RoutineCard.program({
    super.key,
    required this.name,
    required this.seedKey,
    required this.colorHex,
    required this.workoutCount,
    required this.scheduleDays,
    required this.onTap,
    this.experienceLabel,
  }) : isCurrent = false,
       onSetCurrent = null,
       hasReminder = false;

  final String name;
  final String? seedKey;
  final String colorHex;
  final int workoutCount;
  final int scheduleDays;
  final String? experienceLabel;

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
                    Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.routineCardWorkoutCount(workoutCount),
                          style: kMono.copyWith(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                        if (experienceLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              experienceLabel!,
                              style: kMono.copyWith(
                                fontSize: 10,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
                                fontSize: 11.5,
                                color: AppColors.faint,
                              ),
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
