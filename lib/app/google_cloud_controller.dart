import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../application/sync/google_account.dart';
import '../infrastructure/sync/google_auth.dart';
import '../infrastructure/sync/google_credential_store.dart';
import '../infrastructure/sync/google_drive_api.dart';

final googleCloudProvider = Provider<GoogleCloudController>((ref) {
  final auth = createGoogleAuth(), client = http.Client();
  final controller = GoogleCloudController(
    auth,
    GoogleDriveApi(
      auth: auth,
      client: client,
      localMetadata: const SecureGoogleCredentials(
        'orbit.google.drive-roots.v1',
      ),
    ),
  );
  ref.onDispose(() {
    controller.dispose();
    client.close();
  });
  unawaited(controller.restore());
  return controller;
});

class GoogleCloudController extends ChangeNotifier {
  GoogleCloudController(this.auth, this.drive);
  final GoogleAccountAuth auth;
  final GoogleDriveApi drive;
  GoogleAccount? get account => auth.account;
  GoogleStorageQuota? quota;
  List<GoogleRemoteVault> vaults = [];
  List<GoogleDriveBackup> backups = [];
  double? transferProgress;
  bool _cancelTransfer = false;
  String? message, rootId;
  bool busy = false, reconnectRequired = false, _disposed = false;
  bool signingIn = false;
  DateTime? _refreshed;
  int _generation = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    message = null;
    final generation = _generation;
    _notify();
    try {
      await action();
    } on GoogleCloudError catch (e) {
      if (_disposed || generation != _generation) return;
      message = e.message;
      if (e.code == 'reauth' || e.code == 'permission') {
        reconnectRequired = true;
      }
    } on Object {
      if (_disposed || generation != _generation) return;
      message =
          'Google Drive could not complete this action. Your local Vault is safe.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> restore() => _run(() async {
    final generation = _generation;
    await auth.restore();
    if (generation == _generation && account != null) await _refresh();
  });
  Future<void> connect() => _run(() async {
    final previous = account?.subject;
    signingIn = true;
    _notify();
    try {
      await auth.signIn(expectedSubject: reconnectRequired ? previous : null);
    } finally {
      signingIn = false;
      _notify();
    }
    if (previous != account?.subject) _clearAccountData();
    reconnectRequired = false;
    rootId = await drive.ensureRoot();
    await _refresh();
    message =
        'Google Drive is ready. Backups and automatic sync use the choices saved for each Vault.';
  });
  Future<bool> configureDesktop(String source) async {
    var configured = false;
    await _run(() async {
      final setup = auth is GoogleDesktopSetup
          ? auth as GoogleDesktopSetup
          : null;
      if (setup == null || !setup.canConfigureDesktop) {
        throw const GoogleCloudError(
          'configuration',
          'Desktop client setup is unavailable in this build.',
        );
      }
      await setup.configureDesktop(source);
      configured = true;
      message =
          'App registration installed. Continue with Google to connect your account.';
    });
    return configured;
  }

  void _clearAccountData() {
    quota = null;
    vaults = [];
    backups = [];
    rootId = null;
    _refreshed = null;
  }

  Future<void> _refresh() async {
    final generation = _generation, subject = account?.subject;
    bool current() =>
        !_disposed && generation == _generation && subject == account?.subject;
    GoogleCloudError? error;
    try {
      final next = await drive.quota();
      if (!current()) return;
      quota = next;
    } on GoogleCloudError catch (e) {
      if (!current()) return;
      error = e;
      quota = null;
    }
    try {
      final next = await drive.listVaults();
      if (!current()) return;
      vaults = next;
    } on GoogleCloudError catch (e) {
      if (!current()) return;
      error ??= e;
    }
    try {
      final next = await drive.listBackups();
      if (!current()) return;
      backups = next;
    } on GoogleCloudError catch (e) {
      if (!current()) return;
      error ??= e;
    }
    // An incomplete refresh must remain retryable, even inside the cache window.
    _refreshed = error == null ? DateTime.now() : null;
    if (error != null) throw error;
    reconnectRequired = false;
  }

  Future<void> refresh({bool force = false}) => _run(() async {
    if (account == null) return;
    if (force ||
        _refreshed == null ||
        DateTime.now().difference(_refreshed!) > const Duration(minutes: 5)) {
      await _refresh();
    }
  });
  Future<void> prepareRoot() => _run(() async {
    rootId = await drive.ensureRoot();
    message =
        'Your Orbit folder is ready in Google Drive. Preparing this folder does not upload a Vault.';
  });
  Future<void> inspect(
    GoogleRemoteVault vault,
    String localWorkspaceId,
  ) => _run(() async {
    await drive.inspectVault(vault);
    message = vault.workspaceId == localWorkspaceId
        ? 'Verified: this is the same Vault identity. No local files were changed.'
        : 'Verified: this is a separate Vault. Matching names do not merge Vaults.';
  });
  Future<void> signOut() async {
    if (busy || _disposed) return;
    _generation++;
    await _run(() async {
      await auth.signOut();
      _clearAccountData();
      reconnectRequired = false;
    });
  }

  Future<void> refreshBackups() => _run(() async {
    final generation = _generation, subject = account?.subject;
    final next = await drive.listBackups();
    if (!_disposed &&
        generation == _generation &&
        subject == account?.subject) {
      backups = next;
    }
  });
  Future<void> uploadBackup(
    Future<String> Function() snapshot,
  ) => _run(() async {
    _cancelTransfer = false;
    transferProgress = 0;
    _notify();
    try {
      final subject = account?.subject, generation = _generation;
      final source = await snapshot();
      if (_cancelTransfer || _disposed || generation != _generation) {
        throw const GoogleCloudError(
          'cancelled',
          'Backup cancelled before upload. Local files are unchanged.',
        );
      }
      if (subject == null ||
          account?.subject != subject ||
          generation != _generation) {
        throw const GoogleCloudError(
          'account',
          'The account changed before the backup could be uploaded.',
        );
      }
      final uploaded = await drive.uploadBackup(
        source,
        isCancelled: () =>
            _cancelTransfer || _disposed || generation != _generation,
        onProgress: (sent, total) {
          if (_disposed || _cancelTransfer || generation != _generation) return;
          transferProgress = sent / total;
          _notify();
        },
      );
      if (_disposed ||
          generation != _generation ||
          account?.subject != subject) {
        return;
      }
      backups = [uploaded, ...backups.where((b) => b.id != uploaded.id)];
      message =
          'Verified backup uploaded. This independent backup does not change your automatic sync settings.';
      try {
        final listed = await drive.listBackups();
        if (!_disposed &&
            generation == _generation &&
            account?.subject == subject) {
          backups = [uploaded, ...listed.where((b) => b.id != uploaded.id)];
        }
      } on Object {
        if (!_disposed &&
            generation == _generation &&
            account?.subject == subject) {
          message =
              'Backup uploaded and verified. The backup list could not refresh; use Refresh backups before uploading again.';
        }
      }
    } finally {
      transferProgress = null;
    }
  });
  Future<String?> downloadBackup(GoogleDriveBackup backup) async {
    String? result;
    await _run(() async {
      final generation = _generation, subject = account?.subject;
      _cancelTransfer = false;
      transferProgress = 0;
      _notify();
      try {
        final downloaded = await drive.downloadBackup(
          backup,
          isCancelled: () =>
              _cancelTransfer || _disposed || generation != _generation,
          onProgress: (received, total) {
            if (_disposed || _cancelTransfer || generation != _generation) {
              return;
            }
            transferProgress = total == 0 ? 0 : received / total;
            _notify();
          },
        );
        if (_cancelTransfer ||
            _disposed ||
            generation != _generation ||
            subject != account?.subject) {
          return;
        }
        result = downloaded;
        message = 'Backup downloaded and verified. Review it before restoring.';
      } finally {
        transferProgress = null;
      }
    });
    return result;
  }

  void cancelTransfer() {
    _cancelTransfer = true;
    _notify();
  }

  void reportAccountError(GoogleCloudError error) {
    if (!{'reauth', 'permission'}.contains(error.code) || _disposed) return;
    reconnectRequired = true;
    message = error.message;
    _notify();
  }

  void confirmAccountAccess() {
    if (_disposed || !reconnectRequired) return;
    reconnectRequired = false;
    message = 'Google Drive access restored.';
    _notify();
  }

  void cancel() {
    _cancelTransfer = true;
    _generation++;
    auth.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
