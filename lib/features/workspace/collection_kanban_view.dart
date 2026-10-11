import '../../app/orbit_density.dart';
import '../../domain/board_status.dart';
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

class CollectionKanbanView extends StatefulWidget {
  const CollectionKanbanView({
    super.key,
    required this.controller,
    required this.viewObject,
    this.folderFilter,
    this.scope,
  });

  final WorkspaceController controller;
  final UniversalObject viewObject;
  final String? folderFilter;
  final String? scope;

  @override
  State<CollectionKanbanView> createState() => _CollectionKanbanViewState();
}

class _CollectionKanbanViewState extends State<CollectionKanbanView> {
  late String _groupBy; // 'status', 'priority', 'project', 'folder', 'type'
  late String _preset;
  String _searchQuery = '';
  bool _tasksOnly = false;
  bool _hideEmpty = false;
  String? _peekObjectId;

  String? _inlineAddColumnId;
  final _inlineAddController = TextEditingController();
  final _inlineAddFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _groupBy = (widget.viewObject.properties['groupBy'] as String?) ?? 'status';
    _tasksOnly = widget.viewObject.properties['tasksOnly'] == true;
    _hideEmpty = widget.viewObject.properties['hideEmptyColumns'] == true;
    _preset =
        (widget.viewObject.properties['preset'] as String?) ?? 'universal';
  }

  @override
  void dispose() {
    _inlineAddController.dispose();
    _inlineAddFocus.dispose();
    super.dispose();
  }

  bool _isManualCollection() {
    return widget.viewObject.properties['manual'] == true ||
        widget.viewObject.properties['memberIds'] is List;
  }

  List<String> _getManualMemberIds() {
    final raw = widget.viewObject.properties['memberIds'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  bool _matchesScope(UniversalObject o) {
    if (o.isDeleted || o.typeId == 'orbit.view') return false;

    if (_isManualCollection()) {
      return _getManualMemberIds().contains(o.id);
    }

    final folder =
        widget.folderFilter ??
        (widget.viewObject.properties['folder'] as String?);
    final scopeVal =
        widget.scope ?? (widget.viewObject.properties['scope'] as String?);

    if (folder != null && folder.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == folder || f.startsWith('$folder/'))) {
        return true;
      }
      final p = widget.controller.repository.objectPath(o.id);
      if (p != null && (p == folder || p.startsWith('$folder/'))) {
        return true;
      }
      return false;
    }

    if (scopeVal != null && scopeVal.isNotEmpty) {
      final course = o.properties['course']?.toString().toLowerCase();
      final project = o.properties['project']?.toString().toLowerCase();
      final contextVal = o.properties['context']?.toString().toLowerCase();
      final lower = scopeVal.toLowerCase();
      if (course == lower || project == lower || contextVal == lower) {
        return true;
      }
      return false;
    }

    return true;
  }

  void _updateProperty(String key, dynamic value) {
    widget.controller.edit(
      widget.viewObject.id,
      properties: {
        ...(widget.controller.find(widget.viewObject.id)?.properties ??
            widget.viewObject.properties),
        key: value,
      },
    );
    setState(() {});
  }

  List<(String id, String label)> _computeColumns(
    List<UniversalObject> objects,
  ) {
    switch (_groupBy) {
      case 'priority':
        return const [
          ('urgent', '🔴 Urgent'),
          ('high', '🟠 High'),
          ('medium', '🔵 Medium'),
          ('low', '⚪ Low'),
          ('none', 'No Priority'),
        ];
      case 'project':
        final projects = <String>{};
        for (final o in objects) {
          final p = o.properties['project']?.toString().trim();
          if (p != null && p.isNotEmpty) projects.add(p);
        }
        final list = projects.toList()..sort();
        return [for (final pr in list) (pr, pr), ('none', 'No Project')];
      case 'folder':
        final folders = <String>{};
        for (final o in objects) {
          final f = o.properties['folder']?.toString().trim();
          if (f != null && f.isNotEmpty) folders.add(f);
        }
        final list = folders.toList()..sort();
        return [for (final f in list) (f, f), ('root', 'Root / Unfiled')];
      case 'type':
        return const [
          ('orbit.note', 'Notes'),
          ('orbit.task', 'Tasks'),
          ('orbit.canvas', 'Boards'),
          ('other', 'Other'),
        ];
      case 'status':
      default:
        final presetEnum = KanbanPreset.fromId(_preset);
        final baseCols = List<(String, String)>.from(presetEnum.columns);
        baseCols.add(('none', 'No Status'));
        return baseCols;
    }
  }

  String _getObjectColumnId(UniversalObject o, List<(String, String)> cols) {
    switch (_groupBy) {
      case 'priority':
        final pr = (o.properties['priority'] as String?)?.toLowerCase();
        if (pr != null && cols.any((c) => c.$1 == pr)) return pr;
        return 'none';
      case 'project':
        final p = o.properties['project']?.toString().trim();
        if (p != null && p.isNotEmpty && cols.any((c) => c.$1 == p)) return p;
        return 'none';
      case 'folder':
        final f = o.properties['folder']?.toString().trim();
        if (f != null && f.isNotEmpty && cols.any((c) => c.$1 == f)) return f;
        return 'root';
      case 'type':
        if (cols.any((c) => c.$1 == o.typeId)) return o.typeId;
        return 'other';
      case 'status':
      default:
        if (o.typeId == 'orbit.task' && o.isCompleted) {
          if (cols.any((c) => c.$1 == 'done')) return 'done';
          if (cols.any((c) => c.$1 == 'closed')) return 'closed';
        }
        final raw = boardStatus(o.properties['status'], cols.map((c) => c.$1));
        if (cols.any((c) => c.$1 == raw)) return raw;
        if (raw.contains('part') && cols.any((c) => c.$1 == 'partial')) {
          return 'partial';
        }
        return 'none';
    }
  }

  void _handleCardDrop(String objectId, String targetColId) {
    final obj = widget.controller.find(objectId);
    if (obj == null) return;

    switch (_groupBy) {
      case 'status':
        final isDone = targetColId == 'done' || targetColId == 'closed';
        final newStatus = targetColId == 'none' ? null : targetColId;
        widget.controller.edit(
          objectId,
          properties: {
            ...obj.properties,
            'status': newStatus,
            if (obj.typeId == 'orbit.task') 'completed': isDone,
          },
        );
        break;
      case 'priority':
        final newPriority = targetColId == 'none' ? null : targetColId;
        widget.controller.edit(
          objectId,
          properties: {...obj.properties, 'priority': newPriority},
        );
        break;
      case 'project':
        final newProject = targetColId == 'none' ? null : targetColId;
        widget.controller.edit(
          objectId,
          properties: {...obj.properties, 'project': newProject},
        );
        break;
      case 'folder':
        final newFolder = targetColId == 'root' ? null : targetColId;
        widget.controller.edit(
          objectId,
          properties: {...obj.properties, 'folder': newFolder},
        );
        break;
      case 'type':
        // Unsupported transition: changing object type via dragging is not allowed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Object type cannot be modified by dragging cards. Universal object identity is preserved.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
        break;
    }
  }

  Future<void> _submitInlineAdd(String colId) async {
    final text = _inlineAddController.text.trim();
    if (text.isEmpty) {
      setState(() => _inlineAddColumnId = null);
      return;
    }

    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject.properties['folder'] as String?) ??
        '';
    final effectiveScope =
        widget.scope ??
        (widget.viewObject.properties['scope'] as String?) ??
        '';

    final props = <String, dynamic>{
      if (effectiveFolder.isNotEmpty) 'folder': effectiveFolder,
      if (effectiveScope.isNotEmpty) 'project': effectiveScope,
    };

    String typeId = 'orbit.task';

    switch (_groupBy) {
      case 'status':
        if (colId != 'none') {
          props['status'] = colId;
          if (colId == 'done' || colId == 'closed') props['completed'] = true;
        }
        break;
      case 'priority':
        if (colId != 'none') props['priority'] = colId;
        break;
      case 'project':
        if (colId != 'none') props['project'] = colId;
        break;
      case 'folder':
        if (colId != 'root') props['folder'] = colId;
        break;
      case 'type':
        if (colId.startsWith('orbit.')) typeId = colId;
        break;
    }

    final newObj = await widget.controller.create(
      typeId,
      title: text,
      properties: props,
    );

    if (newObj != null && _isManualCollection()) {
      final members = List<String>.from(_getManualMemberIds())..add(newObj.id);
      _updateProperty('memberIds', members);
    }

    _inlineAddController.clear();
    setState(() => _inlineAddColumnId = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final isManual = _isManualCollection();

    // Query matched objects
    var objects = widget.controller.objects.where(_matchesScope).toList();

    if (_tasksOnly) {
      objects = objects.where((o) => o.typeId == 'orbit.task').toList();
    }

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      objects = objects.where((o) {
        if (o.title.toLowerCase().contains(q)) return true;
        final status = (o.properties['status'] as String?)?.toLowerCase() ?? '';
        if (status.contains(q)) return true;
        final folder = (o.properties['folder'] as String?)?.toLowerCase() ?? '';
        if (folder.contains(q)) return true;
        if (o.properties['tags'] is List) {
          for (final t in (o.properties['tags'] as List)) {
            if (t.toString().toLowerCase().contains(q)) return true;
          }
        }
        return false;
      }).toList();
    }

    final columns = _computeColumns(objects);

    // Group objects by column
    final colItems = <String, List<UniversalObject>>{};
    for (final col in columns) {
      colItems[col.$1] = [];
    }
    for (final o in objects) {
      final colId = _getObjectColumnId(o, columns);
      if (colItems.containsKey(colId)) {
        colItems[colId]!.add(o);
      } else {
        colItems[columns.last.$1]!.add(o);
      }
    }

    final peekObj = _peekObjectId != null
        ? widget.controller.find(_peekObjectId!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-toolbar: Collection Mode, Group By, Preset, Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Tasks only'),
                selected: _tasksOnly,
                onSelected: (v) {
                  setState(() => _tasksOnly = v);
                  _updateProperty('tasksOnly', v);
                },
              ),
              FilterChip(
                label: const Text('Hide empty columns'),
                selected: _hideEmpty,
                onSelected: (v) {
                  setState(() => _hideEmpty = v);
                  _updateProperty('hideEmptyColumns', v);
                },
              ),
              // Collection Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isManual
                      ? colors.accent.withValues(alpha: 0.12)
                      : colors.raised,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isManual
                        ? colors.accent.withValues(alpha: 0.3)
                        : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManual
                          ? Icons.bookmarks_outlined
                          : Icons.view_kanban_outlined,
                      size: 13,
                      color: isManual ? colors.accent : colors.subtle,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isManual
                          ? 'Manual Collection (${objects.length})'
                          : (_tasksOnly
                                ? 'Tasks (${objects.length})'
                                : 'All objects (${objects.length})'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isManual ? colors.accent : colors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Group By Dropdown
              Text(
                'Group by:',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.subtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _groupBy,
                underline: const SizedBox.shrink(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: colors.subtle,
                ),
                style: OrbitTypography.metadata(
                  context,
                ).copyWith(color: colors.text, fontWeight: FontWeight.w600),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _groupBy = val);
                    _updateProperty('groupBy', val);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                  DropdownMenuItem(value: 'project', child: Text('Project')),
                  DropdownMenuItem(value: 'folder', child: Text('Folder')),
                  DropdownMenuItem(value: 'type', child: Text('Type')),
                ],
              ),
              const SizedBox(width: 14),

              // Preset Dropdown (when grouped by status)
              if (_groupBy == 'status') ...[
                Text(
                  'Preset:',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.subtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _preset,
                  underline: const SizedBox.shrink(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: colors.subtle,
                  ),
                  style: OrbitTypography.metadata(
                    context,
                  ).copyWith(color: colors.text),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _preset = val);
                      _updateProperty('preset', val);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'universal',
                      child: Text('Universal'),
                    ),
                    DropdownMenuItem(
                      value: 'software',
                      child: Text('Software Dev'),
                    ),
                    DropdownMenuItem(value: 'gamedev', child: Text('Game Dev')),
                    DropdownMenuItem(value: 'bugs', child: Text('Bug Tracker')),
                    DropdownMenuItem(
                      value: 'university',
                      child: Text('University'),
                    ),
                    DropdownMenuItem(
                      value: 'hypotheses',
                      child: Text('Hypotheses'),
                    ),
                    DropdownMenuItem(
                      value: 'functions',
                      child: Text('Function Status'),
                    ),
                    DropdownMenuItem(
                      value: 'research',
                      child: Text('Research'),
                    ),
                    DropdownMenuItem(
                      value: 'content',
                      child: Text('Content Pipeline'),
                    ),
                    DropdownMenuItem(
                      value: 'personal',
                      child: Text('Personal Planning'),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
              ],

              // Search Box
              SizedBox(
                width: 240,
                child: SizedBox(
                  height: OrbitDensity.of(context).controlHeight,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: OrbitTypography.metadata(
                      context,
                    ).copyWith(color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Filter cards...',
                      hintStyle: TextStyle(fontSize: 12, color: colors.subtle),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: colors.subtle,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 8,
                      ),
                      filled: true,
                      fillColor: colors.raised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: colors.accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Kanban Board Canvas & Columns
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrollable Column Deck
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < columns.length; i++)
                              if (!_hideEmpty ||
                                  objects.isEmpty ||
                                  (colItems[columns[i].$1] ?? [])
                                      .isNotEmpty) ...[
                                if (i > 0) const SizedBox(width: 12),
                                SizedBox(
                                  width: OrbitDensity.of(context).boardColumn,
                                  child: _buildKanbanColumn(
                                    columns[i].$1,
                                    columns[i].$2,
                                    colItems[columns[i].$1] ?? [],
                                    colors,
                                  ),
                                ),
                              ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Slide-in Object Detail Peek Panel
              if (peekObj != null) ...[
                VerticalDivider(width: 1, color: colors.divider),
                SizedBox(
                  width: 380,
                  child: Material(
                    color: colors.panel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: colors.divider),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Card Preview',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Open in tab',
                                icon: const Icon(Icons.open_in_new, size: 16),
                                onPressed: () =>
                                    widget.controller.openObject(peekObj.id),
                              ),
                              IconButton(
                                tooltip: 'Close preview (Esc)',
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () =>
                                    setState(() => _peekObjectId = null),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: peekObj.typeId == 'orbit.task'
                              ? TaskDetail(
                                  key: ValueKey(peekObj.id),
                                  object: peekObj,
                                  controller: widget.controller,
                                  viewObject: widget.viewObject,
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        peekObj.title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Text(
                                            peekObj.body.isEmpty
                                                ? '(No body content)'
                                                : peekObj.body,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colors.text,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKanbanColumn(
    String colId,
    String title,
    List<UniversalObject> items,
    OrbitColors colors,
  ) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _handleCardDrop(details.data, colId),
      builder: (context, candidates, rejected) {
        final isTargeted = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isTargeted
                ? colors.accent.withValues(alpha: 0.08)
                : colors.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isTargeted
                  ? colors.accent
                  : colors.border.withValues(alpha: 0.6),
              width: isTargeted ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column Header
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(fontSize: 12, color: colors.subtle),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Add item to $title',
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    onPressed: () {
                      setState(() => _inlineAddColumnId = colId);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _inlineAddFocus.requestFocus();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Inline Add Input Field
              if (_inlineAddColumnId == colId) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.accent),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _inlineAddController,
                        focusNode: _inlineAddFocus,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Enter title...',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _submitInlineAdd(colId),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              _inlineAddController.clear();
                              setState(() => _inlineAddColumnId = null);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(40, 24),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: () => _submitInlineAdd(colId),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: const Size(40, 24),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Card List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          _tasksOnly ? 'No tasks' : 'No items',
                          style: TextStyle(fontSize: 12, color: colors.subtle),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          return _buildKanbanCard(item, colors);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(UniversalObject o, OrbitColors colors) {
    final typeColor = switch (o.typeId) {
      'orbit.task' => Colors.green,
      'orbit.canvas' => Colors.purple,
      'orbit.file' => Colors.orange,
      _ => colors.accent,
    };

    final typeIcon = switch (o.typeId) {
      'orbit.task' => Icons.checklist_outlined,
      'orbit.canvas' => Icons.dashboard_outlined,
      'orbit.file' => Icons.attach_file_outlined,
      _ => Icons.description_outlined,
    };

    final priority = (o.properties['priority'] as String?)?.toLowerCase();
    final tags = (o.properties['tags'] is List)
        ? (o.properties['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final folder = (o.properties['folder'] as String?) ?? '';

    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(OrbitDensity.of(context).cardPadding),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Type icon, Checkbox (if task), Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (o.typeId == 'orbit.task') ...[
                SizedBox(
                  width: OrbitDensity.of(context).smallControl,
                  height: OrbitDensity.of(context).smallControl,
                  child: Checkbox(
                    value: o.isCompleted,
                    onChanged: (val) {
                      widget.controller.edit(
                        o.id,
                        properties: {
                          ...o.properties,
                          'completed': val == true,
                          'status': val == true ? 'done' : 'todo',
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(typeIcon, size: 14, color: typeColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  o.title.isEmpty ? 'Untitled' : o.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    decoration: (o.typeId == 'orbit.task' && o.isCompleted)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Peek / Action Button
              IconButton(
                tooltip: 'Task details',
                onPressed: () => setState(() => _peekObjectId = o.id),
                icon: Icon(
                  Icons.visibility_outlined,
                  size: 13,
                  color: colors.subtle,
                ),
              ),
            ],
          ),

          // Row 2: Badges (Priority, Folder, Tags)
          if (priority != null || folder.isNotEmpty || tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (priority != null && _groupBy != 'priority') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(priority).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _priorityColor(priority),
                      ),
                    ),
                  ),
                ],
                if (folder.isNotEmpty && _groupBy != 'folder') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.panel,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      folder,
                      style: TextStyle(fontSize: 12, color: colors.subtle),
                    ),
                  ),
                ],
                for (final t in tags.take(2))
                  Text(
                    '#$t',
                    style: TextStyle(fontSize: 12, color: colors.subtle),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Draggable<String>(
      data: o.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 260,
          child: Opacity(opacity: 0.85, child: cardWidget),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardWidget),
      child: InkWell(
        onTap: () => widget.controller.openObject(o.id),
        borderRadius: BorderRadius.circular(6),
        child: cardWidget,
      ),
    );
  }

  Color _priorityColor(String priority) {
    return switch (priority.toLowerCase()) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.blue,
      _ => Colors.grey,
    };
  }
}
