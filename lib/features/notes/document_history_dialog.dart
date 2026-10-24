import '../../app/orbit_motion_effects.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';

/// Single snapshot entry in the document's revision history.
class NoteRevisionSnapshot {
  const NoteRevisionSnapshot({
    required this.id,
    required this.revision,
    required this.timestamp,
    required this.title,
    required this.body,
    required this.wordCount,
    this.label = 'Snapshot',
  });

  final String id;
  final int revision;
  final DateTime timestamp;
  final String title;
  final String body;
  final int wordCount;
  final String label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    'timestamp': timestamp.toIso8601String(),
    'title': title,
    'body': body,
    'wordCount': wordCount,
    'label': label,
  };

  static NoteRevisionSnapshot? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'] as String? ?? '';
    final rev = json['revision'] as int? ?? 1;
    final ts =
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
    final title = json['title'] as String? ?? '';
    final body = json['body'] as String? ?? '';
    final words = json['wordCount'] as int? ?? 0;
    final label = json['label'] as String? ?? 'Snapshot';
    return NoteRevisionSnapshot(
      id: id,
      revision: rev,
      timestamp: ts,
      title: title,
      body: body,
      wordCount: words,
      label: label,
    );
  }
}

enum DiffType { unchanged, added, removed }

class DiffLine {
  const DiffLine(this.type, this.text);
  final DiffType type;
  final String text;
}

/// Computes a clean line-by-line diff comparing [oldText] to [newText].
List<DiffLine> computeSimpleDiff(String oldText, String newText) {
  if (oldText == newText) {
    final lines = oldText.isEmpty ? <String>[] : oldText.split('\n');
    return lines.map((l) => DiffLine(DiffType.unchanged, l)).toList();
  }

  final oldLines = oldText.isEmpty ? <String>[] : oldText.split('\n');
  final newLines = newText.isEmpty ? <String>[] : newText.split('\n');

  final m = oldLines.length;
  final n = newLines.length;

  if (m > 300 || n > 300) {
    // Quick line comparison fallback for huge texts
    final diff = <DiffLine>[];
    int maxLen = math.max(m, n);
    for (int i = 0; i < maxLen; i++) {
      if (i < m && i < n) {
        if (oldLines[i] == newLines[i]) {
          diff.add(DiffLine(DiffType.unchanged, oldLines[i]));
        } else {
          diff.add(DiffLine(DiffType.removed, oldLines[i]));
          diff.add(DiffLine(DiffType.added, newLines[i]));
        }
      } else if (i < m) {
        diff.add(DiffLine(DiffType.removed, oldLines[i]));
      } else if (i < n) {
        diff.add(DiffLine(DiffType.added, newLines[i]));
      }
    }
    return diff;
  }

  // Dynamic programming LCS table
  final dp = List.generate(m + 1, (_) => Int32List(n + 1));
  for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) {
      if (oldLines[i] == newLines[j]) {
        dp[i + 1][j + 1] = dp[i][j] + 1;
      } else {
        dp[i + 1][j + 1] = math.max(dp[i + 1][j], dp[i][j + 1]);
      }
    }
  }

  final diff = <DiffLine>[];
  int i = m, j = n;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
      diff.add(DiffLine(DiffType.unchanged, oldLines[i - 1]));
      i--;
      j--;
    } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
      diff.add(DiffLine(DiffType.added, newLines[j - 1]));
      j--;
    } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
      diff.add(DiffLine(DiffType.removed, oldLines[i - 1]));
      i--;
    }
  }

  return diff.reversed.toList();
}

/// Opens the Document History & Revision Diff Inspector dialog.
Future<void> showDocumentHistoryDialog({
  required BuildContext context,
  required WorkspaceController controller,
  required String objectId,
  required String currentTitle,
  required String currentBody,
  ValueChanged<({String title, String body})>? onRestored,
}) => showOrbitDialog<void>(
  context: context,
  builder: (ctx) => DocumentHistoryDialog(
    controller: controller,
    objectId: objectId,
    currentTitle: currentTitle,
    currentBody: currentBody,
    onRestored: onRestored,
  ),
);

