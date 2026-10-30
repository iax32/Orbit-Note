import '../../app/orbit_components.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:file_selector/file_selector.dart';
import '../../domain/code_project.dart';
import '../../domain/university/lab_document.dart';
import '../../domain/university/lab_presets.dart';
import '../../domain/university/protocol_lab.dart';
import '../../domain/university/state_lab.dart';
import '../../platform/university_tools.dart';
import '../../canvas/university_diagram.dart';
import '../../canvas/scene.dart';
import '../../canvas/geometry.dart';
import '../../domain/university/activity_lab.dart';
import 'university_preview.dart';

Future<UniversityDocument?> showUniversityLab(
  BuildContext context, {
  UniversityDocument? initial,
}) => showOrbitDialog<UniversityDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RepaintBoundary(
    key: const ValueKey('university-lab-capture'),
    child: UniversityLabDialog(initial: initial),
  ),
);

Future<void> recoverUniversityReport(
  BuildContext context,
  UniversityDocument document,
  String reason,
) => showOrbitDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: const Text('Keep unsaved university report'),
    content: Text(
      '$reason\n\nYour model and report are still available here. Copy portable Markdown before closing, then paste it into a note.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Discard result'),
      ),
      FilledButton(
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: document.markdown));
            if (context.mounted) Navigator.pop(context);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
        child: const Text('Copy model & report'),
      ),
    ],
  ),
);

class UniversityLabDialog extends StatefulWidget {
  const UniversityLabDialog({super.key, this.initial});
  final UniversityDocument? initial;
  @override
  State<UniversityLabDialog> createState() => _UniversityLabDialogState();
}

