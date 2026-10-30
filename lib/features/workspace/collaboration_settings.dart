import 'shared_server_setup.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/live_host_provider.dart';
import 'package:file_selector/file_selector.dart';
import '../../app/collaboration_controller.dart';
import 'canvas_conflict_dialog.dart';
import '../../app/orbit_components.dart';
import '../../application/backup_execution.dart';
import '../../platform/import_backup.dart';
import '../../platform/android_vault_folders.dart';
import 'backup_import_dialog.dart';

Future<void> showCollaborationSettings(
  BuildContext context,
  CollaborationController collaboration,
) async {
  final route = DialogRoute<void>(
    context: context,
    builder: (_) => _CollaborationSettings(collaboration),
  );
  await Navigator.of(context).push(route);
  await route.completed;
}

class _CollaborationSettings extends ConsumerStatefulWidget {
  const _CollaborationSettings(this.controller);
  final CollaborationController controller;
  @override
  ConsumerState<_CollaborationSettings> createState() =>
      _CollaborationSettingsState();
}

class _CollaborationSettingsState
    extends ConsumerState<_CollaborationSettings> {
  final server = TextEditingController(text: 'http://127.0.0.1:47831');
  final ownerKey = TextEditingController(),
      name = TextEditingController(),
      invitation = TextEditingController();
  String inviteRole = 'editor';
  String? error;
  bool busy = false;
  bool advanced = false;
  bool rememberAfterJoin = true;
  String? _tabletInvitation, _tabletRoom;
  String? serverStatus;
  String? progress;
  String hostingRoute = 'relay';
  final ownAddress = TextEditingController();
  CollaborationController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (c.secrets != null) {
      scheduleMicrotask(() {
        if (mounted) run(c.loadSavedConnection);
      });
    }
  }

  @override
  void dispose() {
    server.dispose();
    ownerKey.dispose();
    name.dispose();
    invitation.dispose();
    ownAddress.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      progress = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : e is StateError
              ? e.message
              : 'The connection could not complete. Check the server address, invitation and access permissions. Your local files are safe.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
        });
      }
    }
  }

  Future<void> host() => run(() async {
    final endpoint = CollaborationController.validateEndpoint(server.text);
    final result = await c.createRoom(
      endpoint,
      ownerKey.text.trim(),
      name.text,
    );
    await c.connect(
      endpoint,
      result['room'] as String,
      result['token'] as String,
    );
  });
  Future<void> startEasy() async {
    Uri? publicAddress;
    if (hostingRoute == 'own-address') {
      try {
        publicAddress = CollaborationController.validateEndpoint(
          ownAddress.text,
        );
        if (publicAddress.scheme != 'https' ||
            !{'', '/'}.contains(publicAddress.path)) {
          throw const FormatException(
            'Enter your HTTPS address without a path.',
          );
        }
      } on FormatException catch (e) {
        setState(() => error = e.message);
        return;
      }
    }
    final accepted = await showOrbitDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start live sharing?'),
        content: Text(
          'This shares the current Vault, including attachments, Archive and Trash, with devices you invite. '
          '${hostingRoute == 'tailscale'
              ? 'Orbit starts a private HTTPS connection through your installed Tailscale network. Sign in to the same network on the tablet. HTTPS may need a one-time Tailscale approval. Orbit uses port 8443 for this session and will not replace an existing service.'
              : hostingRoute == 'own-address'
              ? 'Orbit starts its server on this PC at 127.0.0.1:47831. Your HTTPS proxy must forward to that address. Orbit verifies that your HTTPS address reaches this new server before sharing.'
              : 'A temporary HTTPS connection uses Cloudflare to reach this PC; traffic passes through Cloudflare and is not end-to-end encrypted. No account or domain is needed. A verified connection helper is downloaded on first use.'} '
          'Keep Orbit open on this PC. Stopping or restarting needs a new invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start live sharing'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await run(() async {
      final opening = c.workspace.workspaceGeneration;
      final live = ref.read(liveHostProvider);
      if (!await c.workspace.flushAll()) {
        throw StateError(
          'Save your current work before starting live sharing.',
        );
      }
      c.disconnect();
      try {
        await live.start(route: hostingRoute, publicAddress: publicAddress);
        if (!mounted || c.workspace.workspaceGeneration != opening) {
          throw StateError(
            'Vault changed. Start sharing again in the current Vault.',
          );
        }
        setState(
          () => progress = 'Preparing this Vault for your other devices…',
        );
        final result = await c.createRoom(
          live.localEndpoint!,
          live.ownerToken!,
          name.text.trim().isEmpty ? 'My PC' : name.text.trim(),
        );
        if (!mounted || c.workspace.workspaceGeneration != opening) {
          throw StateError('Vault changed. Start sharing again.');
        }
        await c.connect(
          live.localEndpoint!,
          result['room'] as String,
          result['token'] as String,
        );
        c.invitationEndpoint = live.endpoint;
        _tabletInvitation = _tabletRoom = null;
        setState(() => progress = 'Ready. Copy the invitation to your tablet.');
      } catch (_) {
        await live.stop();
        rethrow;
      }
    });
  }

  Future<void> copyTabletInvitation() => run(() async {
    final room = c.room, address = c.invitationServer;
    if (room == null || address == null) {
      throw StateError('Start live sharing first.');
    }
    if (_tabletInvitation == null || _tabletRoom != room) {
      final token = await c.invite('My tablet', 'editor');
      if (!mounted || c.room != room || c.invitationServer != address) return;
      _tabletInvitation = jsonEncode({
        'version': 1,
        'server': '$address',
        'room': room,
        'token': token,
      });
      _tabletRoom = room;
    }
    await Clipboard.setData(ClipboardData(text: _tabletInvitation!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invitation copied. Paste it into Join shared Vault on your tablet.',
          ),
        ),
      );
    }
  });
  Future<void> join() => run(() async {
    final opening = c.workspace.workspaceGeneration;
    bool owns() => mounted && c.workspace.workspaceGeneration == opening;
    Object? decoded;
    try {
      decoded = jsonDecode(invitation.text.trim());
    } on FormatException {
      throw const FormatException(
        'Paste the entire private invitation copied from your PC.',
      );
    }
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['server'] is! String ||
        decoded['room'] is! String ||
        decoded['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(decoded['room'] as String) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(decoded['token'] as String)) {
      throw const FormatException(
        'This invitation is incomplete. Copy a new tablet invitation from your PC.',
      );
    }
    final data = decoded;
    final endpoint = CollaborationController.validateEndpoint(
      data['server'] as String,
    );
    if (!advanced &&
        ['localhost', '127.0.0.1', '::1'].contains(endpoint.host)) {
      throw StateError(
        'This invitation points to the device itself. On your PC choose Start live sharing, then Copy tablet invitation. Paste that new invitation here.',
      );
    }
    final room = data['room'] as String, token = data['token'] as String;
    setState(() => progress = 'Connecting to your PC…');
    final state = await c.inspectRoom(endpoint, room, token);
    if (!owns()) return;
    if (state['workspaceId'] != c.workspace.repository.workspaceId) {
      if (c.workspace.repository.isBrowser) {
        throw StateError(
          'Import the shared Vault on desktop first. Browser collaboration is not enabled yet.',
        );
      }
      setState(
        () => progress =
            'Downloading and checking your Vault. The first connection copies its files; later edits arrive live.',
      );
      final bundle = await parseBackupBundle(
        await c.downloadRoom(endpoint, room, token),
      );
      if (!mounted || !owns()) return;
      if (await showOrbitDialog<bool>(
            context: context,
            builder: (_) => BackupImportDialog(bundle: bundle),
          ) !=
          true) {
        return;
      }
      if (!owns()) return;
      final parent = usesAndroidVaultFolders
          ? await localBackupImportParent()
          : await getDirectoryPath(
              confirmButtonText: 'Import shared Vault here',
            );
      if (parent == null ||
          !owns() ||
          !await c.workspace.flushAll() ||
          !owns()) {
        return;
      }
      final path = await importBackup(bundle, parent);
      if (!owns()) {
        throw StateError(
          'The downloaded folder was created, but your active Vault changed; it was not opened.',
        );
      }
      await c.workspace.initialize(path: path);
      if (!mounted ||
          c.workspace.repository.location != path ||
          c.workspace.repository.workspaceId != state['workspaceId']) {
        return;
      }
    }
    if (mounted) setState(() => progress = 'Opening live editing…');
    await c.connect(endpoint, room, token);
    if (rememberAfterJoin && c.canRememberConnection) {
      try {
        await c.rememberConnection(autoReconnect: true);
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connected. This device could not remember the connection; use Remember connection to retry.',
              ),
            ),
          );
        }
      }
    }
  });
  Future<void> invite() => run(() async {
    final room = c.room, opening = c.workspace.workspaceGeneration;
    final token = await c.invite(name.text, inviteRole);
    if (!mounted ||
        c.room != room ||
        c.workspace.workspaceGeneration != opening) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: jsonEncode({
          'version': 1,
          'server': '${c.invitationServer}',
          'room': c.room,
          'token': token,
        }),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation copied. Send it privately to this person.'),
        ),
      );
    }
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, ref.watch(liveHostProvider)]),
    builder: (context, _) => OrbitDialog(
      title: const Text('Shared Vault'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit the same Vault on your PC and tablet. Start sharing on the PC, then paste its private invitation on the tablet. Both apps need to stay open. Keep invitations private.',
              ),
              const SizedBox(height: 16),
              if (busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(progress ?? 'Connecting…'),
                const SizedBox(height: 12),
              ],
              if (ref.read(liveHostProvider).supported) ...[
                if (ref.read(liveHostProvider).endpoint == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: hostingRoute,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'How to connect your devices',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'relay',
                        child: Text('Temporary internet link'),
                      ),
                      DropdownMenuItem(
                        value: 'tailscale',
                        child: Text('Private network · Tailscale'),
                      ),
                      DropdownMenuItem(
                        value: 'own-address',
                        child: Text('My own HTTPS address'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => hostingRoute = value!),
                  ),
                  const SizedBox(height: 8),
                  if (hostingRoute == 'tailscale') ...[
                    const Text(
                      'Install Tailscale on your PC and tablet, and sign in to the same network. Orbit starts the server and makes your invitation. No router changes or scripts.',
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse('https://tailscale.com/download'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text('Get Tailscale'),
                    ),
                  ],
                  if (hostingRoute == 'own-address') ...[
                    TextField(
                      controller: ownAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Your HTTPS address',
                        hintText: 'https://notes.example.com',
                      ),
                    ),
                    const Text(
                      'Forward your HTTPS proxy to 127.0.0.1:47831 on this PC. Orbit starts the server for you and checks the connection.',
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed:
                      busy ||
                          ref.read(liveHostProvider).busy ||
                          ref.read(liveHostProvider).endpoint != null
                      ? null
                      : startEasy,
                  icon: const Icon(Icons.devices),
                  label: const Text('Start live sharing'),
                ),
                const SizedBox(height: 8),
                Text(ref.read(liveHostProvider).status),
                if (ref.read(liveHostProvider).setupAddress case final address?)
                  TextButton(
                    onPressed: () => launchUrl(
                      address,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Enable HTTPS in Tailscale'),
                  ),
                if (ref.read(liveHostProvider).busy)
                  const LinearProgressIndicator(),
                if (ref.read(liveHostProvider).endpoint != null && c.connected)
                  FilledButton.icon(
                    onPressed: busy ? null : copyTabletInvitation,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy tablet invitation'),
                  ),
                if (ref.read(liveHostProvider).endpoint != null ||
                    ref.read(liveHostProvider).busy)
                  TextButton(
                    onPressed: () async {
                      c.disconnect();
                      await ref.read(liveHostProvider).stop();
                    },
                    child: const Text('Stop live sharing'),
                  ),
                const Divider(height: 24),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'On your Windows PC choose Start live sharing → Copy tablet invitation. Paste it below and join.',
                  ),
                ),
              if (c.hasSavedConnection) ...[
                Text('Saved on this device: ${c.savedServer}'),
                const Text(
                  'Reconnect restores this Vault’s server access. It does not upload a new snapshot or switch Vaults.',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy || c.profileBusy || c.connecting
                          ? null
                          : () => run(c.reconnectSaved),
                      child: const Text('Reconnect saved server'),
                    ),
                    TextButton(
                      onPressed: busy || c.profileBusy
                          ? null
                          : () => run(c.forgetSavedConnection),
                      child: const Text('Forget saved connection'),
                    ),
                  ],
                ),
                const Divider(height: 24),
              ],
              if (!c.connected) ...[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Advanced: use my own server'),
                  value: advanced,
                  onChanged: busy ? null : (v) => setState(() => advanced = v),
                ),
                if (advanced) ...[
                  SharedServerSetup(
                    onUseAddress: (value) {
                      server.text = value;
                      setState(() => serverStatus = null);
                    },
                  ),
                  TextField(
                    controller: server,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => setState(() => serverStatus = null),
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      helperText: 'HTTPS remotely · HTTP for localhost',
                    ),
                  ),
                  TextField(
                    controller: ownerKey,
                    onChanged: (_) => setState(() => serverStatus = null),
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Server owner key',
                    ),
                  ),
                  TextField(
                    controller: name,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Your display name',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy || c.connecting
                        ? null
                        : () => run(() async {
                            final address = server.text,
                                key = ownerKey.text.trim();
                            setState(() => serverStatus = null);
                            final endpoint =
                                CollaborationController.validateEndpoint(
                                  address,
                                );
                            final info = await c.testServer(endpoint, key);
                            if (mounted &&
                                server.text == address &&
                                ownerKey.text.trim() == key) {
                              setState(
                                () => serverStatus =
                                    'Server ready · protocol ${info['protocol']} · ${info['rooms']} shared Vault(s). No Vault uploaded.',
                              );
                            }
                          }),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.network_check),
                        SizedBox(width: 8),
                        Flexible(child: Text('Test server connection')),
                      ],
                    ),
                  ),
                  if (serverStatus != null) Text(serverStatus!),
                  const Text(
                    'Run collaboration/Start Orbit Server.cmd on the host, then enter the private owner key from its data folder. Other devices need an HTTPS address that reaches that host; localhost refers to this device.',
                  ),
                  FilledButton(
                    onPressed: busy || c.connecting || !c.workspace.hasWorkspace
                        ? null
                        : host,
                    child: const Text('Share this Vault'),
                  ),
                ],
                const Divider(height: 32),
                TextField(
                  controller: invitation,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Paste private invitation',
                  ),
                ),
                OutlinedButton(
                  onPressed: busy || c.connecting || !c.workspace.hasWorkspace
                      ? null
                      : join,
                  child: const Text('Join shared Vault'),
                ),
                if (c.secrets != null)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remember and reconnect automatically'),
                    subtitle: const Text(
                      'Store this private connection securely on this device. The PC must remain on. You can disconnect or forget it anytime.',
                    ),
                    value: rememberAfterJoin,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => rememberAfterJoin = value),
                  ),
              ] else ...[
                Text(c.status),
                Text('Host: ${c.endpoint}'),
                Text('Access: ${c.role}'),
                if (c.lastAcknowledgedAt != null)
                  Text(
                    'Last acknowledged: ${c.lastAcknowledgedAt!.toLocal().toIso8601String().substring(0, 19).replaceAll('T', ' ')}',
                  ),
                OutlinedButton.icon(
                  onPressed: busy || c.busy ? null : () => run(c.retryNow),
                  icon: const Icon(Icons.sync),
                  label: const Text('Check shared changes now'),
                ),
                Text('${c.pendingChanges} shared document(s) pending'),
                if (!c.liveReplication)
                  const Text(
                    'Legacy shared snapshot: new objects, attachments and deletions require a new shared Vault. Create it with the updated host to enable live replication.',
                  ),
                if (c.retryAt != null || c.accessBlocked)
                  OutlinedButton.icon(
                    onPressed: busy || c.busy ? null : () => run(c.retryNow),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry now'),
                  ),
                const Text(
                  'Save your own connection privately so you can reconnect after restarting. It grants your current access.',
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: c.connectionInvitation),
                        ),
                  child: const Text('Copy my connection'),
                ),
                if (c.canRememberConnection)
                  OutlinedButton(
                    onPressed: busy || c.profileBusy
                        ? null
                        : () => run(c.rememberConnection),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Remember connection on this device'),
                        ),
                      ],
                    ),
                  ),
                if (c.canRememberConnection)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reconnect when Orbit opens'),
                    subtitle: const Text(
                      'Remember this server securely and reconnect on launch or resume. Disconnect stops reconnecting for this opening. No closed-app mobile service is installed.',
                    ),
                    value: c.autoReconnectSaved,
                    onChanged: busy || c.profileBusy
                        ? null
                        : (value) => run(
                            () => c.rememberConnection(autoReconnect: value),
                          ),
                  ),
                const Text(
                  'Remembering saves your private room connection in device secure storage. It is never exported with the Vault. Automatic reconnect is optional; Disconnect stops this session and Forget removes the saved connection.',
                ),
                if (c.role == 'owner') ...[
                  TextField(
                    controller: name,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Person to invite · display name',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: inviteRole,
                    decoration: const InputDecoration(labelText: 'Access'),
                    items: const [
                      DropdownMenuItem(value: 'editor', child: Text('Editor')),
                      DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    ],
                    onChanged: (value) => inviteRole = value!,
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : invite,
                    child: const Text('Create private invitation'),
                  ),
                  TextField(
                    controller: invitation,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Paste invitation to revoke',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            final data = jsonDecode(invitation.text) as Map;
                            await c.revoke(data['token'] as String);
                          }),
                    child: const Text('Revoke invitation'),
                  ),
                ],
                for (final entry in c.conflicts.entries) ...[
                  const Divider(),
                  Text(
                    c.workspace.find(entry.key)?.title ?? entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(entry.value),
                  if (c.canReviewCanvas(entry.key))
                    OutlinedButton.icon(
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Review overlapping Canvas items'),
                      onPressed: busy || c.busy
                          ? null
                          : () => run(() async {
                              final review = await c.reviewCanvas(entry.key);
                              if (!context.mounted) return;
                              await showOrbitDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => CanvasConflictDialog(
                                  controller: c,
                                  review: review,
                                ),
                              );
                            }),
                    ),
                  const Text(
                    'Your current version remains saved locally. Adopting the server version keeps the complete before-image in file history for recovery.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(() => c.adoptServer(entry.key)),
                    child: const Text('Keep history and adopt server version'),
                  ),
                ],
                TextButton(
                  onPressed: busy ? null : c.disconnect,
                  child: const Text('Disconnect · keep local Vault'),
                ),
              ],
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (error != null &&
                  !c.hasSavedConnection &&
                  c.secrets != null &&
                  c.workspace.hasWorkspace)
                TextButton(
                  onPressed: busy || c.profileBusy
                      ? null
                      : () => run(c.forgetSavedConnection),
                  child: const Text('Forget saved connection'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class SharedDocumentSurface extends StatelessWidget {
  const SharedDocumentSurface({
    super.key,
    required this.controller,
    required this.objectId,
    required this.child,
    this.canvas = false,
  });
  final CollaborationController controller;
  final String objectId;
  final Widget child;
  final bool canvas;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    child: child,
    builder: (context, stableChild) {
      if (!controller.shares(objectId)) return stableChild!;
      final peers = controller.peers
          .where((p) => p['objectId'] == objectId)
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${controller.status}${peers.isEmpty ? '' : ' · ${peers.map((p) => p['name']).join(', ')}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.retryAt != null || controller.accessBlocked)
                  IconButton(
                    tooltip: 'Retry shared connection now',
                    onPressed: controller.busy ? null : controller.retryNow,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                IconButton(
                  tooltip: 'Shared Vault settings',
                  onPressed: () =>
                      showCollaborationSettings(context, controller),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => MouseRegion(
                onHover: canvas
                    ? null
                    : (event) => controller.cursor(
                        objectId,
                        event.localPosition.dx / constraints.maxWidth,
                        event.localPosition.dy / constraints.maxHeight,
                      ),
                child: Stack(
                  children: [
                    Positioned.fill(child: stableChild!),
                    if (!canvas)
                      for (final peer in peers.where(
                        (p) => p['space'] == 'note',
                      ))
                        Positioned(
                          left:
                              ((peer['x'] as num).toDouble().clamp(0, 1) *
                                      constraints.maxWidth)
                                  .clamp(
                                    0,
                                    (constraints.maxWidth - 120).clamp(
                                      0,
                                      double.infinity,
                                    ),
                                  ),
                          top:
                              ((peer['y'] as num).toDouble().clamp(0, 1) *
                                      constraints.maxHeight)
                                  .clamp(
                                    0,
                                    (constraints.maxHeight - 30).clamp(
                                      0,
                                      double.infinity,
                                    ),
                                  ),
                          child: IgnorePointer(
                            child: _PeerLabel(peer['name'] as String),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PeerLabel extends StatelessWidget {
  const _PeerLabel(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name cursor',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me, size: 12),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
