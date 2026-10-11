import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import '../../app/collaboration_controller.dart';
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
  CollaborationController get c => widget.controller;
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
      if (mounted) setState(() => error = '$e');
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
    final data = jsonDecode(invitation.text) as Map;
    final endpoint = CollaborationController.validateEndpoint(
      data['server'] as String,
    );
    final room = data['room'] as String, token = data['token'] as String;
    final state = await c.inspectRoom(endpoint, room, token);
    if (state['workspaceId'] != c.workspace.repository.workspaceId) {
      if (c.workspace.repository.isBrowser) {
        throw StateError(
          'Import the shared Vault on desktop first. Browser collaboration is not enabled yet.',
        );
      }
      final bundle = BackupBundle.parse(
        await c.downloadRoom(endpoint, room, token),
      );
      if (!mounted ||
          await showDialog<bool>(
                context: context,
                builder: (_) => BackupImportDialog(bundle: bundle),
              ) !=
              true) {
        return;
      }
      final parent = await getDirectoryPath(
        confirmButtonText: 'Import shared Vault here',
      );
      if (parent == null || !await c.workspace.flushAll()) return;
      final path = await importBackup(bundle, parent);
      await c.workspace.initialize(path: path);
    }
    await c.connect(endpoint, room, token);
  });
  Future<void> invite() => run(() async {
    final token = await c.invite(name.text, inviteRole);
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
    builder: (context, _) => AlertDialog(
      title: const Text('Shared Vault'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share a copy of this entire Vault with your self-hosted server. Existing notes and Canvas boards support live edits. Attachments are included in the initial copy; new attachments and newly created objects need a new shared snapshot. Keep invitations private.',
              ),
              const SizedBox(height: 16),
              if (!c.connected) ...[
                TextField(
                  controller: server,
                  decoration: const InputDecoration(
                    labelText: 'Server address',
                    helperText: 'HTTPS remotely · HTTP for localhost',
                  ),
                ),
                TextField(
                  controller: ownerKey,
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
                FilledButton(
                  onPressed: busy ? null : host,
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
                  onPressed: busy ? null : join,
                  child: const Text('Join shared Vault'),
                ),
              ] else ...[
                Text(c.status),
                Text('Access: ${c.role}'),
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
