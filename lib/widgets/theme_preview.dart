import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A miniature of the app painted in [palette], so a colour is judged in
/// context rather than as an isolated chip.
///
/// It deliberately exercises **every** one of the twelve roles. Some of them —
/// `surface2`, `surface3`, `accentPress`, `faint` — mean nothing as a swatch in
/// a list and only make sense once you can see what they do, which is the whole
/// reason the editor shows this rather than twelve squares.
///
/// Nothing here reads [AppColors]: the widget paints from the palette it is
/// handed, so it can preview a draft being edited or a theme someone just
/// scanned, neither of which is the active theme.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.palette});

  final AppPalette palette;

  /// The floor below which body text stops being comfortably readable. The same
  /// 4.5:1 every shipped preset is held to in the feature tests.
  static const double _legibleEnough = 4.5;

  /// Whether this palette paints text too close to the background it sits on.
  /// Checked against both the ground and a card, since text appears on both.
  bool get _hardToRead =>
      contrastRatio(palette.text, palette.ground) < _legibleEnough ||
      contrastRatio(palette.text, palette.surface) < _legibleEnough;

  /// Whether the done and short markers are too close to tell apart. The other
  /// warning is about reading text *against* a background; this one is about
  /// telling two colours apart *from each other*, which no contrast ratio
  /// answers — see [colourDistance].
  bool get _markersAlike =>
      colourDistance(palette.good, palette.gold) < kMarkerDistance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.ground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(),
          const SizedBox(height: 12),
          _statStrip(),
          const SizedBox(height: 12),
          _primaryButton(),
          if (_hardToRead) ...[
            const SizedBox(height: 12),
            _warning(
              'This text is hard to read on this background. Try a lighter or '
              'darker "Text" colour.',
            ),
          ],
          if (_markersAlike) ...[
            const SizedBox(height: 12),
            _warning(
              'Done and short look alike. A glance down a column of sets '
              'should tell them apart.',
            ),
          ],
        ],
      ),
    );
  }

  /// The live workout board, which is the screen this palette has to survive:
  /// an exercise heading with the weight it is being worked at, and three set
  /// rows — one hit, one short, one still to do.
  ///
  /// **The set rows are the point.** `good` and `gold` are the palette's
  /// hardest job — the fastest read in the app is a glance down this column —
  /// and a swatch of each says nothing about whether you could tell them apart
  /// at speed. The untouched third row is what puts `surface2`, `surface3` and
  /// `faint` on screen doing their actual jobs.
  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration:
                    BoxDecoration(color: palette.accent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text('Bench Press',
                    style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              // The working weight, drawn as the board draws it: a value with a
              // hairline under it, not a filled input.
              Container(
                padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: palette.line, width: 1.5)),
                ),
                child: Text('80 kg',
                    style: kMono.copyWith(
                        color: palette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _columnHeaders(),
          _setRow(number: 1, goal: '80×8', weight: '80', result: '8', tone: palette.good),
          _setRow(number: 2, goal: '80×8', weight: '80', result: '6', tone: palette.gold, short: true),
          _setRow(number: 3, goal: '80×8', weight: '80', result: '8'),
        ],
      ),
    );
  }

  Widget _columnHeaders() {
    Widget h(String t, {double? width}) {
      final child = Text(
        t.toUpperCase(),
        textAlign: width == null ? TextAlign.center : TextAlign.left,
        style: kMono.copyWith(
            fontSize: 9, letterSpacing: 0.9, color: palette.faint),
      );
      return width != null ? SizedBox(width: width, child: child) : Expanded(child: child);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [h('Set', width: 28), h('Goal', width: 54), h('kg'), h('Reps')],
      ),
    );
  }

  /// One set row. [tone] null means untouched — the state that shows what the
  /// two raised surfaces and `faint` are for.
  Widget _setRow({
    required int number,
    required String goal,
    required String weight,
    required String result,
    Color? tone,
    bool short = false,
  }) {
    final done = tone != null;
    final ink = tone ?? palette.faint;

    Widget cell(Widget child, {required bool filled}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: done
                  ? tone.withValues(alpha: filled ? 0.15 : 0.10)
                  : (filled ? palette.surface2 : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done ? tone.withValues(alpha: 0.45) : palette.line,
              ),
            ),
            child: child,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? ink.withValues(alpha: 0.15)
                      : palette.surface3,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$number',
                    style: kMono.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: done ? ink : palette.muted)),
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(goal,
                style: kMono.copyWith(
                    fontSize: 11,
                    color: done ? palette.muted : palette.faint)),
          ),
          Expanded(
            child: cell(
              Text(weight,
                  style: kMono.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: done ? ink : palette.muted)),
              filled: false,
            ),
          ),
          Expanded(
            child: cell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result,
                      style: kMono.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                  // The same arrow the board draws, so a palette is judged with
                  // the cue that does not depend on hue already in place.
                  if (short) ...[
                    const SizedBox(width: 1),
                    Icon(Icons.arrow_downward_rounded, size: 11, color: ink),
                  ],
                ],
              ),
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  /// The stat strip above the sets: the numbers in the accent, their labels in
  /// `faint`, divided by `line`.
  Widget _statStrip() {
    Widget stat(String value, String label, {bool accent = false}) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: kMono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent ? palette.accent : palette.text)),
              const SizedBox(height: 2),
              Text(label.toUpperCase(),
                  style: kMono.copyWith(
                      fontSize: 8.5, letterSpacing: 1, color: palette.faint)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.line),
          bottom: BorderSide(color: palette.line),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stat('12:04', 'Duration'),
            VerticalDivider(width: 1, color: palette.line),
            stat('3/17', 'Sets', accent: true),
          ],
        ),
      ),
    );
  }

  /// The primary action. Its label is whichever of a dark tint or white the
  /// palette says reads on the accent, so a bad accent shows up here as a
  /// washed-out label. The bottom edge is `accentPress` — the tone the button
  /// takes when held, which is otherwise invisible until you press one.
  Widget _primaryButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          bottom: BorderSide(color: palette.accentPress, width: 3),
        ),
      ),
      child: Center(
        child: Text('Log set',
            style: TextStyle(
                color: palette.onAccent,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Shown only when the palette fails one of its own checks. Painted in the
  /// palette's own colours on purpose — if the warning itself is unreadable,
  /// that is the point being made.
  ///
  /// Binary, and only ever guidance: it says a thing is wrong, never how wrong.
  /// A running number would make this an accessibility workbench, which is what
  /// the two checked high-contrast presets are for.
  Widget _warning(String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: palette.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: palette.text, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
