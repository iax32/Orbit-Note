import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

class CollectionTableView extends StatefulWidget {
  const CollectionTableView({
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
  State<CollectionTableView> createState() => _CollectionTableViewState();
}

class _CollectionTableViewState extends State<CollectionTableView> {
  String _searchQuery = '';
  String _typeFilter = 'all'; // all, notes, tasks, canvases
  String? _sortColumn;
  bool _sortAscending = true;
  late Set<String> _visibleColumns;

  static const List<String> allColumns = [
    'title',
    'type',
    'folder',
    'status',
    'priority',
    'tags',
    'updated',
  ];

  @override
  void initState() {
    super.initState();
    final savedCols = widget.viewObject.properties['columns'];
    if (savedCols is List) {
      _visibleColumns = savedCols.map((e) => e.toString()).toSet();
    } else {
      _visibleColumns = {
        'title',
        'type',
        'folder',
        'status',
        'priority',
        'tags',
        'updated',
      };
    }
    _sortColumn = widget.viewObject.properties['sortOption'] as String?;
    _sortAscending =
        widget.viewObject.properties['sortAscending'] as bool? ?? true;
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
      properties: {...widget.viewObject.properties, key: value},
    );
    setState(() {});
  }

  void _toggleColumn(String col) {
    setState(() {
      if (_visibleColumns.contains(col)) {
        if (_visibleColumns.length > 1) {
          _visibleColumns.remove(col);
        }
      } else {
        _visibleColumns.add(col);
      }
    });
    _updateProperty('columns', _visibleColumns.toList());
  }

  void _onSort(String col) {
    setState(() {
      if (_sortColumn == col) {
        if (_sortAscending) {
          _sortAscending = false;
        } else {
          _sortColumn = null;
          _sortAscending = true;
        }
      } else {
        _sortColumn = col;
        _sortAscending = true;
      }
    });
    _updateProperty('sortOption', _sortColumn);
    _updateProperty('sortAscending', _sortAscending);
  }

  Future<void> _createNewItem(String typeId) async {
    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject.properties['folder'] as String?) ??
        '';
    final effectiveScope =
        widget.scope ??
        (widget.viewObject.properties['scope'] as String?) ??
        '';

    final defaultTitle = switch (typeId) {
      'orbit.task' => 'New Task',
      'orbit.canvas' => 'New Board',
      _ => 'Untitled Note',
    };

    final props = <String, dynamic>{
      if (effectiveFolder.isNotEmpty) 'folder': effectiveFolder,
      if (effectiveScope.isNotEmpty) 'project': effectiveScope,
      if (typeId == 'orbit.task') 'status': 'todo',
    };

    final newObj = await widget.controller.create(
      typeId,
      title: defaultTitle,
      properties: props,
    );

    if (newObj != null && _isManualCollection()) {
      final members = List<String>.from(_getManualMemberIds())..add(newObj.id);
      _updateProperty('memberIds', members);
    }
  }

