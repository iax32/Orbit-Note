import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../application/sync/background_drive_run.dart';
import '../application/sync/drive_vault_batch.dart';
import '../application/sync/google_account.dart';
import '../infrastructure/storage/device_secret_store.dart';
import '../infrastructure/sync/google_credential_store.dart';
import '../infrastructure/sync/google_desktop_auth.dart';
import '../infrastructure/sync/google_drive_api.dart';
import 'vault_discovery_native.dart';

const _channel = MethodChannel('orbit_note/background_sync');
const _settings = SecureDeviceSecrets('orbit.drive.schedule.v1');
const backgroundReport = SecureDeviceSecrets(
  'orbit.drive.background-report.v1',
);
bool get backgroundSyncSupported => Platform.isWindows || Platform.isAndroid;

Future<String?> backgroundSyncLastRun() async {
  try {
    final raw = await backgroundReport.read();
    if (raw == null || raw.length > 16 * 1024) return null;
    final value = jsonDecode(raw);
    if (value is! Map ||
        value['format'] != 'orbit-background-report' ||
        value['version'] != 1) {
      return null;
    }
    final when = DateTime.tryParse('${value['finished'] ?? value['started']}');
    final label = switch (value['status']) {
      'complete' => 'Checked selected Vaults',
      'review' => 'Open Vaults to review conflicts or unavailable files',
      'reconnect' => 'Reconnect Google Drive in Orbit',
      'retry' => 'Will retry when a background check is allowed',
      'cancelled' => 'Stopped safely; pending transfers will retry',
      'paused' => 'Background checks are paused',
      'running' => 'Previous run started; completion is unconfirmed',
      _ => null,
    };
    return label == null
        ? null
        : '$label${when == null ? '' : ' · ${when.toLocal()}'}';
  } on Object {
    return null;
  }
}

String _xml(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);

/// Task registration is only called by an explicit settings action. No passwords,
/// tokens or Vault paths are put in OS task arguments.
Future<void> configureBackgroundSync(bool enabled) async {
  if (Platform.isAndroid) {
    await _channel.invokeMethod<void>('configure', {'enabled': enabled});
    return;
  }
  if (!Platform.isWindows) {
    throw UnsupportedError('Background sync unavailable');
  }
  final exe = File(Platform.resolvedExecutable).absolute.path;
  final user = await Process.run('whoami.exe', [
    '/user',
    '/fo',
    'csv',
    '/nh',
  ], runInShell: false).timeout(const Duration(seconds: 20));
  final sid = RegExp(r'S-1-5-[0-9-]+').firstMatch('${user.stdout}')?.group(0);
  if (user.exitCode != 0 || sid == null) {
    throw const GoogleCloudError(
      'scheduler',
      'Windows could not identify this user.',
    );
  }
  final name =
      'OrbitNote-Sync-${sha256.convert(utf8.encode('$sid:${exe.toLowerCase()}')).toString().substring(0, 16)}';
  Future<ProcessResult> task(List<String> args) async {
    final result = await Process.run(
      'schtasks.exe',
      args,
      runInShell: false,
      stdoutEncoding: null,
      stderrEncoding: null,
    ).timeout(const Duration(seconds: 20));
    final bytes = result.stdout as List<int>;
    // XML output can be UTF-16 even when the console uses a different codepage.
    final unicode =
        bytes.length >= 2 &&
        ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
            (bytes[0] == 0x3c && bytes[1] == 0));
    final output = unicode
        ? String.fromCharCodes([
            for (var i = bytes[0] == 0xff ? 2 : 0; i + 1 < bytes.length; i += 2)
              bytes[i] | (bytes[i + 1] << 8),
          ])
        : systemEncoding.decode(bytes);
    return ProcessResult(result.pid, result.exitCode, output, '');
  }

  final prior = await task(['/Query', '/TN', name, '/XML']);
  final exists = prior.exitCode == 0;
  if (exists &&
      (!(prior.stdout as String).contains(_xml(exe)) ||
          !(prior.stdout as String).contains('--sync-background'))) {
    throw const GoogleCloudError(
      'scheduler',
      'A different task uses this name. No task was changed.',
    );
  }
  if (!enabled) {
    if (exists) {
      await task(['/End', '/TN', name]);
      final result = await task(['/Delete', '/TN', name, '/F']);
      if (result.exitCode != 0) {
        throw const GoogleCloudError(
          'scheduler',
          'Windows could not remove the background task. Try again.',
        );
      }
    }
    return;
  }
  final start = DateTime.now()
      .add(const Duration(minutes: 1))
      .toIso8601String()
      .split('.')
      .first;
  final directory = await Directory.systemTemp.createTemp('orbit-sync-task-');
  try {
    final file = File(p.join(directory.path, 'task.xml'));
    final taskXml =
        '''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<Triggers><TimeTrigger><Repetition><Interval>PT15M</Interval><StopAtDurationEnd>false</StopAtDurationEnd></Repetition><StartBoundary>$start</StartBoundary><Enabled>true</Enabled></TimeTrigger><LogonTrigger><Enabled>true</Enabled><UserId>$sid</UserId></LogonTrigger></Triggers>
<Principals><Principal id="User"><UserId>$sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>true</StartWhenAvailable><RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>true</Hidden><ExecutionTimeLimit>PT5M</ExecutionTimeLimit></Settings>
<Actions Context="User"><Exec><Command>${_xml(exe)}</Command><Arguments>--sync-background</Arguments><WorkingDirectory>${_xml(p.dirname(exe))}</WorkingDirectory></Exec></Actions></Task>''';
    // schtasks parses a Unicode XML document; an UTF-8 declaration causes
    // "unable to switch the encoding" even for a valid UTF-8 source file.
    await file.writeAsBytes([
      0xff,
      0xfe,
      for (final unit in taskXml.codeUnits) ...[unit & 0xff, unit >> 8],
    ], flush: true);
    final result = await task([
      '/Create',
      '/TN',
      name,
      '/XML',
      file.path,
      if (exists) '/F',
    ]);
    if (result.exitCode != 0) {
      throw const GoogleCloudError(
        'scheduler',
        'Windows did not allow the background task. Local files are unchanged.',
      );
    }
  } finally {
    // This directory was freshly created by this call; never delete a user path.
    await directory.delete(recursive: true);
  }
}

