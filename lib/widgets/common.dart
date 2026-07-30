import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small uppercase monospace section header, e.g. "YOUR ROUTINES".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flexible with nothing else flexible beside it: the heading may take
          // the whole row bar its trailing action, and spaceBetween keeps that
          // action on the right edge when the heading is short. A Spacer here
          // would halve the space the heading gets and ellipsize an ordinary
          // routine name — the headings are routine names, which are as long as
          // "Push / Pull / Legs".
          Flexible(
            child: Text(
              text.toUpperCase(),
              // No line cap and no ellipsis: a heading that does not fit across
              // the phone wraps. These headings are routine names, and a name
              // cut to "PUSH / PULL / L…" tells you less than nothing.
              style: kMono.copyWith(
                fontSize: 11.5,
                letterSpacing: 1.4,
                color: AppColors.faint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Large screen title with an eyebrow line above it (Today / History / …).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.eyebrow, required this.title});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: kMono.copyWith(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill marking the workout a routine suggests doing next.
class NextBadge extends StatelessWidget {
  const NextBadge({super.key, required this.color});
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
        'NEXT',
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

/// Parses a stored "RRGGBB" hex string into an opaque [Color].
Color hexColor(String hex) => Color(int.parse('FF$hex', radix: 16));
