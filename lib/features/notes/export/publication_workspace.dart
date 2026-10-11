import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../domain/document_publication.dart';
import '../../../domain/universal_object.dart';
import '../../../platform/export_file.dart';
import 'publication_export.dart';
import 'publication_math.dart';

Future<void> showPublicationWorkspace(
  BuildContext context, {
  required String title,
  required String source,
  required String ownerId,
  List<UniversalObject> objects = const [],
  Future<Uint8List?> Function(String)? readImage,
}) => showDialog<void>(
  context: context,
  builder: (_) => PublicationWorkspace(
    title: title,
    source: source,
    ownerId: ownerId,
    objects: objects,
    readImage: readImage,
  ),
);

class PublicationWorkspace extends StatefulWidget {
  const PublicationWorkspace({
    super.key,
    required this.title,
    required this.source,
    this.ownerId = '',
    this.objects = const [],
    this.readImage,
    this.previewBuilder,
  });
  final String title, source, ownerId;
  final List<UniversalObject> objects;
  final Future<Uint8List?> Function(String)? readImage;
  final Widget Function(Uint8List)? previewBuilder;
  @override
  State<PublicationWorkspace> createState() => _PublicationWorkspaceState();
}

class _PublicationWorkspaceState extends State<PublicationWorkspace> {
  bool letter = false,
      serif = false,
      numbering = false,
      titlePage = false,
      contents = true,
      pageNumbers = true,
      busy = true,
      exporting = false;
  double margin = 54, fontSize = 11;
  final author = TextEditingController(), header = TextEditingController();
  Timer? debounce;
  int revision = 0;
  String? error;
  Uint8List? preview;
  PublicationExport? ready;
  Map<String, Uint8List>? images, equations;
  Future<void>? resourceFuture;
  final resourceWarnings = <String>[];
  @override
  void initState() {
    super.initState();
    generate();
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    author.dispose();
    header.dispose();
    super.dispose();
  }