class _UniversityLabDialogState extends State<UniversityLabDialog> {
  late UniversityDocument doc =
      widget.initial ?? universityPreset(UniversityLabKind.state);
  late final title = TextEditingController(text: doc.title),
      course = TextEditingController(text: labText(doc.data, 'course')),
      source = TextEditingController(text: labText(doc.data, 'source'));
  final host = TextEditingController(text: '127.0.0.1'),
      port = TextEditingController(text: '20000'),
      command = TextEditingController(text: 'exchange fanout animals'),
      executable = TextEditingController(text: 'dafny');
  final editors = <String, TextEditingController>{};
  final invalidFields = <String>{};
  String report = '', error = '', toolOutput = '';
  int steps = 0, generation = 0, toolBytes = 0;
  bool dirty = false, busy = false, reportCurrent = false;
  CanvasScene? previewScene;
  Set<String> activeNodes = {};
  LabProtocolConnection? connection;
  CodeToolProcess? process;
  StreamSubscription<String>? subscription;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    connection?.close();
    process?.stop();
    for (final c in [
      title,
      course,
      source,
      host,
      port,
      command,
      executable,
      ...editors.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void refresh() {
    for (final c in editors.values) {
      c.dispose();
    }
    editors.clear();
    invalidFields.clear();
    title.text = doc.title;
    course.text = labText(doc.data, 'course');
    source.text = labText(doc.data, 'source');
    steps = 0;
    report = '';
    error = '';
    reportCurrent = false;
  }

  UniversityDocument snapshot() => doc.updated({
    'title': title.text,
    'course': course.text,
    'source': source.text,
  });
  void updateModel(Map<String, dynamic> m) {
    if (doc.kind == UniversityLabKind.contracts) m = {...m, 'verification': ''};
    setState(() {
      doc = doc.updated({'model': m});
      dirty = true;
      reportCurrent = false;
      error = '';
      steps = 0;
    });
  }

  Widget field(String key, String label, {int lines = 1, bool json = false}) {
    final value = doc.model[key];
    final c = editors.putIfAbsent(
      key,
      () => TextEditingController(
        text: json
            ? const JsonEncoder.withIndent('  ').convert(value ?? {})
            : value is List
            ? value.join(', ')
            : value?.toString() ?? '',
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        maxLines: lines,
        minLines: lines > 4 ? 4 : null,
        enabled: !busy && connection == null,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          try {
            Object? next = json
                ? jsonDecode(text)
                : key == 'processes'
                ? text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList()
                : text;
            invalidFields.remove(key);
            updateModel({...doc.model, key: next});
          } catch (_) {
            setState(() {
              invalidFields.add(key);
              error = 'Invalid JSON in $label; fix it before saving.';
              reportCurrent = false;
              dirty = true;
            });
          }
        },
      ),
    );
  }

  Future<bool> confirmDiscard() async {
    if (!dirty && !busy && connection == null) return true;
    return await showOrbitDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard unsaved lab changes?'),
            content: const Text(
              'Inserted models stay in the note or Canvas. Unsaved edits and running tools in this dialog will be closed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> choose(UniversityLabKind kind) async {
    if (!await confirmDiscard() || !mounted) return;
    await stopTools();
    if (!mounted) return;
    setState(() {
      doc = universityPreset(kind);
      refresh();
      dirty = true;
    });
  }

  Future<void> stopTools() async {
    generation++;
    final p = process, c = connection;
    process = null;
    connection = null;
    await subscription?.cancel();
    subscription = null;
    await c?.close();
    await p?.stop();
    if (mounted) setState(() => busy = false);
  }

  void evaluate({bool single = false}) {
    if (invalidFields.isNotEmpty) return;
    try {
      final next = single ? steps + 1 : 500;
      final result = snapshot().report(through: next);
      final active = <String>{};
      if (doc.kind == UniversityLabKind.state) {
        final state = StateLab(doc.model);
        for (final e in labText(
          doc.model,
          'events',
        ).split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).take(next)) {
          state.send(e);
        }
        active.addAll(state.active);
      }
      if (doc.kind == UniversityLabKind.activity) {
        final activity = ActivityLab(doc.model);
        for (final e in labText(
          doc.model,
          'schedule',
        ).split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).take(next)) {
          if (e.startsWith('signal:')) {
            activity.signal(e.substring(7));
          } else {
            activity.step(e);
          }
        }
        active.addAll(activity.tokens.keys);
      }
      var serial = 0;
      final elements = universityDiagram(
        snapshot(),
        () => 'preview${serial++}',
        const CanvasPoint(0, 0),
      );
      final scene = CanvasScene.fromJson({
        'schemaVersion': 1,
        'elements': elements.map((e) => e.data).toList(),
      });
      setState(() {
        steps = next;
        report = result;
        error = '';
        reportCurrent = true;
        previewScene = scene;
        activeNodes = {
          for (final e in elements)
            if (e.data['universityNode'] is Map &&
                active.contains((e.data['universityNode'] as Map)['id']))
              e.id,
        };
      });
    } catch (e) {
      setState(() {
        error = '$e';
        reportCurrent = false;
      });
    }
  }

