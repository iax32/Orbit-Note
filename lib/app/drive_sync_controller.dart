import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/sync/sync_engine.dart';
import '../application/sync/drive_vault_binding.dart';
import '../application/sync/drive_vault_batch.dart';
import '../application/sync/sync_provider.dart';
import '../application/sync/sync_policy.dart';
import '../application/backup_bundle.dart';
import '../domain/sync_entry.dart';
import '../application/workspace_repository.dart';
import '../application/sync/google_account.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/sync/google_drive_api.dart';
import 'workspace_controller.dart';
import 'google_cloud_controller.dart';
import 'collaboration_controller.dart';

/// Local-only startup reads opt-in before constructing any account adapter.
final driveSyncStartupProvider = Provider<void>((ref) {
  var alive = true, checked = -1;
  Future<void> inspect() async {
    final workspace = ref.read(workspaceProvider.notifier);
    if (!workspace.hasWorkspace ||
        workspace.loading ||
        !workspace.repository.supportsFileSync ||
        checked == workspace.workspaceGeneration) {
      return;
    }
    checked = workspace.workspaceGeneration;
    final opening = checked;
    try {
      final settings = await workspace
          .createSyncReplica()
          .createDriveSettingsStore()
          .load();
      if (alive &&
          workspace.hasWorkspace &&
          workspace.workspaceGeneration == opening &&
          settings?['enabled'] == true) {
        ref.read(driveSyncProvider);
      }
    } on Object {
      /* Settings provides an explicit recovery/status path. */
    }
  }

  ref.listen(workspaceProvider, (_, _) => unawaited(inspect()));
  ref.onDispose(() => alive = false);
  scheduleMicrotask(() {
    if (alive) unawaited(inspect());
  });
});

final driveSyncProvider = Provider<DriveSyncController>((ref) {
  final workspace = ref.read(workspaceProvider.notifier);
  final cloud = ref.read(googleCloudProvider);
  final shared = ref.read(collaborationProvider);
  final controller = DriveSyncController(
    workspace,
    cloud,
    sharedActive: () => shared.connected || shared.connecting,
  );
  ref.listen(workspaceProvider, (_, _) => controller.changed());
  cloud.addListener(controller.changed);
  shared.addListener(controller.changed);
  ref.onDispose(() {
    cloud.removeListener(controller.changed);
    shared.removeListener(controller.changed);
    controller.dispose();
  });
  return controller;
});

/// One active, opt-in personal binding. It is operational state, never portable
/// knowledge or account credentials. Every adapter is tied to one Vault opening.
class DriveSyncController extends ChangeNotifier {
  DriveSyncController(
    this.workspace,
    this.cloud, {
    required this.sharedActive,
    this.automatic = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (automatic) {
      _poll = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(syncNow()),
      );
      scheduleMicrotask(changed);
    }
  }
  final WorkspaceController workspace;
  final GoogleCloudController cloud;
  final bool Function() sharedActive;
  final bool automatic;
  final DateTime Function() _now;
  bool enabled = false, busy = false, loading = false, _disposed = false;
  String status = 'Automatic sync is off', error = '';
  DateTime? lastSynced, retryAt;
  SyncResult? result;
  List<GoogleRemoteVault> availableVaults = [];
  Map<String, dynamic> conflicts = {};
  Map<String, dynamic>? _settings;
  SyncStateStore? _settingsStore, _state;
  WorkspaceSyncReplica? _replica;
  SyncEngine? _engine;
  Future<void>? _restoring;
  int _opening = -1, _nonce = 0, _failures = 0;
  Timer? _poll, _debounce;
  Object? _objects;
  int _attachmentRevision = -1;
  String? _activeSubject;
  bool _activeShared = false;
  bool _blocked = false, _wasReconnectRequired = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get supported =>
      workspace.hasWorkspace && workspace.repository.supportsFileSync;
  bool get _sameOpening =>
      !_disposed &&
      workspace.hasWorkspace &&
      !workspace.loading &&
      workspace.workspaceGeneration == _opening;
  bool get _ready =>
      _sameOpening &&
      enabled &&
      !sharedActive() &&
      cloud.account?.subject == _settings?['subject'] &&
      cloud.account != null;
  String? get boundAccount => _settings?['email'] as String?;
  bool get pausePending => !enabled && _settings?['enabled'] == true;

