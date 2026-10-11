import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/source_browser.dart';
import '../../platform/source_folder.dart';
import '../notes/rich/code_block.dart';

Future<void> showSourceBrowser(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const SourceBrowserDialog(),
);

class SourceBrowserDialog extends StatefulWidget {
  const SourceBrowserDialog({
    super.key,
    this.initialFolder,
    this.capture = false,
  });
  final SourceFolder? initialFolder;
  final bool capture;
  @override
  State<SourceBrowserDialog> createState() => _SourceBrowserDialogState();
}

class _SourceBrowserDialogState extends State<SourceBrowserDialog> {
  SourceFolder? folder;
  List<SourceFileEntry> files = [];
  SourceFileEntry? selected;
  CodeController? code;
  final scroll = ScrollController();
  final rangeFocus = FocusNode(debugLabel: 'Source line range');
  final query = TextEditingController();
  final fileQuery = TextEditingController();
  String fileFilter = '';
  String? message;
  bool busy = false, incomplete = false, sensitive = false, showFiles = true;
  int request = 0, match = -1;
  List<int> matches = [];
  int firstLine = 1, lastLine = 1;
  final firstInput = TextEditingController(text: '1');
  final lastInput = TextEditingController(text: '1');
  List<List<TextSpan>>? cachedLines;
  Brightness? cachedBrightness;
  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null) {
      folder = widget.initialFolder;
      scan();
    }
  }

  @override
  void dispose() {
    request++;
    code?.dispose();
    scroll.dispose();
    rangeFocus.dispose();
    query.dispose();
    fileQuery.dispose();
    firstInput.dispose();
    lastInput.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    try {
      final path = await getDirectoryPath(confirmButtonText: 'Browse source');
      if (path != null && mounted) {
        folder = SourceFolder(path);
        await scan();
      }
    } on Object catch (e) {
      if (mounted) setState(() => message = '$e');
    }
  }

  Future<void> scan() async {
    final token = ++request;
    setState(() {
      busy = true;
      message = null;
      files = [];
      selected = null;
      code?.dispose();
      code = null;
      cachedLines = null;
      matches = [];
      match = -1;
    });
    try {
      final result = await folder!.list();
      if (!mounted || token != request) return;
      setState(() {
        files = result.files;
        incomplete = result.incomplete;
      });
    } on Object catch (e) {
      if (mounted && token == request) setState(() => message = '$e');
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  Future<void> read(SourceFileEntry file) async {
    final token = ++request;
    setState(() {
      busy = true;
      selected = file;
      message = null;
      code?.dispose();
      code = null;
      cachedLines = null;
      matches = [];
      match = -1;
    });
    try {
      final text = await folder!.read(file.path);
      if (!mounted || token != request) return;
      setState(() {
        code = CodeController(text: text, language: file.language);
        firstLine = lastLine = 1;
        firstInput.text = lastInput.text = '1';
        updateMatches();
        showFiles = false;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    } on Object catch (e) {
      if (mounted && token == request) setState(() => message = '$e');
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  void updateMatches() {
    matches = sourceMatchingLines(
      code?.text ?? '',
      query.text,
      caseSensitive: sensitive,
    );
    match = -1;
  }

  SourceExcerpt excerpt() => SourceExcerpt(
    folder!.root,
    selected!.path,
    firstLine,
    lastLine,
    sourceLineExcerpt(code!.text, firstLine, lastLine),
    selected!.language,
  );

  Future<void> copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) setState(() => message = 'Source copied.');
    } on Object {
      if (mounted) {
        setState(() => message = 'Could not copy. Source remains unchanged.');
      }
    }
  }

  void rangeAction(bool capture, bool markdown) {
    try {
      final value = excerpt();
      if (capture) {
        if (value.text.trim().isEmpty || value.text.length > 100000) {
          throw const FormatException(
            'Choose a nonempty excerpt up to 100,000 characters.',
          );
        }
        Navigator.pop(context, value);
      } else {
        copy(markdown ? value.markdown : value.text);
      }
    } on Object catch (e) {
      setState(() => message = '$e');
    }
  }

  void nextMatch(int direction) {
    if (matches.isEmpty) return;
    setState(
      () => match = match < 0
          ? (direction > 0 ? 0 : matches.length - 1)
          : (match + direction) % matches.length,
    );
    final height = MediaQuery.textScalerOf(context).scale(14) * 1.8;
    if (scroll.hasClients) {
      scroll.jumpTo(
        (matches[match] * height).clamp(0, scroll.position.maxScrollExtent),
      );
    }
  }

  List<List<TextSpan>> lines(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (cachedLines != null && cachedBrightness == brightness) {
      return cachedLines!;
    }
    final result = <List<TextSpan>>[[]];
    void visit(TextSpan span, TextStyle style) {
      final merged = style.merge(span.style);
      if (span.text != null) {
        final parts = span.text!.split(RegExp(r'\r\n|\r|\n'));
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) result.add([]);
          if (parts[i].isNotEmpty) {
            result.last.add(TextSpan(text: parts[i], style: merged));
          }
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) visit(child, merged);
      }
    }

    visit(
      code!.buildTextSpan(context: context, withComposing: false),
      const TextStyle(),
    );
    cachedBrightness = brightness;
    cachedLines = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textSize = MediaQuery.textScalerOf(context).scale(14);
    final filtered = files
        .where((f) => f.path.toLowerCase().contains(fileFilter.toLowerCase()))
        .toList();
    final fileList = ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            children: [
              TextField(
                controller: fileQuery,
                onChanged: (v) => setState(() => fileFilter = v),
                decoration: const InputDecoration(
                  labelText: 'Filter file paths',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Text('${filtered.length} source files'),
            ],
          );
        }
        final file = filtered[i - 1];
        return ListTile(
          selected: selected?.path == file.path,
          leading: const Icon(Icons.code, size: 18),
          title: Text(file.path, maxLines: 3, overflow: TextOverflow.ellipsis),
          onTap: () => read(file),
        );
      },
    );
    final content = Focus(
      focusNode: rangeFocus,
      onKeyEvent: (_, event) {
        if (!rangeFocus.hasPrimaryFocus ||
            code == null ||
            event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        final keyboard = HardwareKeyboard.instance;
        if ((keyboard.isControlPressed || keyboard.isMetaPressed) &&
            (event.logicalKey == LogicalKeyboardKey.keyC ||
                event.logicalKey == LogicalKeyboardKey.keyX)) {
          rangeAction(false, keyboard.isShiftPressed);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: code == null
          ? Center(
              child: Text(
                busy ? 'Reading source…' : 'Choose a source file to read.',
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final spans = lines(context);
                final longest = code!.text
                    .split(RegExp(r'\r\n|\r|\n'))
                    .fold<int>(0, (m, s) => m > s.length ? m : s.length);
                final width = (longest * textSize * .8 + 90).clamp(
                  constraints.maxWidth,
                  double.infinity,
                );
                final matching = matches.toSet();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: constraints.maxHeight,
                    child: ListView.builder(
                      controller: scroll,
                      itemExtent: textSize * 1.8,
                      itemCount: spans.length,
                      itemBuilder: (context, i) => ColoredBox(
                        color: i + 1 >= firstLine && i + 1 <= lastLine
                            ? colors.tertiaryContainer
                            : matching.contains(i)
                            ? (match >= 0 && matches[match] == i
                                  ? colors.primaryContainer
                                  : colors.secondaryContainer)
                            : colors.surface,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 72,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: InkWell(
                                  key: ValueKey('source-line-${i + 1}'),
                                  onTap: () => setState(() {
                                    rangeFocus.requestFocus();
                                    if (HardwareKeyboard
                                        .instance
                                        .isShiftPressed) {
                                      lastLine = i + 1;
                                      if (lastLine < firstLine) {
                                        final old = firstLine;
                                        firstLine = lastLine;
                                        lastLine = old;
                                      }
                                    } else {
                                      firstLine = lastLine = i + 1;
                                    }
                                    firstInput.text = '$firstLine';
                                    lastInput.text = '$lastLine';
                                  }),
                                  child: Text(
                                    '${i + 1}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText.rich(
                                TextSpan(children: spans[i]),
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.4,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Source browser',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: SourceFolder.supported ? choose : null,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Choose source folder'),
                        ),
                        TextButton(
                          onPressed: folder == null || busy ? null : scan,
                          child: const Text('Refresh files'),
                        ),
                        TextButton(
                          onPressed: selected == null || busy
                              ? null
                              : () => read(selected!),
                          child: const Text('Reload file'),
                        ),
                        TextButton(
                          onPressed: code == null
                              ? null
                              : () => copy(code!.text),
                          child: const Text('Copy file'),
                        ),
                      ],
                    ),
                    if (code != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final isFirst in [true, false])
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: isFirst ? firstInput : lastInput,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: isFirst
                                      ? 'First line'
                                      : 'Last line',
                                ),
                                onChanged: (v) => setState(() {
                                  if (isFirst) {
                                    firstLine = int.tryParse(v) ?? 0;
                                  } else {
                                    lastLine = int.tryParse(v) ?? 0;
                                  }
                                }),
                              ),
                            ),
                          TextButton(
                            onPressed: () => rangeAction(false, false),
                            child: const Text('Copy lines'),
                          ),
                          TextButton(
                            onPressed: () => rangeAction(false, true),
                            child: const Text('Copy for note'),
                          ),
                          if (widget.capture)
                            FilledButton(
                              onPressed: () => rangeAction(true, false),
                              child: const Text('Use excerpt'),
                            ),
                          const Text(
                            'Click a line number; Shift-click to extend. Source files are read-only.',
                          ),
                        ],
                      ),
                    if (!SourceFolder.supported)
                      const Text(
                        'Local source folders are available in the native app.',
                      ),
                    if (folder != null)
                      Text(
                        folder!.root,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (selected != null)
                      Text(
                        selected!.path,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (incomplete)
                      const Text(
                        'Partial file list: scan limits or unreadable directories. Generated folders and symbolic links are excluded.',
                      ),
                    if (code != null && code!.text.length > 50000)
                      const Text(
                        'Large file: plain-text preview with line numbers and search.',
                      ),
                    if (message != null)
                      Semantics(liveRegion: true, child: Text(message!)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: query,
                            onChanged: (_) => setState(updateMatches),
                            onSubmitted: (_) => nextMatch(1),
                            decoration: const InputDecoration(
                              labelText: 'Find in file',
                            ),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Match case'),
                          selected: sensitive,
                          onSelected: (v) => setState(() {
                            sensitive = v;
                            updateMatches();
                          }),
                        ),
                        IconButton(
                          tooltip: 'Previous matching line',
                          onPressed: matches.isEmpty
                              ? null
                              : () => nextMatch(-1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'Next matching line',
                          onPressed: matches.isEmpty
                              ? null
                              : () => nextMatch(1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        Text(
                          query.text.isEmpty
                              ? ''
                              : '${match < 0 ? 0 : match + 1} / ${matches.length} matching lines',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760 * textSize / 14) {
                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => showFiles = !showFiles),
                            child: Text(
                              showFiles ? 'Show source' : 'Show files',
                            ),
                          ),
                        ),
                        Expanded(child: showFiles ? fileList : content),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 280, child: fileList),
                      const VerticalDivider(width: 24),
                      Expanded(child: content),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
