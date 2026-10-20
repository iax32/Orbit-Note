import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../domain/vault_candidate.dart';
import '../../domain/workspace_failure.dart';
import '../../infrastructure/sync/google_drive_api.dart';
import '../backup_bundle.dart';
import '../workspace_repository.dart';
import 'google_account.dart';
import 'drive_vault_binding.dart';
import 'sync_engine.dart';
import 'sync_provider.dart';

enum VaultTransferState {
  queued,
  transferring,
  complete,
  review,
  failed,
  cancelled,
  paused,
}

class VaultTransferJob {
  VaultTransferJob.local(VaultCandidate vault) : local = vault, remote = null;
  VaultTransferJob.cloud(GoogleRemoteVault vault) : remote = vault;
  VaultCandidate? local;
  final GoogleRemoteVault? remote;
  String get id => local?.id ?? remote!.workspaceId;
  String get name => local?.name ?? remote!.name;
  VaultTransferState state = VaultTransferState.queued;
  String message = 'Waiting';
  double? progress;
}

class VaultRepositoryLease {
  const VaultRepositoryLease(
    this.repository,
    this.release, {
    this.createReplica,
  });
  final WorkspaceRepository repository;
  final Future<void> Function() release;
  final WorkspaceSyncReplica Function(bool Function())? createReplica;
}

/// One explicit foreground batch. Each Vault keeps its own existing durable
/// engine/outbox and upload journal. Cancellation never rolls back valid saves.
class DriveVaultBatch {
  DriveVaultBatch({
    required this.api,
    required this.open,
    required this.isCurrent,
    required this.onChanged,
    this.createDownload,
    this.onAccountError,
    this.requireEnabledBinding = false,
  });
  final GoogleDriveApi api;
  final Future<VaultRepositoryLease> Function(VaultCandidate) open;
  final Future<VaultCandidate> Function(GoogleRemoteVault, BackupBundle)?
  createDownload;
  final bool Function() isCurrent;
  final void Function() onChanged;
  final void Function(GoogleCloudError)? onAccountError;
  final bool requireEnabledBinding;
  bool running = false, _cancelled = false;
  void cancel() {
    _cancelled = true;
    onChanged();
  }

  void _check(String subject) {
    if (_cancelled || !isCurrent() || api.auth.account?.subject != subject) {
      throw const WorkspaceConflict(
        'Transfer cancelled or account/Vault changed. Completed transfers remain safe.',
      );
    }
  }

