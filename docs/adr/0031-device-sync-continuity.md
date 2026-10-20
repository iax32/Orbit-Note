# ADR-0031 — Device-local sync continuity and self-hosted readiness

- Status: accepted
- Date: 2026-10-15
- Scope: SYNC-02/03/04/05/07/08/09 continuity subset
- Extends ADR-0030; partially supersedes ADR-0027's memory-only reconnect boundary.

## Context

The owner requested continued Drive and cross-device self-hosting improvements.
Bulk transfers and active-Vault sync already share one durable engine. Remembering
a room must not leak capability tokens through portable Vaults, silently rejoin a
server, or override revoked membership. Drive and shared editing are independent
authorities and must not apply together during connection setup.

## Decision

Persist an explicit selected-Vault schedule in OS-protected device storage, bound
to the Google subject. Reuse the active controller's exclusive batch lease and
native existing-only repository locks for sequential inactive checks. The active
Vault remains with its existing controller. Per-Vault opt-out wins; the schedule
cannot create a binding or re-enable one. Timer work runs only while Orbit is
open, with visible status, cancellation, backoff and explicit account-error retry.
Startup checks local opt-in before constructing account/scheduler services.

Offer explicit Remember/Reconnect/Forget for an existing room capability in secure
device storage keyed by hashed Vault UUID. Never remember the root owner key or
put capabilities in authored files, portable backups, sync payloads or logs.
Reconnection still uses the normal server state/role check and divergence review.
Future private formats freeze rather than overwrite; unknown supported-version
fields survive updates. Neither saved profiles nor schedules prove membership.

Mark both creating and joining a connection as shared authority activity before
the first async operation. Preserve account/opening cancellation guards throughout
Drive transfers and shared import UI. The server exposes a minimal non-disclosing
health endpoint plus owner-authenticated protocol/readiness diagnostics. Storage
failure reports unready. Refuse server storage inside a Vault before creating keys.
Package the existing service as a standalone Windows executable with an explicit
console launcher; do not install a service or alter network/TLS configuration.

## Alternatives and consequences

A new background daemon would add lifecycle/credential ownership beyond this
scope. Invitations in Vault preferences would enter backups and disclose access.
Automatic reconnect could transmit content before users review their session.
The selected design uses existing secure storage without a new dependency or
authored migration. A reachable HTTPS deployment and a running host remain
necessary for other devices. Existing-document live editing remains the current
protocol; new shared objects/deletions/attachments require a separate change.

## Validation

Exercise restart, account changes, native locks, paused/unbound Vaults, cancellation,
offline backoff, future formats, server revocation, readiness/storage failure and
narrow enlarged-text controls. Current-task evidence records actual runs/builds;
local simulated Drive and loopback tests do not claim physical-device acceptance.
