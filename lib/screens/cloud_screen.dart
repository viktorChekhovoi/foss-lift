import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/cloud_snapshot.dart';
import '../l10n/app_localizations.dart';
import '../providers/cloud_provider.dart';
import '../providers/providers.dart';
import '../services/cloud_models.dart';

class CloudScreen extends ConsumerStatefulWidget {
  const CloudScreen({super.key});
  @override
  ConsumerState<CloudScreen> createState() => _CloudScreenState();
}

class _CloudScreenState extends ConsumerState<CloudScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final code = switch (error) {
        CloudFailure(:final code) => code,
        FormatException(:final message) => message,
        _ => '',
      };
      _message = switch (code) {
        'invalid_email' => l10n.cloudEmailInvalid,
        'backup_changed' => l10n.cloudConflict,
        'too_large' || 'cloud_backup_too_large' => l10n.cloudTooLarge,
        'cloud_backup_incompatible' ||
        'cloud_backup_invalid' => l10n.cloudIncompatible,
        'workout_running' => l10n.cloudLiveSession,
        _ => l10n.cloudFailed,
      };
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cloudAccountProvider);
    final active = ref.watch(activeWorkoutProvider) != null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.cloudAccountCopy),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) ...[
              Text(_message!, key: const ValueKey('cloud-message')),
              const SizedBox(height: 16),
            ],
            ...state.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [
                Text(l10n.cloudFailed),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref.invalidate(cloudAccountProvider),
                  child: Text(l10n.cloudRefresh),
                ),
              ],
              data: (account) {
                if (!account.available) {
                  return [Text(l10n.cloudUnavailable)];
                }
                if (account.email == null) {
                  return [
                    AutofillGroup(
                      child: TextField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: InputDecoration(labelText: l10n.cloudEmail),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await ref
                                  .read(cloudClientProvider)
                                  .requestLink(_email.text);
                              if (mounted) {
                                _message = l10n.cloudLinkSent;
                              }
                            }),
                      child: Text(l10n.cloudSendLink),
                    ),
                  ];
                }
                return [
                  Text(
                    account.email!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    account.updatedAt == null
                        ? l10n.cloudNoBackup
                        : l10n.cloudLastBackup(
                            DateFormat.yMMMd(
                              l10n.localeName,
                            ).add_Hm().format(account.updatedAt!.toLocal()),
                          ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || active
                        ? null
                        : () => _run(() async {
                            final snapshot = await ref
                                .read(databaseProvider)
                                .exportCloudSnapshot();
                            await ref
                                .read(cloudClientProvider)
                                .save(snapshot, account.revision);
                            ref.invalidate(cloudAccountProvider);
                            if (mounted) {
                              _message = l10n.cloudSaved;
                            }
                          }),
                    child: Text(l10n.cloudSave),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy || active || account.revision == 0
                        ? null
                        : () async {
                            if (!await _confirm(
                                  l10n.cloudRestoreWarning,
                                  l10n.cloudRestore,
                                ) ||
                                !mounted) {
                              return;
                            }
                            await _run(() async {
                              final snapshot = await ref
                                  .read(cloudClientProvider)
                                  .download();
                              if (!mounted) return;
                              if (ref.read(activeWorkoutProvider) != null) {
                                throw const CloudFailure('workout_running');
                              }
                              await ref
                                  .read(databaseProvider)
                                  .restoreCloudSnapshot(snapshot);
                              ref.invalidate(pagedHistoryProvider);
                              if (mounted) {
                                _message = l10n.cloudRestored;
                              }
                            });
                          },
                    child: Text(l10n.cloudRestore),
                  ),
                  if (active) Text(l10n.cloudLiveSession),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            ref.invalidate(cloudAccountProvider);
                            await ref.read(cloudAccountProvider.future);
                          }),
                    child: Text(l10n.cloudRefresh),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await ref.read(cloudClientProvider).signOut();
                            ref.invalidate(cloudAccountProvider);
                          }),
                    child: Text(l10n.cloudSignOut),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!await _confirm(
                                  l10n.cloudDeleteWarning,
                                  l10n.cloudDeleteAccount,
                                ) ||
                                !mounted) {
                              return;
                            }
                            await _run(() async {
                              await ref
                                  .read(cloudClientProvider)
                                  .deleteAccount();
                              ref.invalidate(cloudAccountProvider);
                            });
                          },
                    child: Text(l10n.cloudDeleteAccount),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
