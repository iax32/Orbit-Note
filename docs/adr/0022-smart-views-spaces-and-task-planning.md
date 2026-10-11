# ADR 0022 — Shared Smart Views, device contexts and task planning

Status: accepted direction, 2026-10-08. Delivery evidence is in the current task.
Extends ADRs 0005, 0007 and 0020; authoritative files and universal identity remain.

## Context

Legacy views and embeds independently filtered objects. Context switching and
Home customization lacked named descriptors. Tasks had dates and basic blockers,
but no explicit occurrence history or recoverable calendar move command.

## Decision

Store a bounded, versioned `smartQuery` in an ordinary `orbit.view` object's
properties. A pure Dart evaluator handles AND/OR rules, scalar properties, tag
membership, date/number comparisons and relation-ID equality. Preserve manual
membership/folder/scope before applying the query. No SQL or scripts are accepted.
One controller projection serves list/table/board/gallery/calendar/timeline,
note embeds, Home and Canvas previews. Results reference canonical objects; cache
invalidation follows the current immutable object snapshot and local date.
Presentation-specific date ordering and explicit embed refinements remain allowed.

Keep named Spaces and layouts in device settings inside the current Vault.
Spaces capture tabs, pane arrangement, note view state/positions, cameras, search
filters, project/folder scope and dashboard; layouts capture pane arrangement.
Appearance is an explicit opt-in. All-Vault context is retained before entering
a Space. Switching flushes drafts first, restores available IDs and retains
unknown descriptor data. Scope filters navigation/search, never file ownership,
object lookup, permissions or Canvas placement identity. No content is copied.

Home widgets are versioned descriptors with explicit apply/cancel, order and
one-to-three column spans. Unknown widgets render placeholders. Reset remains
reachable from Settings/Spaces and preserves knowledge and unknown context records.
These settings use the existing serialized device-settings save contract, not a
new portable knowledge format or an arbitrary docking tree.

Recurring tasks remain one Universal Task. Completing an occurrence appends its
due date and UTC completion instant, advances one civil date and leaves the next
occurrence open. Monthly/yearly schedules retain an anchor day with month-end
clamping. Missed occurrences advance individually and remain overdue. A series
edit affects future completion behavior; existing history is retained.

Dependency and parent edges use task IDs. New edges require active task targets
and reject cycles/self-reference. Legacy unresolved/unsupported unchanged data
survives unrelated edits; it is never silently repaired. Completion remains an
explicit user choice even when blocked. No automatic downstream completion.

Query/planning/reschedule commands check current snapshots, repository read-only
state and validated properties, then use existing recoverable repository saves.
Flush/close wait for active planning writes. A session undo restores the previous
properties only when no later edit intervened; otherwise document history remains
the recovery route. Failure releases the command lock and leaves originals intact.

## Consequences and limits

Existing envelopes, Markdown/frontmatter, SQLite schema and UUIDs are unchanged.
No migration rewrites old workspaces. Queries are evaluated in memory; tables,
boards, lists and galleries build visible rows lazily. Canvas embeds are previews
with navigation to the full saved view, not interactive spreadsheet controls.
Gallery uses recorded text rather than inventing missing image previews.

Version 1 bounds: 32 rules, 20 columns, 30 contexts, 16 widgets, 100 dependency
edges per task and 10,000 recorded occurrences. Limits fail explicitly rather than
truncating stored knowledge. Unknown/future queries and contexts cannot be edited
through older controls. Removing a context or presentation never deletes objects.

Recurrence is date-only daily/weekly/monthly/yearly, not RRULE or a named-zone
scheduler. Timed event moves use device-local clock time, retain seconds and
duration and reject nonexistent DST times; ambiguous times follow the existing
platform resolution. Reminders, provider calendars, Gantt, formulas, AI queries,
arbitrary docking, portable context import/export and multi-window remain separate.

Acceptance covers restart, old/unknown formats, stale/failed saves, command
serialization, exact undo, civil dates/month-end/leap years, dependency cycles,
canonical cross-view edits, lazy tables and narrow/enlarged-text dialog layouts.
