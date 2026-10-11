# PDF Quote Canvas Transclusion & Deep Linking — Evidence & Verification

**Date:** 2026-10-05  
**Milestone:** Direct drag-and-drop linking and transclusion of PDF text citations and quotes onto the Orbit spatial canvas as cards  
**Repository:** Orbit Note  

---

## 1. Executive Summary

This feature extends Orbit Note's spatial canvas and Universal Object architecture with seamless transclusion and bidirectional linking of PDF text citations and quotes. Users can drag text citations directly from PDF reading surfaces (including the PDF selection toolbar, Review Panel, and Connected Notes panel) and drop them onto any spatial canvas board as interactive quote cards.

Key design goals achieved:
- **Quiet Observatory Transclusion Design**: Dropped PDF quote cards default to `presentation: 'transclusion'`. The card displays a refined top transclusion accent bar, a `PDF CITATION` badge, target wiki-link indicator `[[Source Title · p. X]]`, a 3px left-edge vertical accent bar, italicized citation quote text, and a provenance footer `Cited from Source Title · Page X`.
- **Direct Navigation & Deep Linking**: Double-clicking or pressing Enter on a canvas quote card jumps directly to the cited page in the PDF reader via the unified `referenceTarget` (`$pdfId#page=$page`).
- **Interactive Tooltip & Presentation Cycling**: Hovering over a quote card displays an expanded preview tooltip showing the `PDF CITATION · P. X` badge, quote excerpt, presentation mode cycler (transclusion, preview, card, compact), and an "Open in editor" action that navigates to the PDF.
- **Universal Data Resilience**: Supports both top-level and nested `data` schemas across `CanvasElement`, ensuring seamless compatibility regardless of whether the card was created via drag-and-drop, controller extraction, or clipboard.
- **Strictly Offline & Local-First**: Operates completely in-memory and against local workspace storage with zero external network or cloud dependencies.

---

## 2. Key Architecture & Features Delivered

### 2.1. Unified Reference Target & Transfer Model (`lib/domain/pdf_quote_transfer.dart`)
- Added `String get referenceTarget => '$objectId#page=$page';` to `PdfQuoteDragData`.
- Guarantees deterministic deep linking format across drag-and-drop payloads, canvas elements, and editor links.
- Serializes and deserializes `referenceTarget` in `toJson` and `fromJson`.

### 2.2. Canvas Element Presentation Resolution (`lib/canvas/scene.dart`)
- Updated `CanvasElement.cardPresentation` getter:
  ```dart
  String? get cardPresentation {
    final rootPresentation = data['presentation'];
    if (rootPresentation is String && rootPresentation.trim().isNotEmpty) {
      return rootPresentation.trim();
    }
    final nested = data['data'];
    if (nested is Map) {
      final nestedPresentation = nested['presentation'];
      if (nestedPresentation is String && nestedPresentation.trim().isNotEmpty) {
        return nestedPresentation.trim();
      }
    }
    return null;
  }
  ```
- Ensures robust presentation mode handling across all canvas rendering, tooltip, and editing layers.

### 2.3. Controller Transclusion Extraction (`lib/app/workspace_controller.dart`)
- Enhanced `extractPdfQuoteToCanvas(String pdfId, String quote, int page, ...)`:
  - Generates card element with `presentation: 'transclusion'` and `referenceTarget: '$pdfId#page=$page'`.
  - Populates both top-level properties and nested `data` map (`sourceId`, `sourceTitle`, `quote`, `page`, `color`, `presentation`, `referenceTarget`).
  - Emits local change notifications and persists canvas state.

### 2.4. Canvas Drag-and-Drop & Interactive Deep Linking (`lib/features/canvas/canvas_editor.dart`)
- **Drag Target Handler (`_dropQuoteOntoCanvas`)**:
  - Drops `PdfQuoteDragData` directly at mouse/pointer canvas coordinates.
  - Automatically wraps the quote in a card element configured with `presentation: 'transclusion'` and `referenceTarget: quote.referenceTarget`.
  - Captures quote text, page number, PDF title, and color accent.
- **Direct Navigation (`_edit`)**:
  - Checks if an element has a `referenceTarget` or PDF quote metadata (`sourceId`, `quote`, `page`).
  - When double-clicking or pressing Enter, dispatches `widget.onOpenObject(refTarget)` immediately to open the PDF reader at the exact cited page rather than popping a generic note editor dialog.
