import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../app/retained_form.dart';
import 'package:flutter/services.dart';
import '../../application/workspace_recovery.dart';
import '../../application/workspace_repository.dart';
import '../../platform/export_file.dart';

Future<void> showWorkspaceRecoveryDialog({
  required BuildContext context,
  required WorkspaceRepository repository,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => WorkspaceRecoveryDialog(repository: repository),
);

class WorkspaceRecoveryDialog extends StatefulWidget {
  const WorkspaceRecoveryDialog({
    super.key,
    required this.repository,
    this.exportCopy,
  });
  final WorkspaceRepository repository;
  final Future<bool> Function(String name, Uint8List bytes)? exportCopy;

  @override
  State<WorkspaceRecoveryDialog> createState() =>
      _WorkspaceRecoveryDialogState();
}

class _WorkspaceRecoveryDialogState extends State<WorkspaceRecoveryDialog> {
  late Future<List<WorkspaceRecoveryFile>> _files;
  WorkspaceRecoverySnapshot? _snapshot;
  String? _selectedPath, _error;
  int _generation = 0;
  bool _loading = false, _exporting = false;

  Widget _keptForms() {
    final owner = RetainedForm.capture(context, 'recovery', {});
    if (owner == null ||
        !identical(owner.controller.repository, widget.repository)) {
      return const SizedBox.shrink();
    }
    final raw = owner.controller.session.extra['retainedForms'];
    if (raw is! Map || raw['version'] != 1 || raw['entries'] is! Map) {
      return const SizedBox.shrink();
    }
    final entries = (raw['entries'] as Map).entries
        .where(
          (e) =>
              e.key is String &&
              e.value is Map &&
              (e.value as Map)['values'] is Map,
        )
        .take(25)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Kept form drafts · ${entries.length}'),
      children: [
        SizedBox(
          height: 160,
          child: ListView(
            children: [
              for (final entry in entries)
                Builder(
                  builder: (context) {
                    final key = entry.key as String, parts = key.split(':');
                    final kind = switch (parts.first) {
                      'reference' => 'Reference details',
                      'figure' => 'Figure caption and sources',
                      'pdf-review' => 'PDF review',
                      _ => 'Form draft',
                    };
                    final original = parts.length > 1
                        ? owner.controller.find(parts[1])
                        : null;
                    return ListTile(
                      title: Text(
                        '$kind · ${original?.title ?? "Original unavailable"}',
                      ),
                      subtitle: Text(
                        '${(entry.value as Map)["savedAt"] ?? "Time unavailable"}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _inspectKeptForm(key, kind),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _inspectKeptForm(String key, String title) async {
    final draft = RetainedForm.capture(context, key, {});
    if (draft == null ||
        !identical(draft.controller.repository, widget.repository)) {
      return;
    }
    final values = draft.recovered;
    if (values == null) return;
    final text = const JsonEncoder.withIndent('  ').convert(values);
    final ownerId = key.split(':').length > 1 ? key.split(':')[1] : '';
    final original = draft.controller.find(ownerId);
    final action = await showOrbitDialog<String>(
      context: context,
      builder: (context) => OrbitDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unapplied input. Open the original and its form to review and apply it. Copy the contents before discarding a draft you may need.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  text.length > 20000
                      ? '${text.substring(0, 20000)}\n… Copy contents preserves all text.'
                      : text,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'copy'),
            child: const Text('Copy contents'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard draft…'),
          ),
          if (original != null && !original.isDeleted)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'open'),
              child: const Text('Open original'),
            ),
        ],
      ),
    );
    if (!mounted || !draft.current) return;
    try {
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: text));
      } else if (action == 'open') {
        draft.controller.openObject(ownerId);
        Navigator.pop(context);
      } else if (action == 'discard') {
        final confirmed = await showOrbitDialog<bool>(
          context: context,
          builder: (context) => OrbitDialog(
            title: const Text('Discard retained form draft?'),
            content: const Text(
              'This removes the unapplied form input. Your original note, Canvas and PDF are unchanged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep draft'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard draft'),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          await draft.discard();
          if (mounted) setState(() {});
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void initState() {
    super.initState();
    _files = widget.repository.recoveryFiles();
  }

  void _refresh() {
    _generation++;
    setState(() {
      _snapshot = null;
      _selectedPath = null;
      _error = null;
      _loading = false;
      _files = widget.repository.recoveryFiles();
    });
  }

  Future<void> _select(WorkspaceRecoveryFile file) async {
    final generation = ++_generation;
    setState(() {
      _selectedPath = file.path;
      _snapshot = null;
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.readRecoveryFile(file.path);
      if (!mounted || generation != _generation) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Could not read this file: $error');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _export() async {
    final snapshot = _snapshot;
    if (snapshot == null || _exporting) return;
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      final name = 'Recovered-${snapshot.path.split('/').last}';
      final saved =
          await (widget.exportCopy?.call(name, snapshot.bytes) ??
              exportBinaryFile(name, snapshot.bytes));
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recovery copy exported. The retained original is unchanged.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _preview(WorkspaceRecoverySnapshot snapshot) {
    // Avoid decoding/rendering multi-megabyte journals or binary payloads.
    final bytes = snapshot.bytes;
    final sample = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
    if (sample.contains(0)) {
      return 'Binary recovery copy. Export to inspect it with the appropriate application.';
    }
    try {
      final text = utf8.decode(sample, allowMalformed: bytes.length > 8192);
      return '$text${bytes.length > 8192 ? '\n\n… Preview limited to 8 KiB. Export preserves every byte.' : ''}';
    } on FormatException {
      return 'This file is not UTF-8 text. Export preserves the original bytes.';
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    maxWidth: 760,
    title: const Text('Recovery files'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Review copies retained after an interrupted save or conflict. Export a copy before resolving anything in the Vault folder. Files are never applied or deleted here.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Unapplied form drafts reopen in their original Reference details, Figure caption and sources, or PDF Review dialog. A recovered draft requires your review. Unsaved editor conflicts appear in the editor recovery banner; inspect both versions before choosing one.',
        ),
        const SizedBox(height: 12),
        _keptForms(),
        SizedBox(
          height: 320,
          child: FutureBuilder<List<WorkspaceRecoveryFile>>(
            future: _files,
            builder: (context, result) {
              if (result.hasError) {
                return Center(
                  child: Text('Could not list recovery files: ${result.error}'),
                );
              }
              if (!result.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (result.data!.isEmpty) {
                return const Center(child: Text('No retained recovery files.'));
              }
              return ListView.builder(
                itemCount: result.data!.length,
                itemBuilder: (_, index) {
                  final file = result.data![index];
                  return ListTile(
                    selected: file.path == _selectedPath,
                    leading: const Icon(Icons.restore_page_outlined),
                    title: Text(
                      file.path,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${file.length} bytes',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: _exporting ? null : () => _select(file),
                  );
                },
              );
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_snapshot != null)
          SizedBox(
            height: 240,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _preview(_snapshot!),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _exporting ? null : _refresh,
        child: const Text('Refresh'),
      ),
      TextButton(
        onPressed: _exporting ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: _snapshot == null || _loading || _exporting ? null : _export,
        icon: const Icon(Icons.save_alt),
        label: Text(_exporting ? 'Exporting…' : 'Export a copy'),
      ),
    ],
  );
}
