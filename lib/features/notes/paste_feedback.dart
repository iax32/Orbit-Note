import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../domain/pdf_quote_transfer.dart';
import 'markdown_clipboard.dart';

/// Only the last explicit Orbit PDF copy. Never infer a source from other apps.
PdfQuoteDragData? _pdfCopy;

class EditorPasteCancelled implements Exception {
  const EditorPasteCancelled();
}

void rememberPdfCopy(PdfQuoteDragData value) {
  _pdfCopy = value.text.length <= 1024 * 1024 ? value : null;
}

/// Deliberate prose cleanup: blank paragraphs, indentation and code stay intact.
/// Never applied automatically to ordinary clipboard text.
String cleanPdfParagraphs(String value) {
  final lines = value.replaceAll(RegExp(r'\r\n|\r'), '\n').split('\n');
  final out = StringBuffer();
  final boundaries = RegExp(r'\s|[#>*`|]|[-+]\s|\d+[.)]\s');
  final fences = RegExp(r'^\s*(`{3,}|~{3,}|\$\$)');
  String? fence;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final marker = fences.firstMatch(line)?[1];
    final protected = fence != null || marker != null;
    if (marker != null) {
      if (fence == null) {
        fence = marker;
      } else if (marker.startsWith(fence[0]) && marker.length >= fence.length) {
        fence = null;
      }
    }
    out.write(line);
    if (i == lines.length - 1) break;
    final next = lines[i + 1];
    final prose =
        !protected &&
        line.trim().isNotEmpty &&
        next.trim().isNotEmpty &&
        !line.startsWith(boundaries) &&
        !next.startsWith(boundaries);
    out.write(prose ? ' ' : '\n');
  }
  return out.toString();
}

Future<String?> readEditorClipboard(
  BuildContext context, {
  bool preferHtml = true,
  bool interpretOrbitData = true,
  bool plain = false,
}) async {
  final text = await readMarkdownClipboard(
    preferHtml: preferHtml,
    interpretOrbitData: interpretOrbitData,
  );
  final pdf = _pdfCopy;
  if (!context.mounted || plain || pdf == null || text != pdf.text) return text;
  final focus = FocusManager.instance.primaryFocus;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Paste PDF text'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(pdf.citation),
        ),
        for (final option in const [
          'Keep original line breaks',
          'Cleaned paragraphs',
          'Linked quote with page source',
        ].indexed)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, option.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(option.$2),
            ),
          ),
      ],
    ),
  );
  if (context.mounted && focus?.context != null) {
    focus!.requestFocus();
    // The caller validates focus immediately after this async operation. Apply
    // the queued restoration before that check, rather than losing the paste.
    FocusManager.instance.applyFocusChangesIfNeeded();
  }
  if (result == null) throw const EditorPasteCancelled();
  return switch (result) {
    1 =>
      pdf.text.length > 32768
          ? await compute(cleanPdfParagraphs, pdf.text)
          : cleanPdfParagraphs(pdf.text),
    2 => pdf.markdownQuote,
    _ => pdf.text,
  };
}

/// Guarded actions cannot replace edits made after the paste.
void showPasteFeedback(
  BuildContext context,
  String text, {
  required bool Function() isCurrent,
  required VoidCallback undo,
  VoidCallback? pastePlain,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final images = RegExp(r'!\[[^\]\r\n]*\]\(').allMatches(text).length;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      content: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            images > 0
                ? 'Pasted $images ${images == 1 ? 'image' : 'images'}'
                : 'Text pasted',
          ),
          if (pastePlain != null)
            TextButton(
              onPressed: () {
                if (isCurrent()) pastePlain();
                messenger.hideCurrentSnackBar();
              },
              child: const Text('Paste as plain text'),
            ),
        ],
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (isCurrent()) undo();
        },
      ),
    ),
  );
}