/// Interactive revision history inspector with side-by-side snapshot comparison.
class DocumentHistoryDialog extends StatefulWidget {
  const DocumentHistoryDialog({
    super.key,
    required this.controller,
    required this.objectId,
    required this.currentTitle,
    required this.currentBody,
    this.onRestored,
  });

  final WorkspaceController controller;
  final String objectId;
  final String currentTitle;
  final String currentBody;
  final ValueChanged<({String title, String body})>? onRestored;

  @override
  State<DocumentHistoryDialog> createState() => _DocumentHistoryDialogState();
}

class _SnapshotLabelDialog extends StatefulWidget {
  const _SnapshotLabelDialog();
  @override
  State<_SnapshotLabelDialog> createState() => _SnapshotLabelDialogState();
}

class _SnapshotLabelDialogState extends State<_SnapshotLabelDialog> {
  final _label = TextEditingController(text: 'Manual checkpoint');

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Create Revision Snapshot'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Label this snapshot to easily recognize it in history:',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Snapshot label',
            isDense: true,
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _label.text.trim()),
        child: const Text('Save Snapshot'),
      ),
    ],
  );
}

class _DocumentHistoryDialogState extends State<DocumentHistoryDialog> {
  int _selectedIndex = 0;
  bool _showDiff = true;
  late List<NoteRevisionSnapshot> _snapshots;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  void _loadSnapshots() {
    final raw = widget.controller.getDocumentSnapshots(widget.objectId);
    _snapshots = raw
        .map(NoteRevisionSnapshot.fromJson)
        .whereType<NoteRevisionSnapshot>()
        .toList();
  }

