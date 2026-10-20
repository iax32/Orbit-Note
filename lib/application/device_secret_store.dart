/// Device-only private settings/capabilities. Never part of a Vault or export.
abstract interface class DeviceSecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
