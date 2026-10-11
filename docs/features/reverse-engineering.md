# Reverse engineering knowledge preset

Status: experimental / future, optional and hidden unless enabled. Source: S10.
Orbit remains a knowledge layer around specialist tools, not a debugger/decompiler.

## Local implementation — 2026-10-03

Readability refinement: dashboard sections reflow at enlarged app zoom. Function
browsing exposes status/confidence/module filters and a scrollable table.
Dashboard function/finding/hypothesis actions share the validated record form
with optional build/address context and evidence. Missing target metadata is
unrecorded. Local feature boundaries below remain unchanged.

Enable **Reverse-engineering research tools** in Settings to show project/record
creation menus. Existing content remains readable with the toggle off. In research
folders, **New Research Record…** creates any of the twelve categories below as
editable Markdown notes, with build/address context and supporting/contradicting
object links. **Map Research Records…** creates shared-engine Canvas cards and
evidence connectors referencing existing objects (up to 500 records). Maps are
editable snapshots; category templates are not yet extensible custom type schemas.

Function tables import CSV or version-1 JSON after validation and preview. CSV
supports quoted comments/newlines. JSON accepts an array or an envelope containing
`version`, `tool`, `source`, `context`, `functions`; addresses are hex strings.
Context can carry `binaryId`, `binaryVersion`, `moduleId`, `module`, `moduleBase`,
`addressSpace` (`virtual`, `rva`, `file`), `address` and `rva`. Complete binary/build/
module context identifies rebased RVAs without conflating numeric addresses.
Incomplete legacy records stay separate; no address-only merging is performed.
Original imported row/context metadata and source/tool provenance are retained.
Invalid batches write nothing; storage failure can leave a reported partial import.
These are manual imports, not live specialist-tool integrations. Function templates
contain empty disassembly; Patch templates describe proposed changes without
modifying binaries. See [audit and remaining requirements](../tasks/game-research-2026-10-03.md).

| ID | Observable behavior |
|---|---|
| REV-01 | Optional schemas cover Binary, Module, Function, Address, Structure, Class, Import, String, Finding, Hypothesis, Patch and Call Graph as ordinary extensible object types. |
| REV-02 | Address references retain binary/version identity, address space and module/base context; identical numeric addresses in different binaries are not conflated. |
| REV-03 | Disassembly blocks, structure/class layouts, call relationships and memory/module maps connect to binary maps on the shared Canvas. |
| REV-04 | Hypotheses record confidence/status and supporting or contradicting findings; screenshots retain anchored annotations and source provenance. |
| REV-05 | Later Ghidra, IDA, Binary Ninja, x64dbg and WinDbg integrations import/link scoped knowledge through versioned connectors; availability is not a promise of integration support. |

Workflow: connect a finding to an address and screenshot, record a hypothesis,
then update its status with new evidence. Preserve earlier evidence and distinguish
observation from inference. A Patch object describes a proposed/recorded change;
creating one does not modify a binary. Acceptance: compare builds with rebased
modules without resolving links to the wrong address; disable the preset/plugin
and retain readable exported findings and unknown type metadata.
