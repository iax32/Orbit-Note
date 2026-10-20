import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../domain/technical_article.dart';
import 'note_templates.dart';

class TechnicalArticleTemplateDialog extends StatefulWidget {
  const TechnicalArticleTemplateDialog({
    super.key,
    required this.template,
    this.insertMode = false,
  });
  final NoteTemplate template;
  final bool insertMode;
  @override
  State<TechnicalArticleTemplateDialog> createState() =>
      _TechnicalArticleTemplateDialogState();
}

class _TechnicalArticleTemplateDialogState
    extends State<TechnicalArticleTemplateDialog> {
  late final fields = <String, TextEditingController>{
    'Article title': TextEditingController(text: widget.template.defaultTitle),
    for (final label in [
      'Author',
      'Audience',
      'Research question',
      'Game / target',
      'Build / version',
      'Architecture',
      'Tools',
    ])
      label: TextEditingController(),
  };
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void create() {
    if (fields.values.any((c) => c.text.length > 500) ||
        fields['Article title']!.text.trim().isEmpty ||
        fields.values.any((c) => c.text.contains(RegExp(r'[\x00-\x1f]')))) {
      setState(
        () => error = 'Add a title and keep each detail under 500 characters.',
      );
      return;
    }
    String value(String name) =>
        fields[name]!.text.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
    final heading = value('Article title').replaceAll(RegExp(r'[#<>]'), '');
    final body = StringBuffer('# $heading\n\n');
    for (final name in fields.keys.skip(1)) {
      if (value(name).isNotEmpty) body.writeln('**$name:** ${value(name)}  ');
    }
    body.write('\n${widget.template.body}');
    final metadata = ArticleMetadata({
      'version': 1,
      'title': value('Article title'),
      'author': value('Author'),
      'language': 'en',
      'indexable': true,
    });
    Navigator.pop(
      context,
      NoteTemplate(
        id: widget.template.id,
        name: widget.template.name,
        description: widget.template.description,
        icon: widget.template.icon,
        defaultTitle: value('Article title'),
        body: widget.insertMode
            ? body.toString()
            : metadata.apply(body.toString()),
        tags: widget.template.tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: Text(widget.template.name),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Start with the investigation and your reader. These details become editable Markdown; publishing metadata stays portable with the note.',
            ),
            const SizedBox(height: 16),
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  key: ValueKey('article-template-${entry.key}'),
                  controller: entry.value,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: entry.key,
                    counterText: '',
                    hintText: entry.key == 'Article title' ? null : 'Optional',
                  ),
                ),
              ),
            if (error != null) Text(error!, semanticsLabel: error),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: create, child: const Text('Create article')),
    ],
  );
}
