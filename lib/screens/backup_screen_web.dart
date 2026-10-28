import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A native-only route may still arrive through an old bookmark.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).backupTitle)),
    body: const Center(child: Icon(Icons.phone_iphone)),
  );
}
