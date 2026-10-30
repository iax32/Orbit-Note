import 'life_workspace.dart';
import 'finance_workspace.dart';
import 'research_dossier_workspace.dart';
import 'object_tag_dialog.dart';
import 'course_hub.dart';
import 'code_ide_workspace.dart';
import '../notes/editor_draft_review.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import '../../domain/orbit_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../app/session_state.dart';
import 'workspace_views.dart';
import 'focus_timer.dart';
import '../notes/latex/latex_template_dialog.dart';
import '../notes/note_template_dialog.dart';
import '../notes/document_history_dialog.dart';
import 'recovery_dialog.dart';
import '../pdf/library/pdf_library_view.dart';

Future<void> showCommandPalette(BuildContext context, WorkspaceController c) =>
    showOrbitDialog<void>(
      context: context,
      builder: (context) => CommandPalette(controller: c),
    );

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  String query = '';
  String _typeFilter = 'all';
  static const _types = {
    'all': 'Everything',
    'orbit.note': 'Notes',
    'orbit.canvas': 'Canvases',
    'orbit.task': 'Tasks',
    'orbit.file': 'Files',
    'orbit.project': 'Projects',
    'orbit.view': 'Views',
    'orbit.event': 'Events',
  };
  List<UniversalObject> results = [];
  List<OrbitSearchResult> _locations = [];
  Timer? _debounce;
  int _generation = 0;
  int _selected = 0;
  final _rowKeys = <GlobalKey>[];
  List<({String title, IconData icon, String group, VoidCallback run})>
  _entries = [];
  late final _searchFocus = FocusNode(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isAltPressed ||
          HardwareKeyboard.instance.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (event is KeyDownEvent &&
            _entries.isNotEmpty &&
            _selected >= 0 &&
            _selected < _entries.length) {
          _run(_entries[_selected].run);
        }
        return KeyEventResult.handled;
      }
      final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
          ? 1
          : event.logicalKey == LogicalKeyboardKey.arrowUp
          ? -1
          : 0;
      if (direction == 0 || _entries.isEmpty) return KeyEventResult.ignored;
      setState(
        () => _selected = (_selected + direction).clamp(0, _entries.length - 1),
      );
      _revealSelected();
      return KeyEventResult.handled;
    },
  );

  void _revealSelected() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || _entries.isEmpty || _selected >= _rowKeys.length) return;
    final row = _rowKeys[_selected].currentContext;
    if (row != null) {
      Scrollable.ensureVisible(row, alignment: 0, duration: Duration.zero);
    }
  });

  void _run(VoidCallback action) {
    if (Navigator.canPop(context)) Navigator.pop(context);
    action();
  }

  @override
  void initState() {
    super.initState();
    results = _recentObjects();
  }

  List<UniversalObject> _recentObjects() {
    final c = widget.controller;
    final seen = <String>{};
    return [
          ...c.session.recent.map(c.find).whereType<UniversalObject>(),
          ...c.activeObjects,
        ]
        .where((o) => !o.isDeleted && seen.add(o.id) && _matchesType(o))
        .take(5)
        .toList();
  }

  bool _matchesType(UniversalObject object) =>
      _typeFilter == 'all' || object.typeId == _typeFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search(String value) {
    value = value.trim();
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _selected = 0;
      query = value;
      results = value.isEmpty ? _recentObjects() : [];
    });
    _revealSelected();
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final found = await widget.controller.searchLocations(value.trim());
        if (mounted && generation == _generation) {
          setState(() {
            _locations = found
                .where((r) => _matchesType(r.object))
                .take(12)
                .toList();
            results = {
              for (final r in _locations) r.object.id: r.object,
            }.values.toList();
            _selected = 0;
          });
          _revealSelected();
        }
      } catch (_) {
        /* Navigation commands stay available if the index is unavailable. */
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    final recentNote = c.session.recent
        .map(c.find)
        .whereType<UniversalObject>()
        .where((o) => !o.isDeleted && o.typeId == 'orbit.note')
        .firstOrNull;
    final recentPdf = c.session.recent
        .map(c.find)
        .whereType<UniversalObject>()
        .where(
          (o) =>
              !o.isDeleted &&
              o.typeId == 'orbit.file' &&
              o.title.toLowerCase().endsWith('.pdf'),
        )
        .firstOrNull;
    final commands = <({String title, IconData icon, VoidCallback run})>[
      (
        title:
            'Open research dossiers · functions, memory layouts, offsets, glossary and investigations',
        icon: Icons.manage_search_outlined,
        run: () => showResearchDossier(context, c),
      ),
      (
        title:
            'Open Finance · expenses, income, accounts, budgets, bills and savings',
        icon: Icons.account_balance_wallet_outlined,
        run: () => showFinanceWorkspace(context, c),
      ),
      (
        title: 'Open Life workspace · goals, habits, fitness and journals',
        icon: Icons.spa_outlined,
        run: () => showLifeWorkspace(context, c),
      ),
      (
        title: 'Open code workspace · HTML / Python / C++',
        icon: Icons.developer_mode,
        run: () => showCodeIde(context, controller: c),
      ),
      (
        title: 'Open courses & study progress',
        icon: Icons.school_outlined,
        run: () => showCourseHub(context, c),
      ),
      if (c.editorDraftConflicts.isNotEmpty)
        (
          title: 'Review conflicting editor drafts',
          icon: Icons.warning_amber_outlined,
          run: () => showEditorDraftReview(context, c),
        ),
      if (recentNote != null)
        (
          title:
              'Continue writing: ${recentNote.title.isEmpty ? 'Untitled note' : recentNote.title}',
          icon: Icons.edit_note_rounded,
          run: () => c.openObject(recentNote.id),
        ),
      if (recentPdf != null)
        (
          title:
              'Continue reading: ${recentPdf.title.isEmpty ? 'PDF Document' : recentPdf.title}',
          icon: Icons.picture_as_pdf_outlined,
          run: () => c.openObject(recentPdf.id),
        ),
      if (c.activeWorkSession != null) ...[
        if (c.activeWorkSession!.isPaused)
          (
            title: 'Resume focus session: ${c.activeWorkSession!.title}',
            icon: Icons.play_arrow_rounded,
            run: () => c.resumeWorkSession(),
          )
        else
          (
            title: 'Pause focus session: ${c.activeWorkSession!.title}',
            icon: Icons.pause_rounded,
            run: () => c.pauseWorkSession(),
          ),
        (
          title: 'End focus session: ${c.activeWorkSession!.title}',
          icon: Icons.stop_rounded,
          run: () => c.endWorkSession(),
        ),
      ] else
        (
          title: 'Start focus session',
          icon: Icons.timer_outlined,
          run: () => c.startWorkSession(),
        ),
      if (c.activeTagFilter != null)
        (
          title: 'Clear active tag filter (#${c.activeTagFilter})',
          icon: Icons.label_off_outlined,
          run: () => c.clearTagFilter(),
        ),
      if (c.allTags.isNotEmpty)
        (
          title: 'Filter explorer by tag…',
          icon: Icons.label_outline_rounded,
          run: () async {
            final tag = await showOrbitDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: const Text('Filter by Tag'),
                children: [
                  for (final t in c.allTags)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, t),
                      child: Text('#$t (${c.countForTag(t)})'),
                    ),
                ],
              ),
            );
            if (tag != null) {
              c.activeTagFilter = tag;
            }
          },
        ),
      if (c.session.activeId != null) ...[
        (
          title: 'Add tag to current document…',
          icon: Icons.new_label_outlined,
          run: () async {
            await showObjectTagDialog(context, c);
          },
        ),
        (
          title: 'Duplicate current document',
          icon: Icons.copy_rounded,
          run: () => c.duplicateObject(c.session.activeId!),
        ),
        if (c.find(c.session.activeId!)?.typeId == 'orbit.note')
          (
            title: 'Copy entire document as Markdown',
            icon: Icons.description_outlined,
            run: () async {
              final active = c.find(c.session.activeId!);
              if (active != null) {
                await Clipboard.setData(ClipboardData(text: active.body));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied entire note to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
      ],
      if (c.repository.supportsFolders) ...[
        (
          title: 'Collapse all folders in explorer',
          icon: Icons.unfold_less_rounded,
          run: () => c.collapseAllFolders(),
        ),
        (
          title: 'Expand all folders in explorer',
          icon: Icons.unfold_more_rounded,
          run: () => c.expandAllFolders(),
        ),
      ],
      if (c.session.closedTabs.isNotEmpty)
        (
          title: 'Reopen closed tab',
          icon: Icons.restore_page_outlined,
          run: () => c.reopenClosedTab(),
        ),
      if (c.canNavigateBack)
        (
          title: 'Go back in navigation history',
          icon: Icons.arrow_back,
          run: () => c.navigateBack(),
        ),
      if (c.canNavigateForward)
        (
          title: 'Go forward in navigation history',
          icon: Icons.arrow_forward,
          run: () => c.navigateForward(),
        ),
      (title: 'New note', icon: Icons.add, run: () => c.create('orbit.note')),
      (
        title: 'New note from template...',
        icon: Icons.auto_stories_outlined,
        run: () async {
          final template = await NoteTemplateDialog.show(context);
          if (template != null) {
            await c.create(
              'orbit.note',
              title: template.defaultTitle,
              body: template.body,
              properties: {if (template.tags.isNotEmpty) 'tags': template.tags},
            );
          }
        },
      ),
      (
        title: 'Insert template into active note...',
        icon: Icons.dashboard_customize_outlined,
        run: () async {
          final activeId = c.session.activeId;
          final activeDoc = activeId != null ? c.find(activeId) : null;
          if (activeDoc != null && activeDoc.typeId == 'orbit.note') {
            final template = await NoteTemplateDialog.show(
              context,
              insertMode: true,
            );
            if (template != null) {
              final newBody = activeDoc.body.isEmpty
                  ? template.body
                  : '${activeDoc.body}\n\n${template.body}';
              c.edit(activeDoc.id, body: newBody);
            }
          }
        },
      ),
      (
        title: 'New LaTeX document',
        icon: Icons.functions_rounded,
        run: () async {
          final template = await LatexTemplateDialog.show(context);
          if (template != null) {
            await c.create(
              'orbit.note',
              title: template.name,
              body: template.body,
              properties: {'documentFormat': 'latex'},
            );
          }
        },
      ),
      (
        title: 'New canvas',
        icon: Icons.dashboard_outlined,
        run: () => c.create('orbit.canvas'),
      ),
      (
        title: 'New task',
        icon: Icons.check_circle_outline,
        run: () => c.create('orbit.task'),
      ),
      (
        title: 'New event',
        icon: Icons.event_outlined,
        run: () => c.create('orbit.event'),
      ),
      (
        title: 'New function note',
        icon: Icons.code_outlined,
        run: () => c.createFunctionDoc(folder: 'Notes', name: 'sub_1400'),
      ),
      (
        title: 'New finding note',
        icon: Icons.check_circle_outline,
        run: () => c.createFindingDoc(folder: 'Notes', title: 'New Finding'),
      ),
      (
        title: 'New hypothesis note',
        icon: Icons.lightbulb_outline,
        run: () =>
            c.createHypothesisDoc(folder: 'Notes', title: 'New Hypothesis'),
      ),
      (
        title: 'New analysis session',
        icon: Icons.terminal_outlined,
        run: () => c.createAnalysisSessionDoc(
          folder: 'Notes',
          title: 'Analysis Session',
        ),
      ),
      (
        title: 'New structure note',
        icon: Icons.table_rows_outlined,
        run: () => c.createStructureDoc(folder: 'Notes', name: 'NewStruct'),
      ),
      (
        title: 'New indicator (IOC)',
        icon: Icons.fingerprint,
        run: () => c.createIocDoc(folder: 'Notes', value: '198.51.100.1'),
      ),
      (
        title: 'Go to Home',
        icon: Icons.home_outlined,
        run: () => c.navigate(OrbitDestination.home),
      ),
      (
        title: 'Go to Calendar',
        icon: Icons.calendar_month_outlined,
        run: () => c.navigate(OrbitDestination.calendar),
      ),
      (
        title: 'Go to Knowledge Graph',
        icon: Icons.hub_outlined,
        run: () => c.navigate(OrbitDestination.graph),
      ),
      (
        title: 'Search knowledge',
        icon: Icons.search,
        run: () => c.navigate(OrbitDestination.search),
      ),
      (
        title: 'Open Settings',
        icon: Icons.settings_outlined,
        run: () => c.navigate(OrbitDestination.settings),
      ),
      (
        title: 'Open Bookshelf & Reading Rooms',
        icon: Icons.local_library_outlined,
        run: () => showOrbitDialog<void>(
          context: context,
          builder: (_) => Dialog.fullscreen(
            child: OrbitLibraryView(
              controller: c,
              onOpenBook: (bookId, {roomId}) {
                Navigator.pop(context);
                c.openObject(bookId);
              },
            ),
          ),
        ),
      ),
      (
        title: 'Open Focus & Pomodoro Timer',
        icon: Icons.timer_outlined,
        run: () => showFocusTimerDialog(context, globalFocusTimer),
      ),
      (
        title: 'Start Focus session',
        icon: Icons.play_arrow_outlined,
        run: () => globalFocusTimer.start(),
      ),
      (
        title: 'Toggle explorer',
        icon: Icons.view_sidebar_outlined,
        run: () => c.updateSession((s) => s.sidebarVisible = !s.sidebarVisible),
      ),
      (
        title: 'Toggle inspector',
        icon: Icons.info_outline,
        run: () =>
            c.updateSession((s) => s.inspectorVisible = !s.inspectorVisible),
      ),
      (title: 'Reset layout', icon: Icons.restart_alt, run: c.resetLayout),
      (
        title: c.session.focusMode ? 'Exit Focus' : 'Enter Focus',
        icon: Icons.fullscreen,
        run: () => c.updateSession((s) => s.focusMode = !s.focusMode),
      ),
      (
        title: "Today's note",
        icon: Icons.today_outlined,
        run: () => c.openTodayNote(),
      ),
      if (c.session.closedTabs.isNotEmpty || c.lastClosed != null)
        (
          title: 'Reopen closed tab',
          icon: Icons.tab,
          run: () => c.reopenClosedTab(),
        ),
      (
        title: 'Save all changes',
        icon: Icons.save_outlined,
        run: () => c.flushAll(),
      ),
      (title: 'Reload from files', icon: Icons.refresh, run: () => c.refresh()),
      if (!c.repository.readOnly)
        (
          title: 'New Gantt timeline',
          icon: Icons.view_timeline_outlined,
          run: () => c.create(
            'orbit.view',
            title: 'Project Gantt',
            properties: {
              'viewType': 'gantt',
              'ganttVersion': 1,
              'ganttDays': 28,
            },
          ),
        ),
      if (!c.repository.readOnly)
        (
          title: 'New research workspace',
          icon: Icons.collections_bookmark_outlined,
          run: () =>
              c.createResearchCollection(title: 'Research', folder: 'Notes'),
        ),
      (
        title: 'Review recovery files',
        icon: Icons.restore_page_outlined,
        run: () => showWorkspaceRecoveryDialog(
          context: context,
          repository: c.repository,
        ),
      ),
      if (c.session.activeId != null &&
          c.find(c.session.activeId!)?.typeId == 'orbit.note')
        (
          title: 'Document revision history',
          icon: Icons.history_rounded,
          run: () {
            final note = c.find(c.session.activeId!)!;
            showDocumentHistoryDialog(
              context: context,
              controller: c,
              objectId: note.id,
              currentTitle: note.title,
              currentBody: note.body,
            );
          },
        ),
    ];
    final filtered = commands
        .where(
          (v) =>
              _typeFilter == 'all' &&
              v.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    String commandGroup(String title) {
      if (title.startsWith('Continue ')) return 'Continue';
      if (title.startsWith('New ')) return 'Create';
      if (title.startsWith('Go to ') ||
          title.startsWith('Open ') ||
          title == 'Search knowledge') {
        return 'Navigate';
      }
      if (title.startsWith('Document revision')) return 'Knowledge';
      return 'Workspace';
    }

    _entries = [
      if (query.isEmpty)
        for (final object in results)
          (
            title: object.title.isEmpty ? 'Untitled' : object.title,
            icon: objectIcon(object.typeId),
            group: 'Recent',
            run: () => c.openObject(object.id),
          ),
      for (final group
          in query.isEmpty
              ? ['Continue', 'Create', 'Navigate', 'Workspace']
              : ['Commands'])
        for (final command in filtered.where(
          (command) => query.isNotEmpty || commandGroup(command.title) == group,
        ))
          (
            title: command.title,
            icon: command.icon,
            group: group,
            run: command.run,
          ),
      if (query.isNotEmpty)
        for (final object in results)
          (
            title: object.title.isEmpty ? 'Untitled' : object.title,
            icon: objectIcon(object.typeId),
            group: 'Knowledge',
            run: () {
              final result = _locations
                  .where((r) => r.object.id == object.id)
                  .firstOrNull;
              if (result != null) {
                c.openSearchResult(result);
              } else {
                c.openObject(object.id);
              }
            },
          ),
    ];
    if (_selected >= _entries.length) _selected = 0;
    while (_rowKeys.length < _entries.length) {
      _rowKeys.add(GlobalKey());
    }
    final colors = OrbitColors.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OrbitSearchField(
                      autofocus: true,
                      focusNode: _searchFocus,
                      hint: 'Search commands and knowledge…',
                      onChanged: _search,
                      onSubmitted: (_) {
                        if (_entries.isNotEmpty) _run(_entries[_selected].run);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close palette',
                    onPressed: Navigator.canPop(context)
                        ? () => Navigator.pop(context)
                        : null,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          popUpAnimationStyle: OrbitMotionScope.popupStyle(
                            context,
                          ),
                          tooltip: 'Filter palette by type',
                          initialValue: _typeFilter,
                          onSelected: (value) {
                            _typeFilter = value;
                            _search(query);
                            _searchFocus.requestFocus();
                          },
                          itemBuilder: (_) => [
                            for (final entry in _types.entries)
                              PopupMenuItem(
                                value: entry.key,
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.key == _typeFilter
                                          ? Icons.check
                                          : null,
                                      size: OrbitSize.iconInline,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(entry.value)),
                                  ],
                                ),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: OrbitSize.iconInline,
                                  color: colors.subtle,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _types[_typeFilter]!,
                                    style: OrbitTypography.metadata(context),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.expand_more,
                                  size: OrbitSize.iconSmall,
                                  color: colors.subtle,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < _entries.length; i++) ...[
                        if (i == 0 ||
                            _entries[i].group != _entries[i - 1].group)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                            child: Text(
                              _entries[i].group,
                              style: OrbitTypography.caption(context),
                            ),
                          ),
                        ListTile(
                          key: _rowKeys[i],
                          selected: i == _selected,
                          dense: true,
                          leading: Icon(_entries[i].icon, size: OrbitSize.icon),
                          title: Text(_entries[i].title),
                          subtitle: _entries[i].title == 'New note'
                              ? Text(
                                  'Ctrl+N',
                                  style: OrbitTypography.caption(context),
                                )
                              : null,
                          trailing: i == _selected
                              ? Icon(
                                  Icons.keyboard_return,
                                  size: OrbitSize.iconInline,
                                  color: colors.subtle,
                                )
                              : null,
                          onTap: () => _run(_entries[i].run),
                        ),
                      ],
                      if (_entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matching commands or objects.'),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '↑ ↓ Navigate    Enter Open    Esc Close',
                          style: OrbitTypography.caption(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
