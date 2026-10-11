import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/orbit_theme.dart';
import '../../../app/workspace_controller.dart';
import 'dynamic_view_block.dart';

class SnapshotItem {
  const SnapshotItem({
    required this.text,
    this.completed,
    this.objectId,
    this.meta,
  });

  final String text;
  final bool? completed;
  final String? objectId;
  final String? meta;

  String? get id => objectId;
  String get title => text;
  bool get isCompleted => completed == true;
  String? get subtitle => meta;
}

class SnapshotConfig {
  const SnapshotConfig({
    required this.type,
    required this.title,
    required this.frozenAt,
    required this.items,
  });

  final String type;
  final String title;
  final String frozenAt;
  final List<SnapshotItem> items;

  DateTime get frozenAtDateTime =>
      DateTime.tryParse(frozenAt) ?? DateTime.now();

  static SnapshotConfig parse(String raw) {
    var type = 'tasks';
    var title = 'Snapshot';
    var frozenAt = DateTime.now().toUtc().toIso8601String();
    final items = <SnapshotItem>[];

    var inItems = false;
    String? currentText;
    bool? currentCompleted;
    String? currentObjectId;
    String? currentMeta;

    void flushItem() {
      if (currentText != null) {
        items.add(
          SnapshotItem(
            text: currentText!,
            completed: currentCompleted,
            objectId: currentObjectId,
            meta: currentMeta,
          ),
        );
      }
      currentText = null;
      currentCompleted = null;
      currentObjectId = null;
      currentMeta = null;
    }

    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      if (!inItems) {
        final idx = trimmed.indexOf(':');
        if (idx > 0) {
          final key = trimmed.substring(0, idx).trim().toLowerCase();
          final val = trimmed.substring(idx + 1).trim();
          if (key == 'type') type = val;
          if (key == 'title') title = val;
          if (key == 'frozenat') frozenAt = val;
          if (key == 'items') inItems = true;
        }
      } else {
        if (trimmed.startsWith('-')) {
          flushItem();
          final afterDash = trimmed.substring(1).trim();
          final idx = afterDash.indexOf(':');
          if (idx > 0) {
            final k = afterDash.substring(0, idx).trim().toLowerCase();
            final v = afterDash.substring(idx + 1).trim();
            if (k == 'text' || k == 'title') currentText = v;
            if (k == 'id' || k == 'objectid') currentObjectId = v;
            if (k == 'completed' || k == 'iscompleted') {
              currentCompleted = v.toLowerCase() == 'true';
            }
            if (k == 'subtitle' || k == 'meta') currentMeta = v;
          }
        } else {
          final idx = trimmed.indexOf(':');
          if (idx > 0) {
            final k = trimmed.substring(0, idx).trim().toLowerCase();
            final v = trimmed.substring(idx + 1).trim();
            if (k == 'text' || k == 'title') currentText = v;
            if (k == 'id' || k == 'objectid') currentObjectId = v;
            if (k == 'completed' || k == 'iscompleted') {
              currentCompleted = v.toLowerCase() == 'true';
            }
            if (k == 'subtitle' || k == 'meta') currentMeta = v;
          }
        }
      }
    }
    flushItem();

    return SnapshotConfig(
      type: type,
      title: title,
      frozenAt: frozenAt,
      items: items,
    );
  }

  static SnapshotConfig fromYaml(String raw) => parse(raw);

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('```orbit-snapshot');
    buffer.writeln('type: $type');
    buffer.writeln('title: $title');
    buffer.writeln('frozenAt: $frozenAt');
    buffer.writeln('items:');
    for (final item in items) {
      buffer.writeln('  - text: ${item.text}');
      if (item.completed != null) {
        buffer.writeln('    completed: ${item.completed}');
      }
      if (item.objectId != null) {
        buffer.writeln('    objectId: ${item.objectId}');
      }
      if (item.meta != null) {
        buffer.writeln('    meta: ${item.meta}');
      }
    }
    buffer.write('```');
    return buffer.toString();
  }
}

/// Renders a frozen historical snapshot of a Dynamic View (EDT-14).
/// Never mutates when underlying workspace data changes over time.
class SnapshotBlock extends StatelessWidget {
  const SnapshotBlock({
    super.key,
    required this.source,
    required this.onChanged,
  });

  final String source;
  final ValueChanged<String> onChanged;

  static bool isSnapshot(String language, String content) =>
      language == 'orbit-snapshot' || language == 'snapshot';

  void _unfreezeToLive() {
    final snapshot = SnapshotConfig.parse(source);
    final dynamicConfig = DynamicViewConfig(
      type: snapshot.type,
      title: snapshot.title,
    );
    onChanged(dynamicConfig.toMarkdown());
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final snapshot = SnapshotConfig.parse(source);
    final formattedDate = snapshot.frozenAt.split('T').first;

    WorkspaceController? c;
    try {
      c = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(workspaceProvider.notifier);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          style: BorderStyle.solid,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Snapshot Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.raised,
              border: Border(
                bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history_toggle_off, size: 16, color: colors.subtle),
                const SizedBox(width: 8),
                Text(
                  snapshot.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Frozen · $formattedDate',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Restore Live View'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  onPressed: _unfreezeToLive,
                ),
              ],
            ),
          ),

          // Items List
          Padding(
            padding: const EdgeInsets.all(12),
            child: snapshot.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'Empty snapshot.',
                        style: TextStyle(fontSize: 12, color: colors.subtle),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final item in snapshot.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              if (item.completed != null) ...[
                                Icon(
                                  item.completed!
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  size: 16,
                                  color: item.completed!
                                      ? colors.subtle
                                      : colors.text,
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: colors.subtle,
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: InkWell(
                                  onTap: item.objectId != null
                                      ? () => c?.openObject(item.objectId!)
                                      : null,
                                  child: Text(
                                    item.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: (item.completed == true)
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: (item.completed == true)
                                          ? colors.subtle
                                          : colors.text,
                                    ),
                                  ),
                                ),
                              ),
                              if (item.meta != null)
                                Text(
                                  item.meta!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.subtle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
