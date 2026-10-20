/// Google identity and authorization are device state, never Vault knowledge.
class GoogleAccount {
  const GoogleAccount({
    required this.subject,
    this.name = '',
    this.email = '',
    this.avatar,
  });
  final String subject, name, email;
  final String? avatar;
  Map<String, dynamic> toJson() => {
    'sub': subject,
    'name': name,
    'email': email,
    'picture': avatar,
  };
  factory GoogleAccount.fromJson(Map<String, dynamic> value) {
    final sub = value['sub'];
    if (sub is! String || sub.isEmpty) {
      throw const GoogleCloudError(
        'identity',
        'Google could not confirm this account. Try signing in again.',
      );
    }
    final picture = value['picture'];
    return GoogleAccount(
      subject: sub,
      name: value['name'] is String ? value['name'] as String : '',
      email: value['email'] is String ? value['email'] as String : '',
      avatar: picture is String && Uri.tryParse(picture)?.scheme == 'https'
          ? picture
          : null,
    );
  }
}

class GoogleCloudError implements Exception {
  const GoogleCloudError(this.code, this.message);
  final String code, message;
  @override
  String toString() => message; // Never expose provider responses or credentials.
}

abstract interface class GoogleAccountAuth {
  bool get configured;
  GoogleAccount? get account;
  Future<GoogleAccount?> restore();
  Future<GoogleAccount> signIn({String? expectedSubject});
  Future<String> accessToken({bool refresh = false});
  Future<void> signOut();
  void cancel();
}

abstract interface class GoogleCredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

/// Optional preview-build activation; production builds bundle app registration.
abstract interface class GoogleDesktopSetup {
  bool get canConfigureDesktop;
  Future<void> configureDesktop(String downloadedJson);
}

const googleDriveScope = 'https://www.googleapis.com/auth/drive.file';
const googleScopes = ['openid', 'profile', 'email', googleDriveScope];

/// int64 quota values are parsed as BigInt so web builds also retain precision.
class GoogleStorageQuota {
  const GoogleStorageQuota({
    this.limit,
    this.usage,
    this.driveUsage,
    this.trashUsage,
    this.maxUploadSize,
  });
  final BigInt? limit, usage, driveUsage, trashUsage, maxUploadSize;
  BigInt? get remaining => limit == null || usage == null
      ? null
      : (limit! - usage! < BigInt.zero ? BigInt.zero : limit! - usage!);
  double? get fraction => limit == null || usage == null || limit == BigInt.zero
      ? null
      : (usage!.toDouble() / limit!.toDouble()).clamp(0, 1);
  bool get nearlyFull => fraction != null && fraction! >= .9;
  factory GoogleStorageQuota.fromJson(Map<String, dynamic> value) {
    BigInt? number(dynamic n) {
      if (n is! String && n is! int) return null;
      if (!RegExp(r'^\d+$').hasMatch('$n')) return null;
      return BigInt.tryParse('$n');
    }

    final q = value['storageQuota'] is Map
        ? value['storageQuota'] as Map
        : const {};
    return GoogleStorageQuota(
      limit: number(q['limit']),
      usage: number(q['usage']),
      driveUsage: number(q['usageInDrive']),
      trashUsage: number(q['usageInDriveTrash']),
      maxUploadSize: number(value['maxUploadSize']),
    );
  }
  void checkUpload(BigInt total, BigInt largest) {
    if (remaining != null && total > remaining!) {
      throw const GoogleCloudError(
        'quota',
        'Not enough Google storage. Your local Vault remains safe.',
      );
    }
    if (maxUploadSize != null && largest > maxUploadSize!) {
      throw const GoogleCloudError(
        'fileSize',
        'A file exceeds Google’s maximum upload size.',
      );
    }
  }
}
