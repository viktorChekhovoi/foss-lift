import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../util/units.dart';

/// The set board's two cells, in one place.
///
/// The live board draws them from the session and the first-run tour draws a
/// still life of the same thing. They used to be written twice, which is how
/// the tour came to show a board the app no longer had. Anything that decides
/// how a cell looks — its share of the row, its fill, its type — lives here and
/// both callers read it.

/// How the two cells divide the row between them.
///
/// The result cell takes the larger share because it is the one that gets
/// tapped: every set is logged through it, while a row's own weight is touched
/// only on the rare set that comes down. The headings use the same numbers, or
/// they drift off the columns they name.
const int kWeightColumnFlex = 2;
const int kResultColumnFlex = 3;

/// The set number's column, and the camera's on the far side.
const double kSetNumberColumnWidth = 40;
const double kSetTrailingColumnWidth = 36;

/// How long one breath of the pulse takes, in each direction.
const Duration kBoardPulsePeriod = Duration(milliseconds: 1100);

/// The fill and the border a board cell wears.
///
/// [primary] is the result cell — the one that logs the set. [done] is a set
/// already logged, which takes its [tone] (green at goal, gold short of it).
/// [pulse] runs 0 → 1 over the cell that is waiting to be tapped; at 0 it is
/// the resting fill, at 1 the accent has come up through it.
BoxDecoration boardCellDecoration({
  required bool primary,
  required bool done,
  required Color tone,
  double pulse = 0,
  bool emphasised = false,
}) {
  final Color fill;
  final Color edge;
  if (done) {
    fill = tone.withValues(alpha: primary ? 0.15 : 0.10);
    edge = tone.withValues(alpha: primary ? 0.55 : 0.30);
  } else if (primary) {
    // Filled and raised while it waits: on a row where everything else is an
    // outline, the solid one is the button. It carries no hairline of its own
    // — the fill is the edge — so the border is set to the fill rather than
    // dropped, which is what holds the row's height steady between states.
    fill = Color.lerp(
      AppColors.surface3,
      AppColors.accent.withValues(alpha: 0.22),
      pulse,
    )!;
    edge = Color.lerp(
      AppColors.surface3,
      AppColors.accent.withValues(alpha: 0.85),
      pulse,
    )!;
  } else {
    fill = Colors.transparent;
    edge = AppColors.line;
  }
  return BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(9),
    border: Border.all(color: edge, width: emphasised ? 2 : 1),
  );
}

/// The type inside a board cell: the result reads louder than the weight it
/// sits beside, for the same reason it is wider.
TextStyle boardCellTextStyle({
  required bool primary,
  required bool done,
  required Color tone,
}) =>
    kMono.copyWith(
      fontSize: primary ? 16 : 14,
      fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
      color: done ? tone : AppColors.muted,
    );

/// Breathes the accent through the cell you are meant to tap next.
///
/// The row is marked as well, but a mark is a thing you read and a pulse is a
/// thing you notice — on a phone propped against a rack between sets, the
/// second one is what gets found without looking for it.
///
/// **It respects the phone's reduce-motion setting.** Where animation is turned
/// off the cell simply rests at the top of the pulse, so what the setting costs
/// is the movement, never the highlight.
class BoardPulse extends StatefulWidget {
  const BoardPulse({super.key, required this.on, required this.builder});

  /// Whether this is the cell waiting to be tapped.
  final bool on;

  /// Draws the cell at [pulse] 0 → 1.
  final Widget Function(BuildContext context, double pulse) builder;

  @override
  State<BoardPulse> createState() => _BoardPulseState();
}

class _BoardPulseState extends State<BoardPulse>
    with SingleTickerProviderStateMixin {
  // Built here rather than in a `late final` initialiser: a lazy one is only
  // created on first use, and a cell that never pulses would first touch it in
  // dispose(), which is too late to be given a ticker.
  late final AnimationController _c;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: kBoardPulsePeriod);
    _t = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    if (widget.on) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BoardPulse old) {
    super.didUpdateWidget(old);
    if (widget.on == old.on) return;
    if (widget.on) {
      _c.repeat(reverse: true);
    } else {
      // Back to rest rather than stopping wherever it happened to be: a cell
      // that stops mid-breath keeps a tint it has no reason to have.
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.builder(context, 0);
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.builder(context, 1);
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => widget.builder(context, _t.value),
    );
  }
}

