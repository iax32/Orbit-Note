# Button-driven temporary live sharing

Owner requests immediate, simple PC/tablet live sharing with no scripts, manual
domain, certificate or router setup. Implements the reachable HTTPS address and
matching invitation request. Keep the manual self-hosting path under Advanced.

Use a managed in-process loopback server and a pinned/checksummed official
cloudflared helper, started only after an in-app review explaining scope,
Cloudflare transit, lack of end-to-end encryption and temporary-link lifetime.
Host room creation and owner key remain on loopback. Editor invitations advertise
the verified HTTPS link. Invitations remain protocol-compatible with 1.0.4,
but this network's DNS failure requires the updated Android transport too.

Status: real HTTPS synthetic acceptance passed (9 s), including second-client
join, Canvas placement update and exact attachment bytes. Real validation exposed
ISP/OS NXDOMAIN for temporary hostnames despite valid authenticated provider DNS;
added a narrow HTTPS-DNS fallback preserving original-host TLS validation. New
Windows and Android builds include it. Physical tablet acceptance remains pending.

Focused checks: host verification/start/stop, rejected bad digest, URL boundaries,
simple UI hiding advanced server fields, prior live ink/selection behavior pass.
No original Vaults or personal content were used in external relay acceptance.

37 focused checks pass (one external-network case skipped in the normal run);
the explicit real HTTPS case separately passes in 9 s. Analyzer clean (14.4 s),
strict format 859 files unchanged. Android 1.0.5+6 built in 124.2 s; existing
preview package/signature verified. Windows built in 117.4 s; final Windows-only
journal isolation correction prevents old grants reappearing on a later start.
Rebuild/check this Windows change before delivery. Android does not host sessions.

Final Windows rebuild passed (95.7 s), with a kernel-managed child process job:
normal exit, Stop and an application crash cannot leave the tunnel forwarding
an abandoned loopback port. All five host checks including the actual HTTPS
transfer pass (11 s). Final Windows-child lint check clean. Android ARM64 AOT
contains both the relay DNS path and the existing public Google client ID.

Final host/UI check: 5 pass, one real-network case correctly skipped by default.
Includes restart isolation proving an earlier room grant cannot access a later
managed session. No full test suite or GitHub workflow is needed for delivery.

Published 1.0.5+6: https://github.com/iax32/Orbit-Note/releases/tag/preview-1.0.5-2026-10-28
Source 6ae4803f101128330c88fbe3f12431f8d62f6de7. Six assets' uploaded sizes verified:
Android 139659074 bytes; Windows setup 27307539 bytes. APK SHA-256
ac168eb73c0df4cc084a53bdb1976aab2ec8c6fd7bf71e1c860e72f1524bbbff;
existing preview signer retained. Latest analyzer clean (7.8 s), strict format
860 files unchanged. Release notes explain relay limits, first-use helper,
initial download, DNS transport and remaining physical acceptance. Source push
and publication completed without triggering workflows. No user server/Vault was
started by tools; only isolated synthetic server data went through the test relay.
