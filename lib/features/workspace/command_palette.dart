import 'dart:async';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/workspace_controller.dart';
import '../../app/session_state.dart';
import 'workspace_views.dart';

Future<void> showCommandPalette(BuildContext context, WorkspaceController c) =>
    showDialog<void>(
      context: context,
      animationStyle: AnimationStyle(
        duration: OrbitMotionScope.duration(context, OrbitMotion.dialog),
        curve: OrbitMotion.ease,
      ),
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
  List<UniversalObject> results = [];
  Timer? _debounce;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    results = widget.controller.activeObjects.take(5).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      query = value;
      results = value.isEmpty
          ? widget.controller.activeObjects.take(5).toList()
          : [];
    });
    if (value.trim().isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      try {
        final found = await widget.controller.search(value.trim());
        if (mounted && generation == _generation) {
          setState(() => results = found.take(12).toList());
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
      (title: 'New note', icon: Icons.add, run: () => c.create('orbit.note')),
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
    ];
    final filtered = commands
        .where((v) => v.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final objects = results;
    void run(VoidCallback action) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      action();
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: OrbitSearchField(
                autofocus: true,
                hint: 'Search commands and knowledge…',
                onChanged: _search,
                onSubmitted: (_) {
                  if (filtered.isNotEmpty) {
                    run(filtered.first.run);
                  } else if (objects.isNotEmpty) {
                    run(() => c.openObject(objects.first.id));
                  }
                },
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  ...filtered.map(
                    (v) => ListTile(
                      leading: Icon(v.icon, size: 18),
                      title: Text(v.title),
                      onTap: () => run(v.run),
                    ),
                  ),
                  if (objects.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'KNOWLEDGE',
                        style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                      ),
                    ),
                  ...objects.map(
                    (o) => ObjectRow(
                      object: o,
                      query: query,
                      onTap: () => run(() => c.openObject(o.id)),
                    ),
                  ),
                  if (filtered.isEmpty && objects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching commands or objects.'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
