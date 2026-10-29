import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../app/drive_sync_controller.dart';
import '../../app/google_cloud_controller.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../application/sync/drive_vault_batch.dart';
import '../../domain/vault_candidate.dart';
import '../../domain/workspace_failure.dart';
import '../../infrastructure/sync/google_drive_api.dart';
import '../../platform/import_backup.dart';
import '../../platform/android_vault_folders.dart';
import '../../platform/vault_discovery.dart';

class DriveVaultBatchDialog extends StatefulWidget {
  const DriveVaultBatchDialog({
    super.key,
    required this.workspace,
    required this.sync,
    required this.cloud,
    this.download = false,
    this.findVaults = discoverVaults,
    this.scheduleVaults,
  });
  final WorkspaceController workspace;
  final DriveSyncController sync;
  final GoogleCloudController cloud;
  final bool download;
  final Future<void> Function(List<VaultCandidate>)? scheduleVaults;
  final Future<VaultDiscovery> Function(List<String>, {bool children})
  findVaults;
  @override
  State<DriveVaultBatchDialog> createState() => _DriveVaultBatchDialogState();
}

class _DriveVaultBatchDialogState extends State<DriveVaultBatchDialog> {
  final _jobs = <VaultTransferJob>[], _selected = <VaultTransferJob>{};
  final _warnings = <String>[];
  DriveVaultBatch? _batch;
  bool _loading = true,
      _started = false,
      _working = false,
      _cancelRequested = false,
      _closing = false;
  bool _schedule = false;
  String _error = '', _parent = '';
  String? _subject;
  int _opening = -1;
  bool get _owns =>
      mounted &&
      !_closing &&
      widget.cloud.account?.subject == _subject &&
      widget.workspace.workspaceGeneration == _opening;
  @override
  void initState() {
    super.initState();
    _subject = widget.cloud.account?.subject;
    _opening = widget.workspace.workspaceGeneration;
    _load();
  }

  @override
  void dispose() {
    _closing = true;
    _batch?.cancel();
    super.dispose();
  }

  void _notify() {
    if (mounted && !_closing) setState(() {});
  }

