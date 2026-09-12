import 'dart:async';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import 'package:flutter/material.dart';
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
      builder: (context) => _CommandPalette(controller: c),
    );

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.controller});
  final WorkspaceController controller;
  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
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
    final c = widget.controller;
    final commands = <({String title, IconData icon, VoidCallback run})>[
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
      Navigator.pop(context);
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
