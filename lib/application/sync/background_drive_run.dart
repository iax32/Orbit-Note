import 'dart:convert';
import '../../domain/vault_candidate.dart';
import '../../domain/workspace_failure.dart';
import '../device_secret_store.dart';
import 'drive_vault_batch.dart';
import 'google_account.dart';

/// Device-only enrollment. Never discovers folders or creates cloud bindings.
class BackgroundDriveEnrollment {
  BackgroundDriveEnrollment._(this.subject, this.vaults, this.enabled);
  final String subject;
  final List<VaultCandidate> vaults;
  final bool enabled;
  factory BackgroundDriveEnrollment.parse(String raw) {
    if (raw.length > 256 * 1024) throw const FormatException();
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['format'] != 'orbit-drive-schedule' ||
        value['version'] != 1 ||
        value['subject'] is! String ||
        (value['subject'] as String).isEmpty ||
        value['vaults'] is! List ||
        (value['vaults'] as List).length > 50 ||
        value['enabled'] is! bool ||
        (value['backgroundEnabled'] != null &&
            value['backgroundEnabled'] is! bool)) {
      throw const FormatException();
    }
    final vaults = <VaultCandidate>[];
    for (final v in value['vaults'] as List) {
      if (v is! Map ||
          v['path'] is! String ||
          (v['path'] as String).isEmpty ||
          v['id'] is! String ||
          (v['id'] as String).isEmpty ||
          v['name'] is! String ||
          vaults.any(
            (prior) => prior.id == v['id'] || prior.path == v['path'],
          )) {
        throw const FormatException();
      }
      vaults.add(VaultCandidate(path: v['path'], id: v['id'], name: v['name']));
    }
    return BackgroundDriveEnrollment._(
      value['subject'],
      List.unmodifiable(vaults),
      value['enabled'] == true && value['backgroundEnabled'] == true,
    );
  }
  bool permits(BackgroundDriveEnrollment next) =>
      next.enabled &&
      subject == next.subject &&
      vaults.length == next.vaults.length &&
      vaults.every(
        (v) => next.vaults.any((n) => n.id == v.id && n.path == v.path),
      );
}

/// One bounded scheduler invocation. The platform supplies silent authorization,
/// network cancellation and repository leases, not a second storage engine.
class BackgroundDriveRun {
  BackgroundDriveRun({
    required this.settings,
    required this.report,
    required this.auth,
    required this.createBatch,
  });
  final DeviceSecretStore settings, report;
  final GoogleAccountAuth auth;
  final DriveVaultBatch Function(bool Function()) createBatch;
  DriveVaultBatch? _batch;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _batch?.cancel();
  }

  Future<bool> run() async {
    final started = DateTime.now().toUtc();
    var status = 'paused';
    final jobs = <VaultTransferJob>[];
    try {
      final raw = await settings.read();
      if (raw == null) return true;
      final enrollment = BackgroundDriveEnrollment.parse(raw);
      if (!enrollment.enabled || _cancelled) return true;
      await report.write(
        jsonEncode({
          'format': 'orbit-background-report',
          'version': 1,
          'started': started.toIso8601String(),
          'status': 'running',
        }),
      );
      status = 'reconnect';
      final account = await auth.restore(); // No signIn or browser call here.
      if (account?.subject != enrollment.subject || _cancelled) return false;
      final latest = await settings.read();
      if (latest == null ||
          !enrollment.permits(BackgroundDriveEnrollment.parse(latest))) {
        status = 'paused';
        return true;
      }
      jobs.addAll(enrollment.vaults.map(VaultTransferJob.local));
      if (jobs.isEmpty) return true;
      _batch = createBatch(
        () => !_cancelled && auth.account?.subject == enrollment.subject,
      );
      if (!_batch!.requireEnabledBinding) {
        throw const WorkspaceConflict(
          'Background sync requires existing enabled bindings.',
        );
      }
      await _batch!.run(jobs);
      status = _cancelled
          ? 'cancelled'
          : jobs.every(
              (j) =>
                  j.state == VaultTransferState.complete ||
                  j.state == VaultTransferState.paused,
            )
          ? 'complete'
          : 'review';
      return status == 'complete';
    } on GoogleCloudError catch (e) {
      status =
          {
            'reauth',
            'account',
            'accountMismatch',
            'permission',
            'configuration',
          }.contains(e.code)
          ? 'reconnect'
          : 'retry';
      return false;
    } on Object {
      status = 'retry';
      return false;
    } finally {
      await report.write(
        jsonEncode({
          'format': 'orbit-background-report',
          'version': 1,
          'started': started.toIso8601String(),
          'finished': DateTime.now().toUtc().toIso8601String(),
          'status': status,
          'vaults': [
            for (final job in jobs) {'id': job.id, 'state': job.state.name},
          ],
        }),
      );
    }
  }
}
