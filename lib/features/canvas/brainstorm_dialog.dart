import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_draft_guard.dart';
import '../../canvas/brainstorm.dart';

class BrainstormDraft {
  const BrainstormDraft(
    this.ideas,
    this.columns, {
    this.source = '',
    this.paragraphs = false,
  });
  final List<String> ideas;
  final int columns;
  final String source;
  final bool paragraphs;
}

class BrainstormDialog extends StatefulWidget {
  const BrainstormDialog({super.key, this.initial});
  final BrainstormDraft? initial;
  @override
  State<BrainstormDialog> createState() => _BrainstormDialogState();
}

class _BrainstormDialogState extends State<BrainstormDialog> {
  final text = TextEditingController();
  bool paragraphs = false;
  int columns = 4;
  @override
  void initState() {
    super.initState();
    if (widget.initial case final initial?) {
      text.text = initial.source;
      paragraphs = initial.paragraphs;
      columns = initial.columns;
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var ideas = <String>[];
    String? error;
    try {
      ideas = brainstormIdeas(text.text, paragraphs: paragraphs);
    } on FormatException catch (e) {
      error = e.message;
    }
    return OrbitDraftGuard(
      dirty:
          text.text != (widget.initial?.source ?? '') ||
          columns != (widget.initial?.columns ?? 4) ||
          paragraphs != (widget.initial?.paragraphs ?? false),
      builder: (context, requestClose) => OrbitDialog(
        title: const Text('Bulk sticky notes'),
        contentSlivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Paste a list of ideas. Each becomes an editable sticky note; one Undo removes the batch.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: text,
                  minLines: 6,
                  maxLines: 12,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ideas',
                    hintText: 'First idea\nSecond idea\nThird idea',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Separate by blank paragraphs'),
                  subtitle: const Text(
                    'Off: one idea per line. On: preserve line breaks within an idea.',
                  ),
                  value: paragraphs,
                  onChanged: (v) => setState(() => paragraphs = v),
                ),
                Text('Columns: $columns'),
                Slider(
                  value: columns.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: '$columns',
                  onChanged: (v) => setState(() => columns = v.round()),
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error ??
                        '${ideas.length} sticky notes · current Canvas color',
                  ),
                ),
              ],
            ),
          ),
        ],
        actions: [
          TextButton(onPressed: requestClose, child: const Text('Cancel')),
          FilledButton(
            onPressed: error != null || ideas.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    BrainstormDraft(
                      ideas,
                      columns,
                      source: text.text,
                      paragraphs: paragraphs,
                    ),
                  ),
            child: const Text('Add sticky notes'),
          ),
        ],
      ),
    );
  }
}
