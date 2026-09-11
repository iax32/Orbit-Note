import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/pdf_form_field.dart';
import '../../platform/pdf_forms.dart';

class PdfFormLayer extends StatefulWidget {
  const PdfFormLayer({
    super.key,
    required this.document,
    required this.page,
    required this.values,
    required this.onChanged,
  });
  final PdfDocument document;
  final PdfPage page;
  final Map<String, dynamic> values;
  final Future<bool> Function(String, Object) onChanged;
  @override
  State<PdfFormLayer> createState() => _PdfFormLayerState();
}

class _PdfFormLayerState extends State<PdfFormLayer> {
  late final Future<List<OrbitPdfField>> fields = readPdfFields(
    widget.document,
    widget.page.pageNumber,
  );
  bool busy = false;
  Future<void> edit(OrbitPdfField field) async {
    if (busy) return;
    final current = widget.values[field.id] ?? field.value;
    Object? value;
    if (field.checkbox) {
      value = current != true;
    } else {
      var text = current.toString();
      value = await showDialog<String>(
        context: context,
        builder: (context) => OrbitDialog(
          title: Text(field.name.isEmpty ? 'PDF text field' : field.name),
          content: TextFormField(
            initialValue: text,
            autofocus: true,
            maxLength: 10000,
            minLines: 1,
            maxLines: 6,
            onChanged: (v) => text = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, text),
              child: const Text('Save field'),
            ),
          ],
        ),
      );
    }
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      final saved = await widget.onChanged(field.id, value);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Field draft could not be saved. Retry before closing the document.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<OrbitPdfField>>(
    future: fields,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: OrbitColors.of(context).raised,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                snapshot.hasError
                    ? 'Forms unavailable on this page. Original PDF remains available.'
                    : 'Finding form fields…',
              ),
            ),
          ),
        );
      }
      if (snapshot.data!.isEmpty) {
        return const Align(
          alignment: Alignment.topCenter,
          child: Material(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'No supported text fields or checkboxes on this page.',
              ),
            ),
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, bounds) => Stack(
          children: [
            for (final field in snapshot.data!)
              ...() {
                final rect = PdfRect(
                  field.left,
                  field.top,
                  field.right,
                  field.bottom,
                ).toRect(page: widget.page);
                final value = widget.values[field.id] ?? field.value;
                return [
                  Positioned(
                    left: rect.left / widget.page.width * bounds.maxWidth,
                    top: rect.top / widget.page.height * bounds.maxHeight,
                    width: rect.width / widget.page.width * bounds.maxWidth,
                    height: rect.height / widget.page.height * bounds.maxHeight,
                    child: SizedBox(
                      child: Tooltip(
                        message: field.name,
                        child: Material(
                          color: OrbitColors.of(context).raised,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: OrbitColors.of(context).accent,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: InkWell(
                            onTap: busy ? null : () => edit(field),
                            child: Semantics(
                              label: field.name,
                              button: true,
                              checked: field.checkbox ? value == true : null,
                              child: field.checkbox
                                  ? Icon(
                                      value == true
                                          ? Icons.check
                                          : Icons.check_box_outline_blank,
                                      size: 18,
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(3),
                                      child: Text(
                                        value.toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ];
              }(),
          ],
        ),
      );
    },
  );
}

class PdfComfortPage extends StatefulWidget {
  const PdfComfortPage({super.key, required this.page});
  final PdfPage page;
  @override
  State<PdfComfortPage> createState() => _PdfComfortPageState();
}

class _PdfComfortPageState extends State<PdfComfortPage> {
  late final text = widget.page.loadText();
  double size = 20;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OrbitColors.of(context).panel,
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Smaller reading text',
              onPressed: size > 14 ? () => setState(() => size -= 2) : null,
              icon: const Icon(Icons.text_decrease),
            ),
            Text('Page ${widget.page.pageNumber} · ${size.round()} pt'),
            IconButton(
              tooltip: 'Larger reading text',
              onPressed: size < 36 ? () => setState(() => size += 2) : null,
              icon: const Icon(Icons.text_increase),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<PdfPageRawText?>(
            future: text,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Text unavailable. Switch to Original page.'),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final content = snapshot.data?.fullText ?? '';
              if (content.trim().isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No readable text on this page. Switch to Original page to view scans and diagrams.',
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: SelectableText(
                      content,
                      style: TextStyle(fontSize: size, height: 1.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
