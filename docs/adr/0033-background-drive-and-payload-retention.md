# ADR-0033 — Opt-in background Drive checks and reviewed payload retention

- Status: accepted
- Date: 2026-10-25
- Scope: SYNC-02/03/04/05/06/07/08/16; extends ADR-0030/0031.

## Decision

Use the existing Drive batch, repository leases, durable outbox, staging and
immutable revision provider for background work. Enrollment is the existing
device-only schedule plus optional `backgroundEnabled: true`; absent means off.
Only existing enabled bindings are eligible. A scheduled run never creates a
cloud binding or changes a Vault's pause setting. Shared profiles are skipped.
No job launches Google sign-in/consent. Account/enrollment changes cancel work.
Reports contain only times, bounded status codes and selected Vault identities.

Explicit settings enable a Windows Task Scheduler task under the logged-in user,
with no administrator privileges/passwords, or an Android persisted JobScheduler
job. Both request roughly 15-minute network checks, not continuous execution.
The Windows executable has a hidden `--sync-background` entry. A foreground
marker prevents starting work alongside the UI and cancels a worker after launch.
Android uses a dedicated process: POSIX advisory locks cannot protect independent
Dart isolates inside one process. Foreground activity startup cancels that job;
foreground account settings cannot race another running Android sync engine.
Job termination relies on existing journal/repository interrupted-save recovery.
OS power/network restrictions, force-stop, sign-out and device shutdown remain
limitations. This is not a guarantee of OneNote-equivalent background delivery.

Retain immutable graph metadata, operation receipts and tombstones. Removing
arbitrary old revision records would break parent validation and offline clients.
Instead offer an explicit reviewed expiration of superseded **payloads**:

- Keep at least 20 payload versions per object, all current heads, and every
  object whose server timestamps include a change within 90 days. Unknown dates
  retain everything. Any unresolved graph fork prevents cleanup.
- Preview no more than 200 eligible payloads, with byte/count totals. Recheck the
  complete graph/checksums before accepting the reviewed plan.
- Journal a generated immutable receipt ID and exact target records/blobs before
  any deletion. Verify the receipt in Drive before upgrading/deleting anything.
- Upgrade the folder to protocol 3 with `orbitRetention: head-blobs-v1` before
  expiration. Existing protocol-2-only clients refuse it. New clients accept
  exactly protocol 2 or this protocol-3 variant; record format/binding ID stay
  unchanged. Local authored files need no migration.
- Validate owned folder, role, operation, SHA-256 declaration and size again
  before deleting each obsolete blob. Missing blobs are idempotently complete;
  interrupted cleanup resumes its original durable plan/receipt. Current heads
  cannot become historical heads again in the validated append-only graph.

## Consequences and limits

Recent/current data, local history and complete graph metadata remain; expired
cloud payload bytes are intentionally unavailable. Cloud receipt files are kept.
There is no automatic destructive cleanup and no maintenance of a personal
account during development tests. Metadata compaction is **not** implemented:
the existing 10,000-record graph/journal safety bound still applies. A future
checkpoint protocol must prove offline-client/outbox migration before raising
that bound or deleting graph metadata. Neither this ADR nor automated HTTP
fixtures prove real Windows-to-Android/Google runtime acceptance.
