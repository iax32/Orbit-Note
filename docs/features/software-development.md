# Software development knowledge

## Code editor preferences — 2026-10-23

Settings → Code editor controls code font, 10–26 px text, default line-number
visibility and wrapping for new code workspaces/IDE panes. Font/size changes
preserve the current source, focus, selection and local pane choices. Existing
per-pane wrap/number controls remain. This does not add a new language service
or start project processes. [Use and validation](../tasks/settings-workspace-2026-10-23.md).


## Source browsing quality — 2026-10-19

Read-only source browsers scope late evidence-save/copy feedback to the originating
read request, avoiding success/error labels on a different selected file. Longest
line width is calculated when reading source, rather than splitting the entire
file again for every selection/theme rebuild. Existing lazy listing/line limits,
exact line endings and explicit capture remain unchanged. Attachment code/model
previews also gain versioned refresh, retry and stale-read retirement.
[Evidence and scope](../tasks/file-workflow-quality-2026-10-19.md).

## Saved launch profiles and local web preview — 2026-10-13

Code workspace now provides editable Python/C++/custom run/build profiles with
project-relative working folders, ordered argument arrays and output placeholders.
Configuration saves retain unknown fields, expected hashes and recoverable
checkpoints. Explicit profile runs validate saved context and stop subsequent
steps on failure or cancellation, including pending startup. Basic multi-file C++
commands are supported without claiming build-system discovery or transactions.

An explicit native static web preview serves selected-project assets/modules on
IPv4 loopback with saved-file/external-change reload, visible address and stop
controls. Hidden paths, unsupported source, directory listings, symlink escapes
and cross-site/invalid Host requests are refused. No public hosting, package
installation, auto-start or Vault migration. See [setup and limits](../development/code-workspace-setup.md)
and [ADR-0029](../adr/0029-code-launch-and-loopback-preview.md).

## Editable Code workspace — 2026-10-13 (DEV-01/03/05 local adapters)

The owner's IDE request explicitly extends the earlier read-only source scope for
a selected coding project. Explorer, command palette, Game and Analysis dashboards
open a multi-file project editor with source creation, search, independent undo,
find/replace, line operations, recovered drafts, guarded saves and checkpoint
comparison. HTML/Python/C++ include offline snippets and optional local LSP
completion, diagnostics, hover, definition, symbols and reviewed formatting.
Explicit Python syntax/run/pdb, C++ single-file build/run/configured console debugger
and HTML browser preview share bounded output/input/cancellation. Source files keep
external UTF-8 authority; linked Vault evidence is created only on explicit capture.

See [setup, recovery and limitations](../development/code-workspace-setup.md) and
[ADR-0028](../adr/0028-scoped-code-workspace.md). Read-only browsers described below
remain read-only. This delivery does not complete Git adapters, graphical debug
adapters, build-system discovery or native mobile/web execution. Local language
servers, interpreters and compilers are separately installed tools. No new package
or Vault migration is introduced; current task records actual validation.

## Scoped source search and evidence — 2026-10-13

Game dashboards retain Browse source files; research dashboards add Source &
evidence. Search all files scans the selected folder listing with literal query,
case/whole-word and path filters, progress, cancellation and readable skip/limit
status. Results show path, exact line and excerpt. Opening verifies the full-source
UTF-8 SHA-256 before selecting that line. Changed files open with a warning and no
old-line selection. Code-reference capture in Gameplay also benefits from search.

Search is read-only, sequential and session-local: 500 matching lines and 16 Mi
UTF-16 code units per operation, on the existing 5,000-file/1 MiB preview bounds.
Path filters apply before limits. Cancellation yields within large text files;
unreadable/binary/oversized files and incomplete directory lists are explicit.
Assembly (.asm/.s) and log (.log) files are now browsable; unsupported syntax
highlighting uses plain text. No repository execution, writes or Git inspection.

Save evidence note on dashboard-opened browsers retains exact line text in a safe
Markdown fence, source path/range/language, capture time, excerpt SHA-256 and whole
source SHA-256, plus the original project/dashboard UUID as a resource link.
The captured local folder label/path is descriptive metadata, not a saved access
grant. The note remains useful with no checkout. Snapshot hashes do not certify a
Git commit; existing manual immutable-commit citations remain a separate workflow.
Evidence uses ordinary validated note saves, history and universal Canvas placement.
No new store, token, plugin permission or migration is required.


