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
          _setChips(),
          const SizedBox(height: 12),
          _primaryButton(),
          if (_hardToRead) ...[
            const SizedBox(height: 12),
            _warning(),
          ],
        ],
      ),
    );
  }

  /// An exercise card: the app's most common surface, carrying text, muted
  /// detail, the completed weight and a record.
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
          Text('Bench Press',
              style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('4 × 6–8 · working set',
              style: kMono.copyWith(color: palette.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('80 kg',
                  style: kMono.copyWith(
                      color: palette.good,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Text('PR 92.5',
                  style: kMono.copyWith(color: palette.gold, fontSize: 13)),
              const Spacer(),
              Text('rest 90s',
                  style: kMono.copyWith(color: palette.faint, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  /// The two raised tiers, shown as the set chips that actually use them: a
  /// warm-up on `surface2`, the set you are on lifted onto `surface3`.
  Widget _setChips() {
    return Row(
      children: [
        _chip('Warm-up', palette.surface2, palette.muted),
        const SizedBox(width: 8),
        _chip('Set 3', palette.surface3, palette.text),
      ],
    );
  }

  Widget _chip(String label, Color fill, Color ink) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: palette.line),
      ),
      child: Text(label, style: kMono.copyWith(color: ink, fontSize: 12)),
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

  /// Shown only when the palette fails its own legibility check. Painted in the
  /// palette's own colours on purpose — if the warning itself is unreadable,
  /// that is the point being made.
  Widget _warning() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: palette.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'This text is hard to read on this background. Try a lighter or '
            'darker "Text" colour.',
            style: TextStyle(color: palette.text, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
