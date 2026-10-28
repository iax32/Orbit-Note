# Mobile Google sign-in and live Canvas sharing

Requested: fix phone Google login; computer/tablet image and drawing sharing.
Lenovo tablet now available after shutdown/resume. PC Ethernet: 192.168.1.163/24,
gateway 192.168.1.1. Tablet screenshot: 192.168.0.45/24, gateway 192.168.0.1.
PC ping succeeded twice (90/204 ms); trace goes through 192.168.1.1. Reverse
reachability is untested. Do not claim physical acceptance before testing.

Plan: repair mobile auth lifecycle and configuration feedback; add iOS adapter
and registered callback configuration; stream bounded ephemeral ink awareness
without bypassing durable Canvas commands; verify attachment/live recovery and
clarify reachable server setup. Google Drive remains file sync, not an ink relay.

Status: implementation in progress. Android public APK was built local-only;
real Google acceptance requires distributor Android package/signing registration
and a Web OAuth client. iOS registration and macOS build also required.

2026-10-28 registration: owner completed Cloud reauthentication and explicitly
approved both OAuth clients. Correct project is orbit-note-511512 (the historical
orbit-note-508518 is inaccessible). Created Android Preview package/certificate
registration and Mobile SDK Web client, verified both in the list. Local ignored
configuration now contains the public Android server client ID; Web secret was
not copied. Audience/scopes unchanged. New Android 1.0.4+5 build in progress.

Validation: 82 focused tests pass (49 s), including mobile auth consent/retry,
cancel/write/sign-out races, two-client automatic ink coalescing and exact
attachment/finished stroke transfer, lost acknowledgements, offline recovery,
Drive transfers/integrity/account isolation. Local ink measurement 110 ms in
the prior focused run; not a physical tablet result. Analyzer clean (12.8 s).
Strict format: 850 lib/test files, zero changes. No full 2900-test run.
