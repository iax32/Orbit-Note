import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/orbit_components.dart';
import '../../canvas/diagram_import.dart';
import '../../canvas/geometry.dart';

/// Interactive modal for importing diagrams, canvas snippets, outlines, and templates.
class CanvasImportDialog extends StatefulWidget {
  const CanvasImportDialog({super.key, required this.center, this.idGenerator});

  final CanvasPoint center;
  final String Function()? idGenerator;

  static Future<DiagramImportResult?> show(
    BuildContext context, {
    required CanvasPoint center,
    String Function()? idGenerator,
  }) {
    return showOrbitDialog<DiagramImportResult>(
      context: context,
      builder: (_) =>
          CanvasImportDialog(center: center, idGenerator: idGenerator),
    );
  }

  @override
  State<CanvasImportDialog> createState() => _CanvasImportDialogState();
}

class _CanvasImportDialogState extends State<CanvasImportDialog> {
  int _selectedTab = 0; // 0: Templates, 1: Mermaid, 2: Outline, 3: File

  // Mermaid tab state
  late final TextEditingController _mermaidCtrl;
  String _mermaidFeedback = '';

  // Outline tab state
  late final TextEditingController _outlineCtrl;
  OutlineDiagramLayout _outlineLayout = OutlineDiagramLayout.mindMap;

  // File import state
  String? _loadedFileName;
  String? _loadedFileContent;
  String _fileFeedback = '';

  // Templates state
  String _templateFilter = 'All';

  @override
  void initState() {
    super.initState();
    _mermaidCtrl = TextEditingController(
      text:
          'graph TD\n'
          '  Start([Start Process]) --> Validate{Is Valid?}\n'
          '  Validate -->|Yes| Process[Execute Logic]\n'
          '  Validate -->|No| Error[Log Error]\n'
          '  Process --> Finish([Complete])\n'
          '  Error --> Finish',
    );
    _updateMermaidFeedback();
    _mermaidCtrl.addListener(_updateMermaidFeedback);

    _outlineCtrl = TextEditingController(
      text:
          '# Orbit Knowledge Hub\n'
          '- Architecture\n'
          '  - SQLite Storage\n'
          '  - Markdown Vault\n'
          '  - Local First\n'
          '- Universal Canvas\n'
          '  - Spatial Ink\n'
          '  - Flowcharts\n'
          '  - Connected Notes\n'
          '- Research\n'
          '  - PDF Annotations\n'
          '  - Passage Links\n'
          '- AI Engine\n'
          '  - Local Search\n'
          '  - Reversible Edits',
    );
  }

  @override
  void dispose() {
    _mermaidCtrl.removeListener(_updateMermaidFeedback);
    _mermaidCtrl.dispose();
    _outlineCtrl.dispose();
    super.dispose();
  }

  void _updateMermaidFeedback() {
    final text = _mermaidCtrl.text;
    if (text.trim().isEmpty) {
      setState(() => _mermaidFeedback = 'Enter Mermaid flowchart code.');
      return;
    }
    final parsed = parseMermaidFlowchart(
      text,
      origin: widget.center,
      idGenerator: widget.idGenerator,
    );
    final nodeCount = parsed.elements
        .where((e) => e.type != 'connector')
        .length;
    final edgeCount = parsed.elements
        .where((e) => e.type == 'connector')
        .length;
    setState(() {
      _mermaidFeedback = '$nodeCount nodes · $edgeCount connections detected';
    });
  }

  void _applyMermaidSample(String type) {
    String sample;
    switch (type) {
      case 'decision':
        sample =
            'graph TD\n'
            '  A([User Request]) --> B{Authenticated?}\n'
            '  B -->|Yes| C[Process Request]\n'
            '  B -->|No| D[Redirect to Login]\n'
            '  C --> E{Data Valid?}\n'
            '  E -->|Yes| F[(Save to DB)]\n'
            '  E -->|No| G[Return 422 Error]\n'
            '  F --> H([200 OK Response])';
      case 'architecture':
        sample =
            'graph LR\n'
            '  Web[Web App] --> Gateway[API Gateway]\n'
            '  Mobile[Mobile App] --> Gateway\n'
            '  Gateway --> Auth[Auth Service]\n'
            '  Gateway --> Core[Core Engine]\n'
            '  Core --> Cache[(Redis Cache)]\n'
            '  Core --> DB[(PostgreSQL)]';
      case 'stateloop':
        sample =
            'graph TD\n'
            '  Idle([Idle State]) --> Scan[Scan Environment]\n'
            '  Scan --> Target{Target Found?}\n'
            '  Target -->|Yes| Engage[Engage Target]\n'
            '  Target -->|No| Idle\n'
            '  Engage --> Result{Success?}\n'
            '  Result -->|Yes| Loot[Collect Reward]\n'
            '  Result -->|No| Retreat[Retreat to Safe Area]\n'
            '  Loot --> Idle\n'
            '  Retreat --> Idle';
      default:
        sample =
            'graph TD\n'
            '  A[Step 1] --> B[Step 2]\n'
            '  B --> C[Step 3]';
    }
    _mermaidCtrl.text = sample;
  }

