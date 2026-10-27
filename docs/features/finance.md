# Finance workspace — local ledger

Owner-approved scope, 2026-10-26: a substantial manual finance workspace using
existing notes, references, durable commands, history, exports and Vault sync.

| ID | Delivered behavior |
| --- | --- |
| FIN-01 | Named accounts, exact starting balances, negative balances, archive, ledger/cleared balances |
| FIN-02 | Income/expense/transfer ledger, date/category/payee/memo, cleared status, receipt/source links, search/account/month filters, recoverable Trash |
| FIN-03 | Monthly category budgets, spent/remaining/over-budget indicators, duplicate-category guard |
| FIN-04 | Weekly/monthly/yearly bill schedules, overdue/upcoming occurrences, explicit idempotent occurrence recording |
| FIN-05 | Manual savings targets, tracked progress and optional target date; never moves account funds |
| FIN-06 | Currency-separated monthly cash flow, category spending, six-month comparison, linked Markdown review notes |
| FIN-07 | CSV file/paste preview, schema validation, repeat-import deduplication, bounded partial-failure recovery, CSV file/clipboard export |
| FIN-08 | Ordinary portable finance notes, canonical links/graph/Canvas, existing history and personal/shared Vault synchronization |

Open Finance using the wallet button in the sidebar or Life header, or search
“Finance” in the command palette. Start with Accounts, then Transactions. Empty
Vaults receive no synthetic financial data. Forms keep drafts on validation/save
failure; model ownership is checked across Vault switches. Small/short screens
and enlarged text scroll all actions into reach.

## Authority and arithmetic

Each record is an ordinary `orbit.note` in `Notes/Finance`, with a version-1
`properties.finance` map. Body is the user's memo; metadata is the ledger
authority. Additive unknown fields survive edits. Unsupported versions are
preserved and reported, not silently included in totals. No database migration.

Amounts use exact integer minor units, never floating-point storage. Supported
currencies: EUR/USD/GBP/CHF/CAD/AUD (two decimal places), JPY (zero). Plain decimal
input accepts comma or point; grouping separators, excessive precision, nonfinite
values and amounts above 9,000,000,000,000 minor units are refused. Aggregate
arithmetic is bounded to 9,000,000,000,000,000 minor units for exact web/native
behavior. No exchange-rate lookup or implicit conversion. Reports stay separated
by currency. Account currency cannot change once transactions reference it.

A transfer is one transaction referencing two same-currency accounts. It debits
one and credits the other; cash flow/budgets exclude it. Ledger balances include
nontrashed transactions through today, including pending ones. Cleared balances
include explicitly cleared transactions and assume the starting balance cleared.
Monthly cash flow/budgets include all recorded dates within the selected month,
including future dates. Archive is organizational, not a transaction reversal.
Trashing/restoring a transaction removes/restores its effect. Missing account
references produce visible issues while keeping transaction cash-flow evidence.

## Bills and savings

Bill first due date is the recurrence anchor. Monthly/yearly dates clamp to the
target month's end without losing the original anchor. Weekly dates use civil
calendar arithmetic. Marking an occurrence creates a normal transaction with a
UUID v5 derived from Vault/bill/date; retries return that note. A payment in Trash
must be restored, not recreated. Concurrent device creations share one identity
and retain normal sync conflict recovery; this does not invent a bank charge.
Recorded bill start/frequency cannot change: archive and create a new schedule.
Future amount/category changes do not rewrite past payments. Projection is bounded
to 16,000 occurrences; the UI shows at most three unpaid occurrences per bill in
the next 31 days (including overdue ones), not automatic payment execution.

Savings goals track a manual earmarked amount/target/date. They are descriptive
and do not transfer, reserve or double-count account funds.

## CSV and review

Required headers: `date,type,amount`; optional `currency,accountId,toAccountId,
category,payee,cleared,memo`. Dates are YYYY-MM-DD, type is income/expense/transfer,
amount is positive. A selected account supplies omitted currency/accountId. This
is Orbit's explicit schema, not arbitrary bank-column detection. Quoted commas,
escaped quotes and multiline fields work. Import is limited to 500 rows / 1 MB.
Preview validates all rows before any ledger write and is rechecked against the
reviewed plan at commit, so a changed account/currency cannot silently alter it.

Normalized row content plus occurrence ordinal determines an import UUID. Repeating
the same rows skips previously imported IDs, including Trash; identical purchases
within a single file keep their occurrence count. This is exact-row identity, not
heuristic detection of manually entered bank transactions. A shortened/edited
statement or altered memo may represent different rows; review the preview.
Partial storage failures report the saved count; retry the same CSV to resume.
Imported notes can be individually edited/trashed/restored through existing history.

CSV export selects the month/currency, limits 10,000 rows / 8 MB, and escapes
formula-like text with an apostrophe for spreadsheet safety. That apostrophe is
part of exported text; CSV is not the lossless backup format. Ordinary Markdown
notes/JSON preserve the original. Review-note reports are explicit snapshots with
live transaction-ID links; edit records in Finance and regenerate the report when
needed. Existing note HTML/Word/PDF export can publish the review note.

## Boundaries

No bank connection, automatic charge, tax filing, investment pricing, financial
advice, exchange conversion, or new server/account dependency. Knowledge remains
offline. Existing opted-in Vault sync transports records; shared-Vault participants
can see financial notes like other shared knowledge. Real-bank import formats and
physical device acceptance are not implied by synthetic/local tests.
