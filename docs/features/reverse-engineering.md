# Reverse engineering knowledge preset

Status: experimental / future, optional and hidden unless enabled. Source: S10.
Orbit remains a knowledge layer around specialist tools, not a debugger/decompiler.

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
