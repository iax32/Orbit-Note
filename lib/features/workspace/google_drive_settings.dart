import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/google_cloud_controller.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../application/sync/sync_inventory.dart';
import '../../application/backup_bundle.dart';
import '../../application/sync/google_account.dart';
import '../../infrastructure/sync/google_drive_api.dart';
import '../../platform/import_backup.dart';
import 'package:file_selector/file_selector.dart';
import 'backup_import_dialog.dart';
import '../../app/collaboration_controller.dart';
import 'collaboration_settings.dart';
import 'drive_sync_settings.dart';

String googleStorageLabel(BigInt? bytes) {
  if (bytes == null) return 'Unavailable';
  var value = bytes.toDouble();
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB'];
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

class GoogleDriveSettings extends ConsumerStatefulWidget {
  const GoogleDriveSettings({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  ConsumerState<GoogleDriveSettings> createState() =>
      _GoogleDriveSettingsState();
}

class _GoogleDriveSettingsState extends ConsumerState<GoogleDriveSettings> {
  Future<void> _setupGoogle(GoogleCloudController cloud) async {
    final setup = cloud.auth is GoogleDesktopSetup
        ? cloud.auth as GoogleDesktopSetup
        : null;
    final import = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => OrbitDialog(
        title: const Text('Activate Google sign-in'),
        content: const SingleChildScrollView(
          child: Text(
            'This preview was built without Google app registration. Normal releases include it so you can simply sign in.\n\nFor this desktop preview, import the JSON downloaded from Google Cloud → Google Auth Platform → Clients → Desktop app. It is stored on this device, outside your Vault. Do not enter a Google password or account token.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final opened = await launchUrl(
                Uri.parse('https://console.cloud.google.com/auth/clients'),
                mode: LaunchMode.externalApplication,
              );
              if (!opened && dialogContext.mounted) {
                ScaffoldMessenger.maybeOf(dialogContext)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open Google Cloud. Try opening its console in your browser.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Open Google setup'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (setup?.canConfigureDesktop == true)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import desktop client…'),
            ),
        ],
      ),
    );
    if (import != true || !mounted || cloud.busy) return;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Google desktop client',
            extensions: ['json'],
          ),
        ],
      );
      if (file == null || !mounted || cloud.busy) return;
      if (await file.length() > 65536) {
        throw const GoogleCloudError(
          'configuration',
          'The selected file is too large for a desktop client configuration.',
        );
      }
      final text = await file.readAsString();
      if (!mounted || cloud.busy) return;
      if (await cloud.configureDesktop(text) && mounted) await cloud.connect();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read the desktop client JSON. No Vault files were changed.',
            ),
          ),
        );
      }
    }
  }

  SyncFootprint? _size;
  bool _allBackups = false;
  String _backupQuery = '';
  String? _sizeError, _sizeVault;
  Future<void> _measure() async {
    final repository = widget.workspace.repository, id = repository.workspaceId;
    try {
      final size = await repository.syncFootprint();
      if (mounted && widget.workspace.repository.workspaceId == id) {
        setState(() {
          _size = size;
          _sizeError = null;
          _sizeVault = id;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _sizeError = 'Vault size is temporarily unavailable.');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_measure());
  }

  @override
  void didUpdateWidget(GoogleDriveSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sizeVault != widget.workspace.repository.workspaceId) {
      _size = null;
      unawaited(_measure());
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(googleCloudProvider);
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        final account = cloud.account,
            quota = cloud.quota,
            colors = OrbitColors.of(context);
        final visibleBackups = cloud.backups
            .where(
              (b) =>
                  b.subject == account?.subject &&
                  (_allBackups ||
                      b.workspaceId ==
                          widget.workspace.repository.workspaceId) &&
                  b.name.toLowerCase().contains(
                    _backupQuery.toLowerCase().trim(),
                  ),
            )
            .toList();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SYNC',
                style: TextStyle(fontSize: 11, letterSpacing: 1.8),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.cloud_outlined),
                  const SizedBox(width: 12),
                  Text(
                    'Google Drive',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text('Local-first', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Your local Vault stays available offline. Uploads follow your explicit backup and automatic sync choices.',
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => showCollaborationSettings(
                  context,
                  ref.read(collaborationProvider),
                ),
                icon: const Icon(Icons.people_outline),
                label: const Text('Shared Vault · self-hosted'),
              ),
              if (account != null) ...[
                Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: account.avatar == null
                            ? const Icon(
                                Icons.account_circle_outlined,
                                size: 40,
                              )
                            : Image.network(
                                account.avatar!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) => const Icon(
                                  Icons.account_circle_outlined,
                                  size: 40,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name.isEmpty
                                ? 'Google account'
                                : account.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            account.email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.subtle),
                          ),
                          Text(
                            cloud.reconnectRequired
                                ? 'Sign-in required'
                                : 'Account connected',
                            style: TextStyle(
                              color: colors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (cloud.busy) ...[
                LinearProgressIndicator(value: cloud.transferProgress),
                if (cloud.transferProgress != null)
                  TextButton(
                    onPressed: cloud.cancelTransfer,
                    child: const Text('Cancel transfer'),
                  ),
                if (cloud.signingIn)
                  TextButton(
                    onPressed: cloud.cancel,
                    child: const Text('Cancel sign-in'),
                  ),
              ] else if (account == null || cloud.reconnectRequired) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF131314),
                    foregroundColor: const Color(0xFFE3E3E3),
                    side: const BorderSide(color: Color(0xFF8E918F)),
                    minimumSize: const Size(220, 42),
                  ),
                  onPressed: cloud.auth.configured
                      ? cloud.connect
                      : () => _setupGoogle(cloud),
                  icon: Image.asset(
                    'assets/google-g.png',
                    width: 20,
                    height: 20,
                  ),
                  label: const Text('Continue with Google'),
                ),
                if (!cloud.auth.configured)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Google sign-in is not configured in this build. Local editing is fully available.',
                    ),
                  ),
              ],
              if (account != null && !cloud.busy)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => cloud.refresh(force: true),
                      child: const Text('Refresh account'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await _confirm(
                          'Change Google account?',
                          'Sign out on this device before choosing another account. Your local Vault and cloud files stay intact. No Vault will be uploaded automatically.',
                        )) {
                          await cloud.signOut();
                          if (cloud.account == null && mounted) {
                            await cloud.connect();
                          }
                        }
                      },
                      child: const Text('Change account'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await _confirm(
                          'Sign out of Google?',
                          'Remove Google access from this device. Your local Vault and files in Drive stay intact.',
                        )) {
                          await cloud.signOut();
                        }
                      },
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              if (cloud.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    cloud.message!,
                    key: const ValueKey('google-status'),
                  ),
                ),
              if (account != null) ...[
                const Divider(height: 30),
                const Text(
                  'Google-reported storage',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (quota?.fraction != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: quota!.fraction,
                      minHeight: 6,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  quota == null
                      ? 'Storage information is unavailable.'
                      : quota.limit == null
                      ? '${googleStorageLabel(quota.usage)} used · No storage limit reported by Google'
                      : '${googleStorageLabel(quota.usage)} used of ${googleStorageLabel(quota.limit)} · ${googleStorageLabel(quota.remaining)} available',
                ),
                if (quota != null)
                  Text(
                    'Files in Drive: ${googleStorageLabel(quota.driveUsage)} · Drive Trash: ${googleStorageLabel(quota.trashUsage)}',
                    style: TextStyle(color: colors.subtle, fontSize: 12),
                  ),
                Text(
                  'Google Workspace accounts may report pooled organization storage.',
                  style: TextStyle(color: colors.subtle, fontSize: 12),
                ),
                if (quota?.nearlyFull == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Google storage is almost full. Large attachments may not upload.',
                    ),
                  ),
              ],
              const Divider(height: 30),
              Text(
                '${widget.workspace.repository.name} · This device',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                _size == null
                    ? (_sizeError ?? 'Measuring Vault…')
                    : '${_size!.files} authored files · ${googleStorageLabel(BigInt.from(_size!.bytes))}',
              ),
              TextButton(
                onPressed: _measure,
                child: const Text('Refresh Vault size'),
              ),
              DriveSyncSettings(workspace: widget.workspace),
              if (account != null && !cloud.reconnectRequired) ...[
                const Divider(height: 30),
                const Text(
                  'Orbit files in Google Drive',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: cloud.busy
                          ? null
                          : () async {
                              if (await _confirm(
                                'Prepare Orbit folder?',
                                'Create or reuse Orbit’s visible folder in Google Drive. This does not upload your Vault.',
                              )) {
                                await cloud.prepareRoot();
                              }
                            },
                      child: Text(
                        cloud.rootId == null
                            ? 'Prepare Orbit folder'
                            : 'Refresh Orbit folder',
                      ),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.https(
                          'drive.google.com',
                          cloud.rootId == null
                              ? '/drive/my-drive'
                              : '/drive/folders/${cloud.rootId}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Open Google Drive'),
                    ),
                  ],
                ),
                for (final vault in cloud.vaults)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(vault.name),
                    subtitle: Text(
                      vault.workspaceId ==
                              widget.workspace.repository.workspaceId
                          ? 'Same Vault identity'
                          : 'Separate cloud Vault',
                    ),
                    trailing: TextButton(
                      onPressed: cloud.busy
                          ? null
                          : () => cloud.inspect(
                              vault,
                              widget.workspace.repository.workspaceId,
                            ),
                      child: const Text('Verify'),
                    ),
                  ),
                if (cloud.vaults.isEmpty)
                  const Text('No Orbit cloud Vaults found for this account.'),
                const SizedBox(height: 8),
                const Text(
                  'Drive backups',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Save an independent Vault backup to your own Drive. Restoring creates a separate local folder. Backups are independent of automatic Vault sync.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Back up this Vault'),
                      onPressed: cloud.busy
                          ? null
                          : () => _backupCurrentVault(cloud),
                    ),
                    TextButton(
                      onPressed: cloud.busy ? null : cloud.refreshBackups,
                      child: const Text('Refresh backups'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('This Vault'),
                      selected: !_allBackups,
                      onSelected: (_) => setState(() => _allBackups = false),
                    ),
                    ChoiceChip(
                      label: const Text('All Vaults'),
                      selected: _allBackups,
                      onSelected: (_) => setState(() => _allBackups = true),
                    ),
                  ],
                ),
                TextField(
                  key: const ValueKey('drive-backup-search'),
                  decoration: const InputDecoration(
                    labelText: 'Find a backup',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _backupQuery = value),
                ),
                Text('${visibleBackups.length} backup(s)'),
                if (visibleBackups.isEmpty)
                  const Text(
                    'No matching backups. Try All Vaults or refresh the list.',
                  ),
                for (final backup in visibleBackups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(backup.name),
                    subtitle: Text(
                      '${googleStorageLabel(BigInt.from(backup.size))} · ${backup.workspaceId == widget.workspace.repository.workspaceId ? 'This Vault' : 'Another Vault'}',
                    ),
                    trailing: TextButton(
                      onPressed: cloud.busy
                          ? null
                          : () => _restoreDriveBackup(cloud, backup),
                      child: const Text('Restore'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _backupCurrentVault(GoogleCloudController cloud) async {
    final workspace = widget.workspace;
    final generation = workspace.workspaceGeneration;
    final id = workspace.repository.workspaceId;
    final subject = cloud.account?.subject;
    bool owns() =>
        identical(widget.workspace, workspace) &&
        workspace.workspaceGeneration == generation &&
        workspace.repository.workspaceId == id &&
        subject != null &&
        cloud.account?.subject == subject;
    if (!await _confirm(
          'Back up this Vault to Google Drive?',
          'Upload ${workspace.repository.name}’s documents and attachments to the connected Google account. This is an independent backup, not automatic sync.',
        ) ||
        !mounted) {
      return;
    }
    if (!owns()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vault or Google account changed. Start the backup again.',
          ),
        ),
      );
      return;
    }
    await cloud.uploadBackup(() async {
      if (!owns() || !await workspace.flushAll() || !owns()) {
        throw StateError(
          'Vault changed or could not be saved. Start the backup again.',
        );
      }
      final source = await workspace.repository.exportBundle();
      if (!owns()) throw StateError('Vault changed before backup finished.');
      return source;
    });
  }

  Future<void> _restoreDriveBackup(
    GoogleCloudController cloud,
    GoogleDriveBackup backup,
  ) async {
    final workspace = widget.workspace,
        generation = widget.workspace.workspaceGeneration;
    bool owns() =>
        mounted &&
        identical(widget.workspace, workspace) &&
        workspace.workspaceGeneration == generation;
    if (widget.workspace.repository.isBrowser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore into a new folder is available on desktop.'),
        ),
      );
      return;
    }
    final source = await cloud.downloadBackup(backup);
    if (source == null || !mounted || !owns()) return;
    try {
      final bundle = BackupBundle.parse(source);
      if (await showDialog<bool>(
                context: context,
                builder: (_) => BackupImportDialog(bundle: bundle),
              ) !=
              true ||
          !owns()) {
        return;
      }
      final parent = await getDirectoryPath(confirmButtonText: 'Restore here');
      if (parent == null || !owns() || !await workspace.flushAll() || !owns()) {
        return;
      }
      final path = await importBackup(bundle, parent);
      if (owns()) await workspace.initialize(path: path);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore failed. Existing Vaults are unchanged.'),
          ),
        );
      }
    }
  }
}