## Source excerpt capture — 2026-10-10 (DEV-01–03 subset)

The source browser supports whole-line ranges using first/last inputs or a line
number followed by Shift-click. Selected rows have a distinct background. Copy
lines preserves exact source endings; Copy for note produces a language-labelled
Markdown code fence, lengthened when the excerpt contains backticks. With the
line-range viewer focused, Ctrl/Cmd+C copies lines, Ctrl/Cmd+Shift+C copies Markdown,
and Ctrl/Cmd+X copies without removing read-only external source. Ordinary text
field/native line selections retain their own shortcuts. Clipboard errors are
reported without changing source. Unreal shader includes (.usf/.ush/.cginc),
Godot .gdshader and .luau now appear in source scans with syntax language mapping.

Attach code reference in the gameplay workbench offers Capture from source file.
Use excerpt returns repository location, relative file path, exact selected lines
and source text into the existing portable code-reference form. Invalid, empty or
over-100,000-character captures are rejected. A new capture clears earlier commit
and branch fields. The user must enter and verify the full immutable commit;
working-tree bytes are not automatically verified against Git. Saving retains
the existing mechanic stale-source guard, ordinary history and canonical links.
No external source modification, Git execution or new durable schema is added.

Status: planned optional workflow. Source: S10. Orbit records technical knowledge;
it does not need to become an IDE or execute code to make snippets useful.

## Expanded code editing — 2026-10-10 (DEV-01 / EDT-09 subset)

Expand code editor on a Markdown code block opens a syntax-colored draft. It now
offers literal find/replace with previous/next, Unicode case folding, case-sensitive
and whole-word matching, selected-match replacement and replace-all. Replacing a
nonmatching selection first finds a match rather than replacing unrelated text.
Replacement is literal: no regular expression or automatic code interpretation.

Code actions provides go-to-line, exact draft copy, duplicate selected lines,
move lines up/down and supported line-comment toggles. Selection direction and
UTF-16 offsets are preserved; moves retain the original line-ending slots, and
duplication/Enter use the source's first line-ending style. Comment toggles apply
`//` to C-family/Dart/JavaScript/TypeScript/Rust/Go/Swift/Kotlin/PHP,
`#` to Python/Ruby/shell/PowerShell/YAML, and `--` to SQL/Lua. Blank lines remain
unchanged. HTML/XML use `<!-- ... -->` and CSS/SCSS use `/* ... */` around selected
whole lines. These wrappers reject existing/nested delimiters; they do not parse
or rewrite nested comment structures. JSON and unknown grammars do not offer a
comment toggle.

Indentation can use two spaces, four spaces or tabs. Tab/Shift+Tab indent/outdent
selected lines; Enter retains indentation and adds a level after `{`, splitting
an adjacent `{}` pair onto indented lines. This is an explicit editing heuristic,
not language-aware completion. No automatic formatter, code execution or external
repository write is introduced.

Shortcuts: Ctrl/Cmd+F find, Ctrl/Cmd+H replace, Ctrl/Cmd+G go to line, F3/Shift+F3
next/previous match, Ctrl/Cmd+D duplicate lines, Ctrl/Cmd+/ toggle supported line
comments, Alt+Up/Down move lines, Ctrl/Cmd+Z undo and Ctrl/Cmd+Y or Ctrl/Cmd+Shift+Z redo.
Code drafts reuse bounded splice history: text edits and structural operations
are reversible, with original selection direction restored. IME composition is
not mutated by toolbar/keyboard commands; Apply waits for composition to finish.
Read-only drafts retain search/navigation/copy but disable editing actions.

Controls scroll on compact/enlarged layouts. Apply remains one owning-note edit
through normal history/save; a changed source rejects the draft and keeps it
available for explicit copy. Drafts are session-local, not a new durable format.

### Code studio refinement (2026-10-10)