  Future<void> apply() async {
    if (busy || connection != null || invalidFields.isNotEmpty) return;
    try {
      final result = snapshot();
      result.report();
      Navigator.pop(context, result);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  Future<void> rowEditor(String key, {int? index}) async {
    final list = labRows(doc.model[key] ?? []),
        original = index == null ? <String, dynamic>{} : list[index];
    final defaults = _rowDefaults(key);
    final fields = {
      for (final e in {...defaults, ...original}.entries)
        if (e.key != '_key')
          e.key: TextEditingController(
            text: e.value is Map || e.value is List
                ? jsonEncode(e.value)
                : '${e.value}',
          ),
    };
    String message = '';
    final accepted = await showOrbitDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (c, change) => AlertDialog(
          title: Text(
            '${index == null ? 'Add' : 'Edit'} ${key.replaceAll('s', '')}',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'IDs connect model elements. Expressions support numbers, booleans, comparisons, && / ||; actions use assignments and ++ / --.',
                  ),
                  for (final e in fields.entries)
                    if ((original[e.key] ?? defaults[e.key]) is bool)
                      SwitchListTile(
                        title: Text(e.key),
                        value: e.value.text == 'true',
                        onChanged: (value) =>
                            change(() => e.value.text = '$value'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: e.value,
                          minLines: 1,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: e.key,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                  if (message.isNotEmpty) Text(message),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final next = <String, dynamic>{...original};
                  for (final e in fields.entries) {
                    final old = original[e.key] ?? defaults[e.key],
                        text = e.value.text;
                    next[e.key] = old is bool
                        ? (text == 'true'
                              ? true
                              : text == 'false'
                              ? false
                              : throw const FormatException(
                                  'Boolean fields use true or false.',
                                ))
                        : old is num
                        ? num.parse(text)
                        : old is Map || old is List
                        ? jsonDecode(text)
                        : text;
                  }
                  Navigator.pop(dialog, next);
                } catch (e) {
                  change(() => message = '$e');
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    for (final c in fields.values) {
      c.dispose();
    }
    if (!mounted || accepted == null) return;
    if (index == null) {
      list.add(accepted);
    } else {
      list[index] = accepted;
    }
    updateModel({...doc.model, key: list});
  }

  Map<String, dynamic> _rowDefaults(String key) => switch (key) {
    'states' => {
      'id': 'state${labRows(doc.model[key] ?? []).length + 1}',
      'name': 'New state',
      'parent': '',
      'region': '',
      'initial': false,
      'final': false,
      'entry': '',
      'do': '',
      'exit': '',
    },
    'transitions' => {
      'from': '',
      'to': '',
      'event': '',
      'guard': '',
      'actions': '',
      'internal': false,
      'history': false,
    },
    'nodes' when doc.kind == UniversityLabKind.activity => {
      'id': 'node${labRows(doc.model[key] ?? []).length + 1}',
      'name': 'Action',
      'kind': 'action',
      'lane': '',
      'region': '',
      'actions': '',
      'signal': '',
      'interruptRegion': '',
    },
    'nodes' when doc.kind == UniversityLabKind.uml => {
      'id': 'Class${labRows(doc.model[key] ?? []).length + 1}',
      'name': 'Class',
      'kind': 'class',
      'attributes': '',
      'operations': '',
      'class': '',
      'slots': '',
      'association': '',
    },
    'nodes' => {
      'id': 'block${labRows(doc.model[key] ?? []).length + 1}',
      'name': 'Basic block',
      'defs': '',
      'uses': '',
      'conditions': '',
    },
    'edges' => {
      'id': 'edge${labRows(doc.model[key] ?? []).length + 1}',
      'from': '',
      'to': '',
      'kind': 'association',
      'label': '',
      'guard': '',
      'exception': false,
      'fromMultiplicity': '',
      'toMultiplicity': '',
    },
    'tests' => {
      'name': 'Test case',
      'input': '',
      'expected': '',
      'observed': false,
      'actual': '',
      'path': '',
      'conditions': <String, dynamic>{},
    },
    'partitions' => {'name': 'input', 'min': 0, 'max': 100, 'step': 1},
    'events' => {
      'process': 'P1',
      'kind': 'local',
      'to': '',
      'message': '',
      'detail': '',
      'key': '',
      'version': 0,
    },
    'messages' => {
      'id': 'm${labRows(doc.model[key] ?? []).length + 1}',
      'from': '',
      'to': '',
      'label': '',
    },
    'fragments' => {'operator': 'strict', 'messages': '', 'guard': ''},
    _ => {},
  };
  Widget rows(String key, String label) {
    final list = labRows(doc.model[key] ?? []);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$label · ${list.length}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Add $label',
                  onPressed: busy ? null : () => rowEditor(key),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            for (var i = 0; i < list.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  [
                    list[i]['id'] ??
                        list[i]['name'] ??
                        list[i]['from'] ??
                        list[i]['process'] ??
                        '',
                    list[i]['to'] != null
                        ? '→ ${list[i]['to']}'
                        : list[i]['kind'] ?? '',
                  ].join(' '),
                ),
                subtitle: Text(
                  '${list[i]['name'] ?? list[i]['event'] ?? list[i]['path'] ?? list[i]['guard'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: busy ? null : () => rowEditor(key, index: i),
                trailing: IconButton(
                  tooltip: 'Remove $label ${i + 1}',
                  onPressed: busy
                      ? null
                      : () {
                          final next = List.of(list)..removeAt(i);
                          updateModel({...doc.model, key: next});
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> importJUnit() async {
    final before = doc;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JUnit XML', extensions: ['xml']),
        ],
      );
      if (file == null) return;
      if (await file.length() > 2000000) {
        throw const FormatException('JUnit report exceeds 2 MB.');
      }
      final text = await file.readAsString();
      if (!mounted || !identical(before, doc)) return;
      final next = {...doc.model, 'junit': text};
      snapshot().updated({'model': next}).report();
      updateModel(next);
      editors['junit']?.text = text;
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> advanced() async {
    final c = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(doc.model),
    );
    String message = '';
    final result = await showOrbitDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Portable model JSON'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: c,
                    minLines: 12,
                    maxLines: 24,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (message.isNotEmpty) Text(message),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final m = labMap(jsonDecode(c.text));
                  snapshot().updated({'model': m}).report();
                  Navigator.pop(dialog, m);
                } catch (e) {
                  set(() => message = '$e');
                }
              },
              child: const Text('Validate & apply'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (result != null && mounted) {
      updateModel(result);
      setState(refresh);
    }
  }

  Future<void> connect() async {
    final request = ++generation;
    setState(() => busy = true);
    try {
      final c = await connectUniversityProtocol(
        host.text,
        int.parse(port.text),
      );
      if (!mounted || generation != request) {
        await c.close();
        return;
      }
      connection = c;
      updateModel({...doc.model, 'transcript': ''});
      subscription = c.lines.listen(
        (line) {
          if (!mounted || generation != request) return;
          final text = '${labText(doc.model, 'transcript')}S> $line\n';
          if (text.length > 300000) {
            setState(
              () => error =
                  'Transcript reached its 300 KB limit. Disconnecting; existing observations are retained.',
            );
            stopTools();
            return;
          }
          doc = doc.updated({
            'model': {...doc.model, 'transcript': text},
          });
          editors['transcript']?.text = text;
          setState(() {
            dirty = true;
            reportCurrent = false;
          });
        },
        onError: (Object e) {
          if (mounted && generation == request) setState(() => error = '$e');
        },
        onDone: () {
          if (mounted && generation == request) {
            setState(() => connection = null);
          }
        },
      );
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => busy = false);
    }
  }

  Future<void> send() async {
    final c = connection;
    if (c == null) return;
    try {
      final text = labText(doc.model, 'transcript');
      // Validate against the transcript without silently sending out-of-order
      // commands. Socket errors never pretend to be successful acknowledgments.
      checkProtocolTranscript(text).client(command.text);
      final next =
          '$text'
          'C> ${command.text}\n';
      doc = doc.updated({
        'model': {...doc.model, 'transcript': next},
      });
      editors['transcript']?.text = next;
      setState(() {
        dirty = true;
        reportCurrent = false;
        busy = true;
      });
      await c.send(command.text);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    final code = labText(doc.model, 'code'), request = ++generation;
    setState(() {
      busy = true;
      toolOutput = '';
      error = '';
      toolBytes = 0;
    });
    try {
      final p = await verifyUniversityDafny(executable.text, code);
      if (!mounted || generation != request) {
        await p.stop();
        return;
      }
      process = p;
      subscription = p.output.listen((chunk) {
        if (mounted && generation == request) {
          setState(() => toolOutput += chunk);
        }
      });
      final exit = await p.exitCode;
      if (!mounted || generation != request) return;
      if (code != labText(doc.model, 'code')) {
        throw const FormatException(
          'Source changed; verifier result discarded.',
        );
      }
      final result = 'Local Dafny exit $exit\n$toolOutput';
      doc = doc.updated({
        'model': {...doc.model, 'verification': result},
      });
      setState(() {
        dirty = true;
        reportCurrent = false;
      });
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) {
        process = null;
        setState(() => busy = false);
      }
    }
  }

  Widget modelFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      switch (doc.kind) {
        UniversityLabKind.state => const Text(
          'Hierarchies: parent ID + region; exactly one initial state per region. Guards are boolean; entry/exit/actions accept assignments. Blank-event transitions are bounded automatic completion steps. do text is documentation, not an executing background activity.',
        ),
        UniversityLabKind.activity => const Text(
          'Kinds: start, action, decision, merge, fork, join, final, flowFinal, send, receive, call, object. Schedule selects enabled nodes; signal:name delivers a signal. Forks duplicate tokens, joins wait for every incoming control edge. Object nodes are explicit model elements; general UML object-token typing is not inferred.',
        ),
        UniversityLabKind.uml => const Text(
          'Declare class/object/associationClass/nary nodes and relationships. Objects use class IDs and slots. Messages reference item IDs. Trace checks use the declared order; expand alt/loop alternatives explicitly.',
        ),
        UniversityLabKind.testing => const Text(
          'Enter CFG blocks, edges, definitions/uses, input partitions and observed test paths. Coverage reflects these paths, not automatically instrumented Java. Enable observed and enter actual only after running/observing a test.',
        ),
        UniversityLabKind.distributed => const Text(
          'Events: local, send, receive, drop, crash, restart; write/read/replicate are labeled observations. Send needs a globally unique message ID; receive must match its recipient. Reordering events models delay. Vector clocks show causality, not physical time.',
        ),
        UniversityLabKind.protocol => const Text(
          'Offline SMQP transcript checker and optional explicit TCP connection. New connection starts a fresh transcript. Commands are sent only with Send. Use Code workspace for Java 21, Maven/Gradle profiles and JUnit execution.',
        ),
        UniversityLabKind.contracts => const Text(
          'Editable Dafny contracts. Verification runs an installed executable explicitly, in an isolated temporary folder, with a 45-second timeout. No verifier is bundled; no proof is claimed before the actual verifier runs.',
        ),
      },
      if ({
        UniversityLabKind.state,
        UniversityLabKind.activity,
        UniversityLabKind.uml,
      }.contains(doc.kind))
        field(
          'variables',
          'Initial variables · JSON object',
          json: true,
          lines: 4,
        ),
      if (doc.kind == UniversityLabKind.state) ...[
        field('events', 'Event sequence · space or comma separated', lines: 2),
        rows('states', 'States'),
        rows('transitions', 'Transitions'),
      ],
      if (doc.kind == UniversityLabKind.activity) ...[
        field('schedule', 'Action / signal schedule', lines: 2),
        rows('nodes', 'Activity nodes'),
        rows('edges', 'Flows'),
      ],
      if (doc.kind == UniversityLabKind.uml) ...[
        rows('nodes', 'Classes & instances'),
        rows('edges', 'Relationships'),
        rows('messages', 'Messages'),
        rows('fragments', 'Trace constraints'),
        field('trace', 'Trace · message IDs', lines: 2),
      ],
      if (doc.kind == UniversityLabKind.testing) ...[
        rows('nodes', 'CFG blocks'),
        rows('edges', 'CFG edges'),
        rows('partitions', 'Input partitions'),
        rows('tests', 'Test cases'),
        field('junit', 'Paste JUnit XML report', lines: 6),
        TextButton.icon(
          onPressed: busy ? null : importJUnit,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Import JUnit XML report'),
        ),
      ],
      if (doc.kind == UniversityLabKind.distributed) ...[
        field('processes', 'Processes · comma separated'),
        field('reachable', 'Reachable election members'),
        rows('events', 'Distributed events'),
      ],
      if (doc.kind == UniversityLabKind.protocol) ...[
        field('buildSystem', 'Build system / toolchain'),
        field('protectedPaths', 'Protected assignment paths'),
        field('transcript', 'Transcript · C> / S> lines', lines: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: host,
                decoration: const InputDecoration(labelText: 'Host'),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: port,
                decoration: const InputDecoration(labelText: 'Port'),
              ),
            ),
            OutlinedButton(
              onPressed: !busy && connection == null && universityToolsSupported
                  ? connect
                  : null,
              child: const Text('Connect · new transcript'),
            ),
            TextButton(
              onPressed: busy || connection != null ? stopTools : null,
              child: const Text('Disconnect / cancel'),
            ),
          ],
        ),
        TextField(
          controller: command,
          decoration: const InputDecoration(labelText: 'SMQP command'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: connection != null && !busy ? send : null,
            child: const Text('Send command'),
          ),
        ),
      ],
      if (doc.kind == UniversityLabKind.contracts) ...[
        field('code', 'Dafny source', lines: 16),
        TextField(
          controller: executable,
          decoration: const InputDecoration(
            labelText: 'Dafny executable / absolute path',
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: !busy && universityToolsSupported ? verify : null,
              child: const Text('Run local verifier'),
            ),
            TextButton(
              onPressed: busy ? stopTools : null,
              child: const Text('Cancel verification'),
            ),
          ],
        ),
        if (toolOutput.isNotEmpty) SelectableText(toolOutput),
      ],
      TextButton.icon(
        onPressed: busy || connection != null ? null : advanced,
        icon: const Icon(Icons.data_object),
        label: const Text('Advanced model JSON · preserve unknown fields'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy && connection == null,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await confirmDiscard() && context.mounted) {
        Navigator.pop(context);
      }
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'University Lab',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close university lab',
                    onPressed: () async {
                      if (await confirmDiscard() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UniversityLabKind>(
                initialValue: doc.kind,
                key: ValueKey(doc.kind),
                isExpanded: true,
                selectedItemBuilder: (_) => [
                  for (final kind in UniversityLabKind.values)
                    Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
                decoration: const InputDecoration(labelText: 'Workspace'),
                items: [
                  for (final kind in UniversityLabKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: busy
                    ? null
                    : (kind) {
                        if (kind != null && kind != doc.kind) choose(kind);
                      },
              ),
              if (busy) const LinearProgressIndicator(),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, size) {
                    final input = SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: title,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                          TextField(
                            controller: course,
                            decoration: const InputDecoration(
                              labelText: 'Course / semester',
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                          TextField(
                            controller: source,
                            decoration: const InputDecoration(
                              labelText:
                                  'Source / task link · e.g. [[object-id#page=3]]',
                            ),
                            onChanged: (_) => setState(() => dirty = true),
                          ),
                          const SizedBox(height: 16),
                          modelFields(),
                        ],
                      ),
                    );
                    final output = SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: report.isEmpty
                            ? const Text(
                                'Run the model to inspect its steps, checks and report. Save inserts the portable model plus a readable Markdown report. Reopen University Lab from the same note or selected Canvas frame.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (previewScene != null &&
                                      !{
                                        UniversityLabKind.protocol,
                                        UniversityLabKind.contracts,
                                      }.contains(doc.kind)) ...[
                                    UniversityPreview(
                                      scene: previewScene!,
                                      active: activeNodes,
                                    ),
                                    const Text(
                                      'Pan / zoom preview · highlighted nodes are active',
                                    ),
                                    const Divider(),
                                  ],
                                  MarkdownBody(data: report, selectable: true),
                                ],
                              ),
                      ),
                    );
                    return size.maxWidth < 760
                        ? DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                const TabBar(
                                  tabs: [
                                    Tab(text: 'Model'),
                                    Tab(text: 'Steps & report'),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(children: [input, output]),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: input),
                              const VerticalDivider(),
                              Expanded(child: output),
                            ],
                          );
                  },
                ),
              ),
              const Divider(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => choose(doc.kind),
                      child: const Text('Reset to example'),
                    ),
                    if ({
                      UniversityLabKind.state,
                      UniversityLabKind.activity,
                      UniversityLabKind.distributed,
                    }.contains(doc.kind))
                      OutlinedButton(
                        onPressed: busy ? null : () => evaluate(single: true),
                        child: const Text('Next step'),
                      ),
                    OutlinedButton(
                      onPressed: busy ? null : evaluate,
                      child: const Text('Run / check'),
                    ),
                    TextButton(
                      onPressed: !reportCurrent
                          ? null
                          : () async {
                              try {
                                await Clipboard.setData(
                                  ClipboardData(text: snapshot().markdown),
                                );
                              } catch (e) {
                                if (mounted) setState(() => error = '$e');
                              }
                            },
                      child: const Text('Copy Markdown'),
                    ),
                    FilledButton(
                      onPressed:
                          busy || connection != null || invalidFields.isNotEmpty
                          ? null
                          : apply,
                      child: const Text('Save to note / Canvas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
