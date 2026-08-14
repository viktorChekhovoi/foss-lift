import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// The style a small-caps section heading is drawn in, for the handful of
/// places that need the words without [SectionLabel]'s row and padding.
///
/// The colour is [AppColors.muted] — the middle of a palette's three text
/// tones. All three clear 4.5:1 on every background the app paints, so the
/// choice is about rank rather than legibility: a heading naming what a list is
/// reads under the words in the list, and above the hints and dates that take
/// [AppColors.faint].
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
///
/// [trailing] is the screen's own action, on the right of the title — the + that
/// adds a routine is the one there is. It is centred against the two lines
/// rather than aligned to either, so it reads as belonging to the header at any
/// text size.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The body role, not the muted one. This line names where you
                // are, and a screen has exactly one of them — there is no column
                // of them to recede into the background, so nothing is gained by
                // dimming it and legibility is lost on the paler palettes.
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

/// The app's dialogs, as one thing.
///
/// Every dialog that asks for typing goes through [showAppDialog] and draws
/// itself as an [AppDialog]. The pair exists because a dialog with a field in
/// it has two problems that are the same problem seven times over, and both are
/// worth solving once:
///
///  - **the keyboard has to be asked for inside the tap.** A browser only lets
///    a page open the keyboard while it is still handling the gesture that
///    asked for it. `autofocus` on the field is a frame too late — the dialog
///    is built after the tap has been handled — so the field takes focus, the
///    keyboard does not come up, and you tap the field a second time to type.
///    [showAppDialog] claims the keyboard before it pushes the route, which is
///    still inside the gesture.
///  - **the box has to make room for what that keyboard covers.** See
///    [AppDialog].
class _KeyboardClaim with TextInputClient {
  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue.empty;

  // Nothing is typed into this client: it holds the keyboard open for the
  // fraction of a second between the tap and the dialog's own field attaching,
  // and that field replaces it as the platform's text input client.
  @override
  void connectionClosed() {}
  @override
  void performAction(TextInputAction action) {}
  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}
  @override
  void performSelector(String selectorName) {}
  @override
  void showAutocorrectionPromptRect(int start, int end) {}
  @override
  void updateEditingValue(TextEditingValue value) {}
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}
  @override
  void insertTextPlaceholder(Size size) {}
  @override
  void removeTextPlaceholder() {}
  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}
}

/// Opens one of the app's dialogs, and asks for the keyboard while the tap that
/// opened it is still being handled.
///
/// [keyboard] is the keyboard the dialog's own field will want — pass the
/// field's `keyboardType`, so what comes up is a number pad when the field is a
/// weight rather than a QWERTY that swaps under the thumb a frame later. Leave
/// it null for a dialog with nothing to type into; there is then nothing to
/// claim and this is a plain `showDialog`.
///
/// **Call it from the gesture, not from after an `await`.** The claim is only
/// worth anything while the browser still counts the work as the user's tap;
/// once the handler has suspended on a future, it is as late as `autofocus`
/// would have been.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  TextInputType? keyboard,
}) {
  // The capability, not `kIsWeb`: a phone raises its keyboard from `autofocus`
  // perfectly well, and claiming it early there would mean a keyboard opening
  // for a dialog the user is about to cancel.
  final eager =
      ProviderScope.containerOf(context, listen: false)
          .read(capabilitiesProvider)
          .eagerKeyboard;
  if (eager && keyboard != null) {
    // Not stored, not closed: attaching the dialog's own field replaces this
    // client, and there is nothing left to detach. A dialog dismissed without
    // ever attaching one leaves the connection to be replaced by the next
    // field the app opens, which is what would have had the keyboard anyway.
    TextInput.attach(
      _KeyboardClaim(),
      TextInputConfiguration(inputType: keyboard),
    ).show();
  }
  return showDialog<T>(context: context, builder: builder);
}

/// The box the app's dialogs are drawn in.
///
/// An `AlertDialog` moves up when the keyboard comes up, but it does not
/// shrink: at a phone's height with a keyboard over a third of it, the column
/// inside runs out of room and squeezes the field — to nothing at all at twice
/// the text size — or overflows past the bottom of the box. Sheets have always
/// made their own room ([bottomSystemInset]); this is that for dialogs, and it
/// is not a browser fix: a dialog clipped by a keyboard is just as wrong on a
/// phone.
///
/// `scrollable` is what does it. The title and the content scroll together
/// inside whatever height is left, at the size they asked for, so the field
/// keeps the height it would have had and the buttons stay where they are.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(title),
    content: content,
    actions: actions,
    scrollable: true,
  );
}
