import '../../application/sync/google_account.dart';

GoogleAccountAuth createGoogleAuth() => _Unavailable();

class _Unavailable implements GoogleAccountAuth {
  @override
  bool get configured => false;
  @override
  GoogleAccount? get account => null;
  @override
  Future<GoogleAccount?> restore() async => null;
  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async =>
      throw const GoogleCloudError(
        'unsupported',
        'Google Drive is available in native Orbit builds.',
      );
  @override
  Future<String> accessToken({bool refresh = false}) async =>
      throw const GoogleCloudError(
        'unsupported',
        'Google Drive is unavailable here.',
      );
  @override
  Future<void> signOut() async {}
  @override
  void cancel() {}
}
