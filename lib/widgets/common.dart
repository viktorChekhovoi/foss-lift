import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// The style a small-caps section heading is drawn in, for the handful of
/// places that need the words without [SectionLabel]'s row and padding.
///
/// The colour is [AppColors.muted], never [AppColors.faint]. `faint` is the one
/// role no palette is asked to keep legible — it exists for a column heading
/// nobody reads twice, and across the shipped palettes it sits nearer 3:1 than
/// 4.5:1 on the ground. A heading naming what a list is has to be read.
TextStyle sectionLabelStyle() => kMono.copyWith(
      fontSize: AppType.sectionLabel,
      letterSpacing: 1.4,
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
    );

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
              style: sectionLabelStyle(),
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
          // The body role, not the muted one. This line names where you are,
          // and a screen has exactly one of them — there is no column of them
          // to recede into the background, so nothing is gained by dimming it
          // and legibility is lost on the paler palettes.
          Text(
            eyebrow.toUpperCase(),
            style: kMono.copyWith(
              fontSize: AppType.eyebrow,
              letterSpacing: 1.2,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppType.screenTitle,
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
        AppLocalizations.of(context).commonNextBadge,
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

/// The room a surface has to leave at its bottom edge: the keyboard while it is
/// up, the phone's own gesture bar or Back / Home / Recents strip the rest of
/// the time.
///
/// A modal sheet has to apply this itself. `showModalBottomSheet`'s
/// `useSafeArea` pads the top and leaves the bottom edge alone on purpose — the
/// sheet is meant to reach the bottom of the screen — so a button at the foot
/// of one lands under the Back key unless the sheet pads its own content.
/// Screens do not need it: they sit inside a `SafeArea`. Nor does a scrolling
/// list, which takes the same padding off the `MediaQuery` by itself.
double bottomSystemInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  // Added, not maxed: the framework has already taken the keyboard's share out
  // of `padding`, so a strip the keyboard covers contributes nothing here and
  // the two are never counted twice.
  return mq.viewInsets.bottom + mq.padding.bottom;
}
