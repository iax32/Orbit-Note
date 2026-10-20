import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/workspace_controller.dart';
import '../../application/code_project_session.dart';
import '../../application/code_profile_run.dart';
import '../../application/code_language_client.dart';
import '../../application/source_search.dart';
import '../../domain/code_project.dart';
import '../../domain/code_launch.dart';
import '../../domain/code_language.dart';
import '../../domain/source_browser.dart';
import '../../domain/universal_object.dart';
import '../../platform/code_tools.dart';
import '../../platform/code_launch.dart';
import '../../platform/code_tool_settings.dart';
import '../../platform/source_folder.dart';
import '../notes/rich/code_block.dart';
import '../notes/rich/code_surface.dart';
import '../notes/rich/code_editing.dart';
import '../notes/rich/code_workspace.dart';
import '../notes/rich/document_history.dart';
import 'source_search_dialog.dart';
import 'code_launch_profiles.dart';

Future<bool> openCodePreviewBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> showCodeIde(
  BuildContext context, {
  WorkspaceController? controller,
  UniversalObject? owner,
  String evidenceFolder = 'Notes',
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => CodeIdeWorkspace(
    controller: controller,
    owner: owner,
    evidenceFolder: evidenceFolder,
  ),
);

class CodeIdeWorkspace extends StatefulWidget {
  const CodeIdeWorkspace({
    super.key,
    this.initialProject,
    this.controller,
    this.owner,
    this.evidenceFolder = 'Notes',
    this.toolStarter = startCodeTool,
    this.languageStarter = startCodeLanguageTool,
    this.launchStoreFactory = openCodeLaunchStore,
    this.previewStarter = startCodeWebPreview,
    this.previewOpener = openCodePreviewBrowser,
  });
  final CodeProject? initialProject;
  final WorkspaceController? controller;
  final UniversalObject? owner;
  final String evidenceFolder;
  final Future<CodeToolProcess> Function(ToolCommand, String) toolStarter;
  final Future<LanguageTransport> Function(ToolCommand, String) languageStarter;
  final CodeLaunchStore Function(String) launchStoreFactory;
  final Future<CodeWebPreview> Function(String, String) previewStarter;
  final Future<bool> Function(Uri) previewOpener;
  @override
  State<CodeIdeWorkspace> createState() => _CodeIdeWorkspaceState();
}

class _CodeTab {
  _CodeTab(this.doc, this.changed)
    : editor = CodeController(
        text: doc.text,
        language: codeLanguageId(doc.path) == 'html'
            ? 'xml'
            : sourceLanguage(doc.path) ?? '',
      ) {
    editor.selection = const TextSelection.collapsed(offset: 0);
    previous = editor.value;
    editor.addListener(observe);
  }
  final CodeDocument doc;
  final VoidCallback changed;
  final CodeController editor;
  final focus = FocusNode();
  final history = DocumentHistory();
  final undoSelections = <(TextSelection, TextSelection)>[],
      redoSelections = <(TextSelection, TextSelection)>[];
  late TextEditingValue previous;
  bool replaying = false;
  Timer? recovery, sync;
  String? lineText;
  List<({int start, int contentEnd, int end})> cachedLines = [];
  List<({int start, int contentEnd, int end})> get lines {
    if (lineText != editor.text) {
      lineText = editor.text;
      cachedLines = codeLines(editor.text);
    }
    return cachedLines;
  }

  void observe() {
    if (!replaying && editor.value.composing.isCollapsed) {
      if (previous.text != editor.text) {
        history.record(previous.text, editor.text);
        undoSelections.add((previous.selection, editor.selection));
        redoSelections.clear();
        if (undoSelections.length > 200) undoSelections.removeAt(0);
      }
      previous = editor.value;
    }
    final before = doc.version;
    doc.edit(editor.text);
    if (before != doc.version) changed();
  }

  void undo({bool redo = false}) {
    if (!editor.value.composing.isCollapsed ||
        !(redo ? history.canRedo : history.canUndo)) {
      return;
    }
    final pair = (redo ? redoSelections : undoSelections).removeLast();
    (redo ? undoSelections : redoSelections).add(pair);
    final text = redo ? history.redo(editor.text) : history.undo(editor.text);
    final selection = redo ? pair.$2 : pair.$1;
    replaying = true;
    editor.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selection.baseOffset.clamp(0, text.length),
        extentOffset: selection.extentOffset.clamp(0, text.length),
      ),
    );
    previous = editor.value;
    replaying = false;
  }

  void dispose() {
    recovery?.cancel();
    sync?.cancel();
    editor.dispose();
    focus.dispose();
  }
}

