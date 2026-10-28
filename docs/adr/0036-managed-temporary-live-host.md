# ADR-0036 — Opt-in temporary live host

- Status: accepted for preview
- Date: 2026-10-28
- Extends ADR-0031's manual hosting boundary on explicit owner request.

The owner needs a tablet-reachable HTTPS address without scripts, DNS or router
configuration. Add an optional managed Windows host with temporary Cloudflare
Quick Tunnel. It is a preview convenience, not a guaranteed production service.
Cloudflare documents changing hostnames, 200 in-flight requests, no SSE and no
uptime guarantee. Orbit uses bounded HTTP long polling, not SSE.

Download only the version-pinned official Windows x64 helper and verify its
published SHA-256 before execution (including cached copies). No package install,
system service, firewall or router rule is made. A fresh loopback port/private
application-data directory isolates it from manually launched servers and Vaults.
Existing server persistence, grants and repository commands stay authoritative.

Review before starting discloses that Vault snapshots include Archive/Trash and
attachments; HTTPS terminates at Cloudflare and is not end-to-end encryption.
The helper starts only on user action. Root owner credentials never go through
the relay: host room creation is loopback, invitations contain only room grants.
Keep manual HTTPS hosting available as Advanced; do not silently start, enroll,
share on launch, or persist the temporary endpoint as a stable hosted service.

Reachability is checked before exposing an invitation. Leaving the dialog keeps
sharing active for homework; Stop and normal app exit stop the helper and host.
A Windows kernel job with kill-on-close also ends the helper on app crash, so it
cannot keep forwarding a loopback port later reused by another application.
Temporary addresses change after restarting, so users must send a new invitation.
No knowledge is deleted on stop. Existing 1.0.4 clients can join using the same
protocol; do not weaken TLS validation or allow remote plaintext HTTP.

Each managed start uses a separate private journal directory. A later session
does not reload earlier session grants under its new public address. Previous
journals remain private for recovery; the authored Vault remains authoritative.

Real network validation found OS DNS returning NXDOMAIN for newly issued relay
names while the provider's authenticated DNS returned valid public addresses.
The collaboration-only native transport therefore resolves exact temporary
trycloudflare hostnames through Cloudflare HTTPS DNS after OS DNS failure, with
bounded retries/cache and public-address validation. It upgrades TCP with TLS
against the original hostname (SNI/certificate validation preserved). Other
hosts/proxies keep normal resolution/TLS. No system DNS setting is changed.
Clients on similarly filtered networks need the updated transport.

Validation must cover invalid helper hashes, startup failure/cancellation, URL
parsing, reachability, stop/exit cleanup and real two-client room/blob transfer.
Physical tablet acceptance is separate; an isolated synthetic tunnel check does
not authorize uploading a personal Vault.
