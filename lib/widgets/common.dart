import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

TextStyle sectionLabelStyle() => kMono.copyWith(
      fontSize: AppType.sectionLabel,
      letterSpacing: 1.4,
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
    );

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
          Flexible(
            child: Text(
              text.toUpperCase(),
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

Color hexColor(String hex) => Color(int.parse('FF$hex', radix: 16));

double bottomSystemInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.viewInsets.bottom + mq.padding.bottom;
}

class _KeyboardClaim with TextInputClient {
  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue? get currentTextEditingValue => TextEditingValue.empty;

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

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  TextInputType? keyboard,
}) {
  final eager =
      ProviderScope.containerOf(context, listen: false)
          .read(capabilitiesProvider)
          .eagerKeyboard;
  if (eager && keyboard != null) {
    TextInput.attach(
      _KeyboardClaim(),
      TextInputConfiguration(inputType: keyboard),
    ).show();
  }
  return showDialog<T>(context: context, builder: builder);
}

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