  Future<void> _createSnapshot() async {
    final label = await showOrbitDialog<String>(
      context: context,
      builder: (_) => const _SnapshotLabelDialog(),
    );
    if (!mounted) return;
    if (label != null && label.isNotEmpty) {
      await widget.controller.createDocumentSnapshot(
        widget.objectId,
        label: label,
        title: widget.currentTitle,
        body: widget.currentBody,
      );
      if (!mounted) return;
      setState(() {
        _loadSnapshots();
        _selectedIndex = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Snapshot "$label" saved'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _restoreSnapshot(NoteRevisionSnapshot snap) async {
    final confirmed = await showOrbitDialog<bool>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: const Text('Restore Revision Snapshot?'),
        content: Text(
          'This will restore "${snap.title}" from ${_formatTimestamp(snap.timestamp)}.\n\n'
          'A pre-restore checkpoint of your current document will be saved automatically so no work is lost.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Version'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.restoreDocumentSnapshot(widget.objectId, snap.id);
      widget.onRestored?.call((title: snap.title, body: snap.body));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored revision from ${_formatTimestamp(snap.timestamp)} (Pre-restore checkpoint saved)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final snapshot = _snapshots.isNotEmpty && _selectedIndex < _snapshots.length
        ? _snapshots[_selectedIndex]
        : null;
    final lines = snapshot == null
        ? <DiffLine>[]
        : computeSimpleDiff(snapshot.body, widget.currentBody);
    return OrbitDialog(
      maxWidth: 900,
      title: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 20, color: colors.accent),
          const Text('Revision History & Snapshots'),
          OutlinedButton.icon(
            key: const ValueKey('create-snapshot-button'),
            onPressed: _createSnapshot,
            icon: const Icon(Icons.add, size: 15),
            label: const Text('Save Snapshot'),
            style: OutlinedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          // Bound the document viewports; headings and controls can scroll with
          // the dialog when the window or keyboard leaves little room.
          final compact =
              constraints.maxWidth < 700 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final history = SizedBox(
            height: compact ? 240 : 520,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(OrbitRadius.card),
                border: Border.all(color: colors.border),
              ),
              child: _snapshots.isEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 32,
                            color: colors.muted,
                          ),
                          const SizedBox(height: 8),
                          const Text('No snapshots yet'),
                          const SizedBox(height: 4),
                          const Text(
                            'Click "Save Snapshot" to create a version checkpoint.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _snapshots.length,
                      itemBuilder: (context, i) {
                        final snap = _snapshots[i];
                        final selected = i == _selectedIndex;
                        return Semantics(
                          selected: selected,
                          button: true,
                          child: InkWell(
                            key: ValueKey('snapshot-item-$i'),
                            onTap: () => setState(() => _selectedIndex = i),
                            child: AnimatedContainer(
                              duration: OrbitMotionScope.duration(
                                context,
                                OrbitMotion.micro,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.accent.withValues(alpha: .12)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: selected
                                        ? colors.accent
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  bottom: BorderSide(
                                    color: colors.border.withValues(alpha: .5),
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    snap.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: selected
                                          ? colors.text
                                          : colors.subtle,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_formatTimestamp(snap.timestamp)} · rev. ${snap.revision} · ${snap.wordCount} words',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          );
          final preview = snapshot == null
              ? Text(
                  'Select a snapshot to compare changes',
                  style: TextStyle(color: colors.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_snapshots.length > 1) ...[
                      Text(
                        'History timeline · ${_selectedIndex + 1} of ${_snapshots.length} · preview only',
                      ),
                      Slider(
                        key: const ValueKey('history-timeline'),
                        value: _selectedIndex.toDouble(),
                        max: (_snapshots.length - 1).toDouble(),
                        divisions: _snapshots.length - 1,
                        label: '${_selectedIndex + 1} of ${_snapshots.length}',
                        onChanged: (v) =>
                            setState(() => _selectedIndex = v.round()),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.raised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text(
                                '+${lines.where((l) => l.type == DiffType.added).length} lines',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: OrbitColors.of(context).success,
                                ),
                              ),
                              Text(
                                '-${lines.where((l) => l.type == DiffType.removed).length} lines',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: OrbitColors.of(context).danger,
                                ),
                              ),
                              Text(
                                '${snapshot.wordCount} words',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ChoiceChip(
                                label: const Text('Diff'),
                                selected: _showDiff,
                                onSelected: (_) =>
                                    setState(() => _showDiff = true),
                              ),
                              ChoiceChip(
                                label: const Text('Preview'),
                                selected: !_showDiff,
                                onSelected: (_) =>
                                    setState(() => _showDiff = false),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('restore-snapshot-button'),
                                onPressed: () => _restoreSnapshot(snapshot),
                                icon: const Icon(
                                  Icons.restore_rounded,
                                  size: 16,
                                ),
                                label: const Text('Restore'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 360,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.panel,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: _showDiff
                            ? ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: lines.length,
                                itemBuilder: (context, i) {
                                  final line = lines[i];
                                  final added = line.type == DiffType.added;
                                  final removed = line.type == DiffType.removed;
                                  final ink = added
                                      ? OrbitColors.of(context).success
                                      : removed
                                      ? OrbitColors.of(context).danger
                                      : colors.text;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    color: added || removed
                                        ? ink.withValues(alpha: .14)
                                        : Colors.transparent,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          added
                                              ? '+ '
                                              : removed
                                              ? '- '
                                              : '  ',
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11.5,
                                            color: ink,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            line.text.isEmpty ? ' ' : line.text,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11.5,
                                              color: ink,
                                              decoration: removed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: OrbitEffect(
                                  trigger: snapshot,
                                  style: 'morph',
                                  family: 'smart',
                                  child: SelectableText(
                                    snapshot.body,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [history, const SizedBox(height: 14), preview],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 260, child: history),
                    const SizedBox(width: 14),
                    Expanded(child: preview),
                  ],
                );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
