import '../../app/orbit_components.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/code_launch.dart';

class CodeLaunchProfiles extends StatefulWidget {
  const CodeLaunchProfiles({
    super.key,
    required this.store,
    this.file = 'main.py',
    this.msvc = false,
  });
  final CodeLaunchStore store;
  final String file;
  final bool msvc;
  @override
  State<CodeLaunchProfiles> createState() => _CodeLaunchProfilesState();
}

class _StepFields {
  _StepFields(Map<String, dynamic> data)
    : raw = {...data},
      tool = data['tool'] as String,
      executable = TextEditingController(
        text: data['executable'] as String? ?? '',
      ),
      arguments = TextEditingController(text: jsonEncode(data['arguments']));
  final Map<String, dynamic> raw;
  String tool;
  final TextEditingController executable, arguments;
  Map<String, dynamic> get value => {
    ...raw,
    'tool': tool,
    'executable': executable.text,
    'arguments': jsonDecode(arguments.text),
  };
  void dispose() {
    executable.dispose();
    arguments.dispose();
  }
}

class _CodeLaunchProfilesState extends State<CodeLaunchProfiles> {
  CodeLaunchSnapshot? snapshot;
  CodeRunProfile? editing;
  final name = TextEditingController(), cwd = TextEditingController(text: '.');
  final steps = <_StepFields>[];
  String error = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    name.dispose();
    cwd.dispose();
    for (final s in steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => busy = true);
    try {
      final value = await widget.store.load();
      if (mounted) {
        setState(() {
          snapshot = value;
          error = '';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          snapshot = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void edit(CodeRunProfile value) {
    for (final s in steps) {
      s.dispose();
    }
    steps.clear();
    steps.addAll(value.steps.map((s) => _StepFields(s.data)));
    setState(() {
      editing = value;
      name.text = value.name;
      cwd.text = value.cwd;
      error = '';
    });
  }

  void create(String kind) {
    if (['java', 'maven', 'gradle', 'dafny'].contains(kind)) {
      final file = kind == 'java' && !widget.file.endsWith('.java')
          ? 'Main.java'
          : kind == 'dafny' && !widget.file.endsWith('.dfy')
          ? 'model.dfy'
          : widget.file;
      edit(
        CodeRunProfile.parse({
          'id': const Uuid().v4(),
          'name': switch (kind) {
            'java' => 'Java source · Java 21',
            'maven' => 'Maven JUnit tests',
            'gradle' => 'Gradle JUnit tests',
            _ => 'Dafny verify',
          },
          'cwd': '.',
          'steps': [
            {
              'tool': 'custom',
              'executable': switch (kind) {
                'java' => 'java',
                'maven' => 'mvn',
                'gradle' => 'gradle',
                _ => 'dafny',
              },
              'arguments': switch (kind) {
                'java' => ['--source', '21', file],
                'maven' => ['test'],
                'gradle' => ['test'],
                _ => ['verify', file],
              },
            },
          ],
        }),
      );
      return;
    }
    final file =
        kind == 'cpp' && !RegExp(r'\.(c|cc|cpp|cxx)$').hasMatch(widget.file)
        ? 'main.cpp'
        : kind == 'python' && !widget.file.endsWith('.py')
        ? 'main.py'
        : widget.file;
    edit(
      CodeRunProfile.parse({
        'id': const Uuid().v4(),
        'name': kind == 'cpp'
            ? 'C++ build and run'
            : kind == 'python'
            ? 'Python script'
            : 'Custom command',
        'cwd': '.',
        'steps': kind == 'cpp'
            ? [
                {
                  'tool': 'compiler',
                  'arguments': widget.msvc
                      ? [
                          '/nologo',
                          '/utf-8',
                          '/EHsc',
                          '/std:c++20',
                          file,
                          '/Fe:{output}',
                          '/Fo:{buildDir}/',
                        ]
                      : ['-std=c++20', file, '-o', '{output}'],
                },
                {'tool': 'program', 'arguments': []},
              ]
            : [
                {
                  'tool': kind == 'python' ? 'python' : 'custom',
                  if (kind == 'custom') 'executable': 'node',
                  'arguments': kind == 'python' ? ['-u', file] : [file],
                },
              ],
      }),
    );
  }

  Future<void> commit(Map<String, dynamic> value) async {
    final expected = snapshot;
    if (expected == null || busy) return;
    setState(() => busy = true);
    try {
      final saved = await widget.store.save(expected, value);
      if (mounted) {
        setState(() {
          snapshot = saved;
          editing = null;
          error = '';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (snapshot == null || busy) return;
    try {
      final past = await widget.store.history();
      if (!mounted) return;
      final choice = await showOrbitDialog<CodeLaunchSnapshot>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Earlier launch settings'),
          content: SizedBox(
            width: 420,
            height: 280,
            child: past.isEmpty
                ? const Text('No checkpoints yet.')
                : ListView(
                    children: [
                      for (var i = 0; i < past.length; i++)
                        ListTile(
                          title: Text('Checkpoint ${i + 1}'),
                          subtitle: Text(
                            past[i].profiles.map((p) => p.name).join(', '),
                          ),
                          onTap: () => Navigator.pop(context, past[i]),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (choice != null && mounted) await commit(choice.data);
    } on Object catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Run & build profiles',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close profiles',
                    onPressed: busy
                        ? null
                        : () => Navigator.pop(context, snapshot),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Profiles run only when you choose Run profile. Arguments are separate values; shell wrappers are not evaluated. {output} is the generated executable; {buildDir} is its output folder.',
                      ),
                      if (error.isNotEmpty)
                        Semantics(liveRegion: true, child: Text(error)),
                      if (snapshot == null)
                        TextButton(
                          onPressed: busy ? null : reload,
                          child: const Text('Retry loading profiles'),
                        ),
                      if (snapshot != null && editing == null) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final (kind, label) in [
                              ('python', 'Add Python'),
                              ('cpp', 'Add C++'),
                              ('java', 'Add Java 21'),
                              ('maven', 'Add Maven / JUnit'),
                              ('gradle', 'Add Gradle / JUnit'),
                              ('dafny', 'Add Dafny verify'),
                              ('custom', 'Add custom'),
                            ])
                              OutlinedButton(
                                onPressed: busy ? null : () => create(kind),
                                child: Text(label),
                              ),
                            TextButton(
                              onPressed: busy ? null : restore,
                              child: const Text('Restore checkpoint'),
                            ),
                          ],
                        ),
                        if (snapshot!.profiles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'No profiles yet. Add a script, build, or development command.',
                            ),
                          ),
                        for (final profile in snapshot!.profiles)
                          ListTile(
                            title: Text(profile.name),
                            subtitle: Text(
                              '${profile.cwd} · ${profile.steps.length} steps',
                            ),
                            onTap: busy ? null : () => edit(profile),
                            trailing: IconButton(
                              tooltip: 'Delete profile; retain checkpoint',
                              onPressed: busy
                                  ? null
                                  : () =>
                                        commit(snapshot!.removing(profile.id)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        TextButton(
                          onPressed: busy ? null : reload,
                          child: const Text('Reload settings from disk'),
                        ),
                      ],
                      if (editing != null) ...[
                        TextField(
                          controller: name,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Profile name',
                          ),
                        ),
                        TextField(
                          controller: cwd,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: 'Working folder relative to project',
                            hintText: '. or web',
                          ),
                        ),
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            key: ObjectKey(steps[i]),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('Step ${i + 1}')),
                                    IconButton(
                                      tooltip: 'Remove step',
                                      onPressed: busy
                                          ? null
                                          : () => setState(() {
                                              steps.removeAt(i).dispose();
                                            }),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: steps[i].tool,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Tool',
                                  ),
                                  items: [
                                    for (final (v, l) in [
                                      ('python', 'Python interpreter'),
                                      ('compiler', 'C++ compiler'),
                                      ('custom', 'Installed executable'),
                                      ('program', 'Built program'),
                                    ])
                                      DropdownMenuItem(
                                        value: v,
                                        child: Text(
                                          l,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: busy
                                      ? null
                                      : (v) =>
                                            setState(() => steps[i].tool = v!),
                                ),
                                if (steps[i].tool == 'custom')
                                  TextField(
                                    controller: steps[i].executable,
                                    enabled: !busy,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Executable path or installed command',
                                    ),
                                  ),
                                TextField(
                                  controller: steps[i].arguments,
                                  enabled: !busy,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: 'Arguments as JSON array',
                                    hintText: '["-u", "main.py"]',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (editing != null)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: busy || steps.length >= 8
                            ? null
                            : () => setState(
                                () => steps.add(
                                  _StepFields({
                                    'tool': 'custom',
                                    'executable': 'node',
                                    'arguments': [],
                                  }),
                                ),
                              ),
                        child: const Text('Add step'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => editing = null),
                        child: const Text('Cancel edit'),
                      ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () {
                                try {
                                  final profile = CodeRunProfile.parse({
                                    ...editing!.data,
                                    'name': name.text.trim(),
                                    'cwd': cwd.text.trim(),
                                    'steps': steps.map((s) => s.value).toList(),
                                  });
                                  commit(snapshot!.replacing(profile));
                                } on Object catch (e) {
                                  setState(() => error = '$e');
                                }
                              },
                        child: const Text('Save profile'),
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
