# Capture and Inbox

Status: planned. Stage: M1–M2; OS integrations later.
Sources: S01, S03, S04, S06 in the [source map](../product/conversation-extraction.md).
Architecture: [objects](../architecture/universal-object-model.md),
[durable storage](../architecture/storage-formats.md).

## Purpose and workflow

Make it easy to save a thought before deciding where it belongs. A user invokes
capture, types “Research conflict handling,” optionally includes a URL or file,
sees the target workspace/Inbox, and saves locally. Later they triage the existing
item into a project, collection, task or linked note.

## Requirements

| ID | Observable behavior |
|---|---|
| CAP-01 | In-app capture accepts text with optional title; organization is optional and the active workspace/destination is visible. |
| CAP-02 | Inbox collects unprocessed captures of several types: notes, tasks, links and attachments. A user can filter and inspect them without converting every item to plain text. |
| CAP-03 | Save commits locally and exposes saving/saved/error state; failure preserves entered content and offers retry or recovery. |
| CAP-04 | Triage can assign collections, tags, project relations or an appropriate type. Marking processed changes Inbox membership/status, not the object's identity. |
| CAP-05 | Quick capture later accepts clipboard text, URLs, screenshots, photos, files, voice and task input through explicit user actions. |
| CAP-06 | Global desktop capture and mobile share sheets can open a compact capture surface without navigating away from the user's main work; availability is platform-dependent. |
| CAP-07 | Journal/daily-note creation provides a repeatable date-based destination and optional template without forcing a journal workflow on all users. |
| CAP-08 | Imported/shared captures can retain source URL/app, capture time, original filename and an optional “reason saved”; inferred metadata is distinguishable. |
| CAP-09 | Optional clipboard history is explicitly enabled, scoped, inspectable and clearable; ordinary paste never requires continuous clipboard monitoring. |

## Data and integration

Inbox is a query/membership state over real objects, not a second object repository.
Choosing “Create task from this note” must explain whether it promotes the object
or creates a related task; it must not silently keep two editable copies. Media
capture uses attachment storage and can link a transcription later. Original audio
remains available when transcription fails. Capture is independent of cloud/AI.

## States and edge cases

An empty Inbox should invite capture once that action exists. An unavailable
workspace should retain the draft and let the user choose a valid destination.
The proposed default is never to silently save into another workspace. Closing
with uncommitted input must offer a draft/recovery path. Duplicate OS deliveries
need an idempotency token where the platform provides one; similar text alone is
not proof two captures are duplicates. Microphone/clipboard permissions are obtained
only for the corresponding action. Date rollover and timezone behavior for daily
notes must be selected in the implementation task.

## Acceptance scenarios

- CAP-01–04: save while offline, restart, triage into a collection, and verify the
  same object ID remains accessible outside Inbox.
- CAP-03: simulate disk-full during save; the user can recover the entire draft.
- CAP-05–08: share a source file twice with one delivery ID; preserve one committed
  import and its source metadata, while independent captures remain separate.

## Delivery

Begin with text capture and a real persisted Inbox after M0. Add attachments and
triage next; global hotkeys, recording and share-sheet integration are separate
platform tasks. M0's empty Inbox is only a navigation placeholder.
