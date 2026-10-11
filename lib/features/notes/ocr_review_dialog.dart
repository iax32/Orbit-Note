import 'dart:async';
import 'package:flutter/material.dart';
import '../workspace/study_workspace.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/ocr_document.dart';
import '../../domain/object_reference.dart';
import '../../domain/universal_object.dart';
import '../../domain/orbit_search.dart';

Future<void> showOcrReview(
  BuildContext context,
  WorkspaceController controller, {
  String? objectId,
}) => showOrbitDialog<void>(
  context: context,
  builder: (_) => OcrReviewDialog(controller: controller, objectId: objectId),
);

class OcrReviewDialog extends StatefulWidget {
  const OcrReviewDialog({super.key, required this.controller, this.objectId});
  final WorkspaceController controller;
  final String? objectId;
  @override
  State<OcrReviewDialog> createState() => _OcrReviewDialogState();
}

class _OcrReviewDialogState extends State<OcrReviewDialog> {
  final _text = TextEditingController();
  String? _id, _message;
  UniversalObject? _expected;
  int _page = 0;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _id = widget.objectId;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _load(UniversalObject? object, OcrDocument? record) {
    _expected = object;
    _page = record == null ? 0 : _page.clamp(0, record.pages.length - 1);
    _text.text = record == null ? '' : record.text(_page);
  }