/// The one weight an exercise is being worked at today.
///
/// Drawn as a control, in the same bordered box the set rows use for a weight:
/// on the goal line it sits beside plain text, and a number with only a
/// hairline under it read as part of the label rather than as the thing you
/// tap. It is still not a text field sitting open — the box holds a value, and
/// touching it opens the editor.
///
/// The tour draws it too, with no [onTap]: a still life of the board takes no
/// gestures, and there is nothing behind it to open.
class WorkingWeight extends StatelessWidget {
  const WorkingWeight({
    super.key,
    required this.weightKg,
    required this.unit,
    this.onTap,
  });

  final double? weightKg;
  final String unit;

  /// What touching the box opens, or null where it opens nothing.
  final VoidCallback? onTap;

  /// The weight and its unit, with the unit set quieter than the number it
  /// belongs to — the number is the value, the symbol is a footnote on it.
  ///
  /// The string is built whole, by the same [weightWithUnit] every other weight
  /// goes through, and only then split on the symbol. So the *order* is the
  /// language's — a pattern that puts the symbol first is drawn that way — and
  /// what is decided here is type and spacing, which are not things a
  /// translation has an opinion about. The join is a fixed 3 px rather than the
  /// pattern's own space, because a space set at the weight's size is 19 px of
  /// this line at twice the text scale, and the line has a control on it.
  ///
  /// An unset weight is a bare dash with no symbol in it, and is drawn as one
  /// run.
  Widget _label(AppLocalizations l10n) {
    final text = weightWithUnit(l10n, weightKg, unit);
    final number = kMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700);
    final symbol = unitSuffix(l10n, unit);
    final at = text.indexOf(symbol);
    if (at < 0) return Text(text, style: number);
    final before = text.substring(0, at).trim();
    final after = text.substring(at + symbol.length).trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      textBaseline: TextBaseline.alphabetic,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      children: [
        if (before.isNotEmpty) ...[
          Text(before, style: number),
          const SizedBox(width: 3),
        ],
        Text(
          symbol,
          style: kMono.copyWith(fontSize: 11, color: AppColors.muted),
        ),
        if (after.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(after, style: number),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 5, 7, 5),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _label(AppLocalizations.of(context)),
              const SizedBox(width: 7),
              Icon(Icons.edit_outlined, size: 13, color: AppColors.faint),
            ],
          ),
        ),
      );
}

/// The headings over the board's columns.
///
/// They carry the row's own trailing column as an empty box: without it the
/// headings divide a wider strip than the cells do and every one of them sits
/// off-centre over what it names.
class BoardColumnHeaders extends StatelessWidget {
  const BoardColumnHeaders({
    super.key,
    required this.unit,
    required this.timed,
    this.showWeight = true,
  });

  final String unit;
  final bool timed;

  /// Whether there is a weight column under this at all. A movement done under
  /// no load has none, rather than an empty box under an empty heading.
  final bool showWeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // [shout] is off for the unit: the headings are set in capitals, but a unit
    // is a symbol rather than a word, and "KG" is not one anybody writes. It is
    // also what the plate line and the rest bar say, so re-casing it here would
    // be the same number written two ways one above the other.
    Widget h(String t, {double? width, int flex = 1, bool shout = true}) {
      final child = Text(
        shout ? t.toUpperCase() : t,
        textAlign: TextAlign.center,
        style: kMono.copyWith(
          fontSize: 10,
          letterSpacing: 0.9,
          color: AppColors.faint,
        ),
      );
      return width != null
          ? SizedBox(width: width, child: child)
          : Expanded(flex: flex, child: child);
    }

    return Padding(
      // The 5 either side is the set row's own inset — its 4 of padding and the
      // 1 of border it carries when it is the set you are on — so the headings
      // stay over their columns whether or not a row below is marked.
      padding: const EdgeInsets.only(bottom: 4, top: 2, left: 5, right: 5),
      child: Row(
        children: [
          h(l10n.sessionColSet, width: kSetNumberColumnWidth),
          if (showWeight)
            h(unitSuffix(l10n, unit), flex: kWeightColumnFlex, shout: false),
          h(
            timed ? l10n.sessionColSecHeld : l10n.sessionColRepsDone,
            flex: kResultColumnFlex,
          ),
          const SizedBox(width: kSetTrailingColumnWidth),
        ],
      ),
    );
  }
}
