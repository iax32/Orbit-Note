import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../../app/drive_sync_controller.dart';
import '../../app/drive_vault_scheduler.dart';
import '../../app/google_cloud_controller.dart';
import '../../app/workspace_controller.dart';
import '../../app/orbit_components.dart';
import '../../application/sync/sync_provider.dart';
import '../../infrastructure/sync/google_drive_api.dart';
import '../../platform/import_backup.dart';
import '../../platform/android_vault_folders.dart';
import 'recovery_dialog.dart';
import 'drive_vault_batch_dialog.dart';
import 'drive_schedule_settings.dart';

class DriveSyncSettings extends ConsumerStatefulWidget {
  const DriveSyncSettings({super.key, required this.workspace});
  final WorkspaceController workspace;
  @override
  ConsumerState<DriveSyncSettings> createState() => _DriveSyncSettingsState();
}

class _DriveSyncSettingsState extends ConsumerState<DriveSyncSettings> {
  int _limit = 20;
  Future<bool> _confirm(String title, String body) async =>
      await showOrbitDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
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
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _cleanup(DriveSyncController c) async {
    try {
      final preview = await c.maintainHistory();
      if (!mounted || preview == null) return;
      if (preview.files == 0) {
        _message(
          'No eligible old payloads. Recent versions and current content are protected.',
        );
        return;
      }
      if (!await _confirm(
        'Clean old Drive payloads?',
        'Remove ${preview.files} obsolete payloads (${(preview.bytes / (1024 * 1024)).toStringAsFixed(1)} MiB) from this cloud Vault. Keeps at least 20 versions per object, every object changed in the last 90 days, current versions, revision metadata and local history.\n\nExpired cloud payloads cannot be recovered through sync. This upgrades the cloud Vault: older Orbit builds will need updating before they can sync it. A durable cleanup receipt is saved first. Interrupted cleanup can be resumed with this button.',
      )) {
        return;
      }
      if (!mounted) return;
      await c.maintainHistory(reviewed: preview);
      _message(
        'Drive cleanup completed. Current content and local history were preserved.',
      );
    } on Object {
      _message(
        'Cleanup stopped safely. Reconnect Drive and review a fresh preview to retry.',
      );
    }
  }

  Future<void> _enable(
    DriveSyncController c, {
    GoogleRemoteVault? target,
  }) async {
    final workspace = widget.workspace,
        opening = widget.workspace.workspaceGeneration;
    final cloud = ref.read(googleCloudProvider),
        subject = ref.read(googleCloudProvider).account?.subject;
    if (!await _confirm(
          'Enable automatic Drive sync?',
          'Sync ${workspace.repository.name} with ${cloud.account?.email ?? 'your connected Google account'} while Orbit is open. This uploads authored notes, Canvas boards, other objects (including Archive and Trash), attachments and deletion records.\n\nOffline edits stay local and retry later. Conflicts require review; retained revisions use Google storage. Local history, caches, device settings and empty folders stay on this device. Pause keeps all local and Drive data.',
        ) ||
        !mounted) {
      return;
    }
    if (!identical(widget.workspace, workspace) ||
        workspace.workspaceGeneration != opening ||
        cloud.account?.subject != subject) {
      _message('Vault or account changed. Start sync setup again.');
      return;
    }
    await c.enable(target: target);
  }

  Future<void> _open(DriveSyncController c, GoogleRemoteVault vault) async {
    final workspace = widget.workspace,
        opening = widget.workspace.workspaceGeneration;
    final cloud = ref.read(googleCloudProvider);
    bool owns() =>
        mounted &&
        identical(widget.workspace, workspace) &&
        workspace.workspaceGeneration == opening &&
        cloud.account?.subject == vault.accountSubject;
    if (!await _confirm(
          'Open ${vault.name} from Drive?',
          'Create a separate local Vault with this cloud Vault’s identity, then download its objects and attachments through automatic sync. Existing local Vaults remain intact. ${usesAndroidVaultFolders ? 'Orbit saves it in local app storage automatically.' : 'Choose a parent folder next.'}',
        ) ||
        !owns()) {
      return;
    }
    try {
      final bundle = await c.prepareOpenVault(vault);
      if (!owns()) return;
      final parent = usesAndroidVaultFolders
          ? await localBackupImportParent()
          : await getDirectoryPath(confirmButtonText: 'Open synced Vault here');
      if (parent == null || !owns() || !await workspace.flushAll() || !owns()) {
        return;
      }
      final path = await importBackup(bundle, parent);
      if (!owns()) {
        _message(
          'The new folder was created; your active Vault changed, so it was not opened.',
        );
        return;
      }
      await workspace.initialize(path: path);
      if (!mounted ||
          workspace.repository.location != path ||
          workspace.repository.workspaceId != vault.workspaceId ||
          cloud.account?.subject != vault.accountSubject) {
        return;
      }
      final newOpening = workspace.workspaceGeneration;
      await c.restore();
      if (!mounted ||
          workspace.workspaceGeneration != newOpening ||
          workspace.repository.location != path ||
          cloud.account?.subject != vault.accountSubject) {
        return;
      }
      await c.enable(target: vault);
    } on Object {
      _message(
        'Could not open this cloud Vault. Existing local files are preserved. Check sync status and retry.',
      );
    }
  }

