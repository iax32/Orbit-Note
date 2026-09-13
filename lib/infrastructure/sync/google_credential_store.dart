import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../application/sync/google_account.dart';

class SecureGoogleCredentials implements GoogleCredentialStore {
  const SecureGoogleCredentials(this.key);
  final String key;
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}