  Future<void> _pickImportFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Diagram & Canvas Files',
            extensions: ['json', 'mermaid', 'mmd', 'txt', 'svg'],
          ),
        ],
      );
      if (file == null) return;

      final content = await file.readAsString();
      final name = file.name;

      DiagramImportResult result;
      if (name.endsWith('.json') ||
          content.trim().startsWith('{') ||
          content.trim().startsWith('[')) {
        result = parseCanvasJson(
          content,
          targetCenter: widget.center,
          idGenerator: widget.idGenerator,
        );
      } else if (name.endsWith('.svg') || content.contains('<svg')) {
        result = parseSvgDiagram(
          content,
          targetCenter: widget.center,
          idGenerator: widget.idGenerator,
        );
      } else {
        result = parseMermaidFlowchart(
          content,
          origin: widget.center,
          idGenerator: widget.idGenerator,
        );
      }

      setState(() {
        _loadedFileName = name;
        _loadedFileContent = content;
        _fileFeedback = result.summary;
      });
    } catch (e) {
      setState(() {
        _fileFeedback = 'Failed to load file: $e';
      });
    }
  }

  void _finishImport(DiagramImportResult result) {
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return OrbitDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome_mosaic_outlined, size: 20),
          SizedBox(width: 8),
          Text('Import Diagrams & Content'),
        ],
      ),
      content: SizedBox(
        width: 540,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tabs Header
            Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _tabButton(
                    0,
                    'Templates',
                    Icons.dashboard_customize_outlined,
                  ),
                  _tabButton(1, 'Mermaid', Icons.account_tree_outlined),
                  _tabButton(2, 'Outline', Icons.hub_outlined),
                  _tabButton(3, 'File', Icons.file_upload_outlined),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tab Content
            Expanded(
              child: switch (_selectedTab) {
                0 => _buildTemplatesTab(colors),
                1 => _buildMermaidTab(colors),
                2 => _buildOutlineTab(colors),
                3 => _buildFileTab(colors),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Material(
        color: isSelected ? colors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplatesTab(ColorScheme colors) {
    final allTemplates = getDiagramTemplates();
    final categories = ['All', ...allTemplates.map((t) => t.category).toSet()];
    final filtered = _templateFilter == 'All'
        ? allTemplates
        : allTemplates.where((t) => t.category == _templateFilter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isSel = _templateFilter == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _templateFilter = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final tmpl = filtered[idx];
              return Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconFromName(tmpl.iconName),
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tmpl.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tmpl.category,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tmpl.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Insert',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        final elements = tmpl.generator(
                          widget.center,
                          idGenerator: widget.idGenerator,
                        );
                        CanvasBounds? b;
                        for (final e in elements) {
                          b = b?.union(e.bounds) ?? e.bounds;
                        }
                        final gid =
                            elements.first.groupId ??
                            'grp_${DateTime.now().millisecondsSinceEpoch}';
                        _finishImport(
                          DiagramImportResult(
                            elements: elements,
                            groupId: gid,
                            elementIds: elements.map((e) => e.id).toSet(),
                            summary:
                                'Inserted "${tmpl.name}" diagram (${elements.length} elements).',
                            bounds:
                                b ??
                                CanvasBounds(
                                  widget.center.x,
                                  widget.center.y,
                                  0,
                                  0,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMermaidTab(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'MERMAID FLOWCHART CODE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              popUpAnimationStyle: OrbitMotionScope.popupStyle(context),
              tooltip: 'Load Sample',
              onSelected: _applyMermaidSample,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'decision',
                  child: Text('Decision & Auth Flow'),
                ),
                PopupMenuItem(
                  value: 'architecture',
                  child: Text('Client/Gateway Architecture'),
                ),
                PopupMenuItem(
                  value: 'stateloop',
                  child: Text('AI/Game State Loop'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.code, size: 14, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Load Sample',
                      style: TextStyle(fontSize: 11, color: colors.primary),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TextField(
            controller: _mermaidCtrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'graph TD\n  A[Start] --> B[Process] --> C([End])',
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _mermaidFeedback,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download_done_rounded, size: 16),
              label: const Text('Import Mermaid'),
              onPressed: () {
                final res = parseMermaidFlowchart(
                  _mermaidCtrl.text,
                  origin: widget.center,
                  idGenerator: widget.idGenerator,
                );
                _finishImport(res);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutlineTab(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'INDENTED OUTLINE / NOTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.lightbulb_outline, size: 14),
              label: const Text(
                'Reset Outline',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () {
                _outlineCtrl.text =
                    '# Orbit Knowledge Hub\n'
                    '- Architecture\n'
                    '  - SQLite Storage\n'
                    '  - Markdown Vault\n'
                    '  - Local First\n'
                    '- Universal Canvas\n'
                    '  - Spatial Ink\n'
                    '  - Flowcharts\n'
                    '  - Connected Notes\n'
                    '- Research\n'
                    '  - PDF Annotations\n'
                    '  - Passage Links\n'
                    '- AI Engine\n'
                    '  - Local Search\n'
                    '  - Reversible Edits';
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TextField(
            controller: _outlineCtrl,
            maxLines: null,
            expands: true,
            style: const TextStyle(fontSize: 12, height: 1.4),
            decoration: InputDecoration(
              hintText: '# Title\n- Subtopic A\n  - Detail 1\n- Subtopic B',
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Layout: ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            ChoiceChip(
              label: const Text(
                'Radial Mind Map',
                style: TextStyle(fontSize: 11),
              ),
              selected: _outlineLayout == OutlineDiagramLayout.mindMap,
              onSelected: (v) {
                if (v) {
                  setState(() => _outlineLayout = OutlineDiagramLayout.mindMap);
                }
              },
            ),
            ChoiceChip(
              label: const Text(
                'Tree (Horizontal)',
                style: TextStyle(fontSize: 11),
              ),
              selected: _outlineLayout == OutlineDiagramLayout.treeHorizontal,
              onSelected: (v) {
                if (v) {
                  setState(
                    () => _outlineLayout = OutlineDiagramLayout.treeHorizontal,
                  );
                }
              },
            ),
            ChoiceChip(
              label: const Text(
                'Tree (Vertical)',
                style: TextStyle(fontSize: 11),
              ),
              selected: _outlineLayout == OutlineDiagramLayout.treeVertical,
              onSelected: (v) {
                if (v) {
                  setState(
                    () => _outlineLayout = OutlineDiagramLayout.treeVertical,
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('Generate Diagram'),
              onPressed: () {
                final res = parseOutlineDiagram(
                  _outlineCtrl.text,
                  origin: widget.center,
                  layout: _outlineLayout,
                  idGenerator: widget.idGenerator,
                );
                _finishImport(res);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileTab(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 40,
                color: colors.primary,
              ),
              const SizedBox(height: 8),
              const Text(
                'Import Diagram or Canvas File',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Supports Orbit Canvas JSON, Mermaid (.mermaid, .mmd, .txt), and SVG vector diagrams.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Choose File...'),
                onPressed: _pickImportFile,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadedFileName != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loadedFileName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _fileFeedback,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.file_download_done, size: 18),
            label: const Text('Import Loaded File to Canvas'),
            onPressed: () {
              if (_loadedFileContent == null) return;
              final name = _loadedFileName ?? '';
              final content = _loadedFileContent!;

              DiagramImportResult result;
              if (name.endsWith('.json') ||
                  content.trim().startsWith('{') ||
                  content.trim().startsWith('[')) {
                result = parseCanvasJson(
                  content,
                  targetCenter: widget.center,
                  idGenerator: widget.idGenerator,
                );
              } else if (name.endsWith('.svg') || content.contains('<svg')) {
                result = parseSvgDiagram(
                  content,
                  targetCenter: widget.center,
                  idGenerator: widget.idGenerator,
                );
              } else {
                result = parseMermaidFlowchart(
                  content,
                  origin: widget.center,
                  idGenerator: widget.idGenerator,
                );
              }
              _finishImport(result);
            },
          ),
        ] else ...[
          const Spacer(),
          Text(
            'Tip: You can also paste Mermaid code in the Mermaid tab or use the pre-built diagram templates.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'call_split':
        return Icons.call_split;
      case 'cloud_outlined':
        return Icons.cloud_outlined;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'schema_outlined':
        return Icons.schema_outlined;
      case 'psychology_outlined':
        return Icons.psychology_outlined;
      case 'hub_outlined':
        return Icons.hub_outlined;
      case 'timeline':
        return Icons.timeline;
      default:
        return Icons.account_tree_outlined;
    }
  }
}
