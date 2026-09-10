import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'latex_catalog.dart';
import 'note_math.dart';

class EquationEditor extends StatefulWidget {
  const EquationEditor({
    super.key,
    required this.source,
    required this.display,
  });
  final String source;
  final bool display;
  @override
  State<EquationEditor> createState() => _EquationEditorState();
}

class _EquationEditorState extends State<EquationEditor> {
  late final input = TextEditingController(text: widget.source);
  late final focus = FocusNode(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          input.value.composing.isCollapsed &&
          !HardwareKeyboard.instance.isControlPressed) {
        final start = input.selection.isValid ? input.selection.start : 0;
        final end = input.selection.isValid ? input.selection.end : 0;
        final next = HardwareKeyboard.instance.isShiftPressed
            ? (start == 0 ? -1 : input.text.lastIndexOf(r'\square', start - 1))
            : input.text.indexOf(r'\square', end);
        if (next >= 0) {
          input.selection = TextSelection(
            baseOffset: next,
            extentOffset: next + 7,
          );
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );
  String query = '', category = 'All';
  void insert(LatexEntry entry) {
    final selection = input.selection.isValid
        ? input.selection
        : TextSelection.collapsed(offset: input.text.length);
    var value = entry.source;
    final selected = selection.textInside(input.text);
    if (selected.isNotEmpty && value.contains(r'\square')) {
      value = value.replaceFirst(r'\square', selected);
    }
    // Separate a control word from subsequent typed letters without changing
    // its meaning, including insertion in the middle of an existing formula.
    if (RegExp(r'\\[a-zA-Z]+$').hasMatch(value)) {
      value += ' ';
    }
    final placeholder = value.indexOf(r'\square');
    input.value = TextEditingValue(
      text: input.text.replaceRange(selection.start, selection.end, value),
      selection: placeholder < 0
          ? TextSelection.collapsed(offset: selection.start + value.length)
          : TextSelection(
              baseOffset: selection.start + placeholder,
              extentOffset: selection.start + placeholder + 7,
            ),
    );
    focus.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = latexCatalog
        .where(
          (e) =>
              (category == 'All' || e.category == category) &&
              '${e.name} ${e.source} ${e.glyph}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return AlertDialog(
      title: Text(widget.display ? 'Block equation' : 'Inline equation'),
      content: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            SizedBox(
              height: 76,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: NoteMath(input.text, display: widget.display),
                ),
              ),
            ),
            TextField(
              key: const ValueKey('equation-source'),
              controller: input,
              focusNode: focus,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Equation',
                helperText:
                    'Choose symbols below. Tab moves to the next square.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('latex-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search symbols or names…',
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final name in {
                    'All',
                    ...latexCatalog.map((e) => e.category),
                  })
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: category == name,
                        onSelected: (_) => setState(() => category = name),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  return ListTile(
                    dense: true,
                    title: Text(entry.name),
                    subtitle: Text(
                      entry.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: SizedBox(
                      width: 50,
                      child: FittedBox(child: NoteMath(entry.source)),
                    ),
                    onTap: () => insert(entry),
                  );
                },
              ),
            ),
            Text(
              '${entries.length} entries · all registered math symbols in this renderer',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, input.text),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
