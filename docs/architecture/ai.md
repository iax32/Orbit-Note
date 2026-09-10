# AI architecture

Status: accepted optional/reviewable direction; implementation deferred to M8.
AI is a capability client of the application, not an alternate storage layer.
Local editing/search/export must work when AI is disabled or unavailable.

## Boundaries

```text
User intent → scoped retrieval → provider adapter → answer or proposed change set
                ↑                                      ↓
        local content/index                       validation + preview
                                                       ↓ user accepts
                                            application commands + history
```

Providers may be local models or user-selected remote services. Separate provider
interfaces, credentials, model configuration, cancellation and cost/context limits
from domain objects. No provider key or model dependency is part of M0. Credentials
stay outside workspace exports and plugin-readable general settings.

Retrieval starts with local lexical search; embeddings are an optional derived
index, never authoritative content. Respect workspace scope, excluded content and
user-approved outbound data. Show which documents/fragments support an answer.
Remote use must make data transmission visible; a local workspace does not imply
that a remote AI request stays on-device.

## Reviewed mutations

1. Gather only needed objects and their expected revisions/hashes.
2. Produce a typed proposal: operation IDs, target IDs, intent, before/after values,
   source/provenance, and preconditions. Model output is untrusted input.
3. Validate types, permissions, references, path boundaries and operation limits.
4. Show a human-readable diff with accept/reject and partial acceptance where
   dependencies permit. Do not call a plan applied before local commitment.
5. Revalidate against current local state on acceptance. Stale proposals require
   recomputation/review, not overwriting newer edits.
6. Execute through normal commands as a recoverable batch and retain before-state
   and audit provenance. Partial failure follows the storage journal protocol.
7. Offer undo/restore; if later edits overlap, create a reviewed compensating change
   instead of blindly rewinding unrelated work. Retention limits are explicit.

Retrieved text, imported files, model responses and plugin content cannot grant
permissions or instruct the application to execute tools. Generated queries use a
validated typed query representation; do not execute arbitrary model-generated SQL
or scripts. Summaries retain links to source; possible contradictions/duplicates
are suggestions with uncertainty, not automatic corrections.

## Planned use cases

Workspace-grounded Q&A, summaries, task extraction, inbox organization, linking,
duplicate/concept suggestions, query/view creation and proposed board arrangement.
Later: knowledge health, assumptions/decision review, contextual resurfacing,
work-session summaries, and optional handwriting conversion. Deterministic orphan
or broken-link checks need not depend on AI.

Before implementation, define privacy UX, provider configuration and change-set
schemas. Validate with a fake provider first; test malformed output, prompt-like
source content, insufficient permissions, stale revisions, partial acceptance,
cancellation, disconnected providers and undo after subsequent user edits.

Expanded [AI requirements](../features/ai-and-knowledge-health.md) include BYO
provider capabilities and per-function routing. Sync permission never authorizes
model transmission. Deterministic health checks can precede AI; semantic changes
still require reviewed, reversible, stale-safe commands.