The draft field now shows optional viewport-painted line numbers and a current
logical-line guide. Positions come from rendered caret geometry, including wraps,
app text scaling and vertical scrolling. Clicking the gutter selects that entire
logical line. Search, go-to-line and programmatic selections reveal the caret.
Line ranges and width estimates are cached until source changes, and only visible
line numbers are painted; syntax highlighting retains the existing large-text fallback.

Compare original and draft shows the captured original as a read-only syntax-colored
pane beside the editable draft; compact/enlarged layouts stack them. Each keeps its
own scroll/selection, while the draft's controller and history survive layout changes.
This is a side-by-side comparison, not a computed Git diff or external file view.
The status bar distinguishes Modified and Unchanged against the captured source.

Code actions adds wrapping the literal selected source in parentheses, brackets,
braces, double quotes or backticks; an empty selection creates a pair with the caret
inside. Wrappers do not escape or interpret selected code. Delete lines (Ctrl/Cmd+
Shift+K) removes selected whole lines. Trim trailing whitespace explicitly removes
line-ending spaces/tabs throughout the draft while preserving LF/CRLF/CR. Reset
draft to original restores the captured source and remains undoable. None of these
tools automatically runs on typing/save or mutates original note source before Apply.

## Local source browsing — 2026-10-10

Game dashboards offer Browse source files. Select a local source folder to browse
supported source/text extensions with path filtering, lazy numbered lines, syntax
colors, selected-file text search with case matching/previous/next, exact file copy,
reload and refresh. Narrow/enlarged layouts retain scrollable controls and switchable
file/source panes. This is read-only scoped filesystem access, not a Git adapter or
an external source editor. Nothing is executed, modified or silently imported.

Scans skip generated directories and symbolic links; incomplete scans warn rather
than claim complete coverage. Limits: 5,000 source files, 50,000 entries, depth 15;
UTF-8 previews up to 1 MiB. Large files above 50,000 characters explicitly use plain
text with line numbers/search; unsupported highlight grammars also fall back to text.
Binary/invalid encoding, missing/access-denied/out-of-folder files report errors.
Native folder access is isolated in platform adapters; web shows native-only status.
Folders are selected per session and not retained as portable workspace access grants.
Search matches lines in the selected file, not every file in a repository. Exact
full-file copy retains original line endings; visible per-line selection is local
to a line. Git commits/diffs and automatic revision citations remain future DEV-03/05.

Delivered local DEV-02–04 subset (2026-10-10): the Game dashboard's Gameplay
workbench connects mechanic specifications, code citations, build-specific playtests,
fix tasks and verification evidence. Citations require a full commit and preserve
repository/path/line range plus literal excerpt independently of checkout availability;
optional captured branches are descriptive and may move. A device-local continuation
restores linked open documents and view positions with missing/changed-source guards.
This is manual capture; no repository/IDE adapter or code execution is implemented.
See [gameplay workflow](game-development-and-teams.md#connected-gameplay-workbench--2026-10-10).

| ID | Observable behavior |
|---|---|
| DEV-01 | Code blocks support syntax highlighting, optional filename/line numbers, folding and exact copy; terminal-output blocks preserve text without interpreting control sequences as commands. |
| DEV-02 | Snippets, bugs and optional API endpoint/function types connect source references, debugging journals, schema/database notes and architecture diagrams. |
| DEV-03 | Repository-aware file/commit/diff references distinguish immutable revisions from moving branches; decisions can cite a commit and retain useful context when a repository is unavailable. |
| DEV-04 | Developer work sessions and a technical context view connect the selected project, recent bugs, resources and decisions through ordinary Resume Context. |
| DEV-05 | Later Git repository, GitHub/GitLab and VS Code/IDE adapters use explicit repository scopes and versioned APIs; imports never silently execute code or rewrite a repository. |

Example: record a bug, paste terminal output, cite a file at a revision and attach
the decision that led to a fix. Renaming a local checkout should not erase the
recorded reference. A line number alone is a fragile anchor; retain revision and
path plus an optional excerpt. Acceptance: exact code-copy round-trip, missing
repository fallback, and references to two revisions remaining distinguishable.
Private source excerpts obey the same export, sharing and AI permissions as notes.
