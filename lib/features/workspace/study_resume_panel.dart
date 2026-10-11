import 'package:flutter/material.dart';
import '../../app/workspace_controller.dart';

class StudyResumePanel extends StatefulWidget {
  const StudyResumePanel({
    super.key,
    required this.controller,
    required this.course,
  });
  final WorkspaceController controller;
  final String course;
  @override
  State<StudyResumePanel> createState() => _StudyResumePanelState();
}

class _StudyResumePanelState extends State<StudyResumePanel> {
  late final TextEditingController _next;
  bool _busy = false;
  String? _feedback;
  @override
  void initState() {
    super.initState();
    _next = TextEditingController(
      text:
          widget.controller.studyResume(widget.course)?['studyContinuation']
              as String? ??
          '',
    );
  }

  @override
  void dispose() {
    _next.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<bool> Function() action, String success) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return false;
    setState(() {
      _busy = false;
      _feedback = ok
          ? success
          : widget.controller.error ?? 'Could not save continuation.';
    });
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final course = widget.course;
    final record = c.studyResume(course);
    final locked = _busy || c.repository.readOnly;
    final tasks = c.unfinishedStudyWork(course);
    final related = c.relatedStudyMaterial(course);
    return ExpansionTile(
      title: const Text('Continue studying'),
      subtitle: Text(
        record == null
            ? 'Save where you left off'
            : '${tasks.length} unfinished tasks · saved ${record['studySavedAt']}',
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _next,
          enabled: !locked,
          maxLength: 4000,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Your next step',
            helperText:
                'Saved on this device with your open course tabs and view positions.',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: locked
                  ? null
                  : () => _run(
                      () => c.saveStudyResume(course, _next.text),
                      'Continuation saved.',
                    ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save current position'),
            ),
            FilledButton.icon(
              onPressed: locked || record == null
                  ? null
                  : () async {
                      final ok = await _run(
                        () => c.resumeStudy(course),
                        'Course reopened at its saved positions. Missing attachments use the reader’s recovery controls.',
                      );
                      if (ok && context.mounted) Navigator.pop(context);
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume course'),
            ),
            if (record != null)
              TextButton(
                onPressed: locked
                    ? null
                    : () => _run(
                        () => c.dismissStudyMaterial(course, '', reset: true),
                        'Dismissed material restored.',
                      ),
                child: const Text('Reset suggestions'),
              ),
          ],
        ),
        for (final warning in c.studyResumeWarnings(course))
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(warning),
          ),
        if (_feedback != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_feedback!),
            ),
          ),
        if (tasks.isNotEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Unfinished work'),
          ),
        for (final task in tasks)
          ListTile(
            title: Text(task.title),
            subtitle: const Text('Open task in this course'),
            onTap: _busy
                ? null
                : () {
                    c.openObject(task.id);
                    Navigator.pop(context);
                  },
          ),
        if (related.isNotEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Return to uncertain material'),
          ),
        for (final material in related)
          ListTile(
            title: Text(material.title),
            subtitle: const Text('Same course · you marked this uncertain'),
            onTap: _busy
                ? null
                : () {
                    c.openObject(material.id);
                    Navigator.pop(context);
                  },
            trailing: IconButton(
              tooltip: record == null
                  ? 'Save a continuation to enable dismissal'
                  : 'Dismiss suggestion',
              onPressed: locked || record == null
                  ? null
                  : () => _run(
                      () => c.dismissStudyMaterial(course, material.id),
                      'Suggestion dismissed.',
                    ),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }
}
