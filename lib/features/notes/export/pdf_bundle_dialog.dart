import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import '../../../app/orbit_components.dart';
import '../../../domain/universal_object.dart';
import '../../../platform/export_file.dart';
import 'canvas_pdf_export.dart';
import 'publication_export.dart';

Future<void> showPdfBundleDialog(
  BuildContext context, {
  required List<UniversalObject> objects,
  PublicationExport? note,
  String? initialCanvasId,
  Future<Uint8List?> Function(String)? readImage,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => PdfBundleDialog(
    objects: List.unmodifiable(objects),
    note: note,
    initialCanvasId: initialCanvasId,
    readImage: readImage,
    canvasColors: Theme.of(context).colorScheme,
  ),
);

class PdfBundleDialog extends StatefulWidget {
  const PdfBundleDialog({
    super.key,
    required this.objects,
    this.note,
    this.initialCanvasId,
    this.readImage,
    this.previewBuilder,
    this.canvasColors,
  });
  final List<UniversalObject> objects;
  final PublicationExport? note;
  final String? initialCanvasId;
  final Future<Uint8List?> Function(String)? readImage;
  final Widget Function(Uint8List)? previewBuilder;
  final ColorScheme? canvasColors;
  @override
  State<PdfBundleDialog> createState() => _PdfBundleState();
}

class _PdfBundleState extends State<PdfBundleDialog> {
  final selected = <CanvasPdfPart>[];
  final search = TextEditingController();
  Uint8List? bytes;
  bool busy = false, saving = false;
  int generation = 0;
  String? error;
  final warnings = <String>[];
  late final candidates =
      widget.objects
          .where(
            (o) => o.typeId == 'orbit.canvas' && !o.isDeleted && !o.isReadOnly,
          )
          .toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
  @override
  void initState() {
    super.initState();
    final initial = candidates
        .where((o) => o.id == widget.initialCanvasId)
        .firstOrNull;
    if (initial != null) selected.add(CanvasPdfPart(initial));
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  void changed(VoidCallback change) {
    setState(() {
      change();
      generation++;
      bytes = null;
      error = null;
      warnings.clear();
    });
  }

  Future<void> generate() async {
    final ticket = ++generation;
    final parts = List<CanvasPdfPart>.of(selected);
    setState(() {
      busy = true;
      error = null;
      bytes = null;
      warnings.clear();
    });
    final issues = <String>[];
    try {
      Future<void> append(pw.Document pdf) => appendCanvasPdfPages(
        pdf,
        parts,
        objects: widget.objects,
        readImage: widget.readImage,
        canvasColors: widget.canvasColors,
        warn: (s) {
          if (!issues.contains(s)) issues.add(s);
        },
        isCancelled: () => !mounted || ticket != generation,
      );
      final Uint8List result;
      if (widget.note case final note?) {
        final snapshot = PublicationExport(
          note.document,
          images: note.images,
          equations: note.equations,
          warnings: note.warnings,
          pdfTheme: note.pdfTheme,
        );
        result = await snapshot.pdf(appendPages: append);
        for (final warning in snapshot.warnings) {
          if (!issues.contains(warning)) issues.add(warning);
        }
      } else {
        final doc = pw.Document(
          title: parts.first.object.title,
          creator: 'Orbit Note',
        );
        await append(doc);
        result = await doc.save();
      }
      if (!mounted || ticket != generation) return;
      setState(() {
        bytes = result;
        warnings.addAll(issues);
        busy = false;
      });
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          error = 'PDF could not be prepared. No file was saved. $e';
          busy = false;
        });
      }
    }
  }

  Future<void> save() async {
    final ready = bytes;
    if (ready == null) return;
    setState(() => saving = true);
    try {
      final title = widget.note?.document.title ?? selected.first.object.title;
      final saved = await exportBinaryFile(
        '${publicationFileName(title)}${widget.note != null && selected.isNotEmpty ? ' + Canvases' : ''}.pdf',
        ready,
        mimeType: 'application/pdf',
      );
      if (mounted && saved) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF exported')));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Export failed. Preview retained; try again. $e',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget controls() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (widget.note != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: Text(widget.note!.document.title),
          subtitle: const Text(
            'First · note pages retain their document style',
          ),
        ),
      const Text('Canvas pages', style: TextStyle(fontWeight: FontWeight.w600)),
      const Text(
        'Each Canvas starts on a new page. Readable pages preserve scale with overlapping edges; fit uses one complete page.',
      ),
      for (var i = 0; i < selected.length; i++)
        Card(
          key: ValueKey(selected[i].object.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${i + 1}. ${selected[i].object.title}', softWrap: true),
                Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Move Canvas earlier',
                      onPressed: busy || saving || i == 0
                          ? null
                          : () => changed(() {
                              final p = selected.removeAt(i);
                              selected.insert(i - 1, p);
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move Canvas later',
                      onPressed: busy || saving || i == selected.length - 1
                          ? null
                          : () => changed(() {
                              final p = selected.removeAt(i);
                              selected.insert(i + 1, p);
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Remove from PDF',
                      onPressed: busy || saving
                          ? null
                          : () => changed(() => selected.removeAt(i)),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: selected[i].orientation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Page orientation',
                  ),
                  items: [
                    for (final v in ['auto', 'portrait', 'landscape'])
                      DropdownMenuItem(value: v, child: Text(v)),
                  ],
                  onChanged: busy || saving
                      ? null
                      : (v) => changed(() {
                          final p = selected[i];
                          selected[i] = CanvasPdfPart(
                            p.object,
                            orientation: v!,
                            a3: p.a3,
                            tiles: p.tiles,
                            overview: p.overview,
                          );
                        }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('A3 paper'),
                  value: selected[i].a3,
                  onChanged: busy || saving
                      ? null
                      : (v) => changed(() {
                          final p = selected[i];
                          selected[i] = CanvasPdfPart(
                            p.object,
                            orientation: p.orientation,
                            a3: v,
                            tiles: p.tiles,
                            overview: p.overview,
                          );
                        }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Readable pages'),
                  subtitle: const Text('Off: fit the whole Canvas on one page'),
                  value: selected[i].tiles,
                  onChanged: busy || saving
                      ? null
                      : (v) => changed(() {
                          final p = selected[i];
                          selected[i] = CanvasPdfPart(
                            p.object,
                            orientation: p.orientation,
                            a3: p.a3,
                            tiles: v,
                            overview: p.overview,
                          );
                        }),
                ),
                if (selected[i].tiles)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Overview before detail pages'),
                    value: selected[i].overview,
                    onChanged: busy || saving
                        ? null
                        : (v) => changed(() {
                            final p = selected[i];
                            selected[i] = CanvasPdfPart(
                              p.object,
                              orientation: p.orientation,
                              a3: p.a3,
                              tiles: p.tiles,
                              overview: v,
                            );
                          }),
                  ),
              ],
            ),
          ),
        ),
      TextField(
        controller: search,
        enabled: !busy && !saving,
        decoration: const InputDecoration(
          labelText: 'Find a Canvas to add',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      ),
      for (final o
          in candidates
              .where(
                (o) =>
                    !selected.any((p) => p.object.id == o.id) &&
                    o.title.toLowerCase().contains(search.text.toLowerCase()),
              )
              .take(50))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(o.title),
          subtitle: Text(
            o.properties['folder'] is String
                ? o.properties['folder'] as String
                : 'Canvas',
          ),
          trailing: const Icon(Icons.add),
          onTap: busy || saving || selected.length >= 20
              ? null
              : () => changed(() => selected.add(CanvasPdfPart(o))),
        ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      for (final s in warnings)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(s)),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: OrbitDialog(
      title: Text(
        widget.note == null ? 'Canvas PDF' : 'Combine note and Canvases',
      ),
      content: SizedBox(
        width: 1100,
        height: 640,
        child: LayoutBuilder(
          builder: (context, c) {
            final preview = bytes == null
                ? Center(
                    child: Text(
                      busy
                          ? 'Preparing PDF pages…'
                          : 'Choose content, then prepare the PDF.',
                    ),
                  )
                : widget.previewBuilder?.call(bytes!) ??
                      PdfViewer.data(
                        bytes!,
                        sourceName: 'bundle-${identityHashCode(bytes)}',
                      );
            if (c.maxWidth < 700) {
              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Content'),
                        Tab(text: 'Preview'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(children: [controls(), preview]),
                    ),
                  ],
                ),
              );
            }
            return Row(
              children: [
                SizedBox(width: 340, child: controls()),
                const VerticalDivider(width: 1),
                Expanded(child: preview),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        OutlinedButton(
          onPressed: busy || saving || selected.isEmpty && widget.note == null
              ? null
              : generate,
          child: Text(busy ? 'Preparing…' : 'Prepare PDF'),
        ),
        FilledButton(
          onPressed: busy || saving || bytes == null ? null : save,
          child: Text(saving ? 'Saving…' : 'Save PDF'),
        ),
      ],
    ),
  );
}
