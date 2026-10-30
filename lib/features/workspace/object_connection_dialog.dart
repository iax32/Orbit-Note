import '../../app/orbit_components.dart';
import 'package:flutter/material.dart';
import '../../app/workspace_controller.dart';
import '../../domain/json_values.dart';
import '../../domain/project_context.dart';
import '../../domain/research_workspace.dart';
import '../../domain/universal_object.dart';

Future<bool?> showObjectConnectionEditor(
  BuildContext context,
  WorkspaceController c,
  UniversalObject source,
  UniversalObject destination, {
  required int generation,
  String? expectedSourceVersion,
}) => showOrbitDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ConnectionEditor(
    controller: c,
    source: source,
    destination: destination,
    generation: generation,
    sourceVersion: expectedSourceVersion ?? researchVersion(source),
  ),
);

class _ConnectionEditor extends StatefulWidget {
  const _ConnectionEditor({
    required this.controller,
    required this.source,
    required this.destination,
    required this.generation,
    required this.sourceVersion,
  });
  final WorkspaceController controller;
  final UniversalObject source, destination;
  final int generation;
  final String sourceVersion;
  @override
  State<_ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<_ConnectionEditor> {
  late final target = TextEditingController(text: widget.destination.id);
  final note = TextEditingController();
  String kind = projectConnectionKinds.first, error = '';
  bool saving = false;
  UniversalObject? pending;
  @override
  void dispose() {
    target.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!mounted || saving) return;
    final c = widget.controller;
    if (widget.generation != c.workspaceGeneration) {
      setState(() => error = 'The Vault changed. Close and reopen this form.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    var ok = false;
    try {
      if (pending case final expected?) {
        // Retry only our retained local draft; never replace a newer relation list.
        if (c.editObjectMetadata(
          expected,
          generation: widget.generation,
          changes: {
            'orbitConnections': expected.properties['orbitConnections'],
          },
        )) {
          await c.retry(expected.id);
          ok =
              widget.generation == c.workspaceGeneration &&
              c.find(expected.id)?.isDeleted == false &&
              !c.dirty.contains(expected.id) &&
              !c.failures.containsKey(expected.id) &&
              jsonValuesEqual(
                c.find(expected.id)?.properties['orbitConnections'],
                expected.properties['orbitConnections'],
              );
        }
      } else {
        final before = c.find(widget.source.id);
        ok = await c.addProjectConnection(
          widget.source.id,
          kind,
          target.text.trim(),
          note.text,
          expectedSourceVersion: widget.sourceVersion,
          expectedGeneration: widget.generation,
        );
        if (widget.generation == c.workspaceGeneration) {
          final after = c.find(widget.source.id);
          if (!ok &&
              after != null &&
              c.dirty.contains(after.id) &&
              !jsonValuesEqual(
                before?.properties['orbitConnections'],
                after.properties['orbitConnections'],
              )) {
            pending = after;
          }
        }
      }
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(
          () => error = pending == null
              ? 'Connection not saved. The source changed, the connection exists, or its target is unavailable. Your draft is retained.'
              : 'The connection draft is retained locally. Retry its save or close and review save status.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not save. Your draft is retained; check local save status.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Connect objects'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.source.title} → ${widget.destination.title}'),
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                items: [
                  for (final k in projectConnectionKinds)
                    DropdownMenuItem(value: k, child: Text(k)),
                ],
                onChanged: saving || pending != null
                    ? null
                    : (v) => setState(() => kind = v!),
              ),
              TextField(
                controller: target,
                enabled: !saving && pending == null,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Target reference',
                  helperText:
                      'Optional #page=3, #heading, #^block, or #element=ID',
                ),
              ),
              TextField(
                controller: note,
                enabled: !saving && pending == null,
                maxLength: 2000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Why these are connected',
                ),
              ),
              if (error.isNotEmpty)
                Semantics(liveRegion: true, child: Text(error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving
                ? 'Saving…'
                : pending != null
                ? 'Retry local save'
                : 'Add connection',
          ),
        ),
      ],
    ),
  );
}
