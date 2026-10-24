import '../../app/orbit_motion_effects.dart';
import 'package:flutter/material.dart';
import '../../domain/document_review.dart';
import '../../app/orbit_theme.dart';

enum ReviewFilter { open, comments, suggestions, all }

class DocumentReviewPanel extends StatefulWidget {
  const DocumentReviewPanel({
    super.key,
    required this.source,
    required this.onAction,
    required this.onJump,
    required this.onAdd,
    required this.onClose,
  });
  final String source;
  final void Function(String id, String action) onAction;
  final ValueChanged<ReviewAnnotation> onJump;
  final ValueChanged<bool> onAdd;
  final VoidCallback onClose;
  @override
  State<DocumentReviewPanel> createState() => _DocumentReviewPanelState();
}

class _DocumentReviewPanelState extends State<DocumentReviewPanel> {
  ReviewFilter filter = ReviewFilter.open;
  @override
  Widget build(BuildContext context) {
    final reviews = documentReviews(widget.source);
    final shown = reviews
        .where(
          (r) => switch (filter) {
            ReviewFilter.open => r.isOpen,
            ReviewFilter.comments => r.kind == 'comment',
            ReviewFilter.suggestions => r.kind == 'suggestion',
            ReviewFilter.all => true,
          },
        )
        .toList();
    final colors = OrbitColors.of(context);
    return ColoredBox(
      color: colors.panel,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Document review',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close document review',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => widget.onAdd(false),
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('Comment'),
                      ),
                      TextButton.icon(
                        onPressed: () => widget.onAdd(true),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Suggest edit'),
                      ),
                      DropdownButton<ReviewFilter>(
                        value: filter,
                        isExpanded: true,
                        items: [
                          for (final f in ReviewFilter.values)
                            DropdownMenuItem(
                              value: f,
                              child: Text(switch (f) {
                                ReviewFilter.open => 'Unresolved',
                                ReviewFilter.comments => 'Comments',
                                ReviewFilter.suggestions => 'Suggestions',
                                ReviewFilter.all => 'Everything',
                              }),
                            ),
                        ],
                        onChanged: (v) => setState(() => filter = v!),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No reviews in this filter. Select a passage to add a comment or suggest an edit.',
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (_, i) {
                final review = shown[i],
                    location = locateReview(widget.source, shown[i]);
                return OrbitEffect(
                  key: ValueKey(review.id),
                  trigger: (review.state, review.replacement),
                  family: 'smart',
                  style: 'highlight',
                  interactive: true,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${review.kind == 'comment' ? 'Comment' : 'Suggested edit'} · ${review.state}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          review.quote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        SelectableText(review.message),
                        if (review.kind == 'suggestion') ...[
                          const SizedBox(height: 12),
                          Text(
                            'Proposed wording',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          SelectableText(
                            review.replacement.isEmpty
                                ? '(Delete selected passage)'
                                : review.replacement,
                          ),
                        ],
                        if (location.warning != null && review.isOpen)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                location.warning!,
                                style: TextStyle(color: colors.secondary),
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: location.start == null
                                  ? null
                                  : () => widget.onJump(review),
                              child: const Text('Go to passage'),
                            ),
                            if (review.isOpen && review.kind == 'suggestion')
                              FilledButton(
                                onPressed: location.start == null
                                    ? null
                                    : () =>
                                          widget.onAction(review.id, 'accept'),
                                child: const Text('Accept'),
                              ),
                            if (review.isOpen)
                              TextButton(
                                onPressed: () => widget.onAction(
                                  review.id,
                                  review.kind == 'comment'
                                      ? 'resolved'
                                      : 'rejected',
                                ),
                                child: Text(
                                  review.kind == 'comment'
                                      ? 'Resolve'
                                      : 'Reject',
                                ),
                              ),
                            if (!review.isOpen && review.state != 'accepted')
                              TextButton(
                                onPressed: () =>
                                    widget.onAction(review.id, 'open'),
                                child: const Text('Reopen'),
                              ),
                            if (review.isOpen && location.start == null)
                              TextButton(
                                onPressed: () =>
                                    widget.onAction(review.id, 'reattach'),
                                child: const Text('Reattach to selection'),
                              ),
                            IconButton(
                              tooltip: 'Remove review annotation',
                              onPressed: () =>
                                  widget.onAction(review.id, 'remove'),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Local annotations · saved with this note',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<({String message, String? replacement})?> showReviewComposer(
  BuildContext context,
  String quote, {
  required bool suggestion,
}) => showDialog<({String message, String? replacement})>(
  context: context,
  builder: (_) => _ReviewComposer(quote: quote, suggestion: suggestion),
);

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer({required this.quote, required this.suggestion});
  final String quote;
  final bool suggestion;
  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  final message = TextEditingController();
  late final replacement = TextEditingController(text: widget.quote);
  @override
  void dispose() {
    message.dispose();
    replacement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.suggestion ? 'Suggest a replacement' : 'Comment on passage',
    ),
    scrollable: true,
    content: SizedBox(
      width: 600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Original passage',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(widget.quote),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('review-message'),
            controller: message,
            autofocus: true,
            maxLength: 4000,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Comment or rationale',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.suggestion)
            TextField(
              key: const ValueKey('review-replacement'),
              controller: replacement,
              minLines: 2,
              maxLines: 8,
              maxLength: 20000,
              decoration: const InputDecoration(
                labelText: 'Proposed Markdown',
                helperText:
                    'An empty replacement deletes the selected passage.',
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
      FilledButton(
        onPressed: message.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                message: message.text.trim(),
                replacement: widget.suggestion ? replacement.text : null,
              )),
        child: const Text('Save review'),
      ),
    ],
  );
}