Future<bool> startBackgroundSync(List<String> args) async {
  if (!Platform.isWindows || !args.contains('--sync-background')) return false;
  var success = false;
  try {
    success = await _run();
  } on Object {
    /* Report/secure storage may be unavailable. */
  }
  exit(success ? 0 : 1);
}

Future<void> runAndroidBackgroundSync() async {
  var success = false;
  try {
    success = await _run();
  } on Object {
    /* Native job retries safely. */
  }
  await _channel.invokeMethod<void>('finished', {'success': success});
}

Future<bool> _run() async {
  final raw = await _settings.read();
  if (raw == null) return true;
  final enrollment = BackgroundDriveEnrollment.parse(raw);
  if (!enrollment.enabled) return true;
  late final GoogleAccountAuth auth;
  var cancelled = false;
  Future<void> guard() async {
    if (Platform.isWindows &&
        await _channel.invokeMethod<bool>('foregroundActive') == true) {
      throw const GoogleCloudError(
        'cancelled',
        'Foreground editing takes priority.',
      );
    }
    final latest = await _settings.read();
    final credentials = await SecureGoogleCredentials(
      Platform.isAndroid
          ? 'orbit.google.android.v1'
          : 'orbit.google.desktop.v1',
    ).read();
    final stored = credentials == null ? null : jsonDecode(credentials);
    final accountData = stored is Map
        ? (Platform.isAndroid ? stored : stored['account'])
        : null;
    final subject = accountData is Map ? accountData['sub'] : null;
    if (cancelled ||
        latest == null ||
        subject != enrollment.subject ||
        !enrollment.permits(BackgroundDriveEnrollment.parse(latest))) {
      throw const GoogleCloudError(
        'cancelled',
        'Background sync paused or account changed.',
      );
    }
  }

  final authClient = _GuardedClient(http.Client(), guard);
  auth = Platform.isAndroid
      ? _AndroidSilentAuth()
      : GoogleDesktopAuth(
          clientId: const String.fromEnvironment(
            'ORBIT_GOOGLE_DESKTOP_CLIENT_ID',
          ),
          clientSecret: const String.fromEnvironment(
            'ORBIT_GOOGLE_DESKTOP_CLIENT_SECRET',
          ),
          credentials: _BackgroundCredentials(
            const SecureGoogleCredentials('orbit.google.desktop.v1'),
            guard,
          ),
          configurationStore: const SecureGoogleCredentials(
            'orbit.google.desktop-client.v1',
          ),
          client: authClient,
          openBrowser: (_) async => false,
          receive: () async =>
              throw const GoogleCloudError('reauth', 'Open Orbit to sign in.'),
        );
  final client = _GuardedClient(http.Client(), guard);
  final api = GoogleDriveApi(
    auth: auth,
    client: client,
    localMetadata: const SecureGoogleCredentials('orbit.google.drive-roots.v1'),
  );
  final run = BackgroundDriveRun(
    settings: _settings,
    report: backgroundReport,
    auth: auth,
    createBatch: (current) => DriveVaultBatch(
      api: api,
      requireEnabledBinding: true,
      isCurrent: () => !cancelled && current(),
      onChanged: () {},
      open: (v) async {
        await guard();
        final shared = await SecureDeviceSecrets(
          'orbit.shared.connection.v1.${sha256.convert(utf8.encode(v.id))}',
        ).read();
        if (shared != null) {
          throw const GoogleCloudError(
            'shared',
            'Open this shared Vault in Orbit to sync.',
          );
        }
        final repo = await openExistingVault(
          v,
        ); // Existing OS-backed exclusive lock.
        return VaultRepositoryLease(repo, repo.close);
      },
    ),
  );
  void cancel() {
    cancelled = true;
    run.cancel();
    auth.cancel();
    client.close();
    authClient.close();
  }

  if (Platform.isAndroid) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'cancel') cancel();
    });
  }
  final deadline = Timer(const Duration(minutes: 3), cancel);
  var checking = false;
  final monitor = Timer.periodic(const Duration(seconds: 1), (_) async {
    if (checking || cancelled) return;
    checking = true;
    try {
      await guard();
    } on Object {
      cancel();
    } finally {
      checking = false;
    }
  });
  try {
    await guard();
    return await run.run();
  } finally {
    deadline.cancel();
    monitor.cancel();
    client.close();
    authClient.close();
    auth.cancel();
    if (auth is GoogleDesktopAuth) auth.client.close();
    if (auth is _AndroidSilentAuth) auth.client.close();
    if (Platform.isAndroid) _channel.setMethodCallHandler(null);
  }
}

