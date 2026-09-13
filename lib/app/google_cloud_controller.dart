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
    _notify();
    try {
      await action();
    } on GoogleCloudError catch (e) {
      message = e.message;
      if (e.code == 'reauth' || e.code == 'permission') {
        reconnectRequired = true;
      }
    } on Object {
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
    await _refresh();
  });
  void _clearAccountData() {
    quota = null;
    vaults = [];
    rootId = null;
    _refreshed = null;
  }

  Future<void> _refresh() async {
    final generation = _generation, subject = account?.subject;
    GoogleCloudError? error;
    try {
      final next = await drive.quota();
      if (generation != _generation || subject != account?.subject) return;
      quota = next;
    } on GoogleCloudError catch (e) {
      error = e;
      quota = null;
    }
    try {
      final next = await drive.listVaults();
      if (generation != _generation || subject != account?.subject) return;
      vaults = next;
    } on GoogleCloudError catch (e) {
      error ??= e;
    }
    _refreshed = DateTime.now();
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
        'Your Orbit folder is ready in Google Drive. Your Vault is still local only.';
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
  Future<void> signOut() => _run(() async {
    _generation++;
    await auth.signOut();
    _clearAccountData();
    reconnectRequired = false;
  });
  void cancel() {
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
