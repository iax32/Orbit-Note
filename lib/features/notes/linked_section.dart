import '../../app/orbit_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../app/workspace_controller.dart';
import '../../domain/document_anchors.dart';
import '../../domain/linked_section.dart';
import '../../domain/object_reference.dart';
import '../../domain/universal_object.dart';
import '../../domain/wiki_links.dart';
import 'note_typography.dart';
import 'rich/note_math.dart';
import 'rich/note_highlight.dart';
import 'rich/note_underline.dart';
import 'rich/callout_block.dart';
import 'rich/code_block.dart';

/// Shared only for one render tree, never persisted or used to change source.
class LinkedSectionPreviewBudget {
  int remaining = 24;
}

class LinkedSectionSyntax extends md.BlockSyntax {
  const LinkedSectionSyntax();
  @override
  RegExp get pattern => LinkedSection.opening;
  @override
  bool canParse(md.BlockParser parser) {
    if (!pattern.hasMatch(parser.current.content)) return false;
    final lines = [parser.current.content];
    for (var i = 1; i < 10000; i++) {
      final line = parser.peek(i);
      if (line == null) return false;
      lines.add(line.content);
      if (line.content == LinkedSection.closing) {
        return LinkedSection.parse(lines.join('\n')) != null;
      }
      if (!line.content.startsWith('> ')) return false;
    }
    return false;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    do {
      lines.add(parser.current.content);
      parser.advance();
    } while (!parser.isDone && lines.last != LinkedSection.closing);
    return md.Element.text('orbit-section', lines.join('\n'));
  }
}

class LinkedSectionBuilder extends MarkdownElementBuilder {
  LinkedSectionBuilder({
    required this.objects,
    required this.onOpen,
    required this.typography,
    this.ancestors = const {},
    this.imageBuilder,
    this.budget,
  });
  final List<UniversalObject> objects;
  final ValueChanged<String> onOpen;
  final NoteTypography typography;
  final Set<String> ancestors;
  final Widget Function(BuildContext, String)? imageBuilder;
  final LinkedSectionPreviewBudget? budget;
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final link = LinkedSection.parse(element.textContent);
    if (link == null) return Text(element.textContent);
    if (budget != null && budget!.remaining-- <= 0) {
      return TextButton(
        onPressed: () => onOpen(link.target.target),
        child: const Text('More linked sections — open source to continue'),
      );
    }
    return LinkedSectionCard(
      link: link,
      objects: objects,
      onOpen: onOpen,
      typography: typography,
      ancestors: ancestors,
      imageBuilder: imageBuilder,
      budget: budget,
    );
  }
}

class LinkedSectionCard extends StatelessWidget {
  const LinkedSectionCard({
    super.key,
    required this.link,
    required this.objects,
    required this.onOpen,
    required this.typography,
    this.ancestors = const {},
    this.onRemove,
    this.onCopy,
    this.imageBuilder,
    this.budget,
  });
  final LinkedSection link;
  final List<UniversalObject> objects;
  final ValueChanged<String> onOpen;
  final NoteTypography typography;
  final Set<String> ancestors;
  final VoidCallback? onRemove;
  final ValueChanged<String>? onCopy;
  final Widget Function(BuildContext, String)? imageBuilder;
  final LinkedSectionPreviewBudget? budget;
  @override
  Widget build(BuildContext context) {
    final resolved = resolveLinkedSection(link, objects, ancestors);
    final title =
        objects
            .where((o) => o.id == link.target.id && !o.isDeleted)
            .firstOrNull
            ?.title ??
        'Missing note';
    final colors = Theme.of(context).colorScheme;
    final chain = {...ancestors, link.target.id};
    final previewBudget = budget ?? LinkedSectionPreviewBudget();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Icon(Icons.link, size: 18),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              TextButton(
                onPressed: () => onOpen(link.target.target),
                child: const Text('Open source'),
              ),
              if (onCopy != null)
                TextButton(
                  onPressed: () =>
                      onCopy!(snapshotLinkedSection(link, objects, ancestors)),
                  child: const Text('Make independent copy'),
                ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove linked section',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          if (resolved.warning != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  resolved.warning!,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ),
          if (resolved.text.length > 100000)
            const Text(
              'Saved snapshot exceeds the preview limit. Open the source or make an independent copy.',
            )
          else
            MarkdownBody(
              data: wikiLinksToMarkdown(resolved.text, [
                for (final o in objects.where((o) => !o.isDeleted))
                  NoteLinkTarget(id: o.id, title: o.title),
              ]),
              selectable: true,
              styleSheet: typography.markdown(Theme.of(context)),
              inlineSyntaxes: [
                MathInlineSyntax(),
                HighlightInlineSyntax(),
                UnderlineInlineSyntax(),
              ],
              blockSyntaxes: resolved.warning == null
                  ? const [
                      LinkedSectionSyntax(),
                      MathBlockSyntax(),
                      MathTableSyntax(),
                      CalloutBlockSyntax(),
                    ]
                  : const [
                      MathBlockSyntax(),
                      MathTableSyntax(),
                      CalloutBlockSyntax(),
                    ],
              builders: {
                'pre': CodeElementBuilder(),
                'math-inline': MathElementBuilder(),
                'math-block': MathElementBuilder(),
                'mark': HighlightElementBuilder(),
                'u': UnderlineElementBuilder(),
                'callout': CalloutElementBuilder(
                  typography: typography,
                  onTapLink: (_, href, _) {
                    if (href != null) onOpen(href);
                  },
                ),
                'orbit-section': LinkedSectionBuilder(
                  objects: objects,
                  onOpen: onOpen,
                  typography: typography,
                  ancestors: chain,
                  imageBuilder: imageBuilder,
                  budget: previewBudget,
                ),
              },
              onTapLink: (_, href, _) {
                if (href != null) onOpen(href);
              },
              imageBuilder: imageBuilder == null
                  ? null
                  : (uri, _, _) => imageBuilder!(context, uri.toString()),
            ),
        ],
      ),
    );
  }
}