  Future<void> _review(
    DriveSyncController c,
    String key,
    RemoteSyncEntry remote,
  ) async {
    final workspace = widget.workspace,
        opening = widget.workspace.workspaceGeneration;
    final subject = ref.read(googleCloudProvider).account?.subject;
    try {
      final review = await c.review(key, remote.version);
      if (!mounted || workspace.workspaceGeneration != opening) return;
      final choice = await showOrbitDialog<String>(
        context: context,
        builder: (context) => OrbitDialog(
          title: const Text('Review Drive conflict'),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(remote.entry.path),
                  const SizedBox(height: 8),
                  const Text(
                    'Previous versions remain in Drive and local recovery. Edit the local document first if you want to combine wording, then review it again.',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      Widget source(String label, String body) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SelectableText(
                              body,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 620) {
                        return Column(
                          children: [
                            source('This device', review.local),
                            const SizedBox(height: 16),
                            source('Cloud version', review.remote),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: source('This device', review.local)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: source('Cloud version', review.remote),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: review.localHash == 'absent'
                  ? null
                  : () => Navigator.pop(context, 'local'),
              child: const Text('Keep this device'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'remote'),
              child: const Text('Use cloud version'),
            ),
          ],
        ),
      );
      if (choice == null ||
          !mounted ||
          !identical(widget.workspace, workspace) ||
          workspace.workspaceGeneration != opening ||
          ref.read(googleCloudProvider).account?.subject != subject) {
        return;
      }
      await c.resolve(
        key,
        remoteVersion: choice == 'remote' ? remote.version : null,
        expectedLocalHash: review.localHash,
      );
    } on Object {
      _message(
        'This review could not finish. Refresh sync and review the latest versions; local work is preserved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.workspace.hasWorkspace ||
        !widget.workspace.repository.supportsFileSync) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Automatic sync requires a writable native Vault folder. Manual backups remain available.',
        ),
      );
    }
    final c = ref.watch(driveSyncProvider);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final entries = c.conflicts.entries.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 30),
            Text(
              'Automatic Vault sync',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Saved edits queue automatically. While Orbit is open, this Vault checks Drive for changes every 5 seconds; network delays and conflicts can take longer. Offline work retries when connectivity returns.',
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(c.status, key: const ValueKey('drive-sync-status')),
            ),
            if (c.boundAccount != null && c.enabled)
              Text('Bound account: ${c.boundAccount}'),
            if (c.busy || c.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (c.busy && c.transferBytes > 0)
              Text(
                'Uploading file: ${(100 * c.transferredBytes / c.transferBytes).round()}% · ${c.transferredBytes} / ${c.transferBytes} bytes',
              ),
            if (c.error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(c.error),
              ),
            if (c.lastSynced != null)
              Text(
                'Last completed: ${c.lastSynced!.toLocal().toIso8601String().substring(0, 19).replaceAll('T', ' ')}',
              ),
            if (c.lastChecked != null)
              Text(
                'Last cloud check: ${c.lastChecked!.toLocal().toIso8601String().substring(11, 19)}',
              ),
            if (c.enabled && c.localChangesPending)
              const Text(
                'Newer local edits are queued for the next sync pass.',
              ),
            if (c.enabled && c.retryAt != null)
              Text(
                'Next retry: ${c.retryAt!.toLocal().toIso8601String().substring(11, 19)} · Sync now retries immediately.',
              ),
            if (c.result != null)
              Text(
                '${c.result!.pending} pending · ${c.result!.conflicts} need review',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!c.enabled)
                  FilledButton.icon(
                    onPressed:
                        c.busy ||
                            c.loading ||
                            !c.supported ||
                            ref.read(googleCloudProvider).account == null ||
                            ref.read(googleCloudProvider).reconnectRequired
                        ? null
                        : () => _enable(c),
                    icon: const Icon(Icons.sync),
                    label: Text(
                      c.boundAccount == null
                          ? 'Enable automatic sync'
                          : 'Resume automatic sync',
                    ),
                  ),
                if (c.enabled)
                  OutlinedButton.icon(
                    onPressed: c.busy || c.loading
                        ? null
                        : () => c.syncNow(force: true),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                if (c.enabled || c.pausePending)
                  TextButton(
                    onPressed: c.loading ? null : c.pause,
                    child: Text(c.pausePending ? 'Retry pause' : 'Pause sync'),
                  ),
                TextButton(
                  onPressed: c.busy || c.loading ? null : c.refreshVaults,
                  child: const Text('Browse synced Vaults'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      c.busy ||
                          c.loading ||
                          ref.read(googleCloudProvider).account == null ||
                          ref.read(googleCloudProvider).reconnectRequired
                      ? null
                      : () => showOrbitDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => DriveVaultBatchDialog(
                            workspace: widget.workspace,
                            sync: c,
                            cloud: ref.read(googleCloudProvider),
                            scheduleVaults: (vaults) => ref
                                .read(driveVaultSchedulerProvider)
                                .addVaults(vaults),
                          ),
                        ),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload multiple Vaults'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      c.busy ||
                          c.loading ||
                          ref.read(googleCloudProvider).account == null ||
                          ref.read(googleCloudProvider).reconnectRequired
                      ? null
                      : () => showOrbitDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => DriveVaultBatchDialog(
                            workspace: widget.workspace,
                            sync: c,
                            cloud: ref.read(googleCloudProvider),
                            download: true,
                            scheduleVaults: (vaults) => ref
                                .read(driveVaultSchedulerProvider)
                                .addVaults(vaults),
                          ),
                        ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download multiple Vaults'),
                ),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: () => showWorkspaceRecoveryDialog(
                      context: context,
                      repository: widget.workspace.repository,
                    ),
                    child: const Text('Recovery files'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const DriveScheduleSettings(),
            TextButton.icon(
              onPressed: c.busy || c.loading ? null : () => _cleanup(c),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Review old Drive payload cleanup'),
            ),
            const Text(
              'Retained versions use Drive storage. History, caches, device settings and empty folders stay local. Optional background checks require separate enablement above.',
              style: TextStyle(fontSize: 12),
            ),
            for (final entry in entries.take(_limit)) ...[
              const Divider(height: 24),
              Text(
                widget.workspace.find(entry.key)?.title ?? entry.key,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Builder(
                builder: (context) {
                  final conflict = entry.value as Map;
                  final versions =
                      [
                            if (conflict['remote'] is Map) conflict['remote'],
                            ...?conflict['alternatives'] as List?,
                          ]
                          .map(
                            (v) => RemoteSyncEntry.fromJson(
                              Map<String, dynamic>.from(v as Map),
                            ),
                          )
                          .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict['reason'] == 'missing-without-tombstone'
                            ? 'Source disappeared without an explicit deletion. Restore it from recovery before syncing.'
                            : 'Local and cloud edits need review. No timestamp winner was selected.',
                      ),
                      for (var i = 0; i < versions.length; i++)
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${versions[i].entry.deleted ? 'Deletion' : 'Cloud version'} ${i + 1} · ${versions[i].entry.hash.substring(0, 10)}',
                            ),
                            TextButton(
                              onPressed: c.busy || !c.enabled
                                  ? null
                                  : () => _review(c, entry.key, versions[i]),
                              child: const Text('Compare and resolve'),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ],
            if (entries.length > _limit)
              TextButton(
                onPressed: () => setState(() => _limit += 20),
                child: const Text('Show more conflicts'),
              ),
            for (final vault in c.availableVaults.where(
              (v) =>
                  v.accountSubject ==
                  ref.read(googleCloudProvider).account?.subject,
            )) ...[
              const Divider(height: 24),
              Text(vault.name, style: Theme.of(context).textTheme.titleSmall),
              Text(
                vault.workspaceId == widget.workspace.repository.workspaceId
                    ? 'Same Vault identity'
                    : 'Separate cloud Vault',
              ),
              TextButton(
                onPressed: c.busy || c.loading
                    ? null
                    : () =>
                          vault.workspaceId ==
                              widget.workspace.repository.workspaceId
                          ? _enable(c, target: vault)
                          : _open(c, vault),
                child: Text(
                  vault.workspaceId == widget.workspace.repository.workspaceId
                      ? 'Connect this Vault'
                      : 'Open in a new local folder',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