  Future<void> _save({bool reset = false}) async {
    final object = _expected;
    if (object == null) return;
    setState(() => _saving = true);
    final ok = await widget.controller.correctRecognition(
      object,
      _page,
      reset ? null : _text.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = ok
          ? 'Correction saved. The original recognition and attachment are preserved.'
          : widget.controller.error ??
                'Could not save. Your draft remains here.';
      if (ok) {
        _load(
          widget.controller.find(object.id),
          OcrDocument.parse(
            widget.controller.find(object.id)?.properties['ocr'],
          ),
        );
      }
    });
  }

  Future<void> _note() async {
    final object = _expected;
    if (object == null) return;
    final selection = _text.selection;
    final passage = selection.isValid && !selection.isCollapsed
        ? selection.textInside(_text.text)
        : _text.text;
    setState(() => _saving = true);
    try {
      final note = await widget.controller.createRecognitionNote(
        object,
        _page,
        passage,
      );
      if (!mounted) return;
      setState(
        () => _message = note == null
            ? widget.controller.error ?? 'Could not create the note.'
            : 'Passage saved as a linked note.',
      );
    } on Object catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: widget.controller.pdfIndexChanges,
    builder: (context, _) {
      final c = widget.controller;
      final files = c.ocrAttachments;
      _id ??= files.firstOrNull?.id;
      final object = c.find(_id ?? '');
      final latest = OcrDocument.parse(object?.properties['ocr']);
      final prior = OcrDocument.parse(_expected?.properties['ocr']);
      final oldText = prior == null ? '' : prior.text(_page);
      if (!identical(object, _expected) && !_saving && _text.text == oldText) {
        _load(object, latest);
      }
      final record = OcrDocument.parse(_expected?.properties['ocr']);
      final readOnly = c.repository.readOnly || object?.isReadOnly == true;
      final busy = _saving || c.ocrRunning;
      return OrbitDialog(
        title: const Text('Recognized text'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recognize PDF scans and images locally. Printed text works best; handwriting, equations, columns and rotated pages may contain errors. Check every important passage against its source. No confidence score is supplied by the Windows engine.',
            ),
            const SizedBox(height: 16),
            if (files.isEmpty)
              const Text('Attach a PDF or image to get started.')
            else
              DropdownButtonFormField<String>(
                initialValue: files.any((o) => o.id == _id) ? _id : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Source attachment',
                ),
                items: [
                  for (final file in files)
                    DropdownMenuItem(
                      value: file.id,
                      child: Text(file.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged:
                    busy ||
                        _text.text !=
                            (OcrDocument.parse(
                                  _expected?.properties['ocr'],
                                )?.text(_page) ??
                                '')
                    ? null
                    : (id) => setState(() {
                        _id = id;
                        _page = 0;
                        _message = null;
                        _load(
                          c.find(id!),
                          OcrDocument.parse(c.find(id)?.properties['ocr']),
                        );
                      }),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: object == null || busy || readOnly
                      ? null
                      : () => unawaited(c.recognizeFiles([object.id])),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(
                    record == null ? 'Recognize source' : 'Recognize again',
                  ),
                ),
                TextButton(
                  onPressed: files.isEmpty || busy || readOnly
                      ? null
                      : () => unawaited(
                          c.recognizeFiles(
                            files
                                .where((o) => o.properties['ocr'] == null)
                                .map((o) => o.id)
                                .toList(),
                          ),
                        ),
                  child: const Text('Recognize unprocessed files'),
                ),
                if (c.ocrRunning)
                  TextButton(
                    onPressed: () => c.pauseOcr(!c.ocrPaused),
                    child: Text(c.ocrPaused ? 'Resume' : 'Pause'),
                  ),
                if (c.ocrRunning)
                  TextButton(
                    onPressed: c.cancelOcr,
                    child: const Text('Cancel recognition'),
                  ),
                if (c.ocrFailures.isNotEmpty)
                  TextButton(
                    onPressed: busy || readOnly
                        ? null
                        : () => unawaited(
                            c.recognizeFiles(c.ocrFailures.keys.toList()),
                          ),
                    child: const Text('Retry failed files'),
                  ),
              ],
            ),
            if (c.ocrStatus.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(c.ocrStatus),
                ),
              ),
            if (c.ocrFailures[_id] != null)
              Semantics(liveRegion: true, child: Text(c.ocrFailures[_id]!)),
            if (object?.properties['ocr'] != null && record == null)
              const Text(
                'This recognition format is unsupported. Its data remains preserved.',
              ),
            if (record != null) ...[
              Text(
                'Language: ${record.language} · ${record.pages.length} pages · Original recognition retained',
              ),
              if (record.checksum != object?.properties['checksum'])
                const Text(
                  'Source version differs. Saved recognition is retained for review; verify or recognize the current source before extracting.',
                ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous recognized page',
                    onPressed:
                        busy || _page == 0 || _text.text != record.text(_page)
                        ? null
                        : () => setState(() {
                            _page--;
                            _load(object, record);
                          }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Page ${_page + 1} of ${record.pages.length}'),
                  IconButton(
                    tooltip: 'Next recognized page',
                    onPressed:
                        busy ||
                            _page + 1 >= record.pages.length ||
                            _text.text != record.text(_page)
                        ? null
                        : () => setState(() {
                            _page++;
                            _load(object, record);
                          }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  TextButton(
                    onPressed: object == null
                        ? null
                        : () {
                            c.openSearchResult(
                              OrbitSearchResult(
                                object: object,
                                location: ObjectReference(
                                  object.id,
                                  page: _page + 1,
                                ),
                                matchKind: 'Recognized text',
                                matchedText: '',
                                score: 0,
                                sourceChecksum: record.checksum,
                                sourcePath: record.path,
                              ),
                            );
                            Navigator.pop(context);
                          },
                    child: const Text('Open source page'),
                  ),
                ],
              ),
              TextField(
                controller: _text,
                readOnly: busy || readOnly,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Review and correct text',
                  helperText:
                      'Select a passage to extract it. Corrections use page navigation; original recognition keeps line regions.',
                  helperMaxLines: 3,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy || readOnly ? null : () => _save(),
                    child: const Text('Save correction'),
                  ),
                  TextButton(
                    onPressed: busy || readOnly
                        ? null
                        : () => _save(reset: true),
                    child: const Text('Restore recognized text'),
                  ),
                  TextButton(
                    onPressed: busy || readOnly || _text.text.trim().isEmpty
                        ? null
                        : _note,
                    child: const Text('Create linked passage note'),
                  ),
                  TextButton(
                    onPressed: busy || readOnly || _text.text.trim().isEmpty
                        ? null
                        : () {
                            final selection = _text.selection;
                            final passage =
                                selection.isValid && !selection.isCollapsed
                                ? selection.textInside(_text.text)
                                : _text.text;
                            showStudyCardEditor(
                              context,
                              c,
                              source: object,
                              passage: passage,
                              page: _page + 1,
                              checksum: record.checksum,
                            );
                          },
                    child: const Text('Make study card'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _load(object, record)),
                    child: const Text('Discard draft'),
                  ),
                ],
              ),
            ],
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