  Future<void> _renameObject(UniversalObject o) async {
    final ctrl = TextEditingController(text: o.title);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Object'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Enter title',
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty && res != o.title) {
      widget.controller.edit(o.id, title: res);
    }
  }

  Future<void> _editFolder(UniversalObject o) async {
    final current = (o.properties['folder'] as String?) ?? '';
    final ctrl = TextEditingController(text: current);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'e.g. Work/Projects or University',
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (res != null) {
      widget.controller.edit(
        o.id,
        properties: {...o.properties, 'folder': res.isEmpty ? null : res},
      );
    }
  }

  Future<void> _addTag(UniversalObject o) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'tag (without #)',
          ),
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != null && res.isNotEmpty) {
      final clean = res.startsWith('#') ? res.substring(1) : res;
      final existing = (o.properties['tags'] is List)
          ? List<String>.from(o.properties['tags'] as List)
          : <String>[];
      if (!existing.contains(clean)) {
        existing.add(clean);
        widget.controller.edit(
          o.id,
          properties: {...o.properties, 'tags': existing},
        );
      }
    }
  }

  void _removeTag(UniversalObject o, String tag) {
    final existing = (o.properties['tags'] is List)
        ? List<String>.from(o.properties['tags'] as List)
        : <String>[];
    existing.remove(tag);
    widget.controller.edit(
      o.id,
      properties: {...o.properties, 'tags': existing},
    );
  }

  void _updateStatus(UniversalObject o, String newStatus) {
    final isDone = newStatus == 'done' || newStatus == 'closed';
    widget.controller.edit(
      o.id,
      properties: {
        ...o.properties,
        'status': newStatus,
        if (o.typeId == 'orbit.task') 'completed': isDone,
      },
    );
  }

  void _updatePriority(UniversalObject o, String? newPriority) {
    widget.controller.edit(
      o.id,
      properties: {
        ...o.properties,
        'priority': newPriority == 'none' ? null : newPriority,
      },
    );
  }

  String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final isManual = _isManualCollection();

    // Query matched objects
    var objects = widget.controller.objects.where(_matchesScope).toList();

    // Type filter
    if (_typeFilter == 'notes') {
      objects = objects.where((o) => o.typeId == 'orbit.note').toList();
    } else if (_typeFilter == 'tasks') {
      objects = objects.where((o) => o.typeId == 'orbit.task').toList();
    } else if (_typeFilter == 'canvases') {
      objects = objects.where((o) => o.typeId == 'orbit.canvas').toList();
    }

    // Search query filter
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

    // Sorting
    if (_sortColumn != null) {
      objects.sort((a, b) {
        int cmp = 0;
        switch (_sortColumn) {
          case 'title':
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            break;
          case 'type':
            cmp = a.typeId.compareTo(b.typeId);
            break;
          case 'folder':
            final fa = (a.properties['folder'] as String?) ?? '';
            final fb = (b.properties['folder'] as String?) ?? '';
            cmp = fa.compareTo(fb);
            break;
          case 'status':
            final sa = (a.properties['status'] as String?) ?? '';
            final sb = (b.properties['status'] as String?) ?? '';
            cmp = sa.compareTo(sb);
            break;
          case 'priority':
            final pa = (a.properties['priority'] as String?) ?? '';
            final pb = (b.properties['priority'] as String?) ?? '';
            cmp = pa.compareTo(pb);
            break;
          case 'updated':
            cmp = a.updatedAt.compareTo(b.updatedAt);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    final effectiveFolder =
        widget.folderFilter ??
        (widget.viewObject.properties['folder'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Sub-toolbar: Collection Mode, Search, Filters, Columns, and Add
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
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
                          : Icons.filter_alt_outlined,
                      size: 13,
                      color: isManual ? colors.accent : colors.subtle,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isManual
                          ? 'Manual Collection (${objects.length})'
                          : 'Smart Query (${objects.length}${effectiveFolder != null ? ' · $effectiveFolder' : ''})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isManual ? colors.accent : colors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Search input
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 12, color: colors.text),
                    decoration: InputDecoration(
                      hintText: 'Search items, tags, or statuses...',
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
              const SizedBox(width: 12),

              // Type filter pills
              _buildTypeFilterChip('all', 'All', colors),
              const SizedBox(width: 4),
              _buildTypeFilterChip('notes', 'Notes', colors),
              const SizedBox(width: 4),
              _buildTypeFilterChip('tasks', 'Tasks', colors),
              const SizedBox(width: 4),
              _buildTypeFilterChip('canvases', 'Boards', colors),
              const SizedBox(width: 12),

              // Columns customization button
              PopupMenuButton<String>(
                tooltip: 'Customize Columns',
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.raised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_column_outlined,
                        size: 14,
                        color: colors.subtle,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Columns',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                onSelected: (col) => _toggleColumn(col),
                itemBuilder: (ctx) => [
                  for (final col in allColumns)
                    CheckedPopupMenuItem<String>(
                      value: col,
                      checked: _visibleColumns.contains(col),
                      child: Text(col[0].toUpperCase() + col.substring(1)),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Add Item button
              PopupMenuButton<String>(
                tooltip: 'Add to Collection',
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                onSelected: (type) => _createNewItem(type),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'orbit.note',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('New Note', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'orbit.task',
                    child: Row(
                      children: [
                        Icon(Icons.checklist_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('New Task', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'orbit.canvas',
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_outlined, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'New Board / Canvas',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              if (_visibleColumns.contains('title'))
                Expanded(
                  flex: 4,
                  child: _buildHeaderCell('title', 'TITLE / NAME', colors),
                ),
              if (_visibleColumns.contains('type'))
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('type', 'TYPE', colors),
                ),
              if (_visibleColumns.contains('folder'))
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('folder', 'FOLDER', colors),
                ),
              if (_visibleColumns.contains('status'))
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('status', 'STATUS', colors),
                ),
              if (_visibleColumns.contains('priority'))
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('priority', 'PRIORITY', colors),
                ),
              if (_visibleColumns.contains('tags'))
                Expanded(
                  flex: 3,
                  child: Text(
                    'TAGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: colors.subtle,
                    ),
                  ),
                ),
              if (_visibleColumns.contains('updated'))
                Expanded(
                  flex: 2,
                  child: _buildHeaderCell('updated', 'UPDATED', colors),
                ),
              SizedBox(
                width: 90,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: objects.isEmpty
              ? (widget.controller.objects.isEmpty
                    ? EmptyWorkspace(
                        icon: Icons.table_chart_outlined,
                        title: 'No items in this collection',
                        description:
                            'Track notes, tasks, and canvas boards in a customizable structured table.',
                        action: () => _createNewItem('orbit.note'),
                        label: 'Create First Note',
                      )
                    : Center(
                        child: Text(
                          'No items match your query or filter.',
                          style: TextStyle(color: colors.subtle, fontSize: 13),
                        ),
                      ))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: objects.length,
                  separatorBuilder: (ctx, i) => Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.divider.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (ctx, i) {
                    final obj = objects[i];
                    return _buildTableRow(obj, colors);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterChip(
    String filterKey,
    String label,
    OrbitColors colors,
  ) {
    final selected = _typeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _typeFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.raised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? colors.accent : colors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String colKey, String label, OrbitColors colors) {
    final isSorted = _sortColumn == colKey;
    return InkWell(
      onTap: () => _onSort(colKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isSorted ? colors.accent : colors.subtle,
            ),
          ),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: colors.accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableRow(UniversalObject o, OrbitColors colors) {
    final typeName = switch (o.typeId) {
      'orbit.task' => 'Task',
      'orbit.canvas' => 'Board',
      'orbit.file' => 'File',
      _ => 'Note',
    };

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

    final status =
        (o.properties['status'] as String?) ??
        (o.typeId == 'orbit.task' ? (o.isCompleted ? 'done' : 'todo') : 'none');
    final priority = (o.properties['priority'] as String?) ?? 'none';
    final folder = (o.properties['folder'] as String?) ?? '';
    final tags = (o.properties['tags'] is List)
        ? (o.properties['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Title / Name Column
          if (_visibleColumns.contains('title'))
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  if (o.typeId == 'orbit.task') ...[
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: o.isCompleted,
                        onChanged: (val) {
                          _updateStatus(o, val == true ? 'done' : 'todo');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(typeIcon, size: 16, color: typeColor),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: InkWell(
                      onTap: () => widget.controller.openObject(o.id),
                      child: Text(
                        o.title.isEmpty ? 'Untitled' : o.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                          decoration:
                              (o.typeId == 'orbit.task' && o.isCompleted)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: colors.subtle,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    onPressed: () => _renameObject(o),
                  ),
                ],
              ),
            ),

          // Type Column
          if (_visibleColumns.contains('type'))
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                ),
              ),
            ),

          // Folder Column
          if (_visibleColumns.contains('folder'))
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _editFolder(o),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 12,
                          color: colors.subtle,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            folder.isEmpty ? 'Root' : folder,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.subtle,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Status Column
          if (_visibleColumns.contains('status'))
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'Change Status',
                  onSelected: (newSt) => _updateStatus(o, newSt),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'todo', child: Text('Todo')),
                    PopupMenuItem(
                      value: 'in-progress',
                      child: Text('In Progress'),
                    ),
                    PopupMenuItem(value: 'review', child: Text('In Review')),
                    PopupMenuItem(value: 'done', child: Text('Done')),
                    PopupMenuItem(value: 'backlog', child: Text('Backlog')),
                    PopupMenuItem(value: 'blocked', child: Text('Blocked')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        status,
                        colors,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor(
                          status,
                          colors,
                        ).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status, colors),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Priority Column
          if (_visibleColumns.contains('priority'))
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'Change Priority',
                  onSelected: (newPr) => _updatePriority(o, newPr),
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'urgent', child: Text('🔴 Urgent')),
                    PopupMenuItem(value: 'high', child: Text('🟠 High')),
                    PopupMenuItem(value: 'medium', child: Text('🔵 Medium')),
                    PopupMenuItem(value: 'low', child: Text('⚪ Low')),
                    PopupMenuItem(value: 'none', child: Text('None (-)')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _priorityColor(
                        priority,
                        colors,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      priority == 'none' ? '-' : priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _priorityColor(priority, colors),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Tags Column
          if (_visibleColumns.contains('tags'))
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final t in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.raised,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#$t',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.subtle,
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: () => _removeTag(o, t),
                            child: Icon(
                              Icons.close,
                              size: 10,
                              color: colors.subtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: () => _addTag(o),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.panel,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(Icons.add, size: 11, color: colors.subtle),
                    ),
                  ),
                ],
              ),
            ),

          // Updated Column
          if (_visibleColumns.contains('updated'))
            Expanded(
              flex: 2,
              child: Text(
                _formatRelativeDate(o.updatedAt),
                style: TextStyle(fontSize: 11, color: colors.subtle),
              ),
            ),

          // Actions Column
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new, size: 15),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => widget.controller.openObject(o.id),
                ),
                IconButton(
                  tooltip: 'Trash',
                  icon: Icon(
                    Icons.delete_outline,
                    size: 15,
                    color: colors.subtle,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => widget.controller.trash(o.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, OrbitColors colors) {
    return switch (status.toLowerCase()) {
      'done' || 'closed' || 'confirmed' => Colors.green,
      'in-progress' || 'testing' || 'investigating' => Colors.blue,
      'review' || 'verify' => Colors.amber,
      'blocked' || 'rejected' => Colors.red,
      _ => colors.subtle,
    };
  }

  Color _priorityColor(String priority, OrbitColors colors) {
    return switch (priority.toLowerCase()) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.blue,
      'low' => colors.subtle,
      _ => colors.subtle,
    };
  }
}
