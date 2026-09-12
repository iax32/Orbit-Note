# Current milestone — M6 optional local-first sync

2026-09-12: owner explicitly selected Google Drive first and WebDAV second. The
[audit](sync-audit-2026-09-12.md) and [design](../architecture/sync-design.md) are
pre-implementation work. No cloud capability is shipped. Exit requires durable
queue/base/deletion state, conflict recovery, safe provider writes and real
Windows/Android two-device acceptance. Preserve the delivered local/PDF baseline.

## Historical local-core milestone

Updated 2026-09-09. The owner expanded the original Foundation/M0 task to recover
existing implementation and deliver usable high-priority local features.
Foundation is present; M1 hardening is the current priority. Useful subsets of
M2–M5 have been implemented without declaring those entire milestones complete.

See [implementation status](implementation-status.md) for delivered capabilities,
validation evidence and explicit gaps. The [roadmap](roadmap.md) retains the original
milestone sequence and exit gates; broad feature specifications are not completion claims.

## Next exit gates

- Completed bounded backup import; next validate larger backups and recovery inspection.
- Native reopen and external-edit workflows exercised with representative user files.
- Measured Canvas performance and real pen/clipboard/device interaction checks.
- Workspace selection now persists; continue native missing-device/reconnect validation.
- Production browser persistence designed and validated separately from the limited adapter.

No sync service, plugin runtime, AI provider, graph or calendar is implemented.
The [current task](../tasks/current.md) records Rich Markdown stabilization on top
of the preserved audit/folder delivery. Complete and validate the bounded editor
work before Calendar or another shared Canvas expansion.
