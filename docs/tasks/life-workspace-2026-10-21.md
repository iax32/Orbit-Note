# Connected Life Workspace

Status: validated; implementation, regression checks and local release builds complete.
User authorized the complete twelve-part Life Workspace
proposal: Home, goals, habits/routines, fitness, journaling, experiments, check-ins,
life administration, learning, templates, live Canvas planning and reviews.

## Plan and acceptance

1. Reuse ordinary notes/tasks/events/Canvas identity with versioned optional Life
   metadata. Add validated, guarded repository commands, civil-date log identity,
   recoverable edits and explicit handling of unsupported/unknown data.
2. Ship an accessible Life hub and Home bridge: real summaries, configuration,
   quick capture and canonical navigation. Implement goal/milestone progress,
   flexible habit/routine logging, custom exercises/workouts/programs and resumable
   sessions with set logging/rest timers/history/comparisons.
3. Add dated journals, personal experiments, check-ins/trends, skills/practice,
   household/meal/maintenance/travel/people/event workflows and grounded period
   reviews. Scheduling uses the existing calendar; linked actions are real tasks.
4. Add content packs, setup fields and personal note/Canvas templates. Life boards
   contain canonical live cards, retaining normal removal, references and undo.
5. Cover validation, stale/save-failure/duplicate/restart boundaries, date/unit
   behavior and responsive UI. Run format/strict check, analysis, focused and full
   tests, then configured local Windows/server and standard web builds.

Relevant existing requirements: CTX-01/02/06/12, TASK-03–09, EVT-01–03,
EDT-09, CAP-07, CAN-02/03/14–17, HIST and portable storage authority.
The approved Life behavior is specified in `docs/features/life-workspace.md`.
Preserve all earlier uncommitted changes. No personal Vaults, desktop control,
cloud operations, publishing, shutdown, automatic medical advice or AI execution.

## Evidence

### Delivered workflows

| Scope | User-facing implementation |
| --- | --- |
| LIFE-01 | Home/sidebar/command-palette entry, configurable Life Home sections, actual priorities/calendar/habits/routines/goals, capture, session resume and weekly records. |
| LIFE-02 | Action or measured goals, dates/reasons/constraints, canonical tasks and milestones, evidence and recoverable state changes. A target without a recorded measurement has no invented progress. |
| LIFE-03 | Daily/weekly/weekday quantity habits, minimum/break fields, done/skip/rest dates, neutral heatmap and snapshot-based dated routines. |
| LIFE-04 | Custom exercises/instructions/equipment/substitutions; workouts/programs; idempotent calendar rotation; resumable session sets, units, optional effort, add/remove/duplicate/complete, rest deadlines, previous results, charts and selectable comparisons. |
| LIFE-05 | Dated free writing and daily/gratitude/decision/achievement/travel/nature starters, plus period reviews. |
| LIFE-06 | Experiment baseline/change/period/measure/outcome and linked dated observations. |
| LIFE-07 | Optional sleep/mood/energy/stress/outdoor/custom records; clearable values, unit-separated observed trends, gap-aware charts and accessible tables. |
| LIFE-08 | Meal/recipe/grocery, home maintenance, renewals/documents/appointments, travel/packing, inventory, people/follow-up and event starters with checklists and real tasks/calendar. |
| LIFE-09 | Parent skill roadmap without cycles, practice minutes, course/resource/portfolio links and self-assessment, bridge to existing Courses & study. |
| LIFE-10 | 31 individual starters and five connected setup packs; partial-result/retry UX; personal note/Canvas templates; editor Save as Template; personal note templates in shared picker/insertion. |
| LIFE-11 | Selected canonical Life cards on the existing Canvas, current progress summaries, card-to-Life controls and missing-source recovery through existing references. |
| LIFE-12 | Week/month/year evidence snapshots from actual dated records/completed tasks/upcoming commitments, preserved authored conclusions, linked next actions. |

Main code: `domain/life_workspace.dart`, `domain/life_templates.dart`,
`app/workspace_life.dart`, `app/workspace_life_packs.dart`,
`features/workspace/life_workspace.dart` and `life_pack_dialog.dart`, with small
Home/shell/graph/Canvas/template-picker bridges. Existing planning commands gained
a Vault-generation guard. Ordinary Markdown/property envelopes retain authority;
no package, account, new database layer, migration or architecture change.