  void changed() {
    if (_disposed) return;
    if (!_sameOpening) {
      _nonce++;
      _engine = null;
      _replica = null;
      _state = null;
      _debounce?.cancel();
      if (!loading && workspace.hasWorkspace && !workspace.loading) {
        unawaited(restore());
      }
      return;
    }
    final subject = cloud.account?.subject, shared = sharedActive();
    if (_wasReconnectRequired &&
        !cloud.reconnectRequired &&
        subject == _settings?['subject']) {
      _blocked = false;
      retryAt = null;
      if (automatic && _ready) _schedule();
    }
    _wasReconnectRequired = cloud.reconnectRequired;
    if (_activeSubject != subject || _activeShared != shared) {
      if (_activeSubject != subject) {
        availableVaults = [];
        conflicts = {};
        result = null;
      }
      _nonce++;
      _engine = null;
      _replica = null;
      _state = null;
      _activeSubject = subject;
      _blocked = false;
      _activeShared = shared;
      if (enabled) {
        status = shared
            ? 'Personal sync paused while Shared Vault is connected'
            : subject != _settings?['subject']
            ? 'Reconnect ${boundAccount ?? 'the bound Google account'} to resume'
            : 'Ready to sync';
      }
      _notify();
      if (automatic && _ready) _schedule();
    }
    if (!identical(_objects, workspace.objects) ||
        _attachmentRevision != workspace.attachmentRevision) {
      _objects = workspace.objects;
      _attachmentRevision = workspace.attachmentRevision;
      if (automatic && _ready && !busy) _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(syncNow()));
  }

  Future<void> restore() async {
    final pending = _restoring;
    if (pending != null) {
      await pending;
      if (!_disposed &&
          workspace.hasWorkspace &&
          workspace.workspaceGeneration != _opening) {
        await restore();
      }
      return;
    }
    final operation = _restoreOpening();
    _restoring = operation;
    try {
      await operation;
    } finally {
      _restoring = null;
    }
    if (!_disposed &&
        workspace.hasWorkspace &&
        workspace.workspaceGeneration != _opening) {
      await restore();
    }
  }

  Future<void> _restoreOpening() async {
    if (_disposed || loading || !workspace.hasWorkspace || workspace.loading) {
      return;
    }
    final opening = workspace.workspaceGeneration;
    loading = true;
    _nonce++;
    _opening = opening;
    _settings = null;
    _settingsStore = null;
    enabled = false;
    conflicts = {};
    result = null;
    error = '';
    lastSynced = retryAt = null;
    _engine = null;
    _state = null;
    _replica = null;
    _notify();
    try {
      if (!supported) {
        status = 'Automatic sync requires a native Vault folder';
        return;
      }
      final store = workspace.createSyncReplica().createDriveSettingsStore();
      final settings = await store.load();
      if (!_sameOpening) return;
      validateDriveBinding(settings, workspace.repository.workspaceId);
      _settingsStore = store;
      _settings = settings;
      enabled = settings?['enabled'] == true;
      _activeSubject = cloud.account?.subject;
      _activeShared = sharedActive();
      status = !enabled
          ? 'Automatic sync is off'
          : sharedActive()
          ? 'Personal sync paused while Shared Vault is connected'
          : cloud.account?.subject != settings?['subject']
          ? 'Reconnect ${boundAccount ?? 'the bound Google account'} to resume'
          : 'Ready to sync';
      _objects = workspace.objects;
      _attachmentRevision = workspace.attachmentRevision;
      if (automatic && _ready) _schedule();
    } on Object catch (e) {
      if (_sameOpening) {
        error = _message(e);
        status = 'Sync setup needs attention';
      }
    } finally {
      loading = false;
      _notify();
      if (!_disposed &&
          workspace.hasWorkspace &&
          workspace.workspaceGeneration != _opening) {
        changed();
      }
    }
  }

