import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../domain/code_preview.dart';
import '../notes/rich/code_block.dart';

class CodeFilePreview extends StatefulWidget {
  const CodeFilePreview({
    super.key,
    required this.title,
    required this.language,
    required this.loadBytes,
    required this.onOpenOriginal,
  });
  final String title, language;
  final Future<Uint8List?> Function() loadBytes;
  final VoidCallback onOpenOriginal;
  @override
  State<CodeFilePreview> createState() => _CodeFilePreviewState();
}

class _CodeFilePreviewState extends State<CodeFilePreview> {
  late final Future<String> _source = _load();
  Future<String> _load() async {
    final bytes = await widget.loadBytes();
    if (bytes == null) {
      throw const FormatException(
        'The original file is unavailable. Its reference is preserved.',
      );
    }
    return decodeCodePreview(bytes);
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: OrbitColors.of(context).background),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OrbitColors.of(context).raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.code_rounded,
                  color: OrbitColors.of(context).accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'SOURCE FILE  ·  READ ONLY',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OrbitColors.of(context).muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open original externally',
                onPressed: widget.onOpenOriginal,
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<String>(
            future: _source,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: SelectableText('${snapshot.error}'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: NoteCodeBlock(
                  code: snapshot.data!,
                  language: widget.language,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