  PublicationStyle get style => PublicationStyle(
    letter: letter,
    serif: serif,
    numberHeadings: numbering,
    titlePage: titlePage,
    contents: contents,
    pageNumbers: pageNumbers,
    margin: margin,
    fontSize: fontSize,
    author: author.text,
    header: header.text,
  );
  void change(VoidCallback action) {
    setState(() {
      action();
      busy = true;
      ready = null;
      error = null;
    });
    revision++;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), generate);
  }

  Future<void> resources(PublicationExport export) =>
      resourceFuture ??= loadResources(export);
  Future<void> loadResources(PublicationExport export) async {
    if (images != null) return;
    final loadedImages = <String, Uint8List>{},
        loadedMath = <String, Uint8List>{};
    var totalBytes = 0, count = 0;
    for (final element in export.elements) {
      if (!mounted) return;
      if (element.tag == 'img') {
        final src = element.attributes['src'] ?? '';
        if (loadedImages.containsKey(src)) continue;
        if (++count > 100) {
          resourceWarnings.add(
            'Only the first 100 image/equation resources are embedded.',
          );
          break;
        }
        try {
          final uri = Uri.tryParse(src);
          Uint8List? bytes;
          if (uri?.scheme == 'data' && src.startsWith('data:image/')) {
            bytes = UriData.parse(src).contentAsBytes();
          } else if (uri?.hasScheme != true && !src.startsWith('//')) {
            bytes = await widget.readImage?.call(src);
          }
          if (bytes == null ||
              bytes.length > 20 * 1024 * 1024 ||
              totalBytes + bytes.length > 64 * 1024 * 1024) {
            throw const FormatException('Missing, external or oversized image');
          }
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          late ui.Codec codec;
          try {
            final descriptor = await ui.ImageDescriptor.encoded(buffer);
            try {
              if (descriptor.width * descriptor.height > 100000000) {
                throw const FormatException(
                  'Image exceeds 100 million pixels.',
                );
              }
              final scale =
                  1600 /
                  (descriptor.width > descriptor.height
                      ? descriptor.width
                      : descriptor.height);
              codec = await descriptor.instantiateCodec(
                targetWidth: scale < 1
                    ? (descriptor.width * scale).round().clamp(1, 1600)
                    : descriptor.width,
                targetHeight: scale < 1
                    ? (descriptor.height * scale).round().clamp(1, 1600)
                    : descriptor.height,
              );
            } finally {
              descriptor.dispose();
            }
          } finally {
            buffer.dispose();
          }
          try {
            final frame = await codec.getNextFrame();
            try {
              final png = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final encoded = png!.buffer.asUint8List();
              if (totalBytes + encoded.length > 64 * 1024 * 1024) {
                throw const FormatException('Image memory limit reached.');
              }
              loadedImages[src] = encoded;
              totalBytes += encoded.length;
              if (codec.frameCount > 1) {
                resourceWarnings.add(
                  'Animated image uses its first frame: $src',
                );
              }
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        } catch (_) {
          resourceWarnings.add('Image retained as labelled fallback: $src');
        }
      } else if (element.tag.startsWith('math')) {
        final tex = element.textContent;
        if (loadedMath.containsKey(tex)) continue;
        if (++count > 100) {
          resourceWarnings.add(
            'Only the first 100 image/equation resources are embedded.',
          );
          break;
        }
        try {
          final bytes = await renderPublicationMath(tex);
          if (totalBytes + bytes.length > 64 * 1024 * 1024) {
            throw const FormatException('Equation image memory limit reached.');
          }
          loadedMath[tex] = bytes;
          totalBytes += bytes.length;
        } catch (_) {
          resourceWarnings.add(
            'Equation retained as editable TeX fallback: $tex',
          );
        }
      }
    }
    images = loadedImages;
    equations = loadedMath;
  }

  Future<void> generate() async {
    final ticket = ++revision;
    try {
      final document = PublicationDocument.parse(
        widget.title,
        widget.source,
        style,
        objects: widget.objects,
        ownerId: widget.ownerId,
      );
      final initial = PublicationExport(document);
      await resources(initial);
      if (!mounted || ticket != revision) return;
      final export = PublicationExport(
        document,
        images: images ?? {},
        equations: equations ?? {},
        warnings: resourceWarnings,
      );
      Uint8List? bytes;
      String? pdfError;
      try {
        bytes = await export.pdf();
      } catch (failure) {
        pdfError = 'PDF preview unavailable: $failure';
        export.warn(pdfError);
      }
      // Generate all formats before showing the common fidelity report.
      export.html();
      export.docx();
      if (!mounted || ticket != revision) return;
      setState(() {
        preview = bytes;
        ready = export;
        busy = false;
        error = pdfError;
      });
    } catch (failure) {
      if (!mounted || ticket != revision) return;
      setState(() {
        error = 'Unable to publish this snapshot: $failure';
        busy = false;
        ready = null;
      });
    }
  }

  Future<void> save(String format) async {
    final snapshot = ready, bytes = preview;
    if (snapshot == null || (format == 'pdf' && bytes == null) || exporting) {
      return;
    }
    setState(() => exporting = true);
    try {
      final name = publicationFileName(widget.title);
      final saved = format == 'html'
          ? await exportFile(
              '$name.html',
              snapshot.html(),
              mimeType: 'text/html',
            )
          : await exportBinaryFile(
              '$name.$format',
              format == 'pdf' ? bytes! : snapshot.docx(),
              mimeType: format == 'pdf'
                  ? 'application/pdf'
                  : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            );
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} exported')),
        );
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = 'Export failed; your note is unchanged. $failure',
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Document style presets',
            onSelected: exporting
                ? null
                : (value) => change(() {
                    serif = value == 'Academic';
                    fontSize = serif ? 12 : 11;
                    margin = serif
                        ? 72
                        : value == 'Design brief'
                        ? 48
                        : 54;
                    numbering = serif;
                    titlePage = serif;
                    contents = true;
                    pageNumbers = true;
                  }),
            itemBuilder: (_) => [
              for (final name in ['Report', 'Academic', 'Design brief'])
                PopupMenuItem(value: name, child: Text(name)),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Style presets ▾'),
            ),
          ),
          TextButton(
            onPressed: exporting
                ? null
                : () => change(() {
                    letter = false;
                    serif = false;
                    fontSize = 11;
                    margin = 54;
                    numbering = false;
                    titlePage = false;
                    contents = true;
                    pageNumbers = true;
                  }),
            child: const Text('Reset style'),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('A4'),
            selected: !letter,
            onSelected: exporting ? null : (_) => change(() => letter = false),
          ),
          ChoiceChip(
            label: const Text('Letter'),
            selected: letter,
            onSelected: exporting ? null : (_) => change(() => letter = true),
          ),
          ChoiceChip(
            label: const Text('Sans'),
            selected: !serif,
            onSelected: exporting ? null : (_) => change(() => serif = false),
          ),
          ChoiceChip(
            label: const Text('Serif'),
            selected: serif,
            onSelected: exporting ? null : (_) => change(() => serif = true),
          ),
        ],
      ),
      Text('Margins · ${margin.round()} pt'),
      Slider(
        value: margin,
        min: 24,
        max: 90,
        divisions: 11,
        label: '${margin.round()} pt',
        onChanged: exporting ? null : (v) => change(() => margin = v),
      ),
      Text('Body text · ${fontSize.round()} pt'),
      Slider(
        value: fontSize,
        min: 9,
        max: 18,
        divisions: 9,
        label: '${fontSize.round()} pt',
        onChanged: exporting ? null : (v) => change(() => fontSize = v),
      ),
      TextField(
        controller: author,
        enabled: !exporting,
        maxLength: 500,
        decoration: const InputDecoration(labelText: 'Author', counterText: ''),
        onChanged: (_) => change(() {}),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: header,
        enabled: !exporting,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Running header',
          counterText: '',
        ),
        onChanged: (_) => change(() {}),
      ),
      for (final item in <(String, bool, void Function(bool))>[
        ('Title page', titlePage, (v) => titlePage = v),
        ('Contents', contents, (v) => contents = v),
        ('Number headings', numbering, (v) => numbering = v),
        ('Page numbers', pageNumbers, (v) => pageNumbers = v),
      ])
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.$1),
          value: item.$2,
          onChanged: exporting ? null : (v) => change(() => item.$3(v!)),
        ),
      const Text(
        'Insert a page break from Writing tools before opening this preview. Exports use the note snapshot captured when you open Publish.',
      ),
      if (ready != null && ready!.warnings.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text(
          'Export details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        for (final warning in ready!.warnings.toSet())
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(warning)),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 1200,
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.auto_stories_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Publish · ${widget.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close publishing',
                  onPressed: exporting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final narrow =
                    bounds.maxWidth <
                    760 * (MediaQuery.textScalerOf(context).scale(14) / 14);
                final previewPane = Stack(
                  children: [
                    Positioned.fill(
                      child: error != null
                          ? Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(error!),
                                      TextButton(
                                        onPressed: generate,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : preview == null
                          ? const Center(child: Text('Preparing pages…'))
                          : widget.previewBuilder?.call(preview!) ??
                                PdfViewer.data(
                                  preview!,
                                  sourceName:
                                      'publication-${identityHashCode(preview)}',
                                ),
                    ),
                    if (busy)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(),
                      ),
                  ],
                );
                final controls = SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: settings(),
                );
                if (narrow) {
                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Pages'),
                            Tab(text: 'Document style'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(children: [previewPane, controls]),
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    SizedBox(width: 300, child: controls),
                    const VerticalDivider(width: 1),
                    Expanded(child: previewPane),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final format in ['pdf', 'html', 'docx'])
                  FilledButton.tonal(
                    onPressed:
                        busy ||
                            exporting ||
                            ready == null ||
                            (format == 'pdf' && preview == null)
                        ? null
                        : () => save(format),
                    child: Text(
                      format == 'docx'
                          ? 'Export Word'
                          : 'Export ${format.toUpperCase()}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