  Future<void> run(List<VaultTransferJob> jobs) async {
    if (running) {
      throw const WorkspaceConflict('A Vault batch is already running.');
    }
    if (jobs.isEmpty ||
        jobs.length > 256 ||
        jobs.map((j) => j.id).toSet().length != jobs.length) {
      throw const WorkspaceConflict(
        'Choose up to 256 Vaults, with only one local/cloud copy of each Vault identity.',
      );
    }
    final subject = api.auth.account?.subject;
    if (subject == null) {
      throw const WorkspaceConflict('Connect Google Drive first.');
    }
    running = true;
    _cancelled = false;
    try {
      for (final job in jobs) {
        if (job.state == VaultTransferState.complete) continue;
        if (_cancelled ||
            !isCurrent() ||
            api.auth.account?.subject != subject) {
          job.state = VaultTransferState.cancelled;
          job.message = 'Not started · retry when ready';
          onChanged();
          continue;
        }
        VaultRepositoryLease? lease;
        job.state = VaultTransferState.transferring;
        job.message = 'Checking Vault…';
        job.progress = null;
        onChanged();
        try {
          if (job.local == null) {
            if (createDownload == null) {
              throw const WorkspaceFailure(
                'Choose a download folder before starting.',
              );
            }
            final bundle = await prepareDriveVaultBundle(
              api,
              job.remote!,
              () =>
                  !_cancelled &&
                  isCurrent() &&
                  api.auth.account?.subject == subject,
            );
            _check(subject);
            job.local = await createDownload!(job.remote!, bundle);
          }
          _check(subject);
          lease = await open(job.local!);
          _check(subject);
          final repo = lease.repository;
          if (repo.workspaceId != job.id || repo.readOnly) {
            throw const WorkspaceConflict(
              'Selected Vault changed or is read-only.',
            );
          }
          bool current() =>
              !_cancelled &&
              isCurrent() &&
              api.auth.account?.subject == subject;
          final replica =
              lease.createReplica?.call(current) ??
              WorkspaceSyncReplica(repo, canApply: current, isCurrent: current);
          if (requireEnabledBinding) {
            final saved = await replica.createDriveSettingsStore().load();
            validateDriveBinding(saved, replica.workspaceId);
            if (saved == null || saved['enabled'] != true) {
              job.state = VaultTransferState.paused;
              job.message = 'Automatic sync is off for this Vault';
              continue;
            }
          }
          final vault = await connectDriveVault(
            replica: replica,
            api: api,
            name: repo.name,
            target: job.remote,
            isCurrent: current,
            enableAutomaticSync: false,
          );
          _check(subject);
          job.message = 'Syncing notes, boards and attachments…';
          onChanged();
          final result = await SyncEngine(
            replica: replica,
            stateStore: replica.createStateStore(),
            provider: GoogleDriveSyncProvider(
              api: api,
              vault: vault,
              journal: replica.createDriveJournalStore(),
              stage: replica.stageTransfer,
              isCurrent: current,
              onProgress: (done, total) {
                job.progress = total == 0 ? null : done / total;
                onChanged();
              },
            ),
          ).sync();
          _check(subject);
          final settingsStore = replica.createDriveSettingsStore();
          final settings = await settingsStore.load();
          validateDriveBinding(settings, replica.workspaceId);
          if (settings == null ||
              settings['subject'] != subject ||
              settings['folder'] != vault.folderId) {
            throw const WorkspaceConflict(
              'Drive binding changed during transfer.',
            );
          }
          _check(subject);
          await settingsStore.save({...settings, 'enabled': true});
          _check(subject);
          job.state = result.upToDate
              ? VaultTransferState.complete
              : VaultTransferState.review;
          job.message = result.upToDate
              ? 'Up to date · automatic sync when opened'
              : '${result.conflicts} conflict(s), ${result.pending} pending, ${result.missing} missing · open Vault to review';
        } on Object catch (error) {
          final cancelled =
              _cancelled ||
              !isCurrent() ||
              api.auth.account?.subject != subject;
          job.state = cancelled
              ? VaultTransferState.cancelled
              : VaultTransferState.failed;
          job.message = cancelled
              ? 'Stopped safely · retry to resume'
              : error is GoogleCloudError
              ? error.message
              : error is WorkspaceFailure
              ? error.message
              : 'Could not transfer this Vault. Local files and recovery history were preserved.';
          if (error is GoogleCloudError &&
              {
                'reauth',
                'permission',
                'configuration',
                'quota',
              }.contains(error.code)) {
            _cancelled = true;
            onAccountError?.call(error);
          }
        } finally {
          try {
            await lease?.release();
          } on Object {
            job.state = VaultTransferState.failed;
            job.message =
                'Transfer stopped; Vault cleanup needs attention. Local files are preserved.';
          }
          job.progress = null;
          onChanged();
        }
      }
    } finally {
      running = false;
      onChanged();
    }
  }
}

Future<BackupBundle> prepareDriveVaultBundle(
  GoogleDriveApi api,
  GoogleRemoteVault vault,
  bool Function() isCurrent,
) async {
  await api.verifySyncVault(vault);
  final provider = GoogleDriveSyncProvider(
    api: api,
    vault: vault,
    journal: _DiscoveryState(),
    stage: (_, _) => throw StateError('Discovery cannot upload'),
    isCurrent: isCurrent,
  );
  final delta = await provider.fetchChanges(null);
  final key = 'vault:${vault.workspaceId}';
  final manifests = delta.entries.where((e) => e.entry.key == key).toList();
  if (manifests.length != 1 || delta.forks.containsKey(key)) {
    throw const WorkspaceConflict(
      'Resolve the cloud Vault manifest conflict on an existing device first.',
    );
  }
  final output = BytesBuilder(copy: false);
  await for (final chunk in provider.download(manifests.single)) {
    if (output.length + chunk.length > 1024 * 1024) {
      throw const WorkspaceFailure(
        'Cloud Vault manifest exceeds the safe opening limit.',
      );
    }
    output.add(chunk);
  }
  final bytes = output.takeBytes();
  if (!isCurrent() ||
      sha256.convert(bytes).toString() != manifests.single.entry.hash) {
    throw const WorkspaceConflict('Cloud manifest verification failed.');
  }
  return BackupBundle.parse(
    jsonEncode({
      'format': 'orbit-note-backup',
      'version': 1,
      'encoding': 'base64',
      'workspaceId': vault.workspaceId,
      'files': {'workspace.json': base64Encode(bytes)},
    }),
  );
}

class _DiscoveryState implements SyncStateStore {
  Map<String, dynamic>? _value;
  @override
  Future<Map<String, dynamic>?> load() async => _value;
  @override
  Future<void> save(Map<String, dynamic> state) async => _value = state;
}
