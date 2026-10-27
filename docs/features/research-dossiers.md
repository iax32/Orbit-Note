# Reverse engineering research dossiers

Owner-approved 2026-10-27: information/authoring tools around existing REV-01–04,
CAN/EDT and developer knowledge. Ordinary notes, existing Canvas engine and
repository commands; no memory scanner, binary modification or process access.

| ID | Delivered workflow |
| --- | --- |
| REV-06 | Dossiers group function, structure, offset, hypothesis, journal, build and glossary notes; name/symbol/alias, type/state/build and Needs review filters |
| REV-07 | Memory layout rows: exact hexadecimal offset, field name/type, byte size and explanation; unsigned 64-bit bounds and informative overlap/union warnings |
| REV-08 | Reusable address/offset records with dossier, build, module and address-space context; universal references and live section summaries |
| REV-09 | Recorded instruction rows with explanations and branch labels; responsive code/interpretation columns in notes and workbench |
| REV-10 | Function signature, calling convention, parameters, returns/side effects, caller/callee relationships and evidence |
| REV-11 | Editable Canvas maps reference canonical records/sources; separately labeled pointer, field, call and evidence connections |
| REV-12 | Journals record experiment steps, inputs, observations and conclusions; explicit suspected/testing/confirmed/disproved state, confidence and review history |
| REV-13 | Build changes flag findings for rechecking without changing their state; changed/missing evidence needs explicit acknowledgement |
| REV-14 | Editable entity, inventory, coordinate transform, save format, networking, engine and investigation-log templates |
| REV-15 | Linked glossary definitions and aliases, searchable and embeddable like other records |

Open Research dossiers from the sidebar, Analysis dashboard or command palette.
Create a dossier/current build, then choose New record or Templates. Link existing
evidence through the searchable picker. Roles: evidence, contradicts, caller,
callee, pointer, field, defines and related. Offset labels are recorded text;
nothing is dereferenced. Open note provides full rich editing, screenshots,
drawings, math, export and ordinary Trash/restore.

Copy reference creates a universal link usable in notes/Canvas. Copy live summary
uses existing linked-section metadata targeting Research summary; source navigation,
updates, missing-source fallbacks, cycle protection and publication snapshots use
existing behavior. Canvas cards resolve canonical records live; positions/edge
labels are editable snapshots, not continuously rearranged.

Function records bridge into existing Function tables and recorded build comparison.
Dossier UUID defines the comparison scope (binaryId); build supplies binaryVersion.
Stable module identity and symbol must be entered explicitly; no address heuristic
invents identities. Missing identities/locations stay Unmatched. The comparator
describes recorded metadata, not binary equivalence.

## Storage, editing and limits

properties.researchDossier v1 is additive metadata on an ordinary orbit.note.
Kind/parent identity are stable. Unknown top-level/row/link data survives edits.
Changed known metadata validates at repository saves; unsupported records remain
readable notes and cannot be rewritten by the structured editor. No migration.

Generated Markdown lives between orbit:dossier-summary:start/end HTML comments.
Structured edits replace that summary only, preserving authored text outside it
byte-for-byte. The form explains this boundary. Direct edits inside the summary
are replaced on the next structured save; missing/duplicated markers refuse a
save with a history/recovery explanation instead of replacing the whole document.

Links store UUID, revision and existing content fingerprint. Unrelated edits never
silently acknowledge changed evidence. Explicit reviewed-sources acknowledgement
records current available versions without proving a claim. Preexisting missing
links remain warned; newly missing links fail. Build checks compare recorded
strings, not inferred game versions. Existing history, guarded Undo, failed-save
draft retention, read-only/stale/Vault checks and sync boundaries apply.

Bounds: title 300 characters; metadata/initial free writing 200,000 characters;
500 rows (12 editing rows/page); 200 relationships; 100 review entries; 50 browse
records/page; Canvas map 1–200 dossier records, at most 500 sources. Field sizes
are 1–1,048,576 bytes; hexadecimal addresses use strings/BigInt for web precision.
Workbench is a structured preview; Open note provides the full editor. No real
game/debugger acceptance is implied. Validation evidence: tasks/current.md.
