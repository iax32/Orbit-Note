import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import 'block_formatting.dart';

class BlockFormatDialog extends StatefulWidget {
  const BlockFormatDialog({super.key});
  @override
  State<BlockFormatDialog> createState() => _BlockFormatDialogState();
}

class _BlockFormatDialogState extends State<BlockFormatDialog> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final formats = noteBlockFormats
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return OrbitDialog(
      title: const Text('Format block'),
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Format the current block or selected complete blocks. Inline formatting and source links are retained. Structured content keeps its own editing tools.',
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Find a block style',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (s) => setState(() => query = s),
                onSubmitted: (_) {
                  if (formats.length == 1) {
                    Navigator.pop(context, formats.single);
                  }
                },
              ),
              if (formats.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No matching block styles.'),
                ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => ListTile(
              title: Text(formats[i]),
              leading: Icon(
                formats[i].contains('callout') || formats[i] == 'BTW block'
                    ? Icons.chat_bubble_outline
                    : Icons.format_align_left,
              ),
              onTap: () => Navigator.pop(context, formats[i]),
            ),
            childCount: formats.length,
          ),
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
