# Focused implementation workflow

1. Read AGENTS and the current task. A user-requested documentation task can
   update future specifications without implementing the current product task.
2. For implementation, identify the task's requirement IDs in the feature spec
   and consult only relevant architecture/ADRs. Use the backlog for sequence and
   prerequisites, not permission to build extra features.
3. Inspect existing code/tests and repository changes. State the small intended
   change. Preserve unrelated work and distinguish implemented behavior from plans.
4. Implement the narrow observable outcome. Avoid unused packages, placeholder
   services, speculative generic frameworks and empty types for future features.
5. Exercise the happy path and relevant failure boundary. Persistent features
   require restart/recovery evidence; clipboard features require native checks;
   schema changes require compatibility fixtures. See the definition of done.
6. Run the task's checks, record actual outcomes and explain environmental blocks.
   Never mark planned features implemented because their docs or interfaces exist.
7. Update task evidence; update behavior docs only for changed behavior and ADRs
   only for architectural decisions. Suggest one next task and stop.

## Context and source ownership

Current task owns authorized implementation scope. Feature specs own observable
behavior and stable requirement IDs. The single backlog owns release class and
sequencing. Architecture/accepted ADRs own technical contracts. Source extraction
records provenance, not a second specification. Examples and proposed defaults
are not selected production dependencies. Resolve material conflicts explicitly.

Use targeted lookup, for example `rg "CAN-05" docs`, rather than reading every
document. Read a full relevant spec when implementing its behavior; small context
does not mean skipping acceptance criteria or failure cases.

## Review questions

- Does this operation change an object, a placement, a view, or private UI state?
- Does identity survive rename, another view, export and restart?
- Can a failed save or undo lose a later user edit? Are durable bytes authoritative?
- Can unknown data survive a new/old version or absent plugin?
- Does a clipboard/drop action create owned bytes or an external reference?
- Can layout/input recovery still be reached by keyboard and on a smaller screen?
- Are AI, sync, plugin and external connector permissions kept distinct?

Use session authorization for routine reversible work. Ask only when an unresolved
choice materially affects scope, data safety or architecture; document proposals
instead of inventing user decisions. Avoid changing the stack to mask a local
toolchain failure.
