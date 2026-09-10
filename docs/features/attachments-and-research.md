# Attachments, media and research

Status: planned. Stage: M2 basic files; M4 annotations; richer viewers later.
Sources: S01, S03, S04, S07, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [storage](../architecture/storage-formats.md),
[annotation engine](../architecture/canvas-engine.md).

## Purpose and workflow

A researcher keeps a PDF alongside notes, highlights a claim, links it to a
decision and adds handwritten context. A developer attaches source code and a
diagram; a student captures audio. Original files remain available even if an
in-app viewer or extraction tool is unavailable.

## Requirements

| ID | Observable behavior |
|---|---|
| FILE-01 | Attach or reference arbitrary file types with filename/type/size and an explicit external-open option; attaching never executes a file. |
| FILE-02 | Store original bytes separately from object metadata and previews, retaining source filename, checksum and ownership/reference information. |
| FILE-03 | Image viewing supports suitable resolution, thumbnails and later crop/regions/annotations; destructive transformations preserve originals or explicit history. |
| FILE-04 | PDF viewing navigates pages, previews only needed pages and supports later text highlights, ink, comments and deep links to a page/region/annotation. |
| FILE-05 | Highlights/regions can become linkable knowledge with tags/comments/relations and a navigable source; selecting them elsewhere returns to their context. |
| FILE-06 | Text/code previews preserve raw text and add syntax highlighting where supported; code execution requires a separately authorized extension capability. |
| FILE-07 | Audio/video playback and voice capture can retain time-based source references; transcription is optional and linked to its original media. |
| FILE-08 | OCR/extracted text can participate in search with source attribution and recognition-quality limits; extraction failure does not make the original inaccessible. |
| FILE-09 | Unsupported/corrupt/missing media has a usable fallback and recovery/relink path; shared references do not duplicate bytes for each card/view. |
| FILE-10 | Future citation/bookmark integrations preserve source URL, capture context and extracted metadata with review/correction of uncertain values. |
| FILE-11 | First-class PDF reading provides page navigation, thumbnails and in-document search, with Continue Reading restoring page/zoom/highlight context. |
| FILE-12 | PDF highlights, underline, strikeout, comments, sticky notes and shared-ink annotations retain stable anchors. Selected text can be extracted to a note with exact page/highlight provenance and backlinks. |
| FILE-13 | PDF highlights are linkable Universal Objects when created as knowledge annotations; ordinary ink samples remain local stroke data. Canvas can display the PDF and its referenced highlights together. |
| FILE-14 | Citation properties can include DOI, ISBN, author, year and source metadata; Zotero integration and annotated-PDF export are later adapters with declared fidelity. |

## Format support ladder

| Family from the chat | Initial treatment | Later intended enhancement |
|---|---|---|
| `.md`, `.txt`, source code | Text/open-file support appropriate to the object | Preview, syntax highlighting and linked snippets |
| `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg` | Original attachment plus supported preview | Regions, annotations, safe SVG rendering, thumbnails |
| `.pdf` | Original attachment and planned viewer | Highlights, comments, linked regions and shared ink |
| `.mp3`, `.wav`, `.m4a`, `.mp4`, `.webm` | Original attachment, platform-capable playback later | Voice notes, timestamps, transcription |
| `.csv`, `.json`, `.yaml`, `.yml`, `.html` | Preserve original / safe text or import preview | Structured import and sanitized saved-page view |
| `.docx`, `.xlsx`, `.pptx` | Original attachment/external open | Evaluated import or viewer; native editing is not promised |
| Other files: archives, `.blend`, project assets, executables | Metadata/reference/external-open choice | Plugin-provided preview where supported |

“First-class file object” does not mean every codec or proprietary format has an
editable native implementation at launch. Each supported preview must name its
platform/fidelity limits. External-open uses an explicit user gesture and respects
OS choices; HTML/SVG/remote embeds do not inherit arbitrary script privileges.

The original PDF stays unmodified by default. Annotations live in documented
sidecars/objects referencing its version. An exported annotated PDF is a derivative
with explicit overwrite choice, not a silent replacement. Reading Workspace layout,
reading sessions and Continue Reading share CTX restoration/session behavior.
Windows screenshot paste, resize/aspect ratio, replace, open original and Show in
Explorer are defined once in [desktop interactions](desktop-interactions.md).

## States and acceptance scenarios

- FILE-02/09: attach one PDF, reference it in several notes/boards, remove one
  placement and verify original bytes remain for other references.
- FILE-04/05: open a linked highlight after restart and return to the same page
  region. Replace the PDF with a different revision and show a re-anchor state.
- FILE-03: import large photos and verify bounded decoding/thumbnail memory at low zoom.
- FILE-07/08: deny microphone/remote extraction access and keep local file viewing usable.
- FILE-09: simulate corrupt content and missing bytes without crashing the workspace
  or losing annotation metadata. Removing the last reference does not silently
  authorize permanent byte deletion; retention follows the recovery policy.

## Delivery

Start with durable attachment objects and explicit open/fallback. Add viewers one
at a time, then annotations and extraction. Choose packages based on actual target
platform support in the corresponding task, not a speculative all-format dependency list.
