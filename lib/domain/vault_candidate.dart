/// A discovered native Vault, identified before it can be selected for transfer.
class VaultCandidate {
  const VaultCandidate({
    required this.path,
    required this.id,
    required this.name,
  });
  final String path, id, name;
}

class VaultDiscovery {
  const VaultDiscovery(this.vaults, this.warnings);
  final List<VaultCandidate> vaults;
  final List<String> warnings;
}
