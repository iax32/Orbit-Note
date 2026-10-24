import '../../../platform/publication_image_download.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../../domain/document_publication.dart';
import '../../../domain/json_values.dart';
import '../../../app/orbit_draft_guard.dart';
import '../../../domain/publication_layout.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../domain/universal_object.dart';
import '../../../platform/export_file.dart';
import 'publication_export.dart';
import 'publication_math.dart';
import 'publication_svg.dart';
import 'publication_canvas.dart';

Future<void> showPublicationWorkspace(
  BuildContext context, {
  required String title,
  required String source,
  required String ownerId,
  List<UniversalObject> objects = const [],
  Map<String, String> objectPaths = const {},
  Future<Uint8List?> Function(String)? readImage,
  bool Function(String, String)? onApply,
}) => showDialog<void>(
  context: context,
  builder: (_) => PublicationWorkspace(
    title: title,
    source: source,
    ownerId: ownerId,
    objects: objects,
    objectPaths: objectPaths,
    readImage: readImage,
    onApply: onApply,
  ),
);

class PublicationWorkspace extends StatefulWidget {
  const PublicationWorkspace({
    super.key,
    required this.title,
    required this.source,
    this.ownerId = '',
    this.objects = const [],
    this.objectPaths = const {},
    this.readImage,
    this.previewBuilder,
    this.onApply,
    this.onNavigatePage,
    this.imageDownloader,
  });
  final String title, source, ownerId;
  final List<UniversalObject> objects;
  final Map<String, String> objectPaths;
  final Future<Uint8List?> Function(String)? readImage;
  final Widget Function(Uint8List)? previewBuilder;
  final bool Function(String before, String next)? onApply;
  final ValueChanged<int>? onNavigatePage;
  final PublicationImageDownload? imageDownloader;
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
  String? error, exportError;
  late Object appliedSettings;
  Map<String, dynamic> get currentSettings => {
    'style': style.toJson(),
    'blocks': layouts,
  };
  void rememberSettings() {
    appliedSettings = jsonDecode(jsonEncode(currentSettings));
  }

  Uint8List? preview;
  PublicationExport? ready;
  Map<String, Uint8List>? images, equations;
  Future<void>? resourceFuture;
  final resourceWarnings = <String>[];
  late final publicationObjects = List<UniversalObject>.unmodifiable(
    widget.objects,
  );
  late final publicationPaths = Map<String, String>.unmodifiable(
    widget.objectPaths,
  );
  late final snapshotTime = DateTime.now();
  late String source;
  final layouts = <String, Map<String, dynamic>>{};
  final layoutResetSerial = <String, int>{};
  final contentsFind = TextEditingController();
  int contentsPage = 0, layoutsPage = 0;
  final viewerController = PdfViewerController();
  String? settingsWarning;
  bool saved = false, includeWebImages = false, webImagesCancelled = false;
  late final imageDownloader =
      widget.imageDownloader ?? PublicationImageDownload();
  bool get hasWebImages =>
      ready?.elements.any(
        (element) =>
            element.tag == 'img' &&
            (Uri.tryParse(element.attributes['src'] ?? '')?.hasScheme == true ||
                (element.attributes['src'] ?? '').startsWith('//')) &&
            Uri.tryParse(element.attributes['src'] ?? '')?.scheme != 'data' &&
            !ready!.document.objectSnapshots.canvases.containsKey(
              element.attributes['src'],
            ),
      ) ??
      false;

