import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_draft_guard.dart';
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
  final _search = TextEditingController();
  final _horizontal = ScrollController();
  UniversalObject? _optionsSource;
  List<dynamic> _unknownColumns = [];
  int _actionEpoch = 0, _generation = -1;
  bool _creating = false;
  List<UniversalObject>? _viewObjects;
  UniversalObject? _viewInput, _cachedView;
  WorkspaceController? _viewController;

  UniversalObject get _view {
    final c = widget.controller;
    if (!identical(_viewObjects, c.objects) ||
        !identical(_viewInput, widget.viewObject) ||
        !identical(_viewController, c)) {
      _viewObjects = c.objects;
      _viewInput = widget.viewObject;
      _viewController = c;
      _cachedView = c.find(widget.viewObject.id) ?? widget.viewObject;
    }
    return _cachedView!;
  }

  bool get _readOnly =>
      _view.isReadOnly ||
      _view.isDeleted ||
      widget.controller.repository.readOnly ||
      widget.viewObject.workspaceId != widget.controller.repository.workspaceId;
  String _text(Object? value) => value?.toString() ?? '';

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
    _loadOptions();
  }

  void _loadOptions() {
    final source = _view;
    _optionsSource = source;
    _generation = widget.controller.workspaceGeneration;
    final savedCols = source.properties['columns'];
    if (savedCols is List) {
      _visibleColumns = savedCols
          .whereType<String>()
          .where(allColumns.contains)
          .toSet();
      _unknownColumns = savedCols
          .where((e) => e is! String || !allColumns.contains(e))
          .toList();
      if (_visibleColumns.isEmpty) _visibleColumns.add('title');
    } else {
      _unknownColumns = [];
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
    final sort = source.properties['sortOption'];
    _sortColumn = sort is String && allColumns.contains(sort) ? sort : null;
    _sortAscending = source.properties['sortAscending'] is bool
        ? source.properties['sortAscending'] as bool
        : true;
  }

  @override
  void didUpdateWidget(covariant CollectionTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.viewObject.id != widget.viewObject.id ||
        _generation != widget.controller.workspaceGeneration) {
      _actionEpoch++;
      _creating = false;
      _searchQuery = '';
      _search.clear();
      _typeFilter = 'all';
      _loadOptions();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  bool _isManualCollection() {
    return _view.properties['manual'] == true ||
        _view.properties['memberIds'] is List;
  }

  void _patchView(Map<String, dynamic> changes) {
    if (_readOnly) return;
    widget.controller.edit(
      _view.id,
      properties: {..._view.properties, ...changes},
    );
    setState(() {});
  }

  void _toggleColumn(String col) {
    if (_readOnly) return;
    setState(() {
      if (_visibleColumns.contains(col)) {
        if (_visibleColumns.length > 1) {
          _visibleColumns.remove(col);
        }
      } else {
        _visibleColumns.add(col);
      }
    });
    _patchView({
      'columns': [..._visibleColumns, ..._unknownColumns],
    });
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
    _patchView({'sortOption': _sortColumn, 'sortAscending': _sortAscending});
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  ValueChanged<T> _ownedValue<T>(ValueChanged<T> action) {
    final c = widget.controller, owner = _view.id;
    final generation = c.workspaceGeneration, epoch = _actionEpoch;
    return (value) {
      if (mounted &&
          identical(c, widget.controller) &&
          generation == c.workspaceGeneration &&
          epoch == _actionEpoch &&
          owner == _view.id) {
        action(value);
      }
    };
  }

  UniversalObject? _writable(UniversalObject expected) {
    final current = widget.controller.find(expected.id);
    return !_readOnly &&
            current != null &&
            !current.isDeleted &&
            !current.isReadOnly &&
            current.workspaceId == expected.workspaceId
        ? current
        : null;
  }

  Future<void> _createNewItem(String typeId) async {
    if (_readOnly || _creating) return;
    final c = widget.controller, origin = _view;
    final generation = c.workspaceGeneration, epoch = _actionEpoch;
    final manual = _isManualCollection();
    final folder = widget.folderFilter ?? _text(origin.properties['folder']);
    final scope = widget.scope ?? _text(origin.properties['scope']);
    setState(() => _creating = true);
    try {
      final created = await c.create(
        typeId,
        title: switch (typeId) {
          'orbit.task' => 'New Task',
          'orbit.canvas' => 'New Board',
          _ => 'Untitled Note',
        },
        properties: {
          if (folder.isNotEmpty) 'folder': folder,
          if (scope.isNotEmpty) 'project': scope,
          if (origin.properties['courseId'] is String)
            'courseId': origin.properties['courseId'],
          if (typeId == 'orbit.task') 'status': 'todo',
        },
      );
      if (created == null || generation != c.workspaceGeneration || !manual) {
        return;
      }
      final current = c.find(origin.id);
      if (current == null ||
          current.isDeleted ||
          current.isReadOnly ||
          c.repository.readOnly ||
          !(current.properties['manual'] == true ||
              current.properties['memberIds'] is List)) {
        _notice(
          'The item was created, but its original collection is unavailable.',
        );
        return;
      }
      final members = current.properties['memberIds'];
      c.edit(
        current.id,
        properties: {
          ...current.properties,
          'memberIds': [if (members is List) ...members, created.id],
        },
      );
    } finally {
      if (mounted && epoch == _actionEpoch) setState(() => _creating = false);
    }
  }

  Future<void> _textDialog({
    required String title,
    required String initial,
    required String hint,
    required String action,
    required FutureOr<String?> Function(String) apply,
  }) async {
    final c = widget.controller, viewId = _view.id;
    final generation = c.workspaceGeneration, epoch = _actionEpoch;
    await showDialog<void>(
      context: context,
      builder: (_) => _CollectionTextDialog(
        title: title,
        initial: initial,
        hint: hint,
        action: action,
        apply: apply,
        canApply: () =>
            mounted &&
            identical(widget.controller, c) &&
            _view.id == viewId &&
            c.workspaceGeneration == generation &&
            epoch == _actionEpoch &&
            !_readOnly,
      ),
    );
  }

  Future<void> _renameObject(UniversalObject expected) async {
    if (_writable(expected) == null) return;
    await _textDialog(
      title: 'Rename Object',
      initial: expected.title,
      hint: 'Enter title',
      action: 'Save',
      apply: (value) {
        final current = _writable(expected);
        if (current == null) return 'This item is unavailable or read-only.';
        if (value.isEmpty) return 'Enter a title.';
        if (current.title != expected.title && current.title != value) {
          return 'The title changed elsewhere. Your draft is retained.';
        }
        widget.controller.edit(current.id, title: value);
        return widget.controller.find(current.id)?.title == value
            ? null
            : 'The title could not be applied.';
      },
    );
  }

  Future<void> _editFolder(UniversalObject expected) async {
    if (_writable(expected) == null) return;
    final original = _text(expected.properties['folder']);
    await _textDialog(
      title: 'Move to Folder',
      initial: original,
      hint: 'Existing folder, e.g. Work/Projects',
      action: 'Move',
      apply: (value) async {
        final current = _writable(expected);
        if (current == null) return 'This item is unavailable or read-only.';
        if (_text(current.properties['folder']) != original) {
          return 'The folder changed elsewhere. Your draft is retained.';
        }
        final ok = await widget.controller.moveObjectToFolder(
          current.id,
          value,
        );
        return ok
            ? null
            : widget.controller.error ??
                  'The item could not be moved. Your draft is retained.';
      },
    );
  }

  Future<void> _addTag(UniversalObject expected) async {
    if (_writable(expected) == null) return;
    await _textDialog(
      title: 'Add Tag',
      initial: '',
      hint: 'tag (without #)',
      action: 'Add',
      apply: (value) {
        final current = _writable(expected);
        if (current == null) return 'This item is unavailable or read-only.';
        final clean = value.replaceFirst(RegExp(r'^#+'), '').trim();
        if (clean.isEmpty) return 'Enter a tag.';
        final raw = current.properties['tags'];
        if (raw != null && raw is! List) {
          return 'This tag format is unsupported; its data is preserved.';
        }
        final tags = raw is List ? [...raw] : <dynamic>[];
        if (tags.whereType<String>().any(
          (t) => t.toLowerCase() == clean.toLowerCase(),
        )) {
          return null;
        }
        tags.add(clean);
        widget.controller.updateProperty(current.id, 'tags', tags);
        return null;
      },
    );
  }

  void _removeTag(UniversalObject expected, String tag) {
    final current = _writable(expected);
    final raw = current?.properties['tags'];
    if (current == null || raw is! List) return;
    widget.controller.updateProperty(current.id, 'tags', [
      for (final value in raw)
        if (value != tag) value,
    ]);
  }

  void _updateStatus(UniversalObject expected, String newStatus) {
    final current = _writable(expected);
    if (current == null) return;
    widget.controller.edit(
      current.id,
      properties: {
        ...current.properties,
        'status': newStatus,
        if (current.typeId == 'orbit.task')
          'completed': newStatus == 'done' || newStatus == 'closed',
      },
    );
  }

  void _updatePriority(UniversalObject expected, String? newPriority) {
    final current = _writable(expected);
    if (current == null) return;
    widget.controller.updateProperty(
      current.id,
      'priority',
      newPriority == 'none' ? null : newPriority,
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, 1100 * math.max(1, scale)),
            height: constraints.maxHeight,
            child: _buildTable(context),
          ),
        ),
      );
    },
  );

  Widget _buildTable(BuildContext context) {
    if (!identical(_optionsSource, _view)) _loadOptions();
    final colors = OrbitColors.of(context);
    final isManual = _isManualCollection();

    // Query matched objects
    var objects = <UniversalObject>[];
    String? queryIssue;
    try {
      objects = widget.controller
          .queryViewObjects(
            _view,
            folderFilter: widget.folderFilter,
            scope: widget.scope,
          )
          .toList();
    } on Object catch (error) {
      queryIssue = '$error';
    }

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
        final status = _text(o.properties['status']).toLowerCase();
        if (status.contains(q)) return true;
        final folder = _text(o.properties['folder']).toLowerCase();
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
            final fa = _text(a.properties['folder']);
            final fb = _text(b.properties['folder']);
            cmp = fa.compareTo(fb);
            break;
          case 'status':
            final sa = _text(a.properties['status']);
            final sb = _text(b.properties['status']);
            cmp = sa.compareTo(sb);
            break;
          case 'priority':
            final pa = _text(a.properties['priority']);
            final pb = _text(b.properties['priority']);
            cmp = pa.compareTo(pb);
            break;
          case 'updated':
            cmp = a.updatedAt.compareTo(b.updatedAt);
            break;
        }
        if (cmp == 0) cmp = a.id.compareTo(b.id);
        return _sortAscending ? cmp : -cmp;
      });
    }

    final effectiveFolder =
        widget.folderFilter ??
        (_view.properties['folder'] is String
            ? _view.properties['folder'] as String
            : null);

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
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                      Flexible(
                        child: Text(
                          isManual
                              ? 'Manual Collection (${objects.length})'
                              : 'Smart Query (${objects.length}${effectiveFolder != null ? ' · $effectiveFolder' : ''})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isManual ? colors.accent : colors.subtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Search input
              Expanded(
                child: SizedBox(
                  height:
                      32 *
                      math.max(
                        1,
                        MediaQuery.textScalerOf(context).scale(12) / 12,
                      ),
                  child: TextField(
                    controller: _search,
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
                key: ValueKey(('collection-columns', _view, _actionEpoch)),
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
                enabled: !_readOnly,
                onSelected: _ownedValue(_toggleColumn),
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
                key: ValueKey(('collection-create', _view, _actionEpoch)),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 14,
                        color: OrbitColors.of(context).onAccent,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Add Item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OrbitColors.of(context).onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                enabled: !_readOnly && !_creating && queryIssue == null,
                onSelected: _ownedValue(_createNewItem),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'orbit.note',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Note',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'orbit.task',
                    child: Row(
                      children: [
                        Icon(Icons.checklist_outlined, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Task',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'orbit.canvas',
                    child: Row(
                      children: [
                        Icon(Icons.dashboard_outlined, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Board / Canvas',
                            style: TextStyle(fontSize: 13),
                          ),
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
          child: queryIssue != null
              ? Center(child: Text(queryIssue))
              : objects.isEmpty
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

    final typeColor = colors.objectType(o.typeId);

    final typeIcon = switch (o.typeId) {
      'orbit.task' => Icons.checklist_outlined,
      'orbit.canvas' => Icons.dashboard_outlined,
      'orbit.file' => Icons.attach_file_outlined,
      _ => Icons.description_outlined,
    };

    final storedStatus = _text(o.properties['status']);
    final status = storedStatus.isNotEmpty
        ? storedStatus
        : (o.typeId == 'orbit.task'
              ? (o.isCompleted ? 'done' : 'todo')
              : 'none');
    final storedPriority = _text(o.properties['priority']);
    final priority = storedPriority.isEmpty ? 'none' : storedPriority;
    final folder = _text(o.properties['folder']);
    // Rows already come from the current query snapshot. Resolve identity again
    // only when an action commits, rather than scanning the Vault per cell.
    final writable = !_readOnly && !o.isReadOnly && !o.isDeleted;
    final tags = (o.properties['tags'] is List)
        ? (o.properties['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Container(
      key: ValueKey('collection-row-${o.id}'),
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
                        onChanged: !writable
                            ? null
                            : (val) {
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
                    onPressed: writable ? () => _renameObject(o) : null,
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
                  key: ValueKey('collection-folder-${o.id}'),
                  onTap: writable ? () => _editFolder(o) : null,
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
                  key: ValueKey(('collection-status', _view, o, _actionEpoch)),
                  tooltip: 'Change Status',
                  enabled: writable,
                  onSelected: _ownedValue((newSt) => _updateStatus(o, newSt)),
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
                  key: ValueKey((
                    'collection-priority',
                    _view,
                    o,
                    _actionEpoch,
                  )),
                  tooltip: 'Change Priority',
                  enabled: writable,
                  onSelected: _ownedValue((newPr) => _updatePriority(o, newPr)),
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
                          Flexible(
                            child: Text(
                              '#$t',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.subtle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          InkWell(
                            onTap: writable ? () => _removeTag(o, t) : null,
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
                    key: ValueKey('collection-add-tag-${o.id}'),
                    onTap: writable ? () => _addTag(o) : null,
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
                  onPressed: writable
                      ? () => widget.controller.trash(o.id)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, OrbitColors colors) {
    return colors.status(status);
  }

  Color _priorityColor(String priority, OrbitColors colors) {
    return colors.priority(priority);
  }
}

class _CollectionTextDialog extends StatefulWidget {
  const _CollectionTextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.action,
    required this.apply,
    required this.canApply,
  });
  final String title, initial, hint, action;
  final FutureOr<String?> Function(String) apply;
  final bool Function() canApply;
  @override
  State<_CollectionTextDialog> createState() => _CollectionTextDialogState();
}

class _CollectionTextDialogState extends State<_CollectionTextDialog> {
  late final input = TextEditingController(text: widget.initial);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (!widget.canApply()) {
      setState(
        () => error =
            'The collection changed. Your draft is retained; reopen the original item.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    String? issue;
    try {
      issue = await widget.apply(input.text.trim());
    } catch (_) {
      issue = 'The change could not be applied. Your draft is retained.';
    }
    if (!mounted) return;
    if (issue == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error = issue;
      });
    }
  }

  @override
  Widget build(BuildContext context) => OrbitDraftGuard(
    dirty: input.text != widget.initial,
    busy: busy,
    builder: (context, close) => AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: input,
        autofocus: true,
        readOnly: busy,
        decoration: InputDecoration(hintText: widget.hint, errorText: error),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(onPressed: busy ? null : close, child: const Text('Cancel')),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(widget.action),
        ),
      ],
    ),
  );
}
