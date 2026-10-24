import 'shared_server_setup.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../app/collaboration_controller.dart';
import 'canvas_conflict_dialog.dart';
import '../../app/orbit_components.dart';
import '../../application/backup_bundle.dart';
import '../../platform/import_backup.dart';
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

class _CollaborationSettings extends StatefulWidget {
  const _CollaborationSettings(this.controller);
  final CollaborationController controller;
  @override
  State<_CollaborationSettings> createState() => _CollaborationSettingsState();
}

class _CollaborationSettingsState extends State<_CollaborationSettings> {
  final server = TextEditingController(text: 'http://127.0.0.1:47831');
  final ownerKey = TextEditingController(),
      name = TextEditingController(),
      invitation = TextEditingController();
  String inviteRole = 'editor';
  String? error;
  bool busy = false;
  String? serverStatus;
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
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'The connection could not complete. Check the server address, invitation and access permissions. Your local files are safe.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
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
  Future<void> join() => run(() async {
    final opening = c.workspace.workspaceGeneration;
    bool owns() => mounted && c.workspace.workspaceGeneration == opening;
    final data = jsonDecode(invitation.text) as Map;
    final endpoint = CollaborationController.validateEndpoint(
      data['server'] as String,
    );
    final room = data['room'] as String, token = data['token'] as String;
    final state = await c.inspectRoom(endpoint, room, token);
    if (!owns()) return;
    if (state['workspaceId'] != c.workspace.repository.workspaceId) {
      if (c.workspace.repository.isBrowser) {
        throw StateError(
          'Import the shared Vault on desktop first. Browser collaboration is not enabled yet.',
        );
      }
      final bundle = BackupBundle.parse(
        await c.downloadRoom(endpoint, room, token),
      );
      if (!mounted || !owns()) return;
      if (await showDialog<bool>(
            context: context,
            builder: (_) => BackupImportDialog(bundle: bundle),
          ) !=
          true) {
        return;
      }
      if (!owns()) return;
      final parent = await getDirectoryPath(
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
    await c.connect(endpoint, room, token);
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
          'server': '${c.endpoint}',
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
    listenable: c,
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
                'Share this Vault with your self-hosted server. Updated hosts transfer new objects, verified attachments, Trash and permanent deletions, and send live change notifications. Notes show source-checked collaborator cursors and selections. Conflicting edits remain recoverable. Keep invitations private.',
              ),
              const SizedBox(height: 16),
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
                              CollaborationController.validateEndpoint(address);
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
                              await showDialog<void>(
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
