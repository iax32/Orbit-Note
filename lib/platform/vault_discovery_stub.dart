import '../application/workspace_repository.dart';
import '../domain/vault_candidate.dart';
import '../domain/workspace_failure.dart';

bool vaultPathsEqual(String a, String b) => a == b;
Future<VaultDiscovery> discoverVaults(
  List<String> paths, {
  bool children = false,
}) async =>
    const VaultDiscovery([], ['Bulk Vault transfers require native folders.']);
Future<WorkspaceRepository> openExistingVault(VaultCandidate vault) async =>
    throw const WorkspaceFailure('Native Vault folders are unavailable.');
Future<void> rememberDownloadedVault(String path) async {}
