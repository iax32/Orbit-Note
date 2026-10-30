import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_draft_guard.dart';
import '../../domain/writing_structure.dart';
import '../../domain/document_footnotes.dart';
import '../../domain/document_anchors.dart';
import '../../domain/universal_object.dart';

/// Tools operate on captured source; the owning editor validates every apply.
class WritingWorkspace extends StatefulWidget {
  const WritingWorkspace({
    super.key,
    required this.source,
    required this.noteId,
    required this.objects,
    required this.onApply,
    required this.onNavigate,
    required this.onFocus,
    required this.onOpen,
    required this.onRepair,
    this.onClose,
    this.initialTab = 0,
    this.canApply,
  });
  final String source, noteId;
  final List<UniversalObject> objects;
  final bool Function(String before, String after) onApply;
  final void Function(int start, int length) onNavigate;
  final ValueChanged<String> onFocus, onOpen;
  final Future<void> Function(UniversalObject host, SectionUse use) onRepair;
  final VoidCallback? onClose;
  final int initialTab;
  final bool Function(String before)? canApply;
  @override
  State<WritingWorkspace> createState() => _WritingWorkspaceState();
}

class _WritingWorkspaceState extends State<WritingWorkspace> {
  String query = '';
  late int tab = widget.initialTab;
  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  bool apply(String before, String after) {
    try {
      return widget.onApply(before, after);
    } catch (e) {
      error(e);
      return false;
    }
  }

  void validateSource(String before) {
    if (!mounted ||
        widget.source != before ||
        widget.canApply?.call(before) == false) {
      throw StateError(
        'The note changed or is read-only. Your draft is retained here; copy it before reopening the writing tool.',
      );
    }
  }

