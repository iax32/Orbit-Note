import '../../domain/universal_object.dart';
import '../../domain/life_workspace.dart';
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import 'note_templates.dart';
import 'creative_brief_dialog.dart';
import 'technical_article_template_dialog.dart';

/// One searchable library for new notes and insertion into an existing note.
class NoteTemplateDialog extends StatefulWidget {
  const NoteTemplateDialog({
    super.key,
    this.insertMode = false,
    this.personalTemplates = const [],
  });
  final bool insertMode;
  final List<UniversalObject> personalTemplates;
  static Future<NoteTemplate?> show(
    BuildContext context, {
    bool insertMode = false,
    List<UniversalObject> personalTemplates = const [],
  }) => showDialog<NoteTemplate>(
    context: context,
    builder: (_) => NoteTemplateDialog(
      insertMode: insertMode,
      personalTemplates: personalTemplates,
    ),
  );
  @override
  State<NoteTemplateDialog> createState() => _NoteTemplateDialogState();
}

class _NoteTemplateDialogState extends State<NoteTemplateDialog> {
  final _search = TextEditingController();
  final _title = TextEditingController();
  final _date = DateTime.now();
  NoteTemplate _selected = NoteTemplates.all.first;
  NoteTemplateCategory? _category;
  bool _preview = false, _choosing = false;

  late final _personal = [
    for (final o in widget.personalTemplates)
      if (lifeKind(o) == LifeKind.template &&
          lifeData(o)['templateFormat'] == 'note')
        NoteTemplate(
          id: 'personal:${o.id}',
          personalSourceId: o.id,
          name: o.title,
          description: 'Personal reusable note',
          icon: Icons.bookmark_outline,
          defaultTitle: o.title,
          body: o.body,
          customizable: true,
          categoryOverride: NoteTemplateCategory.life,
        ),
  ];
  List<NoteTemplate> get _filtered => [
    ...NoteTemplates.search(_search.text, category: _category),
    ..._personal.where(
      (p) =>
          (_category == null || p.category == _category) &&
          p.name.toLowerCase().contains(_search.text.toLowerCase()),
    ),
  ];
  NoteTemplate get _prepared =>
      _selected.instantiate(title: _title.text, date: _date);

  void _filter() => setState(() {
    final options = _filtered;
    if (options.isNotEmpty && !options.contains(_selected)) {
      _select(options.first);
    }
  });
  void _select(NoteTemplate template) {
    _selected = template;
    _title.text = template.defaultTitle;
  }

  Future<void> _choose() async {
    if (_choosing || _filtered.isEmpty) return;
    setState(() => _choosing = true);
    try {
      final result = _selected.id == 'creative_brief'
          ? await showDialog<NoteTemplate>(
              context: context,
              builder: (_) => const CreativeBriefDialog(),
            )
          : _selected.id.startsWith('article_')
          ? await showDialog<NoteTemplate>(
              context: context,
              builder: (_) => TechnicalArticleTemplateDialog(
                template: _selected,
                insertMode: widget.insertMode,
              ),
            )
          : _prepared;
      if (mounted && result != null) Navigator.of(context).pop(result);
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final theme = Theme.of(context);
    final options = _filtered;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 740 &&
                MediaQuery.textScalerOf(context).scale(14) < 23;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.insertMode
                            ? 'Insert Markdown Template'
                            : 'New Note from Template',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close templates',
                      onPressed: _choosing
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextField(
                  key: const ValueKey('note-template-search-field'),
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => _filter(),
                  decoration: InputDecoration(
                    labelText: 'Search templates',
                    hintText: 'Try mind map, nature or prompt…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear template search',
                            onPressed: () {
                              _search.clear();
                              _filter();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('All templates'),
                          selected: _category == null,
                          onSelected: (_) {
                            _category = null;
                            _filter();
                          },
                        ),
                      ),
                      for (final category in NoteTemplateCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey('template-category-${category.name}'),
                            label: Text(category.label),
                            selected: _category == category,
                            onSelected: (_) {
                              _category = category;
                              _filter();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${options.length} templates · editable Markdown · works offline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.subtle,
                  ),
                ),
                if (!wide)
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Browse'),
                        selected: !_preview,
                        onSelected: (_) => setState(() => _preview = false),
                      ),
                      ChoiceChip(
                        label: const Text('Preview & details'),
                        selected: _preview,
                        onSelected: options.isEmpty
                            ? null
                            : (_) => setState(() => _preview = true),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            );
            final footer = Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _choosing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  key: const ValueKey('create-note-from-template-button'),
                  onPressed: options.isEmpty || _choosing ? null : _choose,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    widget.insertMode ? 'Insert Template' : 'Create Note',
                  ),
                ),
              ],
            );
            return Padding(
              padding: EdgeInsets.all(constraints.maxWidth < 480 ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) header,
                  Expanded(
                    child: wide
                        ? options.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching templates. Try another category or search.',
                                  ),
                                )
                              : Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 310,
                                      child: _list(options, colors, wide),
                                    ),
                                    const VerticalDivider(width: 24),
                                    Expanded(child: _details(colors)),
                                  ],
                                )
                        : CustomScrollView(
                            key: ValueKey(
                              'compact-template-${_preview ? "preview" : "browse"}',
                            ),
                            slivers: [
                              SliverToBoxAdapter(child: header),
                              if (options.isEmpty)
                                const SliverToBoxAdapter(
                                  child: Text(
                                    'No matching templates. Try another category or search.',
                                  ),
                                )
                              else if (_preview)
                                SliverToBoxAdapter(
                                  child: _detailContent(colors),
                                )
                              else
                                SliverList.builder(
                                  itemCount: options.length,
                                  itemBuilder: (context, index) =>
                                      _tile(options[index], colors, false),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  footer,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _list(List<NoteTemplate> options, OrbitColors colors, bool wide) =>
      ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) => _tile(options[index], colors, wide),
      );
  Widget _tile(NoteTemplate template, OrbitColors colors, bool wide) =>
      ListTile(
        key: ValueKey('template-item-${template.id}'),
        selected: template.id == _selected.id,
        selectedTileColor: colors.accent.withValues(alpha: .12),
        leading: Icon(template.icon, color: colors.subtle),
        title: Text(template.name),
        subtitle: Text(
          template.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => setState(() {
          _select(template);
          if (!wide) _preview = true;
        }),
      );

  Widget _details(OrbitColors colors) =>
      SingleChildScrollView(child: _detailContent(colors));
  Widget _detailContent(OrbitColors colors) => Column(
    key: ValueKey('template-preview-${_selected.id}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_selected.name, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(_selected.description),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final tag in _selected.tags)
            Text('#$tag', style: TextStyle(color: colors.subtle)),
        ],
      ),
      if (_selected.customizable) ...[
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('template-custom-title'),
          controller: _title,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Note title'),
        ),
        Text(
          'Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const Divider(height: 24),
      const Text(
        'Markdown preview',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SelectableText(
        _prepared.body.isEmpty ? '(Empty document)' : _prepared.body,
        style: const TextStyle(fontSize: 13, height: 1.6),
      ),
    ],
  );
}
