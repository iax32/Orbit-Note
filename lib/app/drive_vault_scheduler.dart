import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/device_secret_store.dart';
import '../application/sync/drive_vault_batch.dart';
import '../domain/vault_candidate.dart';
import '../domain/workspace_failure.dart';
import '../infrastructure/storage/device_secret_store.dart';
import '../platform/vault_discovery.dart';
import '../platform/background_sync.dart';
import 'drive_sync_controller.dart';
import 'google_cloud_controller.dart';
import 'workspace_controller.dart';

final driveScheduleStoreProvider = Provider<DeviceSecretStore>(
  (_) => const SecureDeviceSecrets('orbit.drive.schedule.v1'),
);

final driveScheduleStartupProvider = Provider<void>((ref) {
  var alive = true;
  unawaited(() async {
    try {
      final raw = await ref.read(driveScheduleStoreProvider).read();
      if (!alive || raw == null || raw.length > 256 * 1024) return;
      final value = jsonDecode(raw);
      if (value is Map &&
          value['format'] == 'orbit-drive-schedule' &&
          value['version'] == 1 &&
          value['enabled'] == true) {
        ref.read(driveVaultSchedulerProvider);
      }
    } on Object {
      /* Local use does not depend on optional device storage. */
    }
  }());
  ref.onDispose(() => alive = false);
});

final driveVaultSchedulerProvider = Provider<DriveVaultScheduler>((ref) {
  final sync = ref.read(driveSyncProvider);
  final scheduler = DriveVaultScheduler(
    workspace: sync.workspace,
    sync: sync,
    cloud: sync.cloud,
    store: ref.read(driveScheduleStoreProvider),
    sharedActive: sync.sharedActive,
  );
  ref.onDispose(scheduler.dispose);
  unawaited(scheduler.restore());
  return scheduler;
});

