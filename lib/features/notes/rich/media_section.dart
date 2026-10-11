import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../read_attachment_preview.dart';
import '../note_typography.dart';
import 'media_section_source.dart';
import 'figure_details.dart';

class MediaSectionLayout extends StatelessWidget {
  const MediaSectionLayout({
    super.key,
    required this.section,
    required this.image,
    required this.text,
    this.footer,
  });
  final MediaSectionSource section;
  final Widget image, text;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final picture = SizedBox(
        width: section.width.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: section.alt,
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: image,
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: footer!),
          ],
        ),
      );
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (bounds.maxWidth < section.width + 260 * scale) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: picture),
            const SizedBox(height: 16),
            text,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: section.side == 'right'
            ? [Expanded(child: text), const SizedBox(width: 20), picture]
            : [picture, const SizedBox(width: 20), Expanded(child: text)],
      );
    },
  );
}

class FigureFooter extends StatelessWidget {
  const FigureFooter({
    super.key,
    required this.details,
    required this.onOpen,
    this.fontFamily,
    this.missingNotes = const {},
  });
  final FigureDetails details;
  final ValueChanged<String> onOpen;
  final String? fontFamily;
  final Set<String> missingNotes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (details.caption.isNotEmpty)
        Text(
          details.caption,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      if (details.citations.isNotEmpty)
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final citation in details.citations)
              Tooltip(
                message: missingNotes.contains(citation.destination)
                    ? 'Source note is missing: ${citation.label}'
                    : citation.destination,
                child: ActionChip(
                  avatar: Icon(
                    missingNotes.contains(citation.destination)
                        ? Icons.link_off
                        : Icons.link,
                    size: 14,
                  ),
                  label: Text(
                    citation.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => onOpen(citation.destination),
                ),
              ),
          ],
        ),
    ],
  );
}

class MediaSectionSyntax extends md.BlockSyntax {
  const MediaSectionSyntax();
  @override
  RegExp get pattern => MediaSectionSource.opening;
  @override
  bool canParse(md.BlockParser parser) {
    if (!pattern.hasMatch(parser.current.content)) return false;
    final lines = <String>[parser.current.content];
    for (var i = 1; i < 10000; i++) {
      final line = parser.peek(i);
      if (line == null) return false;
      lines.add(line.content);
      if (line.content == MediaSectionSource.closing &&
          MediaSectionSource.endLine(lines, 0) != null) {
        return MediaSectionSource.parse('${lines.join('\n')}\n') != null;
      }
    }
    return false;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    final lines = <String>[];
    do {
      lines.add(parser.current.content);
      parser.advance();
    } while (!parser.isDone &&
        (lines.last != MediaSectionSource.closing ||
            MediaSectionSource.endLine(lines, 0) == null));
    return md.Element.text('orbit-media', '${lines.join('\n')}\n');
  }
}

class MediaSectionBuilder extends MarkdownElementBuilder {
  MediaSectionBuilder({
    required this.typography,
    required this.onTapLink,
    required this.imageBuilder,
  });
  final NoteTypography typography;
  final void Function(String, String?, String) onTapLink;
  final Widget Function(Uri, String?, String?) imageBuilder;
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final section = MediaSectionSource.parse(element.textContent);
    if (section == null) return Text(element.textContent);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: MediaSectionLayout(
        section: section,
        footer: section.figure == null
            ? null
            : FigureFooter(
                details: section.figure!,
                fontFamily: typography.fontFamily,
                onOpen: (s) => onTapLink('', s, ''),
              ),
        image: ReadAttachmentPreview(
          uri: Uri.parse(section.image),
          description: section.alt,
          onOpen: (s) => onTapLink('', s, ''),
          child: imageBuilder(Uri.parse(section.image), null, section.alt),
        ),
        text: MarkdownBody(
          data: section.textBody,
          selectable: true,
          styleSheet: typography.markdown(Theme.of(context)),
          onTapLink: onTapLink,
          imageBuilder: imageBuilder,
        ),
      ),
    );
  }
}
