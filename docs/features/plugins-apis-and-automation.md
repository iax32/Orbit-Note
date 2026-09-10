# Plugins, personal APIs, automations and executable notes

Status: capability direction planned M7; execution engines/marketplace details exploratory.
Sources: S03, S04, S06, S07 in the [source map](../product/conversation-extraction.md).
Architecture: [plugin boundary](../architecture/plugins.md).

## Purpose and workflow

Orbit Note should become an extensible environment where optional tools work with
the same knowledge. A flashcard extension can use notes/concepts, a citation tool can
link PDFs, and an automation can create a reading task when a PDF enters a collection.
Removing the extension should not make the user's original knowledge disappear.

## Requirements

| ID | Observable behavior |
|---|---|
| EXT-01 | Plugins can register supported commands, views/panels, tools, widgets, object/property types, import/export and automation capabilities through a versioned host API. |
| EXT-02 | Installation/enablement presents identity, compatibility, permissions and platform limits. Capabilities can be denied, scoped and revoked. |
| EXT-03 | Plugin reads/writes use public scoped queries and validated commands/history; private database/file writes are not the extension integration path. |
| EXT-04 | Disable/uninstall/safe mode isolate faulty code, clean up subscriptions/resources and preserve user-created plugin data with fallbacks/export. |
| EXT-05 | Optional local API/CLI, browser clipper, IDE extension and mobile share integrations can create/search/reference knowledge with explicit pairing/scope where needed. |
| EXT-06 | An automation rule expresses trigger → conditions → actions, can be previewed/enabled/disabled, and exposes run history and failures. |
| EXT-07 | Automation delivery avoids duplicate effects and recursive event loops; events describe committed changes and rule runs preserve provenance. |
| EXT-08 | “Living notes” can react to properties/events through those same rules, such as highlighting an approaching deadline or proposing archive after completion. |
| EXT-09 | Executable/interactive blocks may offer formulas, calculations, charts and queries first; scripts/code/API requests require a separately evaluated permissioned runtime. |
| EXT-10 | Community extensions/themes can be shared without requiring the original vendor service; imported files do not silently activate executable capabilities. |
| EXT-11 | MCP and local/public connector APIs may expose scoped capabilities with explicit enablement, authentication and compatibility/version negotiation; no unauthenticated public listener is implied. |

## Examples and boundaries

**PDF workflow:** when a PDF is added to University, extract available metadata,
propose/create a reading task under an authorized rule, add collection membership,
and link the course. A failed extraction does not lose the PDF. **Meeting template:**
when a note is deliberately created from a meeting template/tag rule, insert sections
for participants, decisions and tasks without repeatedly reapplying the template.
**Project completion:** when all relevant tasks complete, use an enabled rule to
update status or propose archive; do not infer permission from a note's prose.

The eventual ecosystem may include Anki/flashcards, Pomodoro, habit/book/budget
trackers, academic citations/Zotero, LaTeX, RSS, Git/GitHub, weather, music,
language-learning tools and a code runner/terminal. These are extension examples;
they are not a request to bundle every integration into core or to create provider
accounts. External messages/payments/other irreversible effects are not guaranteed
reversible just because local commands have undo.

## Runtime and event semantics

A manifest should declare a stable plugin ID/version, host API compatibility,
entry points, requested capabilities and platform support. The exact runtime is
open: a Dart isolate alone is not a security sandbox. Do not promise dynamic native
execution on every platform without an evaluated distribution/runtime design.

Rules need an operation identity and causation trail so an ObjectUpdated event
does not create endless updates to itself. Dry run previews intended effects but
does not execute the external action. Limit work, time, network hosts and scope;
cancel/disable must stop future runs while accurately reporting already completed
effects. A local network listener needs authentication/origin boundaries even on
localhost. No listener or code evaluator is a foundation prerequisite.

## Acceptance scenarios

- EXT-02–04: deny network/mutation, revoke access during use, disable a failing
  plugin and keep the host editor responsive with preserved data.
- EXT-06/07: deliver one PDF-added event twice and trigger a rule-produced update;
  create the intended task once and avoid a recursion loop.
- EXT-05/09: imported Markdown contains executable-looking text; opening it performs
  no process/network action without the corresponding explicit capability/action.
- EXT-04/10: export data with its plugin missing and restore the meaningful original.

## Delivery

Let real built-in consumers establish narrow command/view interfaces first.
Prototype one useful extension and one rule before a marketplace, broad SDK or
general scripting language. Runtime selection and support policy require an ADR.
