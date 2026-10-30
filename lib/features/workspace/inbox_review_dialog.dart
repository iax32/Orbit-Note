import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';

/// Interactive review interface for quick capture inbox items (CAP-02).
/// Separates the cognitive act of capture from later organization.
Future<void> showInboxReviewDialog(
  BuildContext context,
  WorkspaceController controller,
) async {
  await showOrbitDialog<void>(
    context: context,
    builder: (dialogCtx) => _InboxReviewContent(controller: controller),
  );
}

class _InboxReviewContent extends StatefulWidget {
  const _InboxReviewContent({required this.controller});
  final WorkspaceController controller;

  @override
  State<_InboxReviewContent> createState() => _InboxReviewContentState();
}

class _InboxReviewContentState extends State<_InboxReviewContent> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final c = widget.controller;
    final items = c.inboxObjects;

    if (items.isEmpty) {
      return OrbitDialog(
        title: const Row(
          children: [
            Icon(Icons.inbox_outlined, size: 20),
            SizedBox(width: 8),
            Text('Inbox Review'),
          ],
        ),
        content: SizedBox(
          width: 440,
          height: 120,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.done_all,
                  size: 36,
                  color: OrbitColors.of(context).success,
                ),
                SizedBox(height: 12),
                Text('Inbox is clear! No unprocessed captures.'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }

    if (_currentIndex >= items.length) {
      _currentIndex = items.length - 1;
    }
    final current = items[_currentIndex];
    final capturedAt = current.properties['capturedAt']?.toString() ?? '';
    final dateDisplay = capturedAt.isNotEmpty
        ? capturedAt.replaceFirst('T', ' ').split('.').first
        : '';

    final availableProjects = c.activeObjects
        .map((o) => o.properties['project']?.toString())
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty)
        .toSet()
        .toList();
    availableProjects.sort();

    return OrbitDialog(
      title: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 20, color: colors.accent),
          const SizedBox(width: 8),
          Text('Capture Inbox (${_currentIndex + 1} of ${items.length})'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${items.length} unorganized',
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Captured item preview card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.raised.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        current.typeId == 'orbit.task'
                            ? Icons.check_box_outline_blank
                            : Icons.notes_outlined,
                        size: 15,
                        color: colors.subtle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        current.typeId.replaceFirst('orbit.', '').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: colors.subtle,
                        ),
                      ),
                      const Spacer(),
                      if (dateDisplay.isNotEmpty)
                        Text(
                          dateDisplay,
                          style: TextStyle(fontSize: 10, color: colors.subtle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    current.body.isNotEmpty ? current.body : current.title,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick actions row
            const Text(
              'PROCESS ITEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Keep as Note'),
                  onPressed: () async {
                    await c.processInboxItem(current.id);
                    setState(() {});
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Convert to Task'),
                  onPressed: () async {
                    await c.processInboxItem(current.id, asTask: true);
                    setState(() {});
                  },
                ),
                PopupMenuButton<String>(
                  popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
                  tooltip: 'Assign Project',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_special_outlined, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Assign Project',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
                  ),
                  itemBuilder: (_) => [
                    if (availableProjects.isEmpty)
                      const PopupMenuItem(
                        enabled: false,
                        child: Text('No existing projects'),
                      )
                    else
                      for (final p in availableProjects)
                        PopupMenuItem(value: p, child: Text(p)),
                  ],
                  onSelected: (proj) async {
                    await c.processInboxItem(current.id, project: proj);
                    setState(() {});
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Archive'),
                  onPressed: () async {
                    await c.processInboxItem(current.id, archive: true);
                    setState(() {});
                  },
                ),
                IconButton(
                  tooltip: 'Delete capture',
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: OrbitColors.of(context).danger,
                  ),
                  onPressed: () async {
                    await c.processInboxItem(current.id, delete: true);
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (items.length > 1) ...[
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.arrow_back),
            onPressed: _currentIndex > 0
                ? () => setState(() => _currentIndex--)
                : null,
          ),
          IconButton(
            tooltip: 'Next / Skip',
            icon: const Icon(Icons.arrow_forward),
            onPressed: _currentIndex < items.length - 1
                ? () => setState(() => _currentIndex++)
                : null,
          ),
        ],
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