/// Choosing an unanchored fragment saves its anchor through normal note history.
Future<String?> showLinkedSectionPicker(
  BuildContext context,
  List<UniversalObject> objects,
  String hostId,
  WorkspaceController? controller,
) => showOrbitDialog<String>(
  context: context,
  builder: (_) =>
      _SectionPicker(objects: objects, hostId: hostId, controller: controller),
);

class _SectionPicker extends StatefulWidget {
  const _SectionPicker({
    required this.objects,
    required this.hostId,
    this.controller,
  });
  final List<UniversalObject> objects;
  final String hostId;
  final WorkspaceController? controller;
  @override
  State<_SectionPicker> createState() => _SectionPickerState();
}

class _SectionPickerState extends State<_SectionPicker> {
  String query = '';
  ({UniversalObject note, DocumentFragment fragment})? selected;
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final choices = [
      for (final note in widget.objects)
        if (!note.isDeleted &&
            !note.isReadOnly &&
            note.id != widget.hostId &&
            note.typeId == 'orbit.note' &&
            note.properties['documentFormat'] != 'latex')
          for (final fragment in documentFragments(note.body))
            if (isLinkableFragment(fragment) &&
                '${note.title} ${fragment.text}'.toLowerCase().contains(
                  query.toLowerCase(),
                ))
              (note: note, fragment: fragment),
    ];
    return Dialog(
      child: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link a note section',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search notes and sections',
                ),
                onChanged: (v) => setState(() {
                  query = v;
                  selected = null;
                }),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: choices.length,
                  itemBuilder: (_, i) {
                    final choice = choices[i];
                    return ListTile(
                      selected: selected == choice,
                      title: Text(choice.note.title),
                      subtitle: Text(
                        withoutBlockAnchor(choice.fragment.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: busy
                          ? null
                          : () => setState(() => selected = choice),
                    );
                  },
                ),
              ),
              if (selected != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      selectable: true,
                      data: withoutBlockAnchor(
                        linkedFragment(
                              selected!.note.body,
                              LinkedSection(
                                ObjectReference(
                                  selected!.note.id,
                                  anchorType: selected!.fragment.blockId == null
                                      ? 'heading'
                                      : 'block',
                                  anchorId:
                                      selected!.fragment.blockId ??
                                      selected!.fragment.heading,
                                ),
                                '',
                                section: selected!.fragment.heading != null,
                              ),
                            )?.text ??
                            selected!.fragment.text,
                      ),
                    ),
                  ),
                ),
              if (choices.isEmpty) const Text('No matching Markdown sections.'),
              if (error != null) Text(error!),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: selected == null || busy ? null : insert,
                    child: Text(
                      busy ? 'Saving source…' : 'Insert linked section',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> insert() async {
    final choice = selected!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final current = widget.controller?.find(choice.note.id) ?? choice.note;
      if (current.body != choice.note.body || current.isDeleted) {
        throw StateError('Source changed. Reopen the picker.');
      }
      ObjectReference reference;
      if (choice.fragment.blockId != null) {
        reference = ObjectReference(
          current.id,
          anchorType: 'block',
          anchorId: choice.fragment.blockId,
        );
      } else if (widget.controller != null) {
        reference = await widget.controller!.referenceNoteBlock(
          current.id,
          choice.fragment.start,
          structured: true,
        );
      } else if (choice.fragment.heading != null) {
        reference = ObjectReference(
          current.id,
          anchorType: 'heading',
          anchorId: choice.fragment.heading,
        );
      } else {
        throw StateError('A saved block anchor is required.');
      }
      final updated = widget.controller?.find(current.id) ?? current;
      final link = LinkedSection(
        reference,
        '',
        section: choice.fragment.heading != null,
      );
      final fragment = linkedFragment(updated.body, link);
      if (fragment == null) throw StateError('Source is missing or ambiguous.');
      if (fragment.text.length > 100000) {
        throw StateError('Choose a section smaller than 100,000 characters.');
      }
      final result = LinkedSection(
        reference,
        withoutBlockAnchor(fragment.text),
        section: link.section,
      ).encode();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }
}
