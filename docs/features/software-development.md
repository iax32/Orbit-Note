# Software development knowledge

Status: planned optional workflow. Source: S10. Orbit records technical knowledge;
it does not need to become an IDE or execute code to make snippets useful.

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