### Checks completed before final build

- **85 new regressions**, including malformed/future metadata, civil dates/DST,
  unlike units, 10,000 dated records, stale edits, simulated failed writes,
  duplicate clicks, session/routine restart, partial pack retry, deleted sources,
  skill cycles, canonical graph/Canvas links and native portable-file rebuild.
- **Focused matrix: 102 passed**, including existing template and focus-session
  checks. UI exercises all areas/setup forms and populated details at 380 px and
  200% text, failed-save draft retention, optional measurement clearing and
  personal template discovery. `.local/life-focused.log`.
- Formatting and strict check: 711 Dart files, clean. Analysis: no issues.
  `.local/life-format.log`, `life-format-strict.log`, `life-analyze.log`.
- Four headless synthetic previews rendered/inspected with Segoe UI and Material
  fonts: Life Home, goal, workout and phone workout. No personal Vault or desktop
  control. `.local/life-visuals/`, `.local/life-preview.log`.
- `git diff --check` clean; earlier unrelated uncommitted work retained.

The initial full run found one Home focus-card discoverability regression
(`.local/life-full-initial.log`, 2,766 passed/2 existing skips/1 failure). Moving
the Life bridge below existing Home content fixed it; affected focus tests pass.
Additional checks fixed narrow dropdown overflow, retained list scroll on mobile
detail navigation, optional-value clearing and blank effort becoming zero.

Final full suite: **2,769 passed, 2 existing skips**, 4m48s.
`.local/life-full.log`; existing skips require Windows link privilege and manual
Google consent. No new skip or hidden failure was introduced.

Configured Windows/server and standard web builds passed. A verified current-source
snapshot produced a separate runnable
Windows folder while the user's older EXE remains open. No global Flutter setting
or running app is changed. No ZIP, publishing, shutdown, account operation or AI
health recommendation is part of this update.

Snapshot preparation resolved dependencies offline. Windows' restricted symlink
creation required reusing the current checkout's plugin targets through normal
directory junctions. No Developer Mode/security setting, SDK source or global
Flutter configuration was changed. Build input hashes are recorded in
`.local/life-source-snapshot.json` (474 source/asset/tool/runner files).

### Release artifacts — verified 2026-10-21 04:01 CEST

- Runnable Windows: `build/releases/Life Workspace/orbit_note.exe`. Retain its
  sibling DLLs and `data` folder. It is a normal runnable folder, not a ZIP.
- Registered Google desktop configuration retained. Windows build: **119.6s**;
  standalone server built and its launcher/README packaged alongside the app.
- Standard JavaScript web build: **83.4s**. Existing Google SDK Wasm dry-run and
  Cupertino font warnings remain; this is not a Wasm acceptance claim.
- Fresh payloads differ from the previous app/web builds, are newer than inputs,
  and include required runtime files. Custom font payload hashes match source.
  `.local/life-workspace-release-verification.json`.

| Payload | Bytes | SHA-256 |
| --- | ---: | --- |
| Windows `data/app.so` | 25,117,584 | `A60EF908A220BFF9BCFC40E744618EF9CD82307C841C2A03185D473F354D340D` |
| Web `main.dart.js` | 10,741,948 | `1105A31F83385D6974E262A267D38D83D97FB785F84AD0CBAC56F853A43043E6` |
| Standalone server | 7,595,520 | `9F7BF4D4B38342DE8149F0B85AD2F0D3A94E60F45FEEF9352D63F8DF018840EC` |

The older running app and its release folder were left intact. Save/close that
window before starting the new EXE. No app/server was launched for testing, and
no private Vault/account was accessed. GitHub/APK publication is unchanged.

Suggested next task: local daily reminders and mobile quick logging; stop before
implementing it.

### Limits

Plans and packs are editable user-owned content, not prescribed fitness/nutrition
advice. Sensors, external calendars and automated coaching are not added. Reviews
are dated evidence snapshots, preserving their authored conclusions on reopen.
Normal multiplayer/Drive capabilities and their existing limits remain unchanged.
Phone-sized headless layouts do not establish physical Android/iOS acceptance.
Personal templates retain canonical source links rather than duplicating every
linked object. No claim that all other Orbit roadmap requirements are complete.
