import '../canvas/scene.dart';
import 'pdf_annotation.dart';
import 'universal_object.dart';

enum PdfReviewBatchAction {
  resolve,
  reopen,
  color,
  highlight,
  underline,
  strikeout,
  trash,
}

class PdfReviewChange {
  const PdfReviewChange(this.before, this.after);
  final UniversalObject before, after;
}

/// A receipt of actual per-note commits, not an all-or-nothing transaction.
class PdfReviewBatchResult {
  PdfReviewBatchResult({
    required this.workspaceId,
    required this.fileId,
    required this.action,
    List<PdfReviewChange> changes = const [],
    Map<String, String> failures = const {},
    this.unchanged = 0,
    this.cancelled = false,
    this.requested = 0,
  }) : changes = List.unmodifiable(changes),
       failures = Map.unmodifiable(failures);
  final String workspaceId, fileId;
  final PdfReviewBatchAction action;
  final List<PdfReviewChange> changes;
  final Map<String, String> failures;
  final int unchanged, requested;
  final bool cancelled;
  int get processed => changes.length + failures.length + unchanged;
}

typedef RunPdfReviewBatch =
    Future<PdfReviewBatchResult> Function(
      List<PdfAnnotation> items,
      PdfReviewBatchAction action, {
      int? color,
      bool Function()? isCancelled,
      void Function(int, int)? onProgress,
    });
typedef UndoPdfReviewBatch =
    Future<PdfReviewBatchResult> Function(
      PdfReviewBatchResult receipt, {
      bool Function()? isCancelled,
      void Function(int, int)? onProgress,
    });

/// Preserve every authored field and unsupported region while changing only
/// supported review presentation. Page comments never become text markup.
UniversalObject? changedPdfReview(
  PdfAnnotation item,
  PdfReviewBatchAction action, {
  int? color,
}) {
  final object = item.object;
  if (!PdfAnnotation.isAnnotation(object) ||
      object.isReadOnly ||
      (object.properties['pdfReview'] is Map &&
          (object.properties['pdfReview'] as Map)['version'] != 1)) {
    return null;
  }
  if (action == PdfReviewBatchAction.trash) {
    return object.copyWith(deletedAt: DateTime.now().toUtc());
  }
  final state =
      action == PdfReviewBatchAction.resolve ||
      action == PdfReviewBatchAction.reopen;
  if (!state && item.isPageComment && action != PdfReviewBatchAction.color) {
    return null;
  }
  if (action == PdfReviewBatchAction.color &&
      (color == null || color < 0xff000000 || color > 0xffffffff)) {
    return null;
  }
  final source = Map<String, dynamic>.from(item.source);
  if (!state) {
    source['regions'] = [
      for (final region in source['regions'] as List? ?? const [])
        if (region is Map &&
            PdfAnnotation.validRegion(
              CanvasElement(Map<String, dynamic>.from(region)),
            ))
          {
            ...region,
            if (action == PdfReviewBatchAction.color) 'color': color,
            if (action != PdfReviewBatchAction.color) 'style': action.name,
          }
        else
          region,
    ];
  }
  return object.copyWith(
    properties: {
      ...object.properties,
      if (!state) 'pdfSource': source,
      if (state)
        'pdfReview': {
          if (object.properties['pdfReview'] is Map)
            ...object.properties['pdfReview'] as Map,
          'version': 1,
          'resolved': action == PdfReviewBatchAction.resolve,
        },
    },
  );
}
