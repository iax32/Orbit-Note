# ADR-0012 — Rebuildable FTS5 substring search

Status: accepted, 2026-09-10. Extends ADR-0003 and ADR-0009.

## Context and decision

Orbit's native search used LIKE scans. Preserve literal substring search, short
queries, exact-title priority, object UUIDs and the existing shared repository
search path. Introduce a SQLite FTS5 trigram external-content index over title and
search_text, with insert/update/delete triggers in the same database transaction.
Queries of at least three Unicode code points use a quoted literal MATCH expression;
shorter queries retain escaped LIKE. BM25 breaks ties after title priority.
No raw user input becomes SQL or an operator expression.

Schema 3 adds the derived virtual table and triggers, then rebuilds from objects.
Version 1 first gains the version-2 search_text column. Repository initialization
continues rebuilding object rows from authoritative files. Missing/corrupt indexes
are quarantined and rebuilt through the existing path. No Markdown, object JSON,
Canvas format or workspace identity migration is required. Browser memory search
retains its existing literal semantics.

## Alternatives and consequences

A word tokenizer would change mid-word matching; a full scan would retain growing
query cost. Trigrams use more derived disk space and have a three-character minimum.
No boolean-query language, stemming or cross-process Vault ownership is added.
The installed SQLite build must provide FTS5 and trigram support. A damaged index
can be reconstructed; it is never used to recover user content.

Validation: version-2 fixture migration, quoted/punctuation queries, deletion and
reopen; existing ranking, metadata/Canvas search and corrupt/missing-index recovery
regressions. Existing unsaved overlay continues in WorkspaceController.

Reference: [SQLite FTS5 documentation](https://www.sqlite.org/fts5.html).
