# AI assistance and knowledge health

Status: optional AI planned M8; knowledge-compiler and resurfacing refinements exploratory.
Sources: S03, S04, S08 in the [source map](../product/conversation-extraction.md).
Architecture: [AI contracts](../architecture/ai.md),
[history](history-and-recovery.md).

## Purpose and workflow

AI should help users understand and organize their own knowledge, with references
and visible changes. A user can ask where they wrote about a design idea, summarize
recent learning, suggest tasks from selected notes, organize Inbox or build a saved
view. They can inspect the supporting sources and decide what changes to accept.

## Requirements

| ID | Observable behavior |
|---|---|
| AI-01 | AI can be disabled; core editing/search/export remain available without provider credentials, an account or network. |
| AI-02 | Users choose local or supported remote providers and the retrieval scope. Exclusions and the data sent remotely are understandable and enforced. |
| AI-03 | Workspace answers/summaries identify supporting objects/fragments and distinguish evidence, inference and uncertainty; missing evidence is acknowledged. |
| AI-04 | Proposed edits show create/rename/link/move-membership/merge/archive actions as an inspectable before/after change set with source and intent. |
| AI-05 | Users accept all, accept supported independent actions, reject or revise a proposal. Acceptance revalidates current state and never silently overwrites newer edits. |
| AI-06 | Applied changes use normal application commands/history with honest completion/failure reporting and reversible recovery. |
| AI-07 | Natural-language queries and board/view generation preview an editable structured interpretation before saving or rearranging content. |
| AI-08 | A knowledge compiler can suggest duplicates, missing concept pages, related project clusters and semantic links without merging by itself. |
| AI-09 | Health views can surface unresolved links, orphaned notes, tasks without projects, inactive projects, unreviewed sources and possible conflicting decisions with clear definitions. |
| AI-10 | Contradiction/assumption suggestions show competing passages, dates and scope; users can mark obsolete, complementary, mistaken or unresolved interpretations. |
| AI-11 | Resurfacing can consider user importance, recency, current projects and upcoming dates; support dismiss/snooze/disable and explain why an item appears. |
| AI-12 | Requests can be cancelled and have visible progress/provider failures; cancellation does not leave a proposal secretly applying in the background. |
| AI-13 | BYO provider routing may support OpenAI, Gemini, Claude, local models and OpenAI-compatible endpoints, including different providers for different functions; capabilities are negotiated rather than assumed identical. |
| AI-14 | AI data/transmission permissions are separate from sync and connector permissions; syncing a workspace never authorizes sending it to a model provider. |
| AI-15 | Knowledge Health includes inconsistent tags, Markdown/property linting, unresolved decisions and deadlines without tasks. Deterministic cleanup is limited to defined, authorized, reversible rules; semantic cleanup always requires review. |
| AI-16 | Diagram-generation and migration-cleanup suggestions preview changes with source links and recovery; they cannot silently reinterpret imported structure or overwrite a user's Canvas. |

## Concrete examples from the concept

- “What was my idea for multiplayer synchronization?” returns grounded sources.
- “Turn these lecture notes into tasks” proposes tasks with links to their origin.
- “Show active programming projects untouched this week” previews a typed query.
- “These two notes may be duplicates” offers compare, link, merge proposal or ignore.
- “This concept is mentioned in several notes” offers an optional concept page.
- “Two decisions may disagree” presents evidence for review, not a factual verdict.

Similarity/confidence numbers are not truth probabilities unless actually calibrated.
The original chat's percentage examples are illustrative, not required UI metrics.
Deterministic health checks should run locally without a model where possible.
An orphaned note is not necessarily bad; no “Clean Workspace” action deletes content
automatically or assigns the user a misleading productivity score.

## Trust, state and data boundaries

Imported notes, plugins and retrieved content may contain instruction-like text.
They are data, not authority to change permissions, execute scripts or broaden the
retrieval scope. Use validated structured operations, never arbitrary model SQL
against the workspace. Excluded files must not leak through cached embeddings,
summaries or stale indexes. Credentials remain outside exported workspace settings.

A proposal lifecycle should distinguish gathering, generating, ready for review,
applying, applied, partially failed, rejected, cancelled and stale. Not every state
needs a separate screen, but users must be able to tell whether knowledge changed.
Undo of an older batch handles subsequent edits through reviewed compensation.

## Acceptance scenarios

- AI-02/03: use a fake provider to inspect a scoped request; excluded content is
  absent, and answers point to actual retrieved source locations.
- AI-04–06: reject a proposal with no content changes; accept a subset, then undo
  it and verify unrelated later edits survive.
- AI-05/12: modify a target during generation, then cancel or accept; stale changes
  cannot apply silently and cancellation has observable final status.
- AI-08–11: dismiss a duplicate/contradiction suggestion with a reason and keep both
  originals; show deterministic health findings without requiring AI to be enabled.

## Delivery

Begin with scoped read-only assistance and a fake provider harness. Add one kind
of reviewed mutation before general organization. Provider protocol, secret storage,
cost controls, model selection and privacy UX are task-specific decisions, not M0 work.