class _CodeIdeWorkspaceState extends State<CodeIdeWorkspace>
    with WidgetsBindingObserver {
  CodeProjectSession? session;
  final tabs = <String, _CodeTab>{};
  final languages = <String, CodeLanguageClient>{};
  final subscriptions = <String, StreamSubscription>{};
  final diagnostics = <String, List<CodeProblem>>{};
  List<SourceFileEntry> files = [];
  bool incomplete = false,
      busy = false,
      closing = false,
      wrap = false,
      showFiles = true,
      showConsole = true;
  String? selected;
  String filter = '', status = '', output = '';
  String consoleTab = 'Output';
  final fileQuery = TextEditingController();
  final stdin = TextEditingController();
  final consoleUpdates = ValueNotifier<int>(0);
  void updateConsole(VoidCallback change) {
    setState(change);
    consoleUpdates.value++;
  }

  final python = TextEditingController(text: 'python');
  final compiler = TextEditingController(text: 'clang++');
  final debugger = TextEditingController(text: 'gdb');
  final debuggerArguments = TextEditingController(
    text: '["--args", "{program}"]',
  );
  bool toolsEdited = false;
  final serverExecutable = {
    'python': TextEditingController(text: 'python'),
    'cpp': TextEditingController(text: 'clangd'),
    'html': TextEditingController(text: 'vscode-html-language-server'),
  };
  final serverArguments = {
    'python': TextEditingController(text: '["-I", "-m", "pylsp"]'),
    'cpp': TextEditingController(text: '["--background-index=false"]'),
    'html': TextEditingController(text: '["--stdio"]'),
  };
  CodeToolProcess? running;
  CodeLaunchStore? launchStore;
  CodeLaunchSnapshot? launchSettings;
  String? selectedProfile;
  CodeProfileRun? profileRun;
  CodeWebPreview? preview;
  StreamSubscription<String>? previewSubscription;
  bool previewStarting = false;
  bool launching = false;
  int toolCancellation = 0;
  int serial = 0;
  late final int? vaultGeneration;
  _CodeTab? get tab => tabs[selected];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vaultGeneration = widget.controller?.workspaceGeneration;
    loadCodeToolSettings()
        .then((settings) {
          if (!mounted || toolsEdited) return;
          for (final (key, field) in [
            ('python', python),
            ('compiler', compiler),
            ('debugger', debugger),
            ('debuggerArguments', debuggerArguments),
          ]) {
            if (settings[key] is String) field.text = settings[key] as String;
          }
          final savedServers = settings['servers'];
          if (savedServers is Map) {
            for (final language in serverExecutable.keys) {
              final value = savedServers[language];
              if (value is Map &&
                  value['executable'] is String &&
                  value['arguments'] is List) {
                serverExecutable[language]!.text =
                    value['executable'] as String;
                serverArguments[language]!.text = jsonEncode(
                  value['arguments'],
                );
              }
            }
          }
        })
        .catchError((Object _) {});
    defaultCodeToolPaths()
        .then((paths) {
          if (!mounted) return;
          if (toolsEdited) return;
          if (python.text == 'python' && paths['python'] != null) {
            python.text = paths['python']!;
            if (serverExecutable['python']!.text == 'python') {
              serverExecutable['python']!.text = paths['python']!;
            }
          }
          if (compiler.text == 'clang++' && paths['compiler'] != null) {
            compiler.text = paths['compiler']!;
          }
        })
        .catchError((Object _) {});
    if (widget.initialProject != null) loadProject(widget.initialProject!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    serial++;
    for (final t in tabs.values) {
      t.dispose();
    }
    for (final s in subscriptions.values) {
      unawaited(s.cancel());
    }
    for (final client in languages.values) {
      unawaited(client.close());
    }
    unawaited(running?.stop() ?? Future.value());
    profileRun?.cancel();
    unawaited(previewSubscription?.cancel() ?? Future.value());
    unawaited(preview?.stop() ?? Future.value());
    fileQuery.dispose();
    stdin.dispose();
    consoleUpdates.dispose();
    python.dispose();
    compiler.dispose();
    debugger.dispose();
    debuggerArguments.dispose();
    for (final c in [...serverExecutable.values, ...serverArguments.values]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (mounted) setState(() => closing = true);
    try {
      await session?.protectAll();
      profileRun?.cancel();
      await running?.stop();
      await stopPreview();
      return AppExitResponse.exit;
    } on Object {
      if (mounted) {
        setState(() {
          closing = false;
          status =
              'Save or copy source drafts before exiting; recovery failed.';
        });
      }
      return AppExitResponse.cancel;
    }
  }

  void message(Object value) {
    if (mounted) setState(() => status = '$value');
  }

  Future<void> choose() async {
    try {
      final root = await getDirectoryPath(
        confirmButtonText: 'Open coding project',
      );
      if (root != null && mounted) await loadProject(openCodeProject(root));
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> loadProject(CodeProject project) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await session?.dispose();
      serial++;
      profileRun?.cancel();
      await stopPreview();
      await running?.stop();
      running = null;
      for (final client in languages.values) {
        await client.close();
      }
      for (final s in subscriptions.values) {
        await s.cancel();
      }
      languages.clear();
      subscriptions.clear();
      diagnostics.clear();
      for (final t in tabs.values) {
        t.dispose();
      }
      tabs.clear();
      selected = null;
      session = CodeProjectSession(project);
      launchStore = widget.launchStoreFactory(project.root);
      launchSettings = null;
      selectedProfile = null;
      serial++;
      final listing = await project.list();
      try {
        launchSettings = await launchStore!.load();
      } on Object catch (e) {
        message('Launch settings unavailable: $e');
      }
      if (mounted) {
        setState(() {
          files = listing.files;
          incomplete = listing.incomplete;
          output = '';
        });
      }
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scan() async {
    final s = session;
    if (s == null || busy) return;
    setState(() => busy = true);
    try {
      final result = await s.project.list();
      if (mounted && session == s) {
        setState(() {
          files = result.files;
          incomplete = result.incomplete;
        });
      }
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(String path, {CodePosition? position}) async {
    final s = session;
    if (s == null) return;
    try {
      final doc = await s.open(path);
      if (!mounted || s != session) return;
      if (!tabs.containsKey(path)) {
        tabs[path] = _CodeTab(doc, () => changed(path));
      }
      setState(() {
        selected = path;
        showFiles = false;
        status = doc.conflict
            ? 'Recovered draft differs from the current file. Compare before saving.'
            : doc.modified
            ? 'Recovered unsaved source draft.'
            : '';
      });
      if (position != null) {
        tabs[path]!.editor.selection = TextSelection.collapsed(
          offset: codeOffset(doc.text, position),
        );
      }
      await sync(tabs[path]!);
    } on Object catch (e) {
      message(e);
    }
  }

  void changed(String path) {
    final t = tabs[path];
    if (t == null || session == null) return;
    diagnostics.remove(path);
    t.recovery?.cancel();
    t.sync?.cancel();
    final s = session!;
    t.recovery = Timer(const Duration(milliseconds: 350), () async {
      try {
        await s.protect(t.doc);
        if (mounted) setState(() {});
      } on Object catch (e) {
        message(e);
      }
    });
    t.sync = Timer(const Duration(milliseconds: 450), () => sync(t));
    if (mounted) setState(() {});
  }

  Future<void> sync(_CodeTab t) async {
    final s = session, language = codeLanguageId(t.doc.path);
    if (s == null ||
        !t.editor.value.composing.isCollapsed ||
        languages[language] == null) {
      return;
    }
    try {
      await languages[language]!.update(
        s.project.fileUri(t.doc.path),
        language,
        t.doc.text,
        t.doc.version,
      );
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> save([_CodeTab? target]) async {
    final t = target ?? tab, s = session;
    if (s == null ||
        t == null ||
        busy ||
        !t.editor.value.composing.isCollapsed) {
      return;
    }
    setState(() => busy = true);
    try {
      await s.save(t.doc);
      preview?.refresh();
      message(
        t.doc.modified
            ? 'Saved the captured version; newer edits remain unsaved.'
            : 'Source saved.',
      );
    } on Object catch (e) {
      message(
        t.doc.modified
            ? e
            : 'Source saved; recovery cleanup needs attention: $e',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveAll() async {
    final s = session;
    if (s == null || busy) return;
    setState(() => busy = true);
    var count = 0;
    try {
      for (final item in tabs.values.toList()) {
        if (!item.doc.modified) continue;
        if (!item.editor.value.composing.isCollapsed) {
          throw const FormatException(
            'Finish text composition before saving all files.',
          );
        }
        await s.save(item.doc);
        count++;
      }
      preview?.refresh();
      message('Saved $count changed source files.');
    } on Object catch (e) {
      message('Saved $count files; remaining drafts are retained. $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> goToLine() async {
    final t = tab;
    if (t == null) return;
    var value = '';
    final line = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to source line'),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (v) => value = v,
          decoration: InputDecoration(labelText: 'Line 1–${t.lines.length}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(value)),
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (!mounted || tab != t || line == null) return;
    if (line < 1 || line > t.lines.length) {
      message('Choose a valid source line.');
      return;
    }
    t.editor.selection = TextSelection.collapsed(
      offset: t.lines[line - 1].start,
    );
    t.focus.requestFocus();
  }

  Future<void> compare() async {
    final t = tab, s = session;
    if (t == null || s == null || busy) return;
    try {
      final current = await s.project.read(t.doc.path), version = t.doc.version;
      if (!mounted || session != s) return;
      final reviewed = await showDialog<String>(
        context: context,
        builder: (_) => CodeWorkspace(
          code: t.doc.text,
          originalCode: current.text,
          initialComparison: true,
          language: t.editor.language,
          canApply: () => t.doc.version == version && session == s,
        ),
      );
      if (!mounted ||
          reviewed == null ||
          t.doc.version != version ||
          session != s) {
        return;
      }
      await s.resolve(t.doc, current, reviewed);
      t.editor.value = TextEditingValue(
        text: reviewed,
        selection: const TextSelection.collapsed(offset: 0),
      );
      message(
        'Reviewed draft retained against this file version. Save will recheck external changes.',
      );
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> closeTab(String path) async {
    final t = tabs[path], s = session;
    if (t == null || s == null || busy) return;
    setState(() => busy = true);
    try {
      await s.closeDocument(t.doc);
      if (!mounted || session != s) return;
      t.dispose();
      tabs.remove(path);
      setState(() {
        if (selected == path) selected = tabs.keys.lastOrNull;
      });
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (closing || busy) return;
    setState(() => closing = true);
    try {
      await session?.dispose();
      serial++;
      profileRun?.cancel();
      await stopPreview();
      await running?.stop();
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => closing = false);
    }
  }

  Future<void> create({bool directory = false}) async {
    final s = session;
    if (s == null || busy) return;
    var path = '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(directory ? 'New source folder' : 'New source file'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => path = v,
          decoration: InputDecoration(
            labelText: 'Project-relative path',
            hintText: directory ? 'src' : 'main.py / index.html / main.cpp',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, path.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (!mounted || name == null || session != s) return;
    try {
      if (directory) {
        await s.project.createDirectory(name);
      } else {
        await s.project.save(
          CodeSnapshot(name, '', null),
          sourceStarter(codeLanguageId(name)),
        );
      }
      await scan();
      if (!directory) await open(name);
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> searchProject() async {
    final s = session;
    if (s == null) return;
    // Reuse the read-only scoped browser adapter through a project bridge.
    final hit = await showDialog<SourceSearchHit>(
      context: context,
      builder: (_) => SourceSearchDialog(
        folder: _ProjectSearchFolder(s.project),
        files: files,
        incompleteListing: incomplete,
      ),
    );
    if (!mounted || session != s || hit == null) return;
    await open(hit.file.path);
    final t = tab;
    if (t != null &&
        sha256.convert(utf8.encode(t.doc.text)).toString() ==
            hit.sourceSha256) {
      t.editor.selection = TextSelection.collapsed(
        offset: codeOffset(t.doc.text, CodePosition(hit.line - 1, 0)),
      );
      t.focus.requestFocus();
    } else {
      message(
        'Source or draft changed since search; the old line was not selected.',
      );
    }
  }

  Future<void> connect() async {
    final s = session, t = tab;
    if (s == null || t == null || busy) return;
    final language = codeLanguageId(t.doc.path);
    if (!serverExecutable.containsKey(language)) return;
    setState(() => busy = true);
    CodeLanguageClient? next;
    try {
      final args = jsonDecode(serverArguments[language]!.text);
      if (args is! List || args.any((a) => a is! String)) {
        throw const FormatException(
          'Server arguments must be a JSON array of strings.',
        );
      }
      final transport = await widget.languageStarter(
        ToolCommand(serverExecutable[language]!.text, args.cast<String>()),
        s.project.root,
      );
      next = CodeLanguageClient(transport);
      await next.initialize(s.project.rootUri);
      if (!mounted || session != s) {
        await next.close();
        return;
      }
      await languages[language]?.close();
      await subscriptions[language]?.cancel();
      languages[language] = next;
      subscriptions[language] = next.problems.stream.listen((batch) {
        final path = s.project.relativePath(batch.uri);
        if (mounted && session == s && path != null) {
          updateConsole(() => diagnostics[path] = batch.problems);
        }
      });
      for (final item in tabs.values.where(
        (v) => codeLanguageId(v.doc.path) == language,
      )) {
        await sync(item);
      }
      message('$language language tools connected.');
    } on Object catch (e) {
      await next?.close();
      message(
        'Language tools unavailable: $e. Offline editing and snippets still work.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> completion() async {
    final t = tab, s = session;
    if (t == null || s == null || !t.editor.value.composing.isCollapsed) return;
    final version = t.doc.version, offset = t.editor.selection.extentOffset;
    if (offset < 0) return;
    final language = codeLanguageId(t.doc.path),
        client = languages[codeLanguageId(t.doc.path)];
    var suggestions = offlineCodeSuggestions(t.doc.text, offset, language);
    try {
      if (client != null) {
        await sync(t);
        final semantic = await client.complete(
          s.project.fileUri(t.doc.path),
          t.doc.text,
          offset,
        );
        if (semantic.isNotEmpty) suggestions = semantic;
      }
    } on Object catch (e) {
      message('Using offline suggestions: $e');
    }
    if (!mounted || session != s || t.doc.version != version || tab != t) {
      return;
    }
    final chosen = await showDialog<CodeSuggestion>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code completion'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: suggestions.isEmpty
              ? const Text('No suggestions at this position.')
              : ListView(
                  children: [
                    for (final item in suggestions)
                      ListTile(
                        title: Text(item.label),
                        subtitle: Text(item.detail, maxLines: 2),
                        onTap: () => Navigator.pop(context, item),
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
    if (!mounted ||
        chosen == null ||
        t.doc.version != version ||
        session != s ||
        tab != t) {
      return;
    }
    try {
      final text = applyCodeEdits(t.doc.text, chosen.edits);
      t.editor.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: (chosen.edits.first.start + chosen.edits.first.text.length)
              .clamp(0, text.length),
        ),
      );
      t.focus.requestFocus();
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> languageAction(String action) async {
    final t = tab, s = session;
    if (t == null || s == null) return;
    final client = languages[codeLanguageId(t.doc.path)];
    if (client == null) {
      message('Connect language tools for semantic $action.');
      return;
    }
    final version = t.doc.version,
        text = t.doc.text,
        uri = s.project.fileUri(t.doc.path);
    try {
      await sync(t);
      final result = await client.request('textDocument/$action', {
        'textDocument': {'uri': uri.toString()},
        if (action == 'hover' || action == 'definition')
          'position': codePosition(
            text,
            t.editor.selection.extentOffset.clamp(0, text.length),
          ).json,
        if (action == 'formatting')
          'options': {'tabSize': 4, 'insertSpaces': true},
      });
      if (!mounted || t.doc.version != version || session != s || tab != t) {
        return;
      }
      if (action == 'formatting') {
        if (result is! List) {
          throw const FormatException('Formatter returned no edits.');
        }
        final formatted = applyCodeEdits(
          text,
          result.map((e) => CodeTextEdit.parse(text, e)).toList(),
        );
        final reviewed = await showDialog<String>(
          context: context,
          builder: (_) => CodeWorkspace(
            code: formatted,
            originalCode: text,
            initialComparison: true,
            language: t.editor.language,
            canApply: () => t.doc.version == version && session == s,
          ),
        );
        if (reviewed != null &&
            mounted &&
            t.doc.version == version &&
            session == s) {
          t.editor.value = TextEditingValue(
            text: reviewed,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else if (action == 'definition') {
        final item = result is List ? result.firstOrNull : result;
        if (item is! Map) {
          throw const FormatException('No definition at this position.');
        }
        final target = Uri.parse((item['uri'] ?? item['targetUri']).toString());
        final path = s.project.relativePath(target);
        if (path == null) {
          throw const FormatException(
            'Definition is outside the selected project. It was not opened.',
          );
        }
        final range = item['range'] ?? item['targetSelectionRange'];
        await open(path, position: CodePosition.parse((range as Map)['start']));
      } else if (action == 'documentSymbol') {
        final symbols = <({String name, CodePosition position})>[];
        void collect(dynamic entries, int depth) {
          if (entries is! List || depth > 8) return;
          for (final item in entries.take(100)) {
            if (item is! Map ||
                item['name'] is! String ||
                symbols.length >= 200) {
              continue;
            }
            final range =
                item['selectionRange'] ??
                item['range'] ??
                (item['location'] is Map
                    ? (item['location'] as Map)['range']
                    : null);
            if (range is Map) {
              final position = CodePosition.parse(range['start']);
              codeOffset(text, position);
              symbols.add((
                name: '${'  ' * depth}${item['name']}',
                position: position,
              ));
            }
            collect(item['children'], depth + 1);
          }
        }

        collect(result, 0);
        final chosen = await showDialog<CodePosition>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('File symbols'),
            content: SizedBox(
              width: 450,
              height: 350,
              child: ListView(
                children: [
                  for (final symbol in symbols)
                    ListTile(
                      title: Text(symbol.name),
                      subtitle: Text('Line ${symbol.position.line + 1}'),
                      onTap: () => Navigator.pop(context, symbol.position),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        if (chosen != null &&
            mounted &&
            session == s &&
            t.doc.version == version) {
          t.editor.selection = TextSelection.collapsed(
            offset: codeOffset(text, chosen),
          );
          t.focus.requestFocus();
        }
      } else {
        final contents = result is Map ? result['contents'] : null;
        final value = contents is Map
            ? contents['value']?.toString()
            : contents is List
            ? contents.map((v) => v is Map ? v['value'] : v).join('\n\n')
            : contents?.toString();
        if (value == null) {
          throw const FormatException('No symbol information.');
        }
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Symbol information'),
            content: SingleChildScrollView(
              child: SelectableText(
                value.length > 20000 ? value.substring(0, 20000) : value,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> configure() {
    toolsEdited = true;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Local code tools'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose installed executables. Save these settings on this device, outside the Vault. Opening a project never starts tools.',
                ),
                TextField(
                  controller: python,
                  decoration: const InputDecoration(
                    labelText: 'Python interpreter executable',
                  ),
                ),
                TextField(
                  controller: compiler,
                  decoration: const InputDecoration(
                    labelText:
                        'C++ compiler executable (clang++, g++ or MSVC cl.exe)',
                  ),
                ),
                TextField(
                  controller: debugger,
                  decoration: const InputDecoration(
                    labelText:
                        'C++ console debugger executable (GDB, LLDB or CDB)',
                  ),
                ),
                TextField(
                  controller: debuggerArguments,
                  decoration: const InputDecoration(
                    labelText:
                        'Debugger arguments (JSON); {program} is the built executable',
                  ),
                ),
                for (final language in ['html', 'python', 'cpp']) ...[
                  const SizedBox(height: 16),
                  Text(
                    '$language language server',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  TextField(
                    controller: serverExecutable[language],
                    decoration: const InputDecoration(
                      labelText: 'Server executable',
                    ),
                  ),
                  TextField(
                    controller: serverArguments[language],
                    decoration: const InputDecoration(
                      labelText: 'Arguments as JSON array',
                    ),
                  ),
                ],
                const Text(
                  'Python: python -m pylsp. C++: clangd. HTML: an installed HTML language server. For .cmd wrappers, select node.exe and provide the server script path and --stdio arguments instead. C++ semantic tools may need your project’s compile_commands.json.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                await saveCodeToolSettings({
                  'python': python.text,
                  'compiler': compiler.text,
                  'debugger': debugger.text,
                  'debuggerArguments': debuggerArguments.text,
                  'servers': {
                    for (final language in serverExecutable.keys)
                      language: {
                        'executable': serverExecutable[language]!.text,
                        'arguments': jsonDecode(
                          serverArguments[language]!.text,
                        ),
                      },
                  },
                });
                if (context.mounted) Navigator.pop(context);
                message('Code tool settings saved on this device.');
              } on Object catch (e) {
                message(e);
                if (context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Could not save local tools'),
                      content: Text('$e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Save local tools'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<int?> execute(ToolCommand command) async {
    final s = session;
    if (s == null || running != null || launching) return null;
    launching = true;
    final token = serial, cancellation = toolCancellation;
    try {
      final process = await widget.toolStarter(command, s.project.root);
      if (!mounted ||
          session != s ||
          token != serial ||
          cancellation != toolCancellation) {
        await process.stop();
        return null;
      }
      updateConsole(() {
        running = process;
        showConsole = true;
        consoleTab = 'Output';
      });
      final subscription = process.output.listen((value) {
        if (!mounted || session != s || token != serial) return;
        final clean = value
            .replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '')
            .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '');
        updateConsole(() {
          output += clean;
          if (output.length > 40000) {
            output =
                '[Earlier output omitted]\n${output.substring(output.length - 38000)}';
          }
        });
      }, onError: (Object e) => message(e));
      final exit = await process.exitCode;
      await subscription.cancel();
      if (mounted && session == s && token == serial) {
        updateConsole(() {
          running = null;
          output += '\nProcess exited with code $exit.\n';
        });
      }
      return exit;
    } on Object catch (e) {
      message('Tool could not start: $e. Configure an installed executable.');
      if (mounted && session == s) updateConsole(() => running = null);
      return null;
    } finally {
      launching = false;
    }
  }

  Future<void> run(String action) async {
    final t = tab, s = session;
    if (t == null ||
        s == null ||
        running != null ||
        launching ||
        busy ||
        profileRun != null) {
      return;
    }
    if (t.doc.modified || t.doc.conflict) {
      message('Save this source before running, checking or previewing it.');
      return;
    }
    final version = t.doc.version, projectToken = serial;
    try {
      final current = await s.project.read(t.doc.path);
      if (current.hash != t.doc.base.hash) {
        throw const FormatException(
          'Source changed externally. Compare it before running.',
        );
      }
      if (!mounted || session != s || tab != t || projectToken != serial) {
        return;
      }
      if (t.doc.version != version || t.doc.modified || t.doc.conflict) {
        throw const FormatException(
          'Source was edited while preparing the tool. Save before running.',
        );
      }
      final file = s.project.fileUri(t.doc.path).toFilePath();
      if (action == 'preview') {
        if (!await launchUrl(
          s.project.fileUri(t.doc.path),
          mode: LaunchMode.externalApplication,
        )) {
          throw const FormatException('Could not open HTML in the browser.');
        }
        return;
      }
      if (action == 'check') {
        const check =
            'import ast,pathlib,sys\np=pathlib.Path(sys.argv[1])\ntry:\n ast.parse(p.read_text(encoding="utf-8-sig"),filename=str(p));print("Python syntax check passed")\nexcept SyntaxError as e:\n print(f"{p}:{e.lineno}:{e.offset}: {e.msg}");sys.exit(1)\n';
        await execute(ToolCommand(python.text, ['-I', '-c', check, file]));
      } else if (codeLanguageId(t.doc.path) == 'python') {
        if (action == 'debug') {
          message(
            'Python debugger: enter b LINE, n, s, c, p EXPRESSION or q in process input.',
          );
        }
        await execute(
          ToolCommand(python.text, [
            '-u',
            if (action == 'debug') ...['-m', 'pdb'],
            file,
          ]),
        );
      } else {
        if (!RegExp(
          r'\.(cpp|cc|cxx|c)$',
          caseSensitive: false,
        ).hasMatch(t.doc.path)) {
          throw const FormatException(
            'Choose a C++ source file to build; headers are edited alongside it.',
          );
        }
        final binary = await s.project.buildOutput(t.doc.path);
        if (!mounted ||
            session != s ||
            serial != projectToken ||
            t.doc.version != version ||
            t.doc.modified ||
            tab != t) {
          message(
            'Source context changed while preparing the build. Run again from the saved source.',
          );
          return;
        }
        final token = serial;
        final exit = await execute(
          ToolCommand(
            compiler.text,
            RegExp(
                  r'(^|[/\\])cl(\.exe)?$',
                  caseSensitive: false,
                ).hasMatch(compiler.text)
                ? [
                    '/nologo',
                    '/utf-8',
                    '/EHsc',
                    '/Zi',
                    '/Fd:${binary.toFilePath()}.compile.pdb',
                    '/std:c++20',
                    file,
                    '/Fe:${binary.toFilePath()}',
                    '/Fo:${binary.toFilePath()}.obj',
                    '/link',
                    '/DEBUG',
                    '/PDB:${binary.toFilePath()}.pdb',
                  ]
                : ['-std=c++20', '-g', file, '-o', binary.toFilePath()],
          ),
        );
        if ((action == 'run' || action == 'debug') &&
            exit == 0 &&
            mounted &&
            session == s &&
            token == serial) {
          if (action == 'debug') {
            final args = jsonDecode(debuggerArguments.text);
            if (args is! List || args.any((a) => a is! String)) {
              throw const FormatException(
                'Debugger arguments must be a JSON string array.',
              );
            }
            await execute(
              ToolCommand(
                debugger.text,
                args
                    .cast<String>()
                    .map((a) => a.replaceAll('{program}', binary.toFilePath()))
                    .toList(),
              ),
            );
          } else {
            await execute(ToolCommand(binary.toFilePath(), []));
          }
        }
      }
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> manageProfiles() async {
    final s = session, store = launchStore;
    if (s == null || store == null || busy || profileRun != null) return;
    final saved = await showDialog<CodeLaunchSnapshot>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CodeLaunchProfiles(
        store: store,
        file: tab?.doc.path ?? 'main.py',
        msvc: RegExp(
          r'(^|[/\\])cl(\.exe)?$',
          caseSensitive: false,
        ).hasMatch(compiler.text),
      ),
    );
    if (!mounted || session != s || saved == null) return;
    setState(() {
      launchSettings = saved;
      if (!saved.profiles.any((p) => p.id == selectedProfile)) {
        selectedProfile = null;
      }
    });
  }

  Future<void> runProfile() async {
    final s = session, store = launchStore, settings = launchSettings;
    if (s == null ||
        store == null ||
        settings == null ||
        selectedProfile == null ||
        profileRun != null ||
        busy ||
        running != null ||
        launching) {
      return;
    }
    final token = serial, runner = CodeProfileRun();
    updateConsole(() => profileRun = runner);
    try {
      final profile = settings.profiles.singleWhere(
        (p) => p.id == selectedProfile,
      );
      if ((await store.load()).hash != settings.hash) {
        throw const FormatException(
          'Profiles changed externally. Reload profiles before running.',
        );
      }
      final captured = {
        for (final t in tabs.values) t.doc.path: (t.doc, t.doc.version),
      };
      Future<bool> valid() async {
        if (!mounted ||
            session != s ||
            s.disposed ||
            token != serial ||
            runner.cancelled) {
          return false;
        }
        for (final entry in captured.entries) {
          final doc = entry.value.$1;
          if (doc.modified ||
              doc.conflict ||
              doc.version != entry.value.$2 ||
              (await s.project.read(entry.key)).hash != doc.base.hash) {
            throw const FormatException(
              'Save or compare changed source files before running this profile.',
            );
          }
        }
        if (tabs.values.any((t) => t.doc.modified || t.doc.conflict)) {
          throw const FormatException(
            'Save all source drafts before running a profile.',
          );
        }
        return mounted && session == s && token == serial && !runner.cancelled;
      }

      if (!await valid()) return;
      final binary = (await s.project.buildOutput(
        'profile-${profile.id}.cpp',
      )).toFilePath();
      final commands = profile.steps
          .map(
            (step) => step.command(
              {'python': python.text, 'compiler': compiler.text},
              binary,
              profile.cwd,
            ),
          )
          .toList();
      final exit = await runner.run(
        commands,
        execute: execute,
        canContinue: valid,
        onStep: (i, n) => message('${profile.name} · step $i of $n'),
      );
      if (mounted && session == s && token == serial) {
        message(
          runner.cancelled
              ? 'Profile stopped.'
              : exit == 0
              ? '${profile.name} completed.'
              : 'Profile stopped before later steps (${exit == null ? 'context changed or tool failed' : 'exit $exit'}).',
        );
        if (exit == 0) preview?.refresh();
      }
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted && identical(profileRun, runner)) {
        updateConsole(() => profileRun = null);
      }
    }
  }

  Future<void> stopTools() async {
    toolCancellation++;
    profileRun?.cancel();
    await running?.stop();
  }

  Future<void> stopPreview() async {
    final current = preview;
    preview = null;
    await previewSubscription?.cancel();
    previewSubscription = null;
    await current?.stop();
    if (mounted) setState(() {});
  }

  Future<void> startPreview() async {
    final t = tab, s = session;
    if (t == null || s == null || busy || previewStarting || closing) return;
    final version = t.doc.version, token = serial;
    setState(() => previewStarting = true);
    CodeWebPreview? started;
    try {
      if (tabs.values.any((t) => t.doc.modified || t.doc.conflict)) {
        throw const FormatException(
          'Save all web source drafts before starting preview.',
        );
      }
      if ((await s.project.read(t.doc.path)).hash != t.doc.base.hash) {
        throw const FormatException(
          'HTML changed externally. Compare before previewing.',
        );
      }
      if (!mounted ||
          session != s ||
          token != serial ||
          t.doc.version != version) {
        return;
      }
      await stopPreview();
      started = await widget.previewStarter(s.project.root, t.doc.path);
      if (!mounted ||
          session != s ||
          token != serial ||
          t.doc.version != version) {
        await started.stop();
        return;
      }
      setState(() => preview = started);
      previewSubscription = started.events.listen((value) {
        if (mounted && session == s) message(value);
      });
      message('Local web preview started. Saved changes reload the page.');
      if (!await widget.previewOpener(started.url)) {
        message('Preview is ready. Copy its address to open in a browser.');
      }
    } on Object catch (e) {
      message(e);
    } finally {
      if (mounted) setState(() => previewStarting = false);
    }
  }

  Future<void> history() async {
    final t = tab, s = session;
    if (t == null || s == null) return;
    try {
      final entries = await s.project.history(t.doc.path),
          version = t.doc.version;
      if (!mounted || session != s) return;
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Source save checkpoints'),
          content: SizedBox(
            width: 500,
            height: 320,
            child: entries.isEmpty
                ? const Text('No save checkpoints yet.')
                : ListView(
                    children: [
                      for (final e in entries)
                        ExpansionTile(
                          title: Text(e.savedAt),
                          subtitle: const Text(
                            'A checkpoint is retained even if its save was interrupted.',
                          ),
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, e.before),
                              child: const Text('Review before version'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, e.after),
                              child: const Text('Review proposed version'),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (!mounted ||
          chosen == null ||
          t.doc.version != version ||
          session != s) {
        return;
      }
      final reviewed = await showDialog<String>(
        context: context,
        builder: (_) => CodeWorkspace(
          code: chosen,
          originalCode: t.doc.text,
          initialComparison: true,
          language: t.editor.language,
          canApply: () => t.doc.version == version && session == s,
        ),
      );
      if (reviewed != null &&
          mounted &&
          t.doc.version == version &&
          session == s) {
        t.editor.value = TextEditingValue(
          text: reviewed,
          selection: const TextSelection.collapsed(offset: 0),
        );
        message(
          'Checkpoint restored as an unsaved draft. Save explicitly to replace source.',
        );
      }
    } on Object catch (e) {
      message(e);
    }
  }

  Future<void> capture() async {
    final t = tab, s = session, c = widget.controller;
    if (t == null ||
        busy ||
        closing ||
        s == null ||
        c == null ||
        c.workspaceGeneration != vaultGeneration) {
      return;
    }
    try {
      final selection = t.editor.selection;
      final first =
          codePosition(
            t.doc.text,
            selection.start.clamp(0, t.doc.text.length),
          ).line +
          1;
      final end = !selection.isCollapsed && selection.end > 0
          ? selection.end - 1
          : selection.end;
      final last =
          codePosition(t.doc.text, end.clamp(0, t.doc.text.length)).line + 1;
      final excerpt = SourceExcerpt(
        s.project.root,
        t.doc.path,
        first,
        last,
        sourceLineExcerpt(t.doc.text, first, last),
        t.editor.language,
        sourceSha256: sha256.convert(utf8.encode(t.doc.text)).toString(),
      );
      final note = await c.createSourceEvidence(
        excerpt,
        folder: widget.evidenceFolder,
        ownerId: widget.owner?.id,
      );
      message(
        note == null
            ? c.error ?? 'Evidence save failed.'
            : 'Source excerpt saved as a linked Vault note.',
      );
    } on Object catch (e) {
      message(e);
    }
  }

  KeyEventResult key(FocusNode _, KeyEvent event) {
    final t = tab;
    if (t == null ||
        busy ||
        closing ||
        event is! KeyDownEvent ||
        !t.editor.value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance, k = event.logicalKey;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (ctrl && k == LogicalKeyboardKey.keyS) {
      if (keyboard.isShiftPressed) {
        saveAll();
      } else {
        save();
      }
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyW) {
      closeTab(t.doc.path);
      return KeyEventResult.handled;
    }
    if (!t.focus.hasFocus) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.f5 &&
        ['html', 'python', 'cpp'].contains(codeLanguageId(t.doc.path))) {
      run(
        codeLanguageId(t.doc.path) == 'html'
            ? 'preview'
            : ctrl
            ? 'run'
            : 'debug',
      );
      return KeyEventResult.handled;
    }
    if (ctrl &&
        (k == LogicalKeyboardKey.keyF || k == LogicalKeyboardKey.keyH)) {
      expandedEditor();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyG) {
      goToLine();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.space) {
      completion();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.f12) {
      languageAction('definition');
      return KeyEventResult.handled;
    }
    if (ctrl &&
        (k == LogicalKeyboardKey.keyZ || k == LogicalKeyboardKey.keyY)) {
      t.undo(redo: k == LogicalKeyboardKey.keyY || keyboard.isShiftPressed);
      return KeyEventResult.handled;
    }
    TextEditingValue? value;
    if (k == LogicalKeyboardKey.tab && !ctrl && !keyboard.isAltPressed) {
      value = indentCode(
        t.editor.value,
        outdent: keyboard.isShiftPressed,
        unit: codeLanguageId(t.doc.path) == 'python' ? '    ' : '  ',
      );
    }
    if (k == LogicalKeyboardKey.enter && !ctrl && !keyboard.isShiftPressed) {
      value = newlineCode(
        t.editor.value,
        unit: codeLanguageId(t.doc.path) == 'python' ? '    ' : '  ',
        language: codeLanguageId(t.doc.path),
      );
    }
    if (ctrl && k == LogicalKeyboardKey.slash) {
      value = toggleCodeComments(t.editor.value, codeLanguageId(t.doc.path));
    }
    if (ctrl && k == LogicalKeyboardKey.keyD) {
      value = duplicateCodeLines(t.editor.value);
    }
    if (ctrl && keyboard.isShiftPressed && k == LogicalKeyboardKey.keyK) {
      value = deleteCodeLines(t.editor.value);
    }
    if (keyboard.isAltPressed &&
        (k == LogicalKeyboardKey.arrowUp ||
            k == LogicalKeyboardKey.arrowDown)) {
      value = moveCodeLines(
        t.editor.value,
        down: k == LogicalKeyboardKey.arrowDown,
      );
    }
    if (value != null) {
      t.editor.value = value;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> expandedEditor() async {
    final t = tab, s = session;
    if (t == null || s == null) return;
    final version = t.doc.version;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => CodeWorkspace(
        code: t.doc.text,
        language: t.editor.language,
        canApply: () => session == s && t.doc.version == version,
      ),
    );
    if (mounted && value != null && session == s && t.doc.version == version) {
      t.editor.value = TextEditingValue(
        text: value,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  Widget actions(_CodeTab? t, String language) {
    Widget menu(
      String label,
      Map<String, String> labels,
      void Function(String) select,
    ) => PopupMenuButton<String>(
      tooltip: label,
      onSelected: select,
      itemBuilder: (_) => [
        for (final entry in labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: busy || !codeToolsSupported ? null : choose,
          icon: const Icon(Icons.folder_open),
          label: const Text('Open project folder'),
        ),
        if (session != null && !busy)
          menu('New', {
            'file': 'New file',
            'folder': 'New folder',
          }, (v) => create(directory: v == 'folder')),
        IconButton(
          tooltip: 'Refresh files',
          onPressed: session == null || busy ? null : scan,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Search project',
          onPressed: session == null || busy ? null : searchProject,
          icon: const Icon(Icons.manage_search),
        ),
        if (session != null) ...[
          OutlinedButton.icon(
            onPressed: busy || profileRun != null ? null : manageProfiles,
            icon: const Icon(Icons.tune),
            label: const Text('Run profiles'),
          ),
          if (launchSettings?.profiles.isNotEmpty ?? false) ...[
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                key: ValueKey('${launchSettings!.hash}:$selectedProfile'),
                initialValue: selectedProfile,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Launch profile'),
                items: [
                  for (final p in launchSettings!.profiles)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: profileRun != null || busy
                    ? null
                    : (v) => setState(() => selectedProfile = v),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed:
                  selectedProfile == null ||
                      profileRun != null ||
                      running != null ||
                      busy
                  ? null
                  : runProfile,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run profile'),
            ),
          ],
        ],
        if (t != null) ...[
          FilledButton.icon(
            onPressed: busy ? null : () => save(),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save · Ctrl+S'),
          ),
          menu(
            'Code actions',
            {
              'completion': 'Complete · Ctrl+Space',
              'saveAll': 'Save all · Ctrl+Shift+S',
              if (language == 'python' || language == 'cpp')
                'debug': 'Debug in console · F5',
              'line': 'Go to line · Ctrl+G',
              'find': 'Find / replace & code actions',
              'compare': 'Compare with disk',
              'history': 'Save history',
              if (language == 'html') 'previewFile': 'Open saved HTML file',
              'undo': 'Undo',
              'redo': 'Redo',
            },
            (v) {
              switch (v) {
                case 'completion':
                  completion();
                case 'saveAll':
                  saveAll();
                case 'debug':
                  run('debug');
                case 'line':
                  goToLine();
                case 'find':
                  expandedEditor();
                case 'compare':
                  compare();
                case 'history':
                  history();
                case 'previewFile':
                  run('preview');
                case 'undo':
                  t.undo();
                case 'redo':
                  t.undo(redo: true);
              }
            },
          ),
          if (language.isNotEmpty)
            menu(
              'Language',
              {
                'connect': languages[language] == null
                    ? 'Connect language tools'
                    : 'Reconnect language tools',
                'hover': 'Symbol info',
                'definition': 'Go to definition · F12',
                'documentSymbol': 'File symbols',
                'formatting': 'Format & review',
              },
              (v) {
                if (v == 'connect') {
                  if (!busy) connect();
                } else {
                  languageAction(v);
                }
              },
            ),
          if (language == 'python') ...[
            OutlinedButton(
              onPressed: running == null && !busy ? () => run('check') : null,
              child: const Text('Check Python syntax'),
            ),
            FilledButton.tonalIcon(
              onPressed: running == null && !busy ? () => run('run') : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Python'),
            ),
          ],
          if (language == 'cpp') ...[
            OutlinedButton(
              onPressed: running == null && !busy ? () => run('build') : null,
              child: const Text('Build C++'),
            ),
            FilledButton.tonalIcon(
              onPressed: running == null && !busy ? () => run('run') : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Build & run C++'),
            ),
          ],
          if (language == 'html')
            FilledButton.tonalIcon(
              onPressed: busy || previewStarting ? null : startPreview,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Start web preview'),
            ),
          if (widget.controller != null)
            IconButton(
              tooltip: 'Save excerpt to Vault',
              onPressed: capture,
              icon: const Icon(Icons.note_add_outlined),
            ),
        ],
        IconButton(
          tooltip: 'Local tools',
          onPressed: configure,
          icon: const Icon(Icons.tune),
        ),
        if (preview != null) ...[
          SizedBox(
            width: 270,
            child: SelectableText(preview!.url.toString(), maxLines: 2),
          ),
          TextButton(
            onPressed: () async {
              try {
                await Clipboard.setData(
                  ClipboardData(text: preview!.url.toString()),
                );
                message('Preview address copied.');
              } on Object catch (e) {
                message(e);
              }
            },
            child: const Text('Copy preview address'),
          ),
          TextButton(
            onPressed: () {
              preview?.refresh();
              message('Preview reload requested.');
            },
            child: const Text('Refresh preview'),
          ),
          TextButton(onPressed: stopPreview, child: const Text('Stop preview')),
        ],
      ],
    );
  }

  Widget consolePanel() {
    final t = tab;
    final problems = diagnostics[selected] ?? [];
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * .65),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final name in ['Output', 'Problems'])
                          ChoiceChip(
                            label: Text(
                              name == 'Problems'
                                  ? '$name ${problems.length}'
                                  : name,
                            ),
                            selected: consoleTab == name,
                            onSelected: (_) =>
                                updateConsole(() => consoleTab = name),
                          ),
                        TextButton(
                          onPressed: () => updateConsole(() => output = ''),
                          child: const Text('Clear output'),
                        ),
                        if (running != null || profileRun != null)
                          TextButton.icon(
                            onPressed: stopTools,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                      ],
                    ),
                  ),
                  if (running != null)
                    TextField(
                      controller: stdin,
                      decoration: const InputDecoration(
                        labelText: 'Process input · Enter to send',
                      ),
                      onSubmitted: (value) async {
                        try {
                          await running?.writeInput(value);
                          stdin.clear();
                        } on Object catch (e) {
                          message(e);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: consoleTab == 'Output'
                ? SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SelectableText(
                        output.isEmpty
                            ? 'Build/run output appears here. Nothing executes on open.'
                            : output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final problem in problems)
                        ListTile(
                          title: Text(problem.message),
                          subtitle: Text(
                            'Line ${problem.position.line + 1} · ${problem.version == null ? 'server version unreported; location unverified' : 'version ${problem.version}'}',
                          ),
                          leading: Icon(
                            problem.severity == 1
                                ? Icons.error_outline
                                : Icons.info_outline,
                          ),
                          onTap: problem.version == t?.doc.version
                              ? () {
                                  try {
                                    t!.editor.selection =
                                        TextSelection.collapsed(
                                          offset: codeOffset(
                                            t.doc.text,
                                            problem.position,
                                          ),
                                        );
                                    t.focus.requestFocus();
                                  } on Object catch (e) {
                                    message(e);
                                  }
                                }
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tab, language = t == null ? '' : codeLanguageId(t.doc.path);
    final filtered = files
        .where((f) => f.path.toLowerCase().contains(filter.toLowerCase()))
        .toList();
    final listing = Column(
      children: [
        TextField(
          controller: fileQuery,
          onChanged: (v) => setState(() => filter = v),
          decoration: const InputDecoration(
            labelText: 'Find file',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (incomplete)
          const Text('Partial listing; scan limits/unreadable folders.'),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              selected: filtered[i].path == selected,
              leading: const Icon(Icons.code, size: 16),
              title: Text(
                filtered[i].path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => open(filtered[i].path),
            ),
          ),
        ),
      ],
    );
    final pane = t == null
        ? const Center(
            child: Text('Open a source folder, then choose or create a file.'),
          )
        : CodeSurface(
            key: ValueKey(t.doc.path),
            controller: t.editor,
            focus: t.focus,
            fieldKey: const ValueKey('ide-editor'),
            lines: t.lines,
            wrap: wrap,
            readOnly: busy || closing,
            onChanged: (_) {},
          );
    final console = consolePanel();
    return PopScope(
      canPop: closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Focus(
          onKeyEvent: key,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .28,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Code workspace',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close code workspace; protect drafts',
                              onPressed: closing ? null : leave,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        if (session != null)
                          Text(
                            session!.project.root,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        actions(t, language),
                        if (status.isNotEmpty || t?.doc.draftError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(t?.doc.draftError ?? status),
                          ),
                        if (busy) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
                if (tabs.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in tabs.values)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 8,
                            ),
                            child: InputChip(
                              selected: selected == item.doc.path,
                              label: Text(
                                '${item.doc.path}${item.doc.modified ? ' •' : ''}${item.doc.conflict ? ' !' : ''}',
                              ),
                              onPressed: () =>
                                  setState(() => selected = item.doc.path),
                              onDeleted: () => closeTab(item.doc.path),
                              deleteButtonTooltipMessage:
                                  'Close tab and retain unsaved draft',
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, area) {
                      final compact =
                          area.maxWidth <
                          800 * MediaQuery.textScalerOf(context).scale(14) / 14;
                      final editor = Column(
                        children: [
                          Expanded(
                            child: compact && showFiles ? listing : pane,
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (compact)
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => showFiles = !showFiles),
                                    child: Text(
                                      showFiles ? 'Show editor' : 'Show files',
                                    ),
                                  ),
                                if (t != null)
                                  Text(
                                    '${t.doc.modified ? 'Unsaved draft' : 'Saved source'} · $language · UTF-8',
                                  ),
                                FilterChip(
                                  label: const Text('Wrap lines'),
                                  selected: wrap,
                                  onSelected: (v) => setState(() => wrap = v),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (area.maxHeight <
                                        320 *
                                            MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) /
                                            14) {
                                      showDialog<void>(
                                        context: context,
                                        builder: (context) => Dialog(
                                          insetPadding: const EdgeInsets.all(
                                            10,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Code output and problems',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.titleMedium,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Close output',
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.close,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Expanded(
                                                  child:
                                                      ValueListenableBuilder<
                                                        int
                                                      >(
                                                        valueListenable:
                                                            consoleUpdates,
                                                        builder: (_, _, _) =>
                                                            consolePanel(),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    } else {
                                      setState(
                                        () => showConsole = !showConsole,
                                      );
                                    }
                                  },
                                  child: Text(
                                    showConsole &&
                                            area.maxHeight >=
                                                320 *
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(14) /
                                                    14
                                        ? 'Hide output'
                                        : 'Show output',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showConsole &&
                              area.maxHeight >=
                                  320 *
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(14) /
                                      14)
                            SizedBox(
                              height: (area.maxHeight * .28).clamp(100, 230),
                              child: console,
                            ),
                        ],
                      );
                      return compact
                          ? editor
                          : Row(
                              children: [
                                SizedBox(width: 250, child: listing),
                                const VerticalDivider(width: 22),
                                Expanded(child: editor),
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectSearchFolder extends SourceFolder {
  _ProjectSearchFolder(this.project) : super(project.root);
  final CodeProject project;
  @override
  Future<SourceFileListing> list() => project.list();
  @override
  Future<String> read(String relativePath) async =>
      (await project.read(relativePath)).text;
}
