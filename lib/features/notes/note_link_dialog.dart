import 'package:flutter/material.dart';

import '../../domain/wiki_links.dart';

Future<NoteLinkTarget?> showNoteLinkDialog(
  BuildContext context,
  List<NoteLinkTarget> targets, {
  String initialQuery = '',
}) => showDialog<NoteLinkTarget>(
  context: context,
  builder: (context) =>
      _LinkDialog(targets: targets, initialQuery: initialQuery),
);

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.targets, required this.initialQuery});

  final List<NoteLinkTarget> targets;
  final String initialQuery;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.toLowerCase().trim();
    final matches =
        widget.targets
            .where(
              (target) =>
                  target.title.toLowerCase().contains(query) ||
                  target.aliases.any(
                    (alias) => alias.toLowerCase().contains(query),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    return AlertDialog(
      title: const Text('Link to an object'),
      content: SizedBox(
        width: 460,
        height: 350,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              controller: _query,
              decoration: const InputDecoration(
                hintText: 'Search by title or alias',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (matches.length == 1) {
                  Navigator.pop(context, matches.single);
                }
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No matching objects'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final target = matches[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.link_rounded, size: 20),
                          title: Text(target.title),
                          subtitle: Text(
                            target.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          onTap: () => Navigator.pop(context, target),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
