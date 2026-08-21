import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

const String kContactEmail = 'birdie.software.studios@gmail.com';

const String kAppName = 'Foss Lift';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(kAppName,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.aboutSubtitle,
                style: TextStyle(color: AppColors.muted, fontSize: 14)),
            const SizedBox(height: 22),
            _Section(l10n.aboutDataSection),
            _Para(l10n.aboutDataPara1),
            const SizedBox(height: 8),
            _Para(l10n.aboutDataPara2),
            const SizedBox(height: 22),
            _Section(l10n.aboutLicenseSection),
            _Para(l10n.aboutLicenseBody),
            const SizedBox(height: 22),
            _Section(l10n.aboutSomethingBrokenSection),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: AppColors.line),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: Icon(Icons.bug_report_outlined, color: AppColors.accent),
                label: Text(l10n.aboutReportBug),
                onPressed: () => _mail(context, l10n),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onLongPress: () => _copy(context, l10n),
              child: Text(kContactEmail,
                  style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mail(BuildContext context, AppLocalizations l10n) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kContactEmail,
      query: 'subject=${Uri.encodeComponent(l10n.aboutBugReportSubject)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) await _copy(context, l10n);
  }

  Future<void> _copy(BuildContext context, AppLocalizations l10n) async {
    await Clipboard.setData(const ClipboardData(text: kContactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.aboutAddressCopied)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: sectionLabelStyle());
}

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(text,
            style:
                TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5)),
      );
}