  Future<void> refreshVaults() async {
    if (busy || _disposed || cloud.account == null) return;
    final subject = cloud.account!.subject;
    busy = true;
    error = '';
    _notify();
    try {
      final next = await cloud.drive.listSyncVaults();
      if (!_disposed && cloud.account?.subject == subject) {
        availableVaults = next;
      }
    } on Object catch (e) {
      error = _message(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Prevent foreground polling from racing an explicit multi-Vault transfer.
  /// The callback's guard also invalidates late stages/checkpoints on a switch.
  Future<void> runVaultBatch(
    Future<void> Function(bool Function()) action,
  ) async {
    if (busy ||
        loading ||
        _disposed ||
        sharedActive() ||
        cloud.account == null ||
        cloud.busy ||
        cloud.reconnectRequired) {
      throw const WorkspaceConflict(
        'Wait for current sync and connect Google Drive before starting a batch.',
      );
    }
    final opening = workspace.workspaceGeneration,
        subject = cloud.account!.subject;
    final nonce = ++_nonce;
    bool current() =>
        !_disposed &&
        nonce == _nonce &&
        workspace.workspaceGeneration == opening &&
        cloud.account?.subject == subject &&
        !sharedActive();
    busy = true;
    _debounce?.cancel();
    _engine = null;
    _state = null;
    _replica = null;
    status = 'Bulk Vault transfer running';
    _notify();
    try {
      if (!await workspace.flushAll() || !current()) {
        throw const WorkspaceConflict(
          'Save or recover local drafts before transferring Vaults.',
        );
      }
      await action(current);
      if (current()) {
        workspace.mergeRepositoryObjects();
        workspace.notify();
      }
    } finally {
      busy = false;
      _notify();
      if (!_disposed && workspace.workspaceGeneration == opening) {
        await restore();
      }
    }
  }

  void reportBatchAccountError(GoogleCloudError error) {
    _blocked = true;
    cloud.reportAccountError(error);
  }

  Future<BackupBundle> prepareOpenVault(GoogleRemoteVault vault) async {
    if (busy || _disposed || cloud.account?.subject != vault.accountSubject) {
      throw const WorkspaceConflict(
        'Wait for sync and choose a Vault in the connected account.',
      );
    }
    final opening = workspace.workspaceGeneration;
    bool current() =>
        !_disposed &&
        workspace.workspaceGeneration == opening &&
        cloud.account?.subject == vault.accountSubject;
    busy = true;
    _notify();
    try {
      return await prepareDriveVaultBundle(cloud.drive, vault, current);
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> enable({GoogleRemoteVault? target}) async {
    if (busy || loading || _disposed) return;
    if (_opening != workspace.workspaceGeneration || _settingsStore == null) {
      await restore();
    }
    if (_settingsStore == null) return;
    if (!supported ||
        cloud.account == null ||
        cloud.reconnectRequired ||
        sharedActive()) {
      error =
          'Open a writable native Vault and connect Google Drive. Disconnect Shared Vault before enabling personal sync.';
      _notify();
      return;
    }
    final opening = _opening, subject = cloud.account!.subject;
    bool owns() =>
        _sameOpening &&
        opening == _opening &&
        cloud.account?.subject == subject &&
        !sharedActive();
    busy = true;
    error = '';
    status = 'Checking Vault and cloud folder…';
    _notify();
    try {
      if (!await workspace.flushAll() || !owns()) {
        throw const WorkspaceConflict(
          'Save local work before connecting sync.',
        );
      }
      await connectDriveVault(
        replica: workspace.createSyncReplica(isCurrent: owns),
        api: cloud.drive,
        name: workspace.repository.name,
        isCurrent: owns,
        target: target,
      );
      if (!owns()) return;
      _settings = await _settingsStore!.load();
      if (!owns()) return;
      enabled = true;
      _blocked = false;
      _nonce++;
      _engine = null;
      _state = null;
      _activeSubject = subject;
      _activeShared = false;
      retryAt = null;
      status = 'Automatic sync enabled';
    } on Object catch (e) {
      if (owns()) {
        error = _message(e);
        status = 'Sync setup needs attention';
      }
    } finally {
      busy = false;
      _notify();
    }
    if (_ready) await syncNow(force: true);
  }

  Future<void> pause() async {
    if (_disposed || (!enabled && _settings?['enabled'] != true)) return;
    enabled = false;
    error = '';
    _nonce++;
    _engine = null;
    _state = null;
    _debounce?.cancel();
    status = 'Automatic sync paused · local and Drive files retained';
    _notify();
    try {
      final settings = Map<String, dynamic>.from(_settings!)
        ..['enabled'] = false;
      await _settingsStore!.save(settings);
      _settings = settings;
    } on Object catch (e) {
      error =
          '${_message(e)} Paused for this session; retry Pause to persist it before restarting.';
      // Retain an explicit path to retry a failed pause checkpoint.
      _notify();
    }
  }

  void _attach() {
    if (_engine != null) return;
    final nonce = _nonce, opening = _opening;
    bool current() => _ready && nonce == _nonce && opening == _opening;
    final replica = workspace.createSyncReplica(isCurrent: current);
    _replica = replica;
    _state = replica.createStateStore();
    final folder = GoogleRemoteVault(
      folderId: _settings!['folder'] as String,
      workspaceId: replica.workspaceId,
      name: workspace.repository.name,
      accountSubject: _settings!['subject'] as String,
    );
    _engine = SyncEngine(
      replica: replica,
      stateStore: _state!,
      provider: GoogleDriveSyncProvider(
        api: cloud.drive,
        vault: folder,
        journal: replica.createDriveJournalStore(),
        stage: replica.stageTransfer,
        isCurrent: current,
      ),
    );
  }

  Future<void> syncNow({bool force = false}) async {
    if (!_ready || busy || loading || cloud.busy) return;
    if (_blocked && !force) return;
    if (!force && retryAt != null && _now().isBefore(retryAt!)) return;
    final nonce = _nonce;
    if (force) _blocked = false;
    busy = true;
    error = '';
    status = 'Syncing · local editing remains available';
    _notify();
    try {
      if (!await workspace.flushAll() || !_ready || nonce != _nonce) {
        throw const WorkspaceConflict(
          'Save or recover local drafts before syncing.',
        );
      }
      _attach();
      final next = await _engine!.sync();
      if (!_ready || nonce != _nonce) return;
      final state = await _state!.load();
      if (!_ready || nonce != _nonce) return;
      conflicts = Map<String, dynamic>.from(state?['conflicts'] as Map? ?? {});
      result = next;
      cloud.confirmAccountAccess();
      _failures = 0;
      retryAt = null;
      if (next.upToDate) lastSynced = _now();
      status = next.conflicts > 0 || next.missing > 0
          ? '${next.conflicts} item(s) need review · local copies preserved'
          : next.pending > 0
          ? '${next.pending} change(s) pending'
          : 'Up to date with Google Drive';
    } on Object catch (e) {
      if (_ready && nonce == _nonce) {
        error = _message(e);
        _failures = (_failures + 1).clamp(1, 8);
        retryAt = _now().add(Duration(seconds: (1 << _failures).clamp(2, 120)));
        status = 'Saved locally · Drive sync needs attention';
        if (e is GoogleCloudError &&
            {
              'reauth',
              'permission',
              'configuration',
              'quota',
              'protocol',
            }.contains(e.code)) {
          _blocked = true;
          retryAt = null;
          cloud.reportAccountError(e);
        }
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<DriveSyncReview> review(String key, String remoteVersion) async {
    if (!_ready || busy || loading) {
      throw const WorkspaceConflict('Wait for sync before reviewing.');
    }
    final nonce = _nonce;
    busy = true;
    _notify();
    try {
      if (!await workspace.flushAll()) {
        throw const WorkspaceConflict('Save local work before reviewing.');
      }
      _attach();
      final conflict = conflicts[key] as Map?;
      if (conflict == null) {
        throw const WorkspaceConflict('This conflict changed. Refresh sync.');
      }
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
      final remote = versions.singleWhere((v) => v.version == remoteVersion);
      final local = (await _replica!.inventory())[key];
      Future<String> preview(
        SyncEntry? entry,
        Stream<List<int>> Function() source,
      ) async {
        if (entry == null) return 'No local source exists.';
        if (entry.deleted) {
          return 'Permanent deletion record\n${entry.path}\nSHA-256: ${entry.hash}';
        }
        if (syncPathRole(entry.path) == SyncPathRole.attachment) {
          return 'Binary attachment: ${entry.path}\nSHA-256: ${entry.hash}\nRetained alternatives can be exported from Recovery files.';
        }
        final snapshot = await _replica!.stageTransfer(source(), entry.hash);
        try {
          final output = BytesBuilder(copy: false);
          await for (final chunk in snapshot.openRead()) {
            output.add(
              chunk
                  .take((256 * 1024 - output.length).clamp(0, chunk.length))
                  .toList(),
            );
            if (output.length >= 256 * 1024) break;
          }
          return utf8.decode(output.takeBytes(), allowMalformed: true) +
              (snapshot.length > 256 * 1024
                  ? '\n[Preview limited to 256 KiB; full source retained.]'
                  : '');
        } finally {
          await snapshot.close();
        }
      }

      final localText = await preview(local, () => _replica!.read(local!));
      final remoteText = await preview(
        remote.entry,
        () => _engine!.provider.download(remote),
      );
      if (!_ready || nonce != _nonce) {
        throw const WorkspaceConflict(
          'Vault or account changed during review.',
        );
      }
      return DriveSyncReview(localText, remoteText, local?.hash ?? 'absent');
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> resolve(
    String key, {
    String? remoteVersion,
    String? expectedLocalHash,
  }) async {
    if (!_ready || busy || loading) return;
    final nonce = _nonce;
    busy = true;
    error = '';
    _notify();
    try {
      if (!await workspace.flushAll()) {
        throw const WorkspaceConflict('Save local work before resolving.');
      }
      _attach();
      final next = await _engine!.resolve(
        key,
        remoteVersion: remoteVersion,
        expectedLocalHash: expectedLocalHash,
      );
      if (!_ready || nonce != _nonce) return;
      final state = await _state!.load();
      if (!_ready || nonce != _nonce) return;
      result = next;
      conflicts = Map<String, dynamic>.from(state?['conflicts'] as Map? ?? {});
      status = next.upToDate
          ? 'Up to date with Google Drive'
          : 'Resolution saved · review remaining changes';
      if (next.upToDate) lastSynced = _now();
    } on Object catch (e) {
      if (_ready && nonce == _nonce) {
        error = _message(e);
        status = 'Resolution needs review · both versions retained';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  String _message(Object error) => error is GoogleCloudError
      ? error.message
      : error is WorkspaceFailure
      ? error.message
      : 'Drive could not complete this action. Local work and recovery history are preserved.';
  @override
  void dispose() {
    _disposed = true;
    _nonce++;
    _poll?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}

class DriveSyncReview {
  const DriveSyncReview(this.local, this.remote, this.localHash);
  final String local, remote, localHash;
}
