import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.palette});

  final AppPalette palette;

  static const double _legibleEnough = 4.5;

  bool get _hardToRead =>
      contrastRatio(palette.text, palette.ground) < _legibleEnough ||
      contrastRatio(palette.text, palette.surface) < _legibleEnough;

  bool get _markersAlike =>
      colourDistance(palette.good, palette.gold) < kMarkerDistance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          _card(l10n),
          const SizedBox(height: 12),
          _statStrip(l10n),
          const SizedBox(height: 12),
          _primaryButton(l10n),
          if (_hardToRead) ...[
            const SizedBox(height: 12),
            _warning(l10n.themePreviewContrastWarning),
          ],
          if (_markersAlike) ...[
            const SizedBox(height: 12),
            _warning(l10n.themePreviewMarkersWarning),
          ],
        ],
      ),
    );
  }

  Widget _card(AppLocalizations l10n) {
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
                child: Text(l10n.exerciseBenchPress,
                    style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: palette.line, width: 1.5)),
                ),
                child: Text(l10n.unitWeightShort('80', l10n.unitKgSuffix),
                    style: kMono.copyWith(
                        color: palette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _columnHeaders(l10n),
          _setRow(number: 1, goal: '80×8', weight: '80', result: '8', tone: palette.good),
          _setRow(number: 2, goal: '80×8', weight: '80', result: '6', tone: palette.gold, short: true),
          _setRow(number: 3, goal: '80×8', weight: '80', result: '8'),
        ],
      ),
    );
  }

  Widget _columnHeaders(AppLocalizations l10n) {
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
        children: [
          h(l10n.themePreviewSetHeader, width: 28),
          h(l10n.themePreviewGoalHeader, width: 54),
          h(l10n.unitKgSuffix),
          h(l10n.themePreviewRepsHeader),
        ],
      ),
    );
  }

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

  Widget _statStrip(AppLocalizations l10n) {
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
            stat('12:04', l10n.themePreviewDuration),
            VerticalDivider(width: 1, color: palette.line),
            stat('3/17', l10n.themePreviewSets, accent: true),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(AppLocalizations l10n) {
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
        child: Text(l10n.themePreviewStartWorkout,
            style: TextStyle(
                color: palette.onAccent,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

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
