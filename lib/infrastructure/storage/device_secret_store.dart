import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../application/device_secret_store.dart';

class SecureDeviceSecrets implements DeviceSecretStore {
  const SecureDeviceSecrets(this.key);
  final String key;
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: key);
}
