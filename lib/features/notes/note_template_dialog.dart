import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import 'note_templates.dart';
import 'creative_brief_dialog.dart';

/// Modal dialog allowing users to choose or preview a structured Markdown note template.
class NoteTemplateDialog extends StatefulWidget {
  const NoteTemplateDialog({super.key, this.insertMode = false});

  /// If true, the dialog is used to insert markdown into an existing open document.
  final bool insertMode;

  static Future<NoteTemplate?> show(
    BuildContext context, {
    bool insertMode = false,
  }) {
    return showDialog<NoteTemplate>(
      context: context,
      builder: (_) => NoteTemplateDialog(insertMode: insertMode),
    );
  }

  @override
  State<NoteTemplateDialog> createState() => _NoteTemplateDialogState();
}

class _NoteTemplateDialogState extends State<NoteTemplateDialog> {
  final TextEditingController _searchController = TextEditingController();
  NoteTemplate _selectedTemplate = NoteTemplates.all.first;
  String _searchQuery = '';

  Future<void> _choose(NoteTemplate template) async {
    final result = template.id == 'creative_brief'
        ? await showDialog<NoteTemplate>(
            context: context,
            builder: (_) => const CreativeBriefDialog(),
          )
        : template;
    if (mounted && result != null) Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = OrbitColors.of(context);
    final filtered = NoteTemplates.search(_searchQuery);

    // Keep selection valid if filtered list changes
    if (!filtered.contains(_selectedTemplate) && filtered.isNotEmpty) {
      _selectedTemplate = filtered.first;
    }

    final isWide = MediaQuery.of(context).size.width >= 720;

    return Dialog(
      backgroundColor: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.insertMode
                          ? Icons.add_circle_outline
                          : Icons.auto_stories_outlined,
                      size: 18,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.insertMode
                              ? 'Insert Markdown Template'
                              : 'New Note from Template',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.insertMode
                              ? 'Select a structured section to append at your current caret position.'
                              : 'Choose a structured starting point for your notes, study, or projects.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Filter Bar
              TextField(
                key: const ValueKey('note-template-search-field'),
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search templates by title, tag, or description…',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: colors.panel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
                onChanged: (q) => setState(() => _searchQuery = q),
              ),
              const SizedBox(height: 16),

              // Main Content Area (Two Columns if Wide)
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Template list
                          SizedBox(
                            width: 290,
                            child: _buildTemplateList(filtered, colors),
                          ),
                          const SizedBox(width: 16),
                          // Detail & Preview Pane
                          Expanded(child: _buildPreviewPane(colors, theme)),
                        ],
                      )
                    : _buildTemplateList(filtered, colors),
              ),
              const SizedBox(height: 16),

              // Footer Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const ValueKey('create-note-from-template-button'),
                    onPressed: filtered.isNotEmpty
                        ? () => _choose(_selectedTemplate)
                        : null,
                    icon: Icon(
                      widget.insertMode ? Icons.add : Icons.check,
                      size: 16,
                    ),
                    label: Text(
                      widget.insertMode ? 'Insert Template' : 'Create Note',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateList(List<NoteTemplate> templates, OrbitColors colors) {
    if (templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 36, color: colors.subtle),
              const SizedBox(height: 8),
              Text(
                'No matching templates found',
                style: TextStyle(fontSize: 13, color: colors.subtle),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: templates.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          itemBuilder: (context, idx) {
            final template = templates[idx];
            final isSelected = template.id == _selectedTemplate.id;

            return InkWell(
              key: ValueKey('template-item-${template.id}'),
              onTap: () {
                setState(() => _selectedTemplate = template);
              },
              onDoubleTap: () {
                _choose(template);
              },
              child: Container(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.25)
                            : colors.raised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        template.icon,
                        size: 16,
                        color: isSelected ? colors.accent : colors.subtle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected ? colors.accent : null,
                            ),
                          ),
                          Text(
                            template.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (template.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '#${template.tags.first}',
                          style: TextStyle(fontSize: 10, color: colors.subtle),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewPane(OrbitColors colors, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Row(
            children: [
              Icon(_selectedTemplate.icon, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTemplate.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final tag in _selectedTemplate.tags)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedTemplate.description,
            style: TextStyle(fontSize: 12, color: colors.subtle),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          // Preview Body Scroll
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _selectedTemplate.body.isEmpty
                      ? '(Empty document)'
                      : _selectedTemplate.body,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: _selectedTemplate.body.isEmpty
                        ? colors.subtle
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
