# Plugin architecture

Status: boundary principles accepted; runtime/SDK and distribution deferred to M7.
Do not load arbitrary Dart/native code dynamically or label it sandboxed. A Dart
isolate alone is not a security boundary. Select a supported runtime per platform
and demonstrate isolation before third-party execution.

## Capability surfaces

Built-ins should eventually use the same registrations where practical: commands,
views/panels, toolbar/menu entries, theme tokens, object types/properties, canvas
tools, import/export, query helpers, automation triggers/actions, and event
subscriptions. Plugin packages must declare ID, version, host API range, entry
points, platform support and requested capabilities in a versioned manifest.

Keep a stable public API separate from implementation classes. Reads use scoped
query interfaces; writes use validated application commands and history. Plugins
cannot write SQLite, bypass file reconciliation, or call private widget internals.
Committed domain events can drive subscriptions; subscriptions must dispose cleanly
and avoid mutation loops. An event bus is introduced when a real use case needs it.

## Permissions and lifecycle

- Default deny for filesystem, network hosts, secrets, external process execution,
  workspace mutation and background work. Grants are scoped and revocable.
- A file picker can grant a specific file without granting the whole drive.
- Network/request budgets, cancellation, timeouts, resource limits and clear error
  isolation keep plugins from blocking core editing. Disable a failing extension
  without deleting user content.
- Never execute scripts embedded in imported notes just because a plugin recognizes
  them. Executable notes/code runners require an explicit permissioned design.
- Migrations are versioned, backed up, and reversible/recoverable. Preserve unknown
  plugin data if the plugin is unavailable; show a readable fallback and export it.
- Safe mode starts without third-party code. Uninstall revokes capabilities and
  removes code; deletion of user-created objects/data is a separate explicit choice.

Mobile store/runtime restrictions and browser isolation may limit available
capabilities. Do not promise identical extension execution on every platform.

## Future local API and automations

A CLI/local API/browser clipper/share-sheet bridge uses the same capabilities and
commands. A localhost listener is not inherently trusted: require local pairing,
scope, origin/CSRF controls and explicit enablement. No listener is started in M0.

Automation rules can express trigger → condition → reviewed/authorized action.
Track provenance, deduplicate events, bound recursive triggers, provide preview,
disable/reset and reversible history. Music, weather, Git integrations, flashcards,
budgets and code execution are ecosystem examples, not foundational dependencies.
