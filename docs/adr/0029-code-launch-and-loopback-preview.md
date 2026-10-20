# ADR-0029 — Project launch profiles and loopback web preview

- Status: accepted
- Date: 2026-10-13
- Scope: owner-approved Code workspace continuation
- Supersedes: none; extends ADR-0028

## Context

Small scripts and web projects need repeatable commands and HTTP asset/module
preview. External UTF-8 files remain authoritative; project configuration cannot
silently execute tools or become cloud/Vault authority.

## Decision

Pure launch profiles contain stable IDs, scoped working folders and ordered
executable/argument steps. Project configuration is versioned JSON under
`.orbit-ide/config`, guarded by expected hashes, the existing project save lock and
flushed before/after checkpoints. Unknown fields survive edits and future versions
refuse replacement. No auto-start or shell interpretation is added. Explicit run
checks drafts/context and stops between steps on failure/cancellation; interpreter
and compiler paths remain device-local tool choices.

A separate conditional native capability starts a static HTTP server on an
ephemeral IPv4 loopback port. It serves only supported web assets from the selected
project. Exact Host/origin guards and random per-server authorization reject
cross-site/rebinding requests; per-port HttpOnly/SameSite cookies allow root-relative
assets without making two previews interfere. Hidden paths, unsupported source,
directory listings and symlink escapes are refused. This is not public hosting,
an arbitrary filesystem endpoint or a script interpreter.

Saved/external supported-file changes increment a revision; a small injected HTML
script requests page reload. Explicit stop, project changes, close and successful
app exit dispose the service and its watcher. UI accesses the capability through
local boundaries. Shared code uses pure values and native/stub adapters, with no
new package. The preview is temporary; it does not persist a server address/token.

## Alternatives and consequences

Shell command strings would make whitespace/quoting and execution boundaries
ambiguous. A bundled Node server or browser runtime would add an unnecessary
runtime dependency. Static file preview alone cannot support ordinary HTTP module
requests. The selected server is scoped and bounded (16 active requests, 64 MiB per
asset, reload injection up to 2 MiB HTML) and introduces no Vault migration.

This does not provide a bundler, package manager, backend routing, public tunnel or
graphical debugger. Native external watching can be unavailable; Orbit saves and
explicit refresh remain, with browser reload when inline scripts are blocked by
authored CSP. Large media Range requests and project build isolation/transactions
remain outside this static-preview subset.

## Validation

Current task owns actual native HTTP/process, configuration restart/conflict/failure,
cancellation, compact layout and compatibility evidence. Accepted direction does
not itself mark third-party build systems or public/mobile preview complete.