class DriveVaultScheduler extends ChangeNotifier {
  DriveVaultScheduler({
    required this.workspace,
    required this.sync,
    required this.cloud,
    required this.store,
    required this.sharedActive,
    this.automatic = true,
    DateTime Function()? now,
    Future<VaultRepositoryLease> Function(VaultCandidate)? open,
  }) : _now = now ?? DateTime.now,
       _open = open ?? _openNative {
    if (automatic) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => unawaited(checkNow()),
      );
    }
  }
  static Future<VaultRepositoryLease> _openNative(VaultCandidate v) async {
    final repo = await openExistingVault(v);
    return VaultRepositoryLease(repo, repo.close);
  }

  final WorkspaceController workspace;
  final DriveSyncController sync;
  final GoogleCloudController cloud;
  final DeviceSecretStore store;
  final bool Function() sharedActive;
  final bool automatic;
  final DateTime Function() _now;
  final Future<VaultRepositoryLease> Function(VaultCandidate) _open;
  Timer? _timer;
  DriveVaultBatch? _batch;
  Future<void> _writes = Future.value();
  Future<void>? _restoring;
  Map<String, dynamic> _extra = {};
  bool enabled = false,
      busy = false,
      loading = false,
      blocked = false,
      configurationBlocked = false,
      _disposed = false;
  int minutes = 5, _failures = 0, _generation = 0;
  String? subject;
  String status = 'Scheduled Vault checks are off', error = '';
  DateTime? nextCheck, lastCheck;
  List<VaultCandidate> vaults = [];
  List<VaultTransferJob> jobs = [];
  bool get backgroundEnabled => _extra['backgroundEnabled'] == true;
  String? backgroundStatus;
  bool get backgroundSupported => backgroundSyncSupported;
  Future<void> setBackgroundEnabled(bool value) async {
    if (loading ||
        busy ||
        configurationBlocked ||
        _disposed ||
        (value &&
            (!enabled ||
                vaults.isEmpty ||
                cloud.account?.subject != subject ||
                sharedActive()))) {
      return;
    }
    loading = true;
    error = '';
    final wasEnabled = backgroundEnabled;
    _notify();
    try {
      if (!value) {
        _extra['backgroundEnabled'] = false;
        await _save(); // Revoke transfers even if OS task removal fails.
      }
      await configureBackgroundSync(value);
      _extra['backgroundEnabled'] = value;
      await _save();
      status = value
          ? 'Background checks enabled · approximately every 15 minutes when the OS allows'
          : 'Background checks disabled';
    } on Object {
      _extra['backgroundEnabled'] = false;
      var stopped = false, saved = false;
      try {
        await configureBackgroundSync(false);
        stopped = true;
      } on Object {
        /* Saved enrollment can still revoke future requests. */
      }
      try {
        await _save();
        saved = true;
      } on Object {
        /* Preserve actionable error below. */
      }
      if (!stopped && !saved) _extra['backgroundEnabled'] = wasEnabled;
      error = !stopped && !saved
          ? 'Background checks could not be confirmed as disabled. Retry or disable the OrbitNote-Sync task in your OS settings.'
          : 'Background setup could not finish. Transfers were paused; retry setup when ready.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() => _restoring ??= _restore();
  Future<void> _restore() async {
    if (loading || busy) return;
    loading = true;
    _notify();
    try {
      final raw = await store.read();
      if (_disposed || raw == null) return;
      if (raw.length > 256 * 1024) {
        throw const WorkspaceFailure(
          'Scheduled Vault settings exceed the safe limit.',
        );
      }
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['format'] != 'orbit-drive-schedule' ||
          value['version'] != 1 ||
          value['enabled'] is! bool ||
          (value['backgroundEnabled'] != null &&
              value['backgroundEnabled'] is! bool) ||
          value['subject'] is! String ||
          ![1, 5, 15].contains(value['minutes']) ||
          value['vaults'] is! List ||
          (value['vaults'] as List).length > 50) {
        throw const WorkspaceFailure(
          'Saved schedule needs recovery; its data was preserved.',
        );
      }
      final selected = (value['vaults'] as List).map((v) {
        if (v is! Map ||
            v['path'] is! String ||
            v['id'] is! String ||
            v['name'] is! String ||
            (v['path'] as String).isEmpty ||
            (v['id'] as String).isEmpty) {
          throw const WorkspaceFailure('Saved Vault selection is invalid.');
        }
        return VaultCandidate(
          path: v['path'] as String,
          id: v['id'] as String,
          name: v['name'] as String,
        );
      }).toList();
      if (selected.map((v) => v.id).toSet().length != selected.length) {
        throw const WorkspaceFailure(
          'Saved schedule contains duplicate Vault identities.',
        );
      }
      _extra = value;
      vaults = selected;
      subject = value['subject'] as String;
      enabled = value['enabled'] as bool;
      minutes = value['minutes'] as int;
      backgroundStatus = await backgroundSyncLastRun();
      nextCheck = _now();
      status = enabled
          ? 'Scheduled checks enabled while Orbit is open'
          : 'Scheduled checks paused';
    } on Object catch (e) {
      enabled = false;
      blocked = true;
      configurationBlocked = true;
      error = e is WorkspaceFailure
          ? e.message
          : 'Could not read secure device settings. Local work is available.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _save() {
    final body = jsonEncode({
      ..._extra,
      'format': 'orbit-drive-schedule',
      'version': 1,
      'enabled': enabled,
      'subject': subject,
      'minutes': minutes,
      'vaults': vaults
          .map(
            (v) => {
              for (final prior in (_extra['vaults'] as List? ?? []))
                if (prior is Map && prior['id'] == v.id)
                  ...Map<String, dynamic>.from(prior),
              'path': v.path,
              'id': v.id,
              'name': v.name,
            },
          )
          .toList(),
    });
    if (body.length > 256 * 1024) {
      throw const WorkspaceFailure(
        'Scheduled Vault settings exceed the safe limit.',
      );
    }
    final operation = _writes.then((_) => store.write(body));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> addVaults(List<VaultCandidate> selected) async {
    await restore();
    if (loading || busy || _disposed || blocked || cloud.account == null) {
      throw const WorkspaceConflict(
        'Wait for scheduled checks and reconnect the selected Google account.',
      );
    }
    if (subject != null && subject != cloud.account!.subject) {
      throw const WorkspaceConflict(
        'Forget the previous account’s schedule before selecting another account.',
      );
    }
    final combined = {
      for (final v in vaults) v.id: v,
      for (final v in selected) v.id: v,
    }.values.toList();
    if (combined.isEmpty || combined.length > 50) {
      throw const WorkspaceFailure('Choose up to 50 scheduled Vaults.');
    }
    subject = cloud.account!.subject;
    vaults = combined;
    enabled = true;
    error = '';
    nextCheck = _now().add(Duration(minutes: minutes));
    try {
      await _save();
      status = 'Scheduled checks enabled while Orbit is open';
    } catch (_) {
      enabled = false;
      error = 'Could not save the schedule. Retry to enable it.';
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed ||
        loading ||
        configurationBlocked ||
        (value && (vaults.isEmpty || cloud.account?.subject != subject))) {
      return;
    }
    enabled = value;
    _generation++;
    _batch?.cancel();
    error = '';
    status = value
        ? 'Scheduled checks enabled while Orbit is open'
        : 'Scheduled checks paused';
    try {
      await _save();
      nextCheck = _now();
    } catch (_) {
      enabled = false;
      error = 'Pause/resume could not be saved. Retry before restarting Orbit.';
    }
    _notify();
  }

  Future<void> setMinutes(int value) async {
    if (![1, 5, 15].contains(value) || busy || loading || blocked) return;
    minutes = value;
    try {
      await _save();
      nextCheck = _now().add(Duration(minutes: minutes));
    } catch (_) {
      error = 'Could not save the interval. Retry.';
    }
    _notify();
  }

  Future<void> forget() async {
    if (loading) return;
    final hadBackground = backgroundEnabled;
    loading = true;
    enabled = false;
    _generation++;
    _batch?.cancel();
    try {
      await _writes;
      await store.delete();
      vaults = [];
      jobs = [];
      subject = null;
      blocked = false;
      configurationBlocked = false;
      _extra = {};
      error = '';
      status = 'Schedule removed · local and Drive files retained';
      if (hadBackground) {
        try {
          await configureBackgroundSync(false);
        } on Object {
          error =
              'Transfers are disabled; the OS background task could not be removed. Retry removing it in OS settings.';
        }
      }
    } catch (_) {
      error = 'Could not remove the saved schedule. Retry before restarting.';
    }
    loading = false;
    _notify();
  }

  Future<void> removeVault(String id) async {
    if (busy || loading || configurationBlocked) return;
    final previous = vaults, wasEnabled = enabled;
    vaults = vaults.where((v) => v.id != id).toList();
    if (vaults.isEmpty) enabled = false;
    try {
      await _save();
    } catch (_) {
      vaults = previous;
      enabled = wasEnabled;
      error = 'Could not save the selection. Retry.';
    }
    _notify();
  }

  Future<void> checkNow({bool force = false}) async {
    if (_disposed || loading || busy || !enabled || (blocked && !force)) return;
    if (!force && nextCheck != null && _now().isBefore(nextCheck!)) return;
    if (!workspace.hasWorkspace ||
        workspace.loading ||
        !workspace.repository.supportsFileSync ||
        cloud.account?.subject != subject ||
        cloud.reconnectRequired ||
        cloud.busy ||
        sync.busy ||
        sharedActive()) {
      status = sharedActive()
          ? 'Paused while Shared Vault is connecting or connected'
          : cloud.account?.subject != subject
          ? 'Reconnect the bound Google account to continue'
          : 'Waiting for the active Vault and account';
      _notify();
      return;
    }
    final selected = vaults
        .where((v) => !vaultPathsEqual(v.path, workspace.repository.location))
        .toList();
    if (selected.isEmpty) {
      status = 'Selected Vault is handled by active-Vault sync';
      _notify();
      return;
    }
    final generation = _generation;
    busy = true;
    error = '';
    if (force) blocked = false;
    jobs = selected.map(VaultTransferJob.local).toList();
    _notify();
    try {
      await sync.runVaultBatch((leaseCurrent) async {
        bool current() =>
            !_disposed &&
            enabled &&
            generation == _generation &&
            leaseCurrent() &&
            cloud.account?.subject == subject &&
            !sharedActive();
        _batch = DriveVaultBatch(
          api: cloud.drive,
          open: _open,
          isCurrent: current,
          requireEnabledBinding: true,
          onChanged: _notify,
          onAccountError: (e) {
            blocked = true;
            sync.reportBatchAccountError(e);
          },
        );
        await _batch!.run(jobs);
      });
      if (!_disposed && generation == _generation) {
        lastCheck = _now();
        final failures = jobs
            .where(
              (j) =>
                  j.state == VaultTransferState.failed ||
                  j.state == VaultTransferState.cancelled,
            )
            .length;
        _failures = failures == 0 ? 0 : (_failures + 1).clamp(1, 5);
        nextCheck = _now().add(
          Duration(
            minutes: failures == 0 ? minutes : (1 << _failures).clamp(1, 30),
          ),
        );
        status =
            '${jobs.where((j) => j.state == VaultTransferState.complete).length} Vault(s) checked · ${jobs.where((j) => j.state == VaultTransferState.review).length} need review · $failures unavailable';
      }
    } catch (_) {
      error =
          'Scheduled checks stopped safely. Retry when the account and Vault are ready.';
      nextCheck = _now().add(const Duration(minutes: 2));
    } finally {
      busy = false;
      _batch = null;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _batch?.cancel();
    super.dispose();
  }
}
