import '../../infrastructure/sync/google_drive_api.dart';
import '../../domain/workspace_failure.dart';
import '../workspace_repository.dart';

void validateDriveBinding(Map<String, dynamic>? settings, String workspaceId) {
  if (settings != null &&
      (settings['format'] != 'orbit-drive-settings' ||
          settings['version'] != 1 ||
          settings['workspaceId'] != workspaceId ||
          settings['subject'] is! String ||
          settings['email'] is! String ||
          settings['enabled'] is! bool ||
          (settings['folder'] != null && settings['folder'] is! String) ||
          (settings['pendingFolder'] != null &&
              settings['pendingFolder'] is! String) ||
          (settings['enabled'] == true && settings['folder'] is! String))) {
    throw const WorkspaceConflict(
      'Saved Drive settings need recovery; they were preserved.',
    );
  }
}

/// Same durable binding contract for active-Vault setup and explicit batches.
Future<GoogleRemoteVault> connectDriveVault({
  required WorkspaceSyncReplica replica,
  required GoogleDriveApi api,
  required String name,
  required bool Function() isCurrent,
  GoogleRemoteVault? target,
  bool enableAutomaticSync = true,
}) async {
  final account = api.auth.account;
  if (account == null) {
    throw const WorkspaceConflict('Connect Google Drive first.');
  }
  void check() {
    if (!isCurrent() || api.auth.account?.subject != account.subject) {
      throw const WorkspaceConflict(
        'Vault or account changed. Local files were preserved.',
      );
    }
  }

  check();
  await replica.inventory(); // All local blockers precede cloud creation.
  final store = replica.createDriveSettingsStore();
  final saved = await store.load();
  validateDriveBinding(saved, replica.workspaceId);
  check();
  if (saved != null && saved['subject'] != account.subject) {
    throw const WorkspaceConflict(
      'This Vault retains another account’s sync history. Use a separate local copy.',
    );
  }
  if (target != null &&
      (target.workspaceId != replica.workspaceId ||
          target.accountSubject != account.subject)) {
    throw const WorkspaceConflict(
      'Select this exact Vault in the connected account.',
    );
  }
  final settings =
      saved ??
      <String, dynamic>{
        'format': 'orbit-drive-settings',
        'version': 1,
        'workspaceId': replica.workspaceId,
        'subject': account.subject,
        'email': account.email,
        'enabled': false,
      };
  Future<void> save() async {
    check();
    await store.save(settings);
  }

  final vault =
      target ??
      (settings['folder'] is String
          ? GoogleRemoteVault(
              folderId: settings['folder'] as String,
              workspaceId: replica.workspaceId,
              name: name,
              accountSubject: account.subject,
            )
          : await api.ensureSyncVault(
              replica.workspaceId,
              name,
              pendingId: settings['pendingFolder'] as String?,
              rememberId: (id) async {
                settings['pendingFolder'] = id;
                await save();
              },
            ));
  await api.verifySyncVault(vault);
  check();
  if (settings['folder'] != null && settings['folder'] != vault.folderId) {
    throw const WorkspaceConflict(
      'This Vault has another retained folder binding. Its history was preserved.',
    );
  }
  settings['folder'] = vault.folderId;
  if (enableAutomaticSync) settings['enabled'] = true;
  await save();
  return vault;
}