  Future<void> _load() async {
    try {
      if (widget.download) {
        final vaults = await widget.cloud.drive.listSyncVaults();
        if (_owns) _jobs.addAll(vaults.map(VaultTransferJob.cloud));
      } else {
        final paths = await widget.workspace.repository.recentLocations();
        await _discover([widget.workspace.repository.location, ...paths]);
      }
    } on Object {
      _error =
          'Could not load Vaults. Check the account or add a local folder.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _discover(List<String> paths, {bool children = false}) async {
    final found = await widget.findVaults(paths, children: children);
    if (!_owns) return;
    for (final v in found.vaults) {
      if (!_jobs.any((j) => vaultPathsEqual(j.local!.path, v.path))) {
        _jobs.add(VaultTransferJob.local(v));
      }
    }
    _warnings.addAll(found.warnings);
  }

  Future<void> _add({bool children = false}) async {
    final path = await getDirectoryPath(
      confirmButtonText: children ? 'Find Vaults here' : 'Add Vault',
    );
    if (path == null || !_owns) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await _discover([path], children: children);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _run({bool retry = false}) async {
    if (_working || !_owns || _selected.isEmpty) return;
    final jobs = _jobs
        .where(_selected.contains)
        .where((j) => !retry || j.state != VaultTransferState.complete)
        .toList();
    if (jobs.isEmpty) return;
    if (jobs.map((j) => j.id).toSet().length != jobs.length) {
      setState(
        () => _error =
            'Some folders are copies of the same Vault. Select only one copy of each identity.',
      );
      return;
    }
    if (widget.download && _parent.isEmpty) {
      final parent = usesAndroidVaultFolders
          ? await localBackupImportParent()
          : await getDirectoryPath(
              confirmButtonText: 'Download selected Vaults here',
            );
      if (parent == null || !_owns) return;
      _parent = parent;
    }
    setState(() {
      _working = true;
      _started = true;
      _error = '';
      _cancelRequested = false;
    });
    try {
      await widget.sync.runVaultBatch((current) async {
        bool owns() => _owns && current() && !_cancelRequested;
        final batch = _batch = DriveVaultBatch(
          api: widget.cloud.drive,
          isCurrent: owns,
          onChanged: _notify,
          onAccountError: widget.sync.reportBatchAccountError,
          open: (vault) async {
            final active = widget.workspace.repository;
            if (vaultPathsEqual(active.location, vault.path)) {
              if (active.workspaceId != vault.id ||
                  !await widget.workspace.flushAll() ||
                  !owns()) {
                throw const WorkspaceConflict(
                  'Save local drafts and select the Vault again.',
                );
              }
              return VaultRepositoryLease(
                active,
                () async {},
                createReplica: (guard) =>
                    widget.workspace.createSyncReplica(isCurrent: guard),
              );
            }
            final repo = await openExistingVault(vault);
            return VaultRepositoryLease(repo, repo.close);
          },
          createDownload: (vault, bundle) async {
            if (!owns()) throw const WorkspaceConflict('Transfer cancelled.');
            final path = await importBackup(bundle, _parent);
            // Keep this path even if cancellation arrives during publication.
            // Registry failure cannot cause a retry to create a second folder.
            final candidate = VaultCandidate(
              path: path,
              id: vault.workspaceId,
              name: vault.name,
            );
            try {
              await rememberDownloadedVault(path);
            } on Object {
              _warnings.add(
                'Downloaded folder was created at $path; add it to the Vault list manually.',
              );
            }
            return candidate;
          },
        );
        await batch.run(jobs);
        if (owns() && _schedule && widget.scheduleVaults != null) {
          final completed = jobs
              .where((j) => j.state == VaultTransferState.complete)
              .map((j) => j.local!)
              .toList();
          if (completed.isNotEmpty) {
            try {
              await widget.scheduleVaults!(completed);
            } catch (_) {
              throw const WorkspaceFailure(
                'Vaults transferred, but the scheduled selection could not be saved. Check scheduled Vault settings and retry.',
              );
            }
          }
        }
      });
    } on Object catch (e) {
      _error = e is WorkspaceFailure
          ? e.message
          : 'The batch could not start. Save local work and reconnect Google Drive.';
    } finally {
      _working = false;
      _notify();
    }
  }

  String _label(VaultTransferState state) => switch (state) {
    VaultTransferState.queued => 'Waiting',
    VaultTransferState.transferring => 'Transferring',
    VaultTransferState.complete => 'Up to date',
    VaultTransferState.review => 'Needs review',
    VaultTransferState.failed => 'Failed',
    VaultTransferState.cancelled => 'Cancelled',
    VaultTransferState.paused => 'Paused',
  };
  @override
  Widget build(BuildContext context) {
    final complete = _selected
        .where((j) => j.state == VaultTransferState.complete)
        .length;
    return PopScope(
      canPop: !_working,
      child: OrbitDialog(
        maxWidth: 800,
        title: Text(
          widget.download
              ? 'Download Vaults from Drive'
              : 'Sync multiple Vaults',
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google account: ${widget.cloud.account?.email ?? 'Disconnected'}',
                ),
                const SizedBox(height: 8),
                Text(
                  widget.download
                      ? 'Select cloud Vaults. ${usesAndroidVaultFolders ? 'Orbit saves them in local app storage automatically.' : 'Choose one parent folder.'} Each download creates its own new local folder; your current Vault stays open.'
                      : 'Select Vaults to upload and connect. Find Vaults in a folder checks that folder and its immediate children, such as Vaults saved on your Desktop.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Includes notes, boards, attachments, Archive/Trash and deletion records. History, caches, device settings and empty folders stay local. Existing cloud edits may download; conflicts are retained for review. Automatic sync runs while Orbit is open. Enable the optional schedule below or run this batch again to check inactive Vaults.',
                ),
                const SizedBox(height: 12),
                if (widget.scheduleVaults != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Keep these Vaults updated while Orbit is open',
                    ),
                    subtitle: const Text(
                      'Successful Vaults are checked on a schedule, including when another Vault is open. Locked or paused Vaults are skipped.',
                    ),
                    value: _schedule,
                    onChanged: _started
                        ? null
                        : (value) => setState(() => _schedule = value == true),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!widget.download) ...[
                      OutlinedButton.icon(
                        onPressed: _loading || _started ? null : () => _add(),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('Add Vault folder'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loading || _started
                            ? null
                            : () => _add(children: true),
                        icon: const Icon(Icons.folder_copy_outlined),
                        label: const Text('Find Vaults in a folder'),
                      ),
                    ],
                    TextButton(
                      onPressed: _loading || _started
                          ? null
                          : () => setState(() {
                              _selected.clear();
                              // Same-identity copies require an explicit individual choice.
                              _selected.addAll(
                                _jobs.where(
                                  (j) =>
                                      _jobs
                                          .where((other) => other.id == j.id)
                                          .length ==
                                      1,
                                ),
                              );
                            }),
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: _loading || _started
                          ? null
                          : () => setState(_selected.clear),
                      child: const Text('Clear selection'),
                    ),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
                if (!_loading && _jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      widget.download
                          ? 'No synced Vaults found in this account.'
                          : 'No Vaults found. Add a Vault folder or choose a folder to search.',
                    ),
                  ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error),
                  ),
                if (!_owns)
                  const Text(
                    'The account or active Vault changed. Close this picker and open it again before transferring.',
                  ),
                for (final warning in _warnings.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(warning),
                  ),
                if (_warnings.length > 8)
                  Text(
                    '${_warnings.length - 8} more folders could not be inspected.',
                  ),
                for (final job in _jobs) ...[
                  const Divider(height: 20),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _selected.contains(job),
                    onChanged: _started || _loading
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _selected.add(job);
                            } else {
                              _selected.remove(job);
                            }
                          }),
                    title: Text(job.name),
                    subtitle: Text(
                      job.local?.path ?? 'Cloud Vault · ${job.id}',
                    ),
                  ),
                  if (_jobs.where((other) => other.id == job.id).length > 1)
                    const Text(
                      'Another folder has the same Vault identity. Select only one copy.',
                    ),
                  if (_started && _selected.contains(job))
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_label(job.state)} · ${job.message}'),
                          if (job.state == VaultTransferState.transferring)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(
                                value: job.progress,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  _cancelRequested && _working
                      ? 'Cancelling transfers…'
                      : _started
                      ? '$complete of ${_selected.length} Vaults up to date'
                      : '${_selected.length} ${_selected.length == 1 ? 'Vault' : 'Vaults'} selected',
                ),
                if (_parent.isNotEmpty) Text('Download folder: $_parent'),
              ],
            ),
          ),
        ),
        actions: [
          if (_working)
            TextButton(
              onPressed: () {
                _cancelRequested = true;
                _batch?.cancel();
                _notify();
              },
              child: const Text('Cancel transfers'),
            ),
          if (!_working)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_started ? 'Done' : 'Cancel'),
            ),
          if (!_started)
            FilledButton.icon(
              onPressed: _loading || _working || _selected.isEmpty || !_owns
                  ? null
                  : () => _run(),
              icon: Icon(
                widget.download
                    ? Icons.download_outlined
                    : Icons.cloud_upload_outlined,
              ),
              label: Text(
                widget.download
                    ? 'Download selected Vaults'
                    : 'Upload and sync selected Vaults',
              ),
            ),
          if (_started && !_working && complete < _selected.length)
            FilledButton(
              onPressed: !_owns ? null : () => _run(retry: true),
              child: const Text('Retry unfinished Vaults'),
            ),
        ],
      ),
    );
  }
}
