import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Where to write when the app misbehaves. The only address in the app, and the
/// only reason it holds one.
const String kContactEmail = 'birdie.software.studios@gmail.com';

/// What this app is, who made it, and how to complain about it.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Foss Lift')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Foss Lift',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('An offline workout tracker.',
                style: TextStyle(color: AppColors.muted, fontSize: 14)),
            const SizedBox(height: 22),
            _Section('WHAT IT DOES WITH YOUR DATA'),
            _Para(
              'Nothing leaves this phone. No account, no server, no analytics. '
              'The app asks for no network permission, so it could not send '
              'your training anywhere if it wanted to.',
            ),
            const SizedBox(height: 8),
            _Para(
              'Two things reach outside, and both hand off to another app you '
              'can see: opening a demo link in your browser, and passing a '
              'share code to the share sheet.',
            ),
            const SizedBox(height: 22),
            _Section('LICENCE'),
            _Para(
              'AGPL-3.0. Free to use, read, change and pass on — the source is '
              'the whole of it, and anything built on it stays free too.',
            ),
            const SizedBox(height: 22),
            _Section('SOMETHING BROKEN?'),
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
                label: const Text('Report a bug'),
                onPressed: () => _mail(context),
              ),
            ),
            const SizedBox(height: 8),
            // Printed as well as linked: a phone with no mail app set up would
            // otherwise leave you with a button that does nothing and no
            // address to write down.
            GestureDetector(
              onLongPress: () => _copy(context),
              child: Text(kContactEmail,
                  style: kMono.copyWith(fontSize: 12, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a pre-addressed draft in whatever handles mail. Falls back to the
  /// clipboard, which leaves you somewhere you can still act.
  Future<void> _mail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: kContactEmail,
      query: 'subject=${Uri.encodeComponent('Foss Lift bug report')}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) await _copy(context);
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: kContactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: kMono.copyWith(
          fontSize: 11, letterSpacing: 1.2, color: AppColors.faint));
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
