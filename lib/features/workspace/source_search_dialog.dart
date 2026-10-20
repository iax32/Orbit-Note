import 'package:flutter/material.dart';
import '../../application/source_search.dart';
import '../../domain/source_browser.dart';
import '../../platform/source_folder.dart';

class SourceSearchDialog extends StatefulWidget {
  const SourceSearchDialog({
    super.key,
    required this.folder,
    required this.files,
    this.incompleteListing = false,
  });
  final SourceFolder folder;
  final List<SourceFileEntry> files;
  final bool incompleteListing;
  @override
  State<SourceSearchDialog> createState() => _SourceSearchDialogState();
}

class _SourceSearchDialogState extends State<SourceSearchDialog> {
  final query = TextEditingController(), path = TextEditingController();
  bool sensitive = false, wholeWord = false, busy = false;
  int generation = 0, processed = 0, total = 0, found = 0;
  SourceSearchResult? result;
  String? error;
  @override
  void dispose() {
    generation++;
    query.dispose();
    path.dispose();
    super.dispose();
  }

  void cancel() => setState(() {
    generation++;
    busy = false;
  });
  Future<void> search() async {
    final token = ++generation;
    setState(() {
      busy = true;
      result = null;
      error = null;
      processed = found = 0;
      total = widget.files.length;
    });
    try {
      final next = await searchSourceFiles(
        files: widget.files,
        read: widget.folder.read,
        query: query.text,
        pathFilter: path.text,
        wholeWord: wholeWord,
        caseSensitive: sensitive,
        cancelled: () => !mounted || token != generation,
        progress: (n, count, hits) {
          if (mounted && token == generation && (n % 10 == 0 || n == count)) {
            setState(() {
              processed = n;
              total = count;
              found = hits;
            });
          }
        },
      );
      if (!mounted) return;
      // Cancelled results remain useful, but never overwrite a subsequent search.
      if (token != generation && (busy || token + 1 != generation)) return;
      setState(() {
        result = next;
        busy = false;
      });
    } on Object catch (e) {
      if (mounted && token == generation) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Search source folder',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    TextField(
                      controller: query,
                      enabled: !busy,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        labelText: 'Find across source files',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: path,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Path contains (optional)',
                        hintText: 'src/ or .cpp',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          label: const Text('Match case'),
                          selected: sensitive,
                          onSelected: busy
                              ? null
                              : (v) => setState(() => sensitive = v),
                        ),
                        FilterChip(
                          label: const Text('Whole word'),
                          selected: wholeWord,
                          onSelected: busy
                              ? null
                              : (v) => setState(() => wholeWord = v),
                        ),
                        FilledButton.icon(
                          onPressed: busy ? null : search,
                          icon: const Icon(Icons.search),
                          label: const Text('Search files'),
                        ),
                        if (busy)
                          TextButton(
                            onPressed: cancel,
                            child: const Text('Cancel search'),
                          ),
                      ],
                    ),
                    if (busy) ...[
                      LinearProgressIndicator(
                        value: total == 0 ? null : processed / total,
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '$processed / $total files · $found matching lines',
                        ),
                      ),
                    ],
                    if (widget.incompleteListing)
                      const Text(
                        'The folder listing is incomplete. Search covers listed files only.',
                      ),
                    if (error != null)
                      Semantics(liveRegion: true, child: Text(error!)),
                    if (result != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${result!.hits.length} matching lines · ${result!.processed} / ${result!.total} files checked'
                          '${result!.cancelled ? ' · Cancelled; partial results' : ''}'
                          '${result!.truncated ? ' · Search limit reached; narrow the path or query' : ''}'
                          '${result!.skipped.isEmpty ? '' : ' · ${result!.skipped.length} unreadable files skipped'}',
                        ),
                      ),
                    if (result?.skipped.isNotEmpty == true)
                      ExpansionTile(
                        title: const Text('Skipped files'),
                        children: [
                          for (final f in result!.skipped.take(20)) Text(f),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: result == null
                ? const Center(
                    child: Text(
                      'Search code, shaders, scripts and extracted text.',
                    ),
                  )
                : result!.hits.isEmpty
                ? const Center(
                    child: Text('No matching lines in the checked files.'),
                  )
                : ListView.builder(
                    itemCount: result!.hits.length,
                    itemBuilder: (_, i) {
                      final hit = result!.hits[i];
                      return ListTile(
                        key: ValueKey(
                          'source-search-${hit.file.path}-${hit.line}',
                        ),
                        title: Text('${hit.file.path}:${hit.line}'),
                        subtitle: Text(
                          hit.preview,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        trailing: const Icon(Icons.arrow_forward, size: 18),
                        onTap: () => Navigator.pop(context, hit),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