/// A late worker refresh must not restore credentials after foreground sign-out.
class _BackgroundCredentials implements GoogleCredentialStore {
  _BackgroundCredentials(this.inner, this.guard);
  final GoogleCredentialStore inner;
  final Future<void> Function() guard;
  @override
  Future<String?> read() async {
    await guard();
    return inner.read();
  }

  @override
  Future<void> write(String value) async {
    await guard();
    await inner.write(value);
  }

  @override
  Future<void> delete() async =>
      throw const GoogleCloudError('reauth', 'Manage accounts in Orbit.');
}

class _GuardedClient extends http.BaseClient {
  _GuardedClient(this.inner, this.guard);
  final http.Client inner;
  final Future<void> Function() guard;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await guard();
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

/// Previously authorized scopes only. A consent resolution is an error in a job.
class _AndroidSilentAuth implements GoogleAccountAuth {
  final client = http.Client();
  GoogleAccount? _account;
  String? _token;
  bool _cancelled = false;
  @override
  bool get configured => true;
  @override
  GoogleAccount? get account => _account;
  @override
  Future<GoogleAccount?> restore() async {
    final raw = await const SecureGoogleCredentials(
      'orbit.google.android.v1',
    ).read();
    if (raw == null) return null;
    final expected = GoogleAccount.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    _account = expected;
    final token = await accessToken();
    final response = await client
        .get(
          Uri.https('openidconnect.googleapis.com', '/v1/userinfo'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (_cancelled ||
        response.statusCode != 200 ||
        (jsonDecode(response.body) as Map)['sub'] != expected.subject) {
      _account = null;
      throw const GoogleCloudError(
        'reauth',
        'Reconnect Google Drive in Orbit.',
      );
    }
    return expected;
  }

  @override
  Future<String> accessToken({bool refresh = false}) async {
    if (_cancelled || _account == null) {
      throw const GoogleCloudError(
        'reauth',
        'Reconnect Google Drive in Orbit.',
      );
    }
    if (!refresh && _token != null) return _token!;
    try {
      final token = await _channel
          .invokeMethod<String>('authorize', {
            'email': _account!.email,
            'scopes': googleScopes,
            if (refresh) 'clear': _token,
          })
          .timeout(const Duration(seconds: 30));
      if (_cancelled || token == null || token.isEmpty) {
        throw const FormatException();
      }
      return _token = token;
    } on Object {
      throw const GoogleCloudError(
        'reauth',
        'Reconnect Google Drive in Orbit to resume background checks.',
      );
    }
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  Future<GoogleAccount> signIn({String? expectedSubject}) async =>
      throw const GoogleCloudError('reauth', 'Open Orbit to sign in.');
  @override
  Future<void> signOut() async {
    cancel();
    _account = null;
  }
}