  void reloadImages({bool web = false}) {
    if (busy || exporting) return;
    imageDownloader.cancel();
    change(() {
      includeWebImages = includeWebImages || web;
      webImagesCancelled = false;
      images = equations = null;
      resourceFuture = null;
      resourceWarnings.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    source = widget.source;
    final existing = PublicationSettings.parse(source);
    try {
      if (source.startsWith(PublicationSettings.prefix) && existing == null) {
        throw const FormatException(
          'Unrecognized publishing settings are preserved. Use Source to repair them before saving new settings.',
        );
      }
      if (existing != null) {
        final initial = PublicationStyle.fromJson(
          Map<String, dynamic>.from(existing.data['style'] as Map),
        );
        letter = initial.letter;
        serif = initial.serif;
        numbering = initial.numberHeadings;
        titlePage = initial.titlePage;
        contents = initial.contents;
        pageNumbers = initial.pageNumbers;
        margin = initial.margin;
        fontSize = initial.fontSize;
        author.text = initial.author;
        header.text = initial.header;
        for (final e in (existing.data['blocks'] as Map).entries) {
          layouts[e.key as String] = Map<String, dynamic>.from(e.value as Map);
        }
      }
    } catch (failure) {
      settingsWarning = '$failure';
    }
    rememberSettings();
    generate();
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    imageDownloader.dispose();
    author.dispose();
    header.dispose();
    contentsFind.dispose();
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
      error = null;
      saved = false;
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
    final seenImages = <String>{};
    for (final element in export.elements) {
      if (!mounted) return;
      if (element.tag == 'img') {
        final src = element.attributes['src'] ?? '';
        if (!seenImages.add(src)) continue;
        if (++count > 100) {
          resourceWarnings.add(
            'Only the first 100 image/equation resources are embedded.',
          );
          break;
        }
        try {
          final uri = Uri.tryParse(src.startsWith('//') ? 'https:$src' : src);
          Uint8List? bytes;
          final canvasSnapshot = export.document.objectSnapshots.canvases[src];
          if (canvasSnapshot != null) {
            bytes = await renderPublicationCanvas(
              canvasSnapshot,
              objects: export.document.objectSnapshots.objects,
              readImage: widget.readImage,
              warn: (message) {
                if (!resourceWarnings.contains(message)) {
                  resourceWarnings.add(message);
                }
              },
            );
          } else if (uri?.scheme == 'data' && src.startsWith('data:image/')) {
            bytes = UriData.parse(src).contentAsBytes();
          } else if (uri?.hasScheme != true && !src.startsWith('//')) {
            bytes = await widget.readImage?.call(src);
          } else if (uri != null &&
              includeWebImages &&
              !webImagesCancelled &&
              PublicationImageDownload.allows(uri)) {
            bytes = await imageDownloader.read(uri);
          }
          if (!mounted) return;
          if (bytes == null ||
              bytes.length > 20 * 1024 * 1024 ||
              totalBytes + bytes.length > 64 * 1024 * 1024) {
            throw const FormatException('Missing, external or oversized image');
          }
          if (isPublicationSvg(bytes)) {
            bytes = await renderPublicationSvg(bytes);
            resourceWarnings.add(
              'SVG diagram uses a static image preview in publishing: $src',
            );
          }
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          ui.ImageDescriptor? descriptor;
          ui.Codec? codec;
          try {
            // The encoded buffer and descriptor must outlive frame decoding.
            // Disposing either after instantiateCodec can leave an otherwise
            // valid PNG/JPEG without its source bytes when getNextFrame runs.
            descriptor = await ui.ImageDescriptor.encoded(buffer);
            if (descriptor.width * descriptor.height > 100000000) {
              throw const FormatException('Image exceeds 100 million pixels.');
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
            final frame = await codec.getNextFrame();
            try {
              final png = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final encoded = png!.buffer.asUint8List(
                png.offsetInBytes,
                png.lengthInBytes,
              );
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
            codec?.dispose();
            descriptor?.dispose();
            buffer.dispose();
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
    if (!mounted) return;
    images = loadedImages;
    equations = loadedMath;
  }

  Future<void> generate() async {
    final ticket = ++revision;
    try {
      final document = PublicationDocument.parse(
        widget.title,
        source,
        style,
        objects: publicationObjects,
        objectPaths: publicationPaths,
        snapshotTime: snapshotTime,
        ownerId: widget.ownerId,
        layouts: layouts,
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
    if (snapshot == null ||
        (format == 'pdf' && bytes == null) ||
        exporting ||
        busy) {
      return;
    }
    setState(() {
      exporting = true;
      exportError = null;
    });
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
          () => exportError =
              'Export failed; your preview and settings are retained. Try exporting again. $failure',
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget settings(BuildContext controlsContext) {
    final headings =
        ready?.document.headings
            .where(
              (h) => h.text.toLowerCase().contains(
                contentsFind.text.toLowerCase(),
              ),
            )
            .toList() ??
        <PublicationHeading>[];
    final targets =
        ready?.document.nodes.indexed
            .where((entry) => publicationLayoutTarget(entry.$2))
            .toList() ??
        <(int, md.Node)>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exportError != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                exportError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
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
              onSelected: exporting
                  ? null
                  : (_) => change(() => letter = false),
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
        const SizedBox(height: 12),
        const Text('Images', style: TextStyle(fontWeight: FontWeight.w600)),
        if (images != null)
          Text('${images!.length} image(s) embedded in this export.'),
        if (hasWebImages || includeWebImages) ...[
          const Text(
            'Web images need an explicit download. HTTPS images are embedded in this export only; your note and Vault are not uploaded. Some sites require sign-in or block downloads.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy || exporting
                    ? null
                    : () => reloadImages(web: true),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  includeWebImages ? 'Retry web images' : 'Load web images',
                ),
              ),
              if (busy && includeWebImages)
                TextButton(
                  onPressed: () {
                    webImagesCancelled = true;
                    imageDownloader.cancel();
                  },
                  child: const Text('Cancel web image loading'),
                ),
            ],
          ),
        ],
        if (resourceWarnings.any((w) => w.startsWith('Image retained')))
          TextButton(
            onPressed: busy || exporting ? null : () => reloadImages(),
            child: const Text('Retry missing images'),
          ),
        const SizedBox(height: 12),
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
          decoration: const InputDecoration(
            labelText: 'Author',
            counterText: '',
          ),
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
          'All exports use these document settings. Images and tables have print layout controls below. Save settings to retain them with this note.',
        ),
        if (settingsWarning != null)
          Text(
            settingsWarning!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (ready != null) ...[
          const SizedBox(height: 16),
          Text(
            'Contents · ${ready!.pageCount} pages',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: contentsFind,
            decoration: const InputDecoration(
              labelText: 'Find a chapter',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() => contentsPage = 0),
          ),
          for (final heading in headings.skip(contentsPage * 20).take(20))
            ListTile(
              contentPadding: EdgeInsets.only(left: (heading.level - 1) * 8),
              title: Text(heading.text),
              subtitle: Text(
                busy
                    ? 'Updating pages…'
                    : ready!.headingPages[heading.id] == null
                    ? 'Page unavailable'
                    : 'Page ${ready!.headingPages[heading.id]}',
              ),
              enabled: !busy && ready!.headingPages.containsKey(heading.id),
              onTap: () {
                final page = ready!.headingPages[heading.id];
                if (page == null) return;
                if (widget.onNavigatePage != null) {
                  widget.onNavigatePage!(page);
                } else if (viewerController.isReady) {
                  unawaited(viewerController.goToPage(pageNumber: page));
                }
                DefaultTabController.maybeOf(controlsContext)?.animateTo(0);
              },
            ),
          if (headings.length > 20)
            _paging(
              'Contents',
              contentsPage,
              headings.length,
              (page) => setState(() => contentsPage = page),
            ),
          const SizedBox(height: 16),
          const Text(
            'Images & tables',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Print layout for standalone images and tables. Inline images retain their text-flow layout.',
          ),
          for (final entry in targets.skip(layoutsPage * 20).take(20))
            _layoutControl(entry.$2 as md.Element, entry.$1),
          if (targets.length > 20)
            _paging(
              'Layouts',
              layoutsPage,
              targets.length,
              (page) => setState(() => layoutsPage = page),
            ),
        ],
        if (ready != null &&
            ready!.document.objectSnapshots.objectCount > 0) ...[
          const SizedBox(height: 16),
          const Text(
            'Connected content',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${ready!.document.objectSnapshots.objectCount} linked object block(s) · ${ready!.document.objectSnapshots.canvases.length} Canvas snapshot(s)',
          ),
          const Text(
            'Captured when publishing opened. Reopen to refresh linked content. Source objects are unchanged.',
          ),
        ],
        if (ready != null && ready!.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Export details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final warning in ready!.warnings.toSet())
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(warning),
            ),
        ],
      ],
    );
  }

  Widget _paging(
    String label,
    int page,
    int count,
    ValueChanged<int> changed,
  ) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      Text(
        '$label · ${page * 20 + 1}–${((page + 1) * 20).clamp(0, count)} of $count',
      ),
      IconButton(
        tooltip: 'Previous $label',
        onPressed: page > 0 ? () => changed(page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: 'Next $label',
        onPressed: (page + 1) * 20 < count ? () => changed(page + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _layoutControl(md.Element node, int index) {
    final key = node.attributes['orbit-key']!;
    final value = layouts[key] ?? const <String, dynamic>{};
    final options = PublicationBlockLayout.fromJson(value);
    final ambiguous = node.attributes['orbit-ambiguous'] == 'true';
    final isTable = node.tag == 'table';
    final label = isTable
        ? 'Table · ${node.textContent}'
        : 'Image · ${(node.children!.single as md.Element).attributes['alt'] ?? 'Untitled'}';
    void edit(String field, Object v) =>
        change(() => layouts[key] = {...value, field: v});
    return ExpansionTile(
      key: ValueKey('layout-$key-$index'),
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        ambiguous
            ? 'Identical content — layout cannot be assigned safely'
            : '${options.width}% · ${options.alignment}',
      ),
      children: [
        if (!ambiguous) ...[
          Text('Print width · ${options.width}%'),
          Slider(
            value: options.width.toDouble(),
            min: 25,
            max: 100,
            divisions: 15,
            label: '${options.width}%',
            onChanged: exporting ? null : (v) => edit('width', v.round()),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final alignment in ['left', 'center', 'right'])
                ChoiceChip(
                  label: Text(alignment),
                  selected: options.alignment == alignment,
                  onSelected: exporting
                      ? null
                      : (_) => edit('alignment', alignment),
                ),
            ],
          ),
          TextFormField(
            key: ValueKey('caption-$key-${layoutResetSerial[key] ?? 0}'),
            initialValue: options.caption,
            maxLength: 2000,
            enabled: !exporting,
            decoration: const InputDecoration(labelText: 'Print caption'),
            onChanged: (v) => edit('caption', v),
          ),
          CheckboxListTile(
            title: const Text('Start on a new page'),
            value: options.pageBreakBefore,
            onChanged: exporting ? null : (v) => edit('pageBreakBefore', v!),
          ),
          if (isTable)
            CheckboxListTile(
              title: const Text('Repeat table header on each page'),
              value: options.repeatHeader,
              onChanged: exporting ? null : (v) => edit('repeatHeader', v!),
            ),
          TextButton(
            onPressed: exporting
                ? null
                : () => change(() {
                    final remaining = Map<String, dynamic>.of(value);
                    for (final field
                        in const PublicationBlockLayout().toJson().keys) {
                      remaining.remove(field);
                    }
                    if (remaining.isEmpty) {
                      layouts.remove(key);
                    } else {
                      layouts[key] = remaining;
                    }
                    layoutResetSerial[key] = (layoutResetSerial[key] ?? 0) + 1;
                  }),
            child: const Text('Reset this layout'),
          ),
        ],
      ],
    );
  }

  void saveSettings() {
    try {
      final next = PublicationSettings.update(source, style.toJson(), layouts);
      if (widget.onApply?.call(source, next) != true) {
        setState(
          () => settingsWarning =
              'The note changed or is read-only. Reopen Publish before saving settings.',
        );
        return;
      }
      setState(() {
        source = next;
        rememberSettings();
        saved = true;
        settingsWarning = null;
      });
    } catch (failure) {
      setState(() => settingsWarning = '$failure');
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDraftGuard(
    busy: exporting,
    dirty: !jsonValuesEqual(currentSettings, appliedSettings),
    builder: (context, requestClose) => Dialog(
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
                    onPressed: exporting ? null : requestClose,
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
                                    controller: viewerController,
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
                  final controls = Builder(
                    builder: (controlsContext) => SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: settings(controlsContext),
                    ),
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
                            child: TabBarView(
                              children: [previewPane, controls],
                            ),
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
                  if (widget.onApply != null)
                    OutlinedButton.icon(
                      onPressed: exporting || busy || settingsWarning != null
                          ? null
                          : saveSettings,
                      icon: Icon(saved ? Icons.check : Icons.save_outlined),
                      label: Text(
                        saved ? 'Settings saved' : 'Save settings to note',
                      ),
                    ),
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
    ),
  );
}
