# ADR-0028 — Explicitly scoped native code workspace

- Status: accepted
- Date: 2026-10-13
- Scope: user-requested IDE workflows
- Supersedes: none

## Context

The owner now requests editable projects and IDE language support beyond read-only
source evidence. Native source files cannot be silently adopted as Vault notes or
written by presentation code. Tool execution must remain an explicit local action.

## Decision

Compose a code session through project and tool capability adapters. The selected
native project owns ordinary UTF-8 source files. Expected hashes, a project save
lock, flushed before/after history snapshots and same-directory replacement guard
saves. Versioned `.orbit-ide` draft/history state retains recoverable edits; no
Vault database becomes authoritative for code. Resource links continue through
explicit source-evidence capture, using existing universal Vault objects.

A pure LSP JSON-RPC client talks only to explicitly started local servers. Server
workspace edits/commands are not automatically accepted. Formatting/completion
edits validate UTF-16 ranges and document versions. Definition navigation stays
within the selected project. Native processes use executable-plus-argument arrays,
bounded output and explicit stop; no project command string is sent to a shell.
Open/edit alone does not run interpreters, builds or language servers. Shared/web
code uses capability interfaces and conditional adapters. No new package required.

Tool executable/argument preferences are versioned private device state outside
Vaults and exports; updates preserve unknown fields and refuse future versions.
Python pdb and configurable C++ command-line debugging reuse the explicit process
console. Graphical Debug Adapter Protocol integration is a separate future boundary.
Independent sessions retain separate recovery drafts; only the current session's
draft is cleared on save. Checkpoints precede replacement and can include failed
attempts. Existing external editors need not honor Orbit's save lock.

## Alternatives

Embedding an external browser editor/runtime would add packages and a second text
model. Reusing Vault Markdown as code-file authority would corrupt source formats.
Neither is needed for this concrete project editor. Existing code surfaces are
reused, while source browsing remains independently read-only.

## Consequences

Native project editing/execution is a distinct explicit scope. `.orbit-ide` files
are recoverable operational state, excluded from source browsing; old projects
remain readable and no workspace migration is required. Language servers and
interpreters/compilers are installed tools, not cloud services or hidden bundles.
This decision does not promise full IDE/debugger or mobile execution parity.

## Validation / follow-up

Record conflict, failure, restart, LSP framing/version/range and native tool evidence
in current task. Revisit before multi-file refactoring/debug adapters or changing
tool trust/automatic startup. Accepted is direction, not completion.
