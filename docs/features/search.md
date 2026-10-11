# Precise global search

Global Search shows object kind/project context, match kind and a source snippet.
Results can focus a Note paragraph/heading, Canvas element or LaTeX source block.
The Command Palette uses the same body-result projection; Quick Switcher retains
cheap name/context/fuzzy opening. Existing loading/failure/retry states remain.

Result scope is bounded to 100 locations and existing index candidate limits.
Filters refine these results. Vault-wide PDF page-text search is not yet indexed;
active-reader PDF search and page/annotation references remain available.

See [architecture](../architecture/search.md) and
[validation/limits](../tasks/architecture-composition-2026-09-30.md).

## Search workspace — 2026-10-01

Save a query, filters and sorting under a name (up to 24); restore it from the
empty search page or saved-search menu. Manage supports removal and Undo without
overwriting a later recipe with the same name. Recent history keeps ten queries
you opened or saved, and can be cleared. Recipes/history are device-local settings,
not exported knowledge or copied result snapshots.

Type/project filters are joined by folder, tag, match kind and completed-task
exclusion under More filters. Relevance, recently updated and title ordering
refine the same bounded first-100 result set, with an explicit limit notice.
Keyboard arrows select while the query has focus; Enter opens the selected
precise location. Buttons retain normal keyboard behavior. Escape closes the
side preview or clears the query.

Preview exposes the matched excerpt, source context and update date before opening.
Wide panes use an optional side panel; narrower panes use a dialog. Generated
block anchors are hidden from reading excerpts but stay in source and navigation.
The original literal excerpt remains available for Source/LaTeX matches.

See [delivery and validation gaps](../tasks/search-workspace-2026-10-01.md).
