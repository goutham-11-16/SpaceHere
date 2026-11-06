import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/space_theme.dart';
import '../../features/auth/auth_controller.dart';
import '../../services/crypto/aes_encryption_service.dart';
import '../../services/repository/space_providers.dart';
import '../dashboard/space_shell.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final syncState = ref.watch(syncStateProvider);

    return SpaceShell(
      title: 'Vault Settings',
      selectedIndex: 2,
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: auth.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text(error.toString()),
                data: (state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _SettingsRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: state.email ?? 'Not linked',
                    ),
                    _SettingsRow(
                      icon: Icons.phone_rounded,
                      label: 'Telegram',
                      value: state.telegramPhone ?? 'Not linked',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cryptography',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  const _SettingsRow(
                    icon: Icons.enhanced_encryption_rounded,
                    label: 'Cipher',
                    value: 'AES-256 GCM',
                  ),
                  const _SettingsRow(
                    icon: Icons.password_rounded,
                    label: 'KDF',
                    value: 'PBKDF2 HMAC-SHA256',
                  ),
                  const _SettingsRow(
                    icon: Icons.repeat_rounded,
                    label: 'Iterations',
                    value: '${AesEncryptionService.kdfIterations}',
                  ),
                  const _SettingsRow(
                    icon: Icons.key_rounded,
                    label: 'IV',
                    value: '12-byte fresh nonce per file',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: syncState.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) => Text(error.toString()),
                data: (state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Contract',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _SettingsRow(
                      icon: Icons.schema_rounded,
                      label: 'Schema',
                      value: 'v${state.schemaVersion}',
                    ),
                    _SettingsRow(
                      icon: Icons.hub_rounded,
                      label: 'Channel',
                      value: state.channelId,
                    ),
                    _SettingsRow(
                      icon: Icons.account_tree_rounded,
                      label: 'Nodes',
                      value: '${state.nodes.length}',
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(spaceRepositoryProvider)
                                .syncLocalStateToVault();
                            ref.invalidate(syncStateProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sync state successfully pinned to vault',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.push_pin_rounded),
                          label: const Text('Pin sync state'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showRawJsonDialog(context, state);
                          },
                          icon: const Icon(Icons.code_rounded),
                          label: const Text('View Raw Contract JSON'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SpaceColors.amber,
                            side: const BorderSide(color: SpaceColors.amber),
                          ),
                          onPressed: () {
                            _confirmReinitializeVault(context, ref);
                          },
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Re-initialize Vault'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRawJsonDialog(BuildContext context, dynamic state) {
    final rawJson = const JsonEncoder.withIndent('  ').convert(state.toJson());
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.data_object_rounded, color: SpaceColors.cyan),
              SizedBox(width: 10),
              Text('sync_state.json Contract'),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 380,
            child: SingleChildScrollView(
              child: SelectableText(
                rawJson,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReinitializeVault(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Re-initialize Vault?'),
          content: const Text(
            'This will re-create the MTProto storage channel and re-pin the current local VFS state. Use this if the backend channel was deleted or invalid.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: SpaceColors.amber),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Re-initialize'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(spaceRepositoryProvider).reinitializeVault();
      ref.invalidate(syncStateProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vault channel re-initialized and pinned.'),
            backgroundColor: Color(0xFF0D3B2E),
          ),
        );
      }
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: SpaceColors.cyan, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
