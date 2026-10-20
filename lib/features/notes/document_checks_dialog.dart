import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../domain/knowledge_insights.dart';

class DocumentCheckChoice {
  const DocumentCheckChoice(this.finding, {this.repair = false});
  final DocumentFinding finding;
  final bool repair;
}

class DocumentChecksDialog extends StatefulWidget {
  const DocumentChecksDialog({
    super.key,
    required this.source,
    required this.findings,
    required this.hasVault,
    this.canRepair = false,
  });
  final String source;
  final List<DocumentFinding> findings;
  final bool hasVault;
  final bool canRepair;
  @override
  State<DocumentChecksDialog> createState() => _DocumentChecksDialogState();
}

class _DocumentChecksDialogState extends State<DocumentChecksDialog> {
  String category = 'All';
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final rows = widget.findings
        .where((f) => category == 'All' || f.kind == category)
        .toList();
    final pages = (rows.length / 30).ceil().clamp(1, 1000000);
    return OrbitDialog(
      maxWidth: 720,
      title: const Text('Document Checks'),
      contentSlivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.findings.length} findings in the current document snapshot. Checks leave your text unchanged.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Inspect links, footnote definitions and heading hierarchy. Findings are suggestions to review, not grammar judgments. Open a finding in Source to inspect its exact Markdown.',
              ),
              if (widget.canRepair)
                const Text(
                  'Use the link button to choose a replacement source. Repair preserves the written label and page/section fragment; check that location in the chosen source.',
                ),
              if (!widget.hasVault)
                const Text(
                  'Vault link checks are unavailable in this standalone editor.',
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final label in [
                    'All',
                    'Links',
                    'Footnotes',
                    'Structure',
                  ])
                    ChoiceChip(
                      label: Text(
                        '$label (${label == 'All' ? widget.findings.length : widget.findings.where((f) => f.kind == label).length})',
                      ),
                      selected: label == category,
                      onSelected: (_) => setState(() {
                        category = label;
                        page = 0;
                      }),
                    ),
                ],
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No findings in this category. These checks do not validate every Markdown form or external URL.',
                  ),
                ),
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final finding = rows[page * 30 + i];
            final line =
                '\n'
                    .allMatches(widget.source.substring(0, finding.start))
                    .length +
                1;
            return ListTile(
              title: Text(finding.message),
              subtitle: Text('${finding.kind} · Line $line'),
              trailing: widget.canRepair && finding.kind == 'Links'
                  ? IconButton(
                      tooltip: 'Choose a source for this link',
                      icon: const Icon(Icons.link),
                      onPressed: () => Navigator.pop(
                        context,
                        DocumentCheckChoice(finding, repair: true),
                      ),
                    )
                  : const Icon(Icons.arrow_forward, size: 18),
              onTap: () => Navigator.pop(context, DocumentCheckChoice(finding)),
            );
          }, childCount: (rows.length - page * 30).clamp(0, 30)),
        ),
        SliverToBoxAdapter(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous findings page',
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 0 ? () => setState(() => page--) : null,
              ),
              Text('${rows.length} findings · Page ${page + 1} of $pages'),
              IconButton(
                tooltip: 'Next findings page',
                icon: const Icon(Icons.chevron_right),
                onPressed: page + 1 < pages
                    ? () => setState(() => page++)
                    : null,
              ),
            ],
          ),
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
