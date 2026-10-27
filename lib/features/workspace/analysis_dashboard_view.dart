import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'research_record_dialog.dart';
import 'dashboard_columns.dart';
import 'source_browser_dialog.dart';
import 'code_ide_workspace.dart';
import 'research_comparison_dialog.dart';
import 'research_dossier_workspace.dart';

class AnalysisDashboardView extends StatelessWidget {
  const AnalysisDashboardView({
    super.key,
    required this.controller,
    required this.viewObject,
    this.folderFilter,
    this.scope,
    this.onSelectViewType,
  });

  final WorkspaceController controller;
  final UniversalObject viewObject;
  final String? folderFilter;
  final String? scope;
  final ValueChanged<String>? onSelectViewType;

  bool _matchesScope(UniversalObject o) {
    final ff = folderFilter;
    final sc = scope;
    if (ff != null && ff.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == ff || f.startsWith('$ff/'))) {
        return true;
      }
      final p = controller.repository.objectPath(o.id);
      if (p != null && (p == ff || p.startsWith('$ff/'))) {
        return true;
      }
    }
    if (sc != null && sc.isNotEmpty) {
      final target = o.properties['target']?.toString().toLowerCase();
      final project = o.properties['project']?.toString().toLowerCase();
      final contextVal = o.properties['context']?.toString().toLowerCase();
      final lowerScope = sc.toLowerCase();
      if (target == lowerScope ||
          project == lowerScope ||
          contextVal == lowerScope) {
        return true;
      }
    }
    if ((ff == null || ff.isEmpty) && (sc == null || sc.isEmpty)) {
      return true;
    }
    return false;
  }

  bool _isTaskBlocked(UniversalObject t) {
    final raw = t.properties['blockedBy'];
    if (raw == null) return false;
    final List<String> ids = switch (raw) {
      List l => l.map((e) => e.toString()).toList(),
      String s =>
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      _ => const [],
    };
    if (ids.isEmpty) return false;
    for (final id in ids) {
      final blocker = controller.find(id);
      if (blocker != null && !blocker.isDeleted && !blocker.isCompleted) {
        return true;
      }
    }
    return false;
  }

  Future<void> _createRecord(
    BuildContext context,
    String category,
    String section,
  ) => showResearchRecordDialog(
    context,
    controller,
    folder: folderFilter != null
        ? (folderFilter!.endsWith('/$section')
              ? folderFilter!
              : '$folderFilter/$section')
        : 'Reverse Engineering/${scope ?? 'Target'}/$section',
    initialCategory: category,
  );
  Future<void> _quickCreateFunction(BuildContext context) =>
      _createRecord(context, 'Function', 'Functions');
  Future<void> _quickCreateFinding(BuildContext context) =>
      _createRecord(context, 'Finding', 'Findings');
  Future<void> _quickCreateHypothesis(BuildContext context) =>
      _createRecord(context, 'Hypothesis', 'Hypotheses');

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final targetName =
        scope ?? viewObject.properties['target']?.toString() ?? 'Target';

    // Find Target Overview note for metadata
    UniversalObject? overviewNote;
    for (final o in controller.activeObjects) {
      if (!o.isDeleted &&
          o.properties['isTargetOverview'] == true &&
          (o.properties['target']?.toString().toLowerCase() ==
                  targetName.toLowerCase() ||
              _matchesScope(o))) {
        overviewNote = o;
        break;
      }
    }

    final arch =
        overviewNote?.properties['architecture']?.toString() ??
        viewObject.properties['architecture']?.toString() ??
        'Architecture not recorded';
    final format =
        overviewNote?.properties['format']?.toString() ??
        viewObject.properties['format']?.toString() ??
        'Format not recorded';
    final platform =
        overviewNote?.properties['platform']?.toString() ??
        'Platform not recorded';
    final version =
        overviewNote?.properties['version']?.toString() ?? 'Not recorded';

    final allScoped = controller.activeObjects
        .where((o) => !o.isDeleted && _matchesScope(o))
        .toList();

    // Functions
    final functions = allScoped
        .where((o) => o.properties['category'] == 'Function')
        .toList();

    // Findings
    final findings = allScoped
        .where((o) => o.properties['category'] == 'Finding')
        .toList();
    final confirmedFindings = findings
        .where(
          (f) =>
              (f.properties['status'] as String?)?.toLowerCase() == 'confirmed',
        )
        .length;

    // Hypotheses
    final hypotheses = allScoped
        .where((o) => o.properties['category'] == 'Hypothesis')
        .toList();
    final hypothesesByStatus = <String, int>{
      'Open': 0,
      'Testing': 0,
      'Supported': 0,
      'Confirmed': 0,
      'Rejected': 0,
    };
    for (final h in hypotheses) {
      final rawStatus = h.properties['status']?.toString().trim() ?? '';
      final s = rawStatus.isEmpty ? 'Open' : rawStatus;
      final cleanS = s[0].toUpperCase() + s.substring(1).toLowerCase();
      if (hypothesesByStatus.containsKey(cleanS)) {
        hypothesesByStatus[cleanS] = hypothesesByStatus[cleanS]! + 1;
      } else {
        hypothesesByStatus['Open'] = hypothesesByStatus['Open']! + 1;
      }
    }

    // Indicators / IOCs
    final iocs = allScoped
        .where(
          (o) =>
              o.properties['category'] == 'Indicator' ||
              o.properties.containsKey('iocType'),
        )
        .toList();

    // Tasks
    final tasks = allScoped.where((o) => o.typeId == 'orbit.task').toList();
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();
    final blockedTasks = activeTasks.where(_isTaskBlocked).toList();

    // Sessions & Structures
    final sessions = allScoped
        .where(
          (o) =>
              o.properties['category'] == 'Analysis Session' ||
              o.properties['category'] == 'Static Analysis Session' ||
              o.properties['category'] == 'Dynamic Analysis Session',
        )
        .toList();
    final structures = allScoped
        .where((o) => o.properties['category'] == 'Structure')
        .toList();
    final canvases = allScoped
        .where((o) => o.typeId == 'orbit.canvas')
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            // Target Header banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.panel,
                border: Border(bottom: BorderSide(color: colors.border)),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.biotech_outlined,
                        size: 20,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Research workspace',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 11,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _TagBadge(label: format, color: colors.accent),
                      const SizedBox(width: 6),
                      _TagBadge(label: arch, color: colors.accent),
                      const SizedBox(width: 6),
                      _TagBadge(label: platform, color: colors.subtle),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        targetName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          'v$version',
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Local-first research notebook for disassembly, structures, hypotheses, and indicators.',
                    style: TextStyle(color: colors.subtle, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metrics Row
            DashboardColumns(
              minColumnWidth: 200,
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.code_outlined,
                    label: 'Functions',
                    value: '${functions.length}',
                    subtitle:
                        '${functions.where((f) => (f.properties['status'] as String?)?.toLowerCase() == 'confirmed').length} confirmed',
                    color: colors.accent,
                    colors: colors,
                    onTap: () => onSelectViewType?.call('functions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.check_circle_outline,
                    label: 'Findings',
                    value: '${findings.length}',
                    subtitle: '$confirmedFindings verified',
                    color: OrbitColors.of(context).success,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.lightbulb_outline,
                    label: 'Hypotheses',
                    value: '${hypotheses.length}',
                    subtitle:
                        '${hypothesesByStatus['Open']! + hypothesesByStatus['Testing']!} in progress',
                    color: OrbitColors.of(context).secondary,
                    colors: colors,
                    onTap: () => onSelectViewType?.call('board'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.fingerprint,
                    label: 'Indicators / IOCs',
                    value: '${iocs.length}',
                    subtitle: 'Extracted tokens',
                    color: OrbitColors.of(context).warning,
                    colors: colors,
                    onTap: () => onSelectViewType?.call('iocs'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.task_alt_outlined,
                    label: 'Active Tasks',
                    value: '${activeTasks.length}',
                    subtitle: blockedTasks.isEmpty
                        ? 'All clear'
                        : '${blockedTasks.length} blocked!',
                    color: blockedTasks.isEmpty
                        ? colors.accent
                        : OrbitColors.of(context).danger,
                    colors: colors,
                    onTap: () => onSelectViewType?.call('tasks'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Quick Actions & Navigation Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showResearchDossier(context, controller),
                  icon: const Icon(Icons.manage_search_outlined),
                  label: const Text('Research dossiers'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showCodeIde(
                    context,
                    controller: controller,
                    owner: viewObject,
                    evidenceFolder:
                        '${folderFilter ?? 'Reverse Engineering/$targetName'}/Sessions',
                  ),
                  icon: const Icon(Icons.developer_mode),
                  label: const Text('Code workspace'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showSourceBrowser(
                    context,
                    controller: controller,
                    owner: viewObject,
                    folder:
                        '${folderFilter ?? 'Reverse Engineering/$targetName'}/Sessions',
                  ),
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Source & evidence'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showResearchComparison(
                    context,
                    controller,
                    matchesScope: _matchesScope,
                    folder:
                        '${folderFilter ?? 'Reverse Engineering/$targetName'}/Sessions',
                    target: targetName,
                  ),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Compare builds'),
                ),
                FilledButton.icon(
                  onPressed: () => _quickCreateFunction(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Function'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _quickCreateFinding(context),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('New Finding'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _quickCreateHypothesis(context),
                  icon: const Icon(Icons.lightbulb_outline, size: 16),
                  label: const Text('New Hypothesis'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final targetFolder = folderFilter != null
                        ? (folderFilter!.contains('Sessions')
                              ? folderFilter!
                              : '$folderFilter/Sessions')
                        : 'Reverse Engineering/${scope ?? "Target"}/Sessions';
                    controller.createAnalysisSessionDoc(
                      folder: targetFolder,
                      target: targetName,
                    );
                  },
                  icon: const Icon(Icons.terminal_outlined, size: 16),
                  label: const Text('New Session'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final targetFolder = folderFilter != null
                        ? (folderFilter!.contains('Structures')
                              ? folderFilter!
                              : '$folderFilter/Structures')
                        : 'Reverse Engineering/${scope ?? "Target"}/Structures';
                    controller.createStructureDoc(
                      folder: targetFolder,
                      target: targetName,
                    );
                  },
                  icon: const Icon(Icons.table_chart_outlined, size: 16),
                  label: const Text('New Structure'),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Hypotheses Pipeline Row
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(OrbitRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hypotheses Pipeline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.text,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => onSelectViewType?.call('board'),
                        icon: const Icon(Icons.view_kanban_outlined, size: 14),
                        label: const Text('Open Kanban Board'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HypothesisStatusPill(
                        label: 'Open',
                        count: hypothesesByStatus['Open']!,
                        color: OrbitColors.of(context).accent,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _HypothesisStatusPill(
                        label: 'Testing',
                        count: hypothesesByStatus['Testing']!,
                        color: OrbitColors.of(context).warning,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _HypothesisStatusPill(
                        label: 'Supported',
                        count: hypothesesByStatus['Supported']!,
                        color: OrbitColors.of(context).success,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _HypothesisStatusPill(
                        label: 'Confirmed',
                        count: hypothesesByStatus['Confirmed']!,
                        color: OrbitColors.of(context).success,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      _HypothesisStatusPill(
                        label: 'Rejected',
                        count: hypothesesByStatus['Rejected']!,
                        color: OrbitColors.of(context).danger,
                        colors: colors,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Watchdog & Blockers Alert (if any blocked tasks)
            if (blockedTasks.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrbitColors.of(context).danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(OrbitRadius.card),
                  border: Border.all(
                    color: OrbitColors.of(
                      context,
                    ).danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: OrbitColors.of(context).danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Investigation Blockers Detected (${blockedTasks.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: OrbitColors.of(context).danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...blockedTasks
                        .take(3)
                        .map(
                          (t) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: InkWell(
                              onTap: () => controller.openObject(t.id),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 14,
                                    color: OrbitColors.of(context).danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      style: const TextStyle(fontSize: 12.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'Blocked by prerequisite task',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: OrbitColors.of(context).danger,
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
              const SizedBox(height: 24),
            ],

            // Two-column layout: Left (Recent Findings & Sessions) / Right (Canvases & Structures)
            DashboardColumns(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Key Findings & Sessions
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Recent Findings',
                        count: findings.length,
                        colors: colors,
                        actionLabel: '+ Finding',
                        onAction: () => _quickCreateFinding(context),
                      ),
                      const SizedBox(height: 8),
                      if (findings.isEmpty)
                        _EmptyPlaceholder(
                          text:
                              'No findings documented yet. Discoveries will appear here.',
                          colors: colors,
                        )
                      else
                        ...findings
                            .take(4)
                            .map(
                              (f) => _ObjectCard(
                                object: f,
                                controller: controller,
                                colors: colors,
                                badge:
                                    f.properties['status'] as String? ??
                                    'Draft',
                                badgeColor:
                                    (f.properties['status'] as String?)
                                            ?.toLowerCase() ==
                                        'confirmed'
                                    ? OrbitColors.of(context).success
                                    : colors.subtle,
                              ),
                            ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Analysis Sessions',
                        count: sessions.length,
                        colors: colors,
                      ),
                      const SizedBox(height: 8),
                      if (sessions.isEmpty)
                        _EmptyPlaceholder(
                          text:
                              'No sessions logged yet. Keep logs of breakpoints, tools, and observations.',
                          colors: colors,
                        )
                      else
                        ...sessions
                            .take(3)
                            .map(
                              (s) => _ObjectCard(
                                object: s,
                                controller: controller,
                                colors: colors,
                                badge:
                                    s.properties['tool'] as String? ??
                                    'Session',
                                badgeColor: colors.accent,
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column: Canvases, Structures, Diagram Links
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Canvases & Diagrams',
                        count: canvases.length,
                        colors: colors,
                      ),
                      const SizedBox(height: 8),
                      if (canvases.isEmpty)
                        _EmptyPlaceholder(
                          text: 'No diagrams created yet.',
                          colors: colors,
                        )
                      else
                        ...canvases
                            .take(4)
                            .map(
                              (c) => _CanvasCard(
                                canvas: c,
                                controller: controller,
                                colors: colors,
                              ),
                            ),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Structures & Memory Layouts',
                        count: structures.length,
                        colors: colors,
                      ),
                      const SizedBox(height: 8),
                      if (structures.isEmpty)
                        _EmptyPlaceholder(
                          text: 'No structs defined yet.',
                          colors: colors,
                        )
                      else
                        ...structures
                            .take(3)
                            .map(
                              (st) => _ObjectCard(
                                object: st,
                                controller: controller,
                                colors: colors,
                                badge: 'Size: ${st.properties['size'] ?? "?"}',
                                badgeColor: OrbitColors.of(context).accent,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.colors,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final OrbitColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.subtle,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: colors.subtle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        child: content,
      );
    }
    return content;
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

class _HypothesisStatusPill extends StatelessWidget {
  const _HypothesisStatusPill({
    required this.label,
    required this.count,
    required this.color,
    required this.colors,
  });

  final String label;
  final int count;
  final Color color;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.colors,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final int count;
  final OrbitColors colors;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, color: colors.subtle),
          ),
        ),

        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({
    required this.object,
    required this.controller,
    required this.colors,
    required this.badge,
    required this.badgeColor,
  });

  final UniversalObject object;
  final WorkspaceController controller;
  final OrbitColors colors;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
      ),
      child: ListTile(
        onTap: () => controller.openObject(object.id),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Text(
          object.title.isEmpty ? 'Untitled' : object.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: object.body.isNotEmpty
            ? Text(
                object.body.replaceAll(RegExp(r'[#*`\[\]]'), '').trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: colors.subtle),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasCard extends StatelessWidget {
  const _CanvasCard({
    required this.canvas,
    required this.controller,
    required this.colors,
  });

  final UniversalObject canvas;
  final WorkspaceController controller;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: ListTile(
        onTap: () => controller.openObject(canvas.id),
        dense: true,
        leading: Icon(Icons.dashboard_outlined, size: 18, color: colors.accent),
        title: Text(
          canvas.title.isEmpty ? 'Untitled Canvas' : canvas.title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder({required this.text, required this.colors});
  final String text;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: colors.subtle,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