  Future<bool> impact(WritingSection section, String action) async {
    final uses = <({UniversalObject host, SectionUse use})>[];
    for (final host in widget.objects.where(
      (o) => o.typeId == 'orbit.note' && !o.isDeleted,
    )) {
      for (final use in sectionUses(host.body)) {
        if (use.link.target.id != widget.noteId) continue;
        final f = resolveDocumentFragment(widget.source, use.link.target);
        if (f != null && f.start >= section.start && f.start < section.end ||
            use.link.target.anchorType == 'heading' &&
                use.link.target.anchorId == section.title) {
          uses.add((host: host, use: use));
        }
      }
    }
    if (uses.isEmpty && action != 'Delete' && action != 'Inspect') return true;
    return await showOrbitDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$action section'),
            scrollable: true,
            content: SizedBox(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('“${section.title}” includes its subordinate sections.'),
                  const SizedBox(height: 12),
                  Text(
                    '${uses.length} live embed(s) use this section or its children. Stable anchors survive moves and renames; deleted targets retain their saved fallback.',
                  ),
                  for (final entry in uses)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          title: Text(entry.host.title),
                          subtitle: Text(entry.use.link.target.target),
                          trailing: IconButton(
                            tooltip: 'Open referencing note',
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () => widget.onOpen(entry.host.id),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            entry.use.link.fallback.length > 400
                                ? '${entry.use.link.fallback.substring(0, 400)}…'
                                : entry.use.link.fallback,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action == 'Inspect' ? 'Close' : action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> move(WritingSection section, int at) async {
    final before = widget.source;
    try {
      final next = moveWritingSection(before, section, at);
      if (next != before && await impact(section, 'Move') && mounted) {
        apply(before, next);
      }
    } catch (e) {
      error(e);
    }
  }

  Future<void> editSection(WritingSection section) async {
    final before = widget.source;
    final draft = await _edit(
      context,
      'Edit heading',
      section.title,
      '${section.level}',
      secondLabel: 'Heading level (1–6)',
      multiline: false,
      validate: (title, level) {
        validateSource(before);
        renameWritingSection(before, section, title, int.tryParse(level) ?? 0);
      },
    );
    if (!mounted || draft == null) return;
    try {
      final next = renameWritingSection(
        before,
        section,
        draft.$1,
        int.tryParse(draft.$2) ?? 0,
      );
      if (await impact(section, 'Change') && mounted) apply(before, next);
    } catch (e) {
      error(e);
    }
  }

  Future<void> editFootnote(String id) async {
    final before = widget.source, model = DocumentFootnotes(widget.source);
    final definitions = model.definitions.where((d) => d.id == id).toList();
    if (definitions.length > 1) {
      error('Duplicate definitions need repair in Source.');
      return;
    }
    final draft = await _edit(
      context,
      'Footnote',
      id,
      definitions.firstOrNull?.text ?? '',
      secondLabel: 'Definition',
      multiline: true,
      validate: (nextId, text) {
        validateSource(before);
        model.save(id, text, renamedId: nextId);
      },
    );
    if (!mounted || draft == null) return;
    try {
      apply(before, model.save(id, draft.$2, renamedId: draft.$1));
    } catch (e) {
      error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = tab == 0
        ? writingSections(widget.source)
        : <WritingSection>[];
    final filtered = sections
        .where((s) => s.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final footnotes = DocumentFootnotes(widget.source);
    final ids =
        footnotes.ids
            .where((id) => id.toLowerCase().contains(query.toLowerCase()))
            .toList()
          ..sort();
    final incoming = <({UniversalObject host, SectionUse use})>[];
    for (final host in widget.objects.where(
      (o) => tab == 2 && o.typeId == 'orbit.note' && !o.isDeleted,
    )) {
      for (final use in sectionUses(host.body)) {
        if (use.link.target.id == widget.noteId) {
          incoming.add((host: host, use: use));
        }
      }
    }
    final outgoing = tab == 2 ? sectionUses(widget.source) : <SectionUse>[];
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Writing workspace',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        tooltip: 'Close writing workspace',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in [
                      (0, 'Sections'),
                      (1, 'Footnotes'),
                      (2, 'Connections'),
                    ])
                      ChoiceChip(
                        label: Text(entry.$2),
                        selected: tab == entry.$1,
                        onSelected: (_) => setState(() {
                          tab = entry.$1;
                          query = '';
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  key: ValueKey(tab),
                  decoration: const InputDecoration(
                    labelText: 'Filter writing tools',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
            ],
          ),
        ),
        tab == 0
            ? SliverList.list(
                children: [
                  ListTile(
                    title: const Text('Plan by headings'),
                    subtitle: const Text(
                      'Drag a section onto another to move it before that heading. Children move with their parent.',
                    ),
                    trailing: IconButton(
                      tooltip: 'Add heading',
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final before = widget.source;
                        final draft = await _edit(
                          context,
                          'Add heading',
                          '',
                          '1',
                          secondLabel: 'Heading level (1–6)',
                          multiline: false,
                        );
                        if (!mounted || draft == null) return;
                        final level = int.tryParse(draft.$2);
                        if (level == null ||
                            level < 1 ||
                            level > 6 ||
                            draft.$1.trim().isEmpty ||
                            draft.$1.contains(RegExp(r'[\r\n]'))) {
                          error('Enter a heading and level 1–6.');
                          return;
                        }
                        final eol = before.contains('\r\n') ? '\r\n' : '\n';
                        // Preserve literal fenced source when adding headings.
                        try {
                          validateWritingAppend(before);
                          apply(
                            before,
                            '$before$eol$eol${'#' * level} ${draft.$1}$eol$eol',
                          );
                        } catch (e) {
                          error(e);
                        }
                      },
                    ),
                  ),
                  for (final s in filtered)
                    DragTarget<({int start, String source, String noteId})>(
                      onWillAcceptWithDetails: (d) =>
                          d.data.start != s.start &&
                          d.data.source == widget.source &&
                          d.data.noteId == widget.noteId,
                      onAcceptWithDetails: (d) {
                        if (d.data.source != widget.source ||
                            d.data.noteId != widget.noteId) {
                          return;
                        }
                        final origin = sections
                            .where((v) => v.start == d.data.start)
                            .firstOrNull;
                        if (origin != null) move(origin, s.start);
                      },
                      builder: (_, candidates, _) =>
                          LongPressDraggable<
                            ({int start, String source, String noteId})
                          >(
                            data: (
                              start: s.start,
                              source: widget.source,
                              noteId: widget.noteId,
                            ),
                            feedback: Material(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(s.title),
                              ),
                            ),
                            child: Container(
                              color: candidates.isEmpty
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                              margin: EdgeInsets.only(
                                left: (s.level - 1) * 12.0,
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.drag_indicator),
                                title: Text(s.title),
                                subtitle: Text(
                                  'Heading ${s.level} · ${s.end - s.start} source characters',
                                ),
                                onTap: () => widget.onNavigate(s.start, 0),
                                trailing: PopupMenuButton<String>(
                                  popUpAnimationStyle:
                                      OrbitMotionScope.popupStyle(context),
                                  tooltip: 'Section actions',
                                  onSelected: (v) async {
                                    if (v == 'focus') widget.onFocus(s.key);
                                    if (v == 'edit') editSection(s);
                                    if (v == 'impact') {
                                      await impact(s, 'Inspect');
                                    }
                                    if (v == 'delete') {
                                      final before = widget.source;
                                      if (await impact(s, 'Delete') &&
                                          mounted) {
                                        apply(
                                          before,
                                          before.replaceRange(
                                            s.start,
                                            s.end,
                                            '',
                                          ),
                                        );
                                      }
                                    }
                                    if (v == 'up') {
                                      final previous = sections
                                          .where(
                                            (n) =>
                                                n.start < s.start &&
                                                n.end <= s.start &&
                                                n.level == s.level,
                                          )
                                          .lastOrNull;
                                      if (previous != null) {
                                        move(s, previous.start);
                                      }
                                    }
                                    if (v == 'down') {
                                      final next = sections
                                          .where(
                                            (n) =>
                                                n.start >= s.end &&
                                                n.level <= s.level,
                                          )
                                          .firstOrNull;
                                      if (next != null) move(s, next.end);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    for (final e in [
                                      ('focus', 'Focus section'),
                                      ('edit', 'Edit heading'),
                                      ('up', 'Move up'),
                                      ('down', 'Move down'),
                                      ('impact', 'Preview linked uses'),
                                      ('delete', 'Delete section'),
                                    ])
                                      PopupMenuItem(
                                        value: e.$1,
                                        child: Text(e.$2),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No matching headings. Add a heading to start planning.',
                      ),
                    ),
                ],
              )
            : tab == 1
            ? SliverList.list(
                children: [
                  for (final id in ids)
                    Builder(
                      builder: (_) {
                        final defs = footnotes.definitions
                                .where((d) => d.id == id)
                                .toList(),
                            refs = footnotes.references
                                .where((r) => r.id == id)
                                .toList();
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '[^$id] · ${refs.length} reference(s)',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  defs.isEmpty
                                      ? 'Missing definition'
                                      : defs.length > 1
                                      ? 'Duplicate definitions'
                                      : defs.single.text,
                                ),
                                if (refs.isEmpty)
                                  const Text('Unused definition'),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: defs.length > 1
                                          ? null
                                          : () => editFootnote(id),
                                      child: const Text('Edit footnote'),
                                    ),
                                    if (defs.isNotEmpty)
                                      TextButton(
                                        onPressed: () => widget.onNavigate(
                                          defs.first.start,
                                          defs.first.end - defs.first.start,
                                        ),
                                        child: const Text('Go to definition'),
                                      ),
                                    for (var i = 0; i < refs.length; i++)
                                      TextButton(
                                        onPressed: () => widget.onNavigate(
                                          refs[i].start,
                                          refs[i].end - refs[i].start,
                                        ),
                                        child: Text('Reference ${i + 1}'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (ids.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Insert a footnote from the editor to begin.',
                      ),
                    ),
                ],
              )
            : SliverList.list(
                children: [
                  const ListTile(title: Text('Used in other notes')),
                  for (final entry in incoming.where(
                    (e) => e.host.title.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
                  ))
                    ListTile(
                      title: Text(entry.host.title),
                      subtitle: Text(entry.use.link.target.target),
                      onTap: () => widget.onOpen(entry.host.id),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Go to original section',
                            icon: const Icon(Icons.my_location),
                            onPressed: () {
                              final f = resolveDocumentFragment(
                                widget.source,
                                entry.use.link.target,
                              );
                              if (f == null) {
                                error(
                                  'Original section is missing or ambiguous.',
                                );
                              } else {
                                widget.onNavigate(f.start, 0);
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Repair incoming section reference',
                            icon: const Icon(Icons.link),
                            onPressed: entry.host.isReadOnly
                                ? null
                                : () => widget.onRepair(entry.host, entry.use),
                          ),
                        ],
                      ),
                    ),
                  if (incoming.isEmpty)
                    const ListTile(
                      title: Text('No notes embed this document yet.'),
                    ),
                  const ListTile(title: Text('Embedded in this note')),
                  for (final use in outgoing)
                    Builder(
                      builder: (_) {
                        final source = widget.objects
                            .where(
                              (o) => o.id == use.link.target.id && !o.isDeleted,
                            )
                            .firstOrNull;
                        final fragment = source == null
                            ? null
                            : resolveDocumentFragment(
                                source.body,
                                use.link.target,
                              );
                        final host = widget.objects
                            .where((o) => o.id == widget.noteId)
                            .firstOrNull;
                        return ListTile(
                          title: Text(source?.title ?? 'Missing note'),
                          subtitle: Text(
                            '${use.link.target.target}${fragment == null ? '\nMissing or ambiguous section · saved fallback retained' : ''}',
                          ),
                          onTap: () =>
                              widget.onNavigate(use.start, use.end - use.start),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Open original',
                                onPressed: source == null
                                    ? null
                                    : () =>
                                          widget.onOpen(use.link.target.target),
                                icon: const Icon(Icons.open_in_new),
                              ),
                              IconButton(
                                tooltip: 'Repair linked section',
                                onPressed: host == null
                                    ? null
                                    : () => widget.onRepair(host, use),
                                icon: const Icon(Icons.link),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (outgoing.isEmpty)
                    const ListTile(
                      title: Text('No linked sections in this note.'),
                    ),
                ],
              ),
      ],
    );
  }
}

Future<(String, String)?> showFootnoteDraft(
  BuildContext context,
  String id,
  String text, {
  void Function(String id, String text)? validate,
}) => _edit(
  context,
  'Footnote',
  id,
  text,
  secondLabel: 'Definition',
  multiline: true,
  validate: validate,
);

Future<(String, String)?> _edit(
  BuildContext context,
  String title,
  String first,
  String second, {
  required String secondLabel,
  required bool multiline,
  void Function(String first, String second)? validate,
}) => showOrbitDialog<(String, String)>(
  context: context,
  builder: (_) => _WritingDraftDialog(
    title: title,
    first: first,
    second: second,
    secondLabel: secondLabel,
    multiline: multiline,
    validate: validate,
  ),
);

class _WritingDraftDialog extends StatefulWidget {
  const _WritingDraftDialog({
    required this.title,
    required this.first,
    required this.second,
    required this.secondLabel,
    required this.multiline,
    this.validate,
  });
  final String title, first, second, secondLabel;
  final bool multiline;
  final void Function(String first, String second)? validate;
  @override
  State<_WritingDraftDialog> createState() => _WritingDraftDialogState();
}

class _WritingDraftDialogState extends State<_WritingDraftDialog> {
  late final a = TextEditingController(text: widget.first);
  late final b = TextEditingController(text: widget.second);
  String? error;
  void apply() {
    try {
      if (widget.validate != null) {
        widget.validate!(a.text.trim(), b.text);
      } else if (widget.multiline) {
        DocumentFootnotes('').save(a.text.trim(), b.text);
      }
      Navigator.pop(context, (a.text.trim(), b.text));
    } catch (failure) {
      setState(
        () => error = switch (failure) {
          ArgumentError(:final message) => '$message',
          StateError(:final message) => message,
          _ => '$failure',
        },
      );
    }
  }

  @override
  void dispose() {
    a.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitDraftGuard(
    dirty: a.text != widget.first || b.text != widget.second,
    builder: (context, requestClose) => OrbitDialog(
      maxWidth: 640,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: a,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.multiline ? 'Identifier' : 'Heading',
                ),
                maxLength: widget.multiline ? 100 : 500,
                onChanged: (_) => setState(() => error = null),
              ),
              TextField(
                controller: b,
                minLines: widget.multiline ? 3 : 1,
                maxLines: widget.multiline ? 12 : 1,
                decoration: InputDecoration(labelText: widget.secondLabel),
                maxLength: widget.multiline ? 100000 : 16,
                onChanged: (_) => setState(() => error = null),
              ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: requestClose, child: const Text('Cancel')),
        FilledButton(onPressed: apply, child: const Text('Apply')),
      ],
    ),
  );
}