- **Interactive Tooltip (`CanvasCardPreviewTooltip`)**:
  - Disambiguates PDF quote cards from general highlight notes.
  - Displays `PDF CITATION · P. X` badge (or `PDF HIGHLIGHT · P. X` for notes).
  - Renders quote excerpt in a styled card container with left accent border.
  - "Open in editor" button navigates directly to `element.data['referenceTarget']` or `${element.objectId}#page=${element.data['page']}`.
  - Supports presentation mode cycling across transclusion, preview, card, and compact modes.

### 2.5. Vector Painting & Visual Presentation (`lib/features/canvas/canvas_painter.dart`)
- Enhanced `OrbitCanvasPainter._element`:
  - Resolves quote data across top-level and nested maps (`data['quote']`, `data['page']`, `data['sourceTitle']`, `data['sourceId']`).
  - **Transclusion Presentation (`presentation == 'transclusion'`)**:
    - Paints top accent bar with `transBarColor`.
    - Renders `PDF CITATION` badge and link target `[[Source Title · p. X]]`.
    - Renders blockquote container with a 3px left accent line, italic quote body, and citation footer `Cited from Source Title · Page X`.
  - **Preview & Card Presentations (`'preview'`, `'card'`)**:
    - Paints quote block with left accent line, `PAGE X` badge, and italic excerpt.
  - **Compact Presentation (`'compact'`)**:
    - Renders compact row with `CITATION` badge and accent strip.

### 2.6. Reading Surface Draggable Handles (`lib/features/pdf/pdf_review_panel.dart`, `lib/features/pdf/pdf_notes_panel.dart`)
- Verified and aligned `Draggable<PdfQuoteDragData>` drag handles in:
  - `PdfReviewPanel`: drag handles next to review items containing citations.
  - `PdfNotesPanel`: drag handles next to connected notes containing quotes.
  - PDF reader selection toolbar: quote drag button.

---

## 3. Automated Test Suite (`test/pdf_quote_canvas_transclusion_test.dart`)

Added 8 comprehensive unit and widget tests:
1. `PdfQuoteDragData & referenceTarget computes referenceTarget and preserves all fields in JSON`:
   - Validates URL generation (`pdf-doc#page=4`), JSON roundtrip, and schema integrity.
2. `WorkspaceController extractPdfQuoteToCanvas configures transclusion card and referenceTarget`:
   - Validates transclusion card generation, reference target assignment, and both top-level and nested `data` population.
3. `CanvasEditor dropping PdfQuoteDragData places card with transclusion presentation and referenceTarget`:
   - Validates drag-and-drop onto the spatial canvas placing a card at the drop point with `presentation: 'transclusion'`.
4. `CanvasEditor double-click / edit on quote card navigates to PDF page reference target`:
   - Validates opening a quote card triggers `onOpenObject` with the PDF page URL (`doc-1#page=7`).
5. `CanvasCardPreviewTooltip renders quote badge, citation excerpt, and navigation`:
   - Validates tooltip layout, `PDF CITATION · P. 3` badge, quote excerpt, presentation mode cycling, and "Open in editor" callback with page reference.
6. `OrbitCanvasPainter paints transclusion, preview, compact, and standard quote cards`:
   - Validates custom vector painting logic across all 4 presentation modes without rendering exceptions.
7. `PdfReviewPanel exposes Draggable<PdfQuoteDragData> for citations`:
   - Validates the presence of `Draggable<PdfQuoteDragData>` handles in the PDF review panel.
8. `PdfNotesPanel exposes Draggable<PdfQuoteDragData> for notes with quotes`:
   - Validates the presence of `Draggable<PdfQuoteDragData>` handles in the connected notes panel.

---

## 4. Verification & Quality Gates

- `dart format lib test`: Formatted clean across 382 files.
- `dart format --output=none --set-exit-if-changed lib test`: Exit 0 (0 changed).
- `flutter analyze --no-pub`: 0 errors, 0 warnings, 0 issues found.
- `flutter test test/pdf_quote_canvas_transclusion_test.dart --no-pub`: 8/8 tests passed (100%).
- Regression test suite (`canvas_card_previews_test.dart`, `canvas_pen_features_test.dart`, `pdf_quote_extraction_test.dart`, `pdf_reader_test.dart`): 38/38 tests passed.
- `flutter build windows --release --no-pub --dart-define-from-file=.local/google-build.windows.json`: Success (68.5s).
- Production binary: `build\windows\x64\runner\Release\orbit_note.exe` + `data\app.so` (17.9 MB).
- Startup smoke test: Launched executable, verified responsive (`Responding: True`, PID 6480), and confirmed clean shutdown.
- Release distribution packaged: `release-assets\OrbitNote-Windows-x64.zip` (25.9 MB).
