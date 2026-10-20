import 'dart:math' as math;
import 'package:flutter/services.dart';
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
  final _boardFocus = FocusNode();
  final _search = TextEditingController();
  bool _adding = false;
  String? _addError;
  int _epoch = 0, _generation = -1;
  UniversalObject? _optionsSource;
  List<UniversalObject>? _snapshot;
  WorkspaceController? _snapshotController;
  UniversalObject? _input, _currentView;
  List<UniversalObject>? _memberResult;
  Map<String, UniversalObject> _members = {};
  static const _groups = {'status', 'priority', 'project', 'folder', 'type'};

  UniversalObject get _view {
    final c = widget.controller;
    if (!identical(_snapshot, c.objects) ||
        !identical(_snapshotController, c) ||
        !identical(_input, widget.viewObject)) {
      _snapshot = c.objects;
      _snapshotController = c;
      _input = widget.viewObject;
      _currentView = c.find(widget.viewObject.id) ?? widget.viewObject;
    }
    return _currentView!;
  }

  bool get _readOnly =>
      _view.isReadOnly ||
      _view.isDeleted ||
      widget.controller.repository.readOnly ||
      _view.workspaceId != widget.controller.repository.workspaceId;

  bool _owns(
    WorkspaceController c,
    UniversalObject view,
    int generation,
    int epoch,
  ) =>
      mounted &&
      identical(c, widget.controller) &&
      _epoch == epoch &&
      generation == c.workspaceGeneration &&
      identical(_view, view);

  void _loadOptions() {
    final v = _view;
    if (_optionsSource != null &&
        _optionsSource!.id == v.id &&
        (_groupBy != (v.properties['groupBy'] ?? 'status') ||
            _preset != (v.properties['preset'] ?? 'universal')) &&
        _inlineAddColumnId != null &&
        !_adding) {
      _inlineAddColumnId = null;
      _addError =
          'Board grouping changed. Your title is retained; choose a column to continue.';
    }
    _optionsSource = v;
    _generation = widget.controller.workspaceGeneration;
    _groupBy = v.properties['groupBy'] is String
        ? v.properties['groupBy'] as String
        : 'status';
    _preset = v.properties['preset'] is String
        ? v.properties['preset'] as String
        : 'universal';
    _tasksOnly = v.properties['tasksOnly'] == true;
    _hideEmpty = v.properties['hideEmptyColumns'] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void didUpdateWidget(covariant CollectionKanbanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.viewObject.id != widget.viewObject.id ||
        _generation != widget.controller.workspaceGeneration) {
      _epoch++;
      _adding = false;
      _addError = null;
      _inlineAddColumnId = null;
      _inlineAddController.clear();
      _search.clear();
      _searchQuery = '';
      _peekObjectId = null;
      _loadOptions();
    }
  }

  @override
  void dispose() {
    _inlineAddController.dispose();
    _inlineAddFocus.dispose();
    _boardFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  bool _isManualCollection() {
    return _view.properties['manual'] == true ||
        _view.properties['memberIds'] is List;
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _updateProperty(String key, dynamic value) {
    if (_readOnly) return;
    widget.controller.updateProperty(_view.id, key, value);
    setState(() {});
  }

  ValueChanged<T> _optionChange<T>(String key) {
    final c = widget.controller, origin = _view;
    final generation = c.workspaceGeneration, epoch = _epoch;
    return (value) {
      if (value != null && !_adding && _owns(c, origin, generation, epoch)) {
        _updateProperty(key, value);
      }
    };
  }

  UniversalObject? _writable(String id) {
    if (_readOnly) return null;
    final c = widget.controller;
    try {
      final result = c.queryViewObjects(
        _view,
        folderFilter: widget.folderFilter,
        scope: widget.scope,
      );
      if (!identical(_memberResult, result)) {
        _members = {for (final o in result) o.id: o};
        _memberResult = result;
      }
    } on Object {
      return null;
    }
    final current = _members[id];
    if (current == null ||
        current.isReadOnly ||
        current.isDeleted ||
        current.workspaceId != _view.workspaceId) {
      return null;
    }
    return current;
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
        return [
          for (final pr in list) ('project:$pr', pr),
          ('none', 'No Project'),
        ];
      case 'folder':
        final folders = <String>{};
        for (final o in objects) {
          final f = o.properties['folder']?.toString().trim();
          if (f != null && f.isNotEmpty) folders.add(f);
        }
        final list = folders.toList()..sort();
        return [
          for (final f in list) ('folder:$f', f),
          ('root', 'Root / Unfiled'),
        ];
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

  String _getObjectColumnId(UniversalObject o, Set<String> cols) {
    switch (_groupBy) {
      case 'priority':
        final pr = o.properties['priority']?.toString().toLowerCase();
        if (pr != null && cols.contains(pr)) return pr;
        return 'none';
      case 'project':
        final p = o.properties['project']?.toString().trim();
        if (p != null && p.isNotEmpty && cols.contains('project:$p')) {
          return 'project:$p';
        }
        return 'none';
      case 'folder':
        final f = o.properties['folder']?.toString().trim();
        if (f != null && f.isNotEmpty && cols.contains('folder:$f')) {
          return 'folder:$f';
        }
        return 'root';
      case 'type':
        if (cols.contains(o.typeId)) return o.typeId;
        return 'other';
      case 'status':
      default:
        if (o.typeId == 'orbit.task' && o.isCompleted) {
          if (cols.contains('done')) return 'done';
          if (cols.contains('closed')) return 'closed';
        }
        final raw = boardStatus(o.properties['status'], cols);
        if (cols.contains(raw)) return raw;
        if (raw.contains('part') && cols.contains('partial')) {
          return 'partial';
        }
        return 'none';
    }
  }

  Future<void> _handleCardDrop(String objectId, String targetColId) async {
    final obj = _writable(objectId);
    if (obj == null) return;
    final c = widget.controller;
    final changes = <String, dynamic>{};
    switch (_groupBy) {
      case 'status':
        changes['status'] = targetColId == 'none' ? null : targetColId;
        if (obj.typeId == 'orbit.task') {
          changes['completed'] =
              targetColId == 'done' || targetColId == 'closed';
        }
        break;
      case 'priority':
        changes['priority'] = targetColId == 'none' ? null : targetColId;
        break;
      case 'project':
        changes['project'] = targetColId == 'none'
            ? null
            : targetColId.substring(8);
        break;
      case 'folder':
        final folder = targetColId == 'root' ? '' : targetColId.substring(7);
        if ((obj.properties['folder'] ?? '') == folder) return;
        if (!await c.moveObjectToFolder(objectId, folder)) {
          _notice(
            c.error ??
                'The source could not be moved. Its original file is retained.',
          );
        }
        return;
      case 'type':
        _notice('Object type cannot be modified by dragging cards.');
        return;
    }
    if (changes.entries.every((e) => obj.properties[e.key] == e.value)) return;
    c.edit(objectId, properties: {...obj.properties, ...changes});
  }

  Future<void> _submitInlineAdd(String colId) async {
    if (!mounted || _readOnly || _adding || !_canCreateColumn(colId)) return;
    final text = _inlineAddController.text.trim();
    if (text.isEmpty) return;
    final c = widget.controller, origin = _view;
    final epoch = _epoch, generation = c.workspaceGeneration;
    final manual = _isManualCollection();
    final folder = widget.folderFilter ?? origin.properties['folder'];
    final scope = widget.scope ?? origin.properties['scope'];
    final props = <String, dynamic>{
      if (folder is String && folder.isNotEmpty) 'folder': folder,
      if (scope is String && scope.isNotEmpty) 'project': scope,
      if (origin.properties['courseId'] is String)
        'courseId': origin.properties['courseId'],
    };
    var typeId = 'orbit.task';
    switch (_groupBy) {
      case 'status':
        if (colId != 'none') props['status'] = colId;
        if (colId == 'done' || colId == 'closed') props['completed'] = true;
        break;
      case 'priority':
        if (colId != 'none') props['priority'] = colId;
        break;
      case 'project':
        props['project'] = colId == 'none' ? null : colId.substring(8);
        break;
      case 'folder':
        props['folder'] = colId == 'root' ? '' : colId.substring(7);
        break;
      case 'type':
        if (colId.startsWith('orbit.')) typeId = colId;
        break;
    }
    setState(() {
      _adding = true;
      _addError = null;
    });
    try {
      final created = await c.create(typeId, title: text, properties: props);
      if (generation != c.workspaceGeneration) return;
      if (created == null) {
        if (mounted && epoch == _epoch) {
          setState(
            () => _addError =
                c.error ??
                'The item could not be saved. Your title is retained.',
          );
        }
        return;
      }
      if (manual) {
        final current = c.find(origin.id);
        final members = current?.properties['memberIds'];
        if (current != null &&
            !current.isDeleted &&
            !current.isReadOnly &&
            !c.repository.readOnly &&
            (members is List || current.properties['manual'] == true) &&
            (members == null || members is List)) {
          c.updateProperty(current.id, 'memberIds', [
            if (members is List) ...members,
            created.id,
          ]);
        } else {
          _notice(
            'The item was created; its original collection is unavailable.',
          );
        }
      }
      if (mounted && epoch == _epoch) {
        setState(() {
          _inlineAddController.clear();
          _inlineAddColumnId = null;
        });
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _adding = false);
    }
  }

  bool _canCreateColumn(String colId) =>
      _groupBy != 'type' ||
      (const {'orbit.note', 'orbit.task', 'orbit.canvas'}.contains(colId) &&
          (!_tasksOnly || colId == 'orbit.task'));

  @override
  Widget build(BuildContext context) {
    if (!identical(_optionsSource, _view)) _loadOptions();
    if (!_groups.contains(_groupBy) ||
        !KanbanPreset.values.any((p) => p.id == _preset) ||
        ['groupBy', 'preset'].any(
          (key) =>
              _view.properties[key] != null && _view.properties[key] is! String,
        )) {
      return const EmptyWorkspace(
        icon: Icons.warning_amber_outlined,
        title: 'Unsupported board settings',
        description:
            'This board uses unsupported settings. Its definition is preserved.',
      );
    }
    final colors = OrbitColors.of(context);
    final isManual = _isManualCollection();

    // Query matched objects
    List<UniversalObject> objects;
    try {
      objects = widget.controller
          .queryViewObjects(
            _view,
            folderFilter: widget.folderFilter,
            scope: widget.scope,
          )
          .toList();
    } on Object catch (error) {
      return EmptyWorkspace(
        icon: Icons.warning_amber_outlined,
        title: 'Unable to load this board',
        description: '$error',
      );
    }

    if (_tasksOnly) {
      objects = objects.where((o) => o.typeId == 'orbit.task').toList();
    }

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      objects = objects.where((o) {
        if (o.title.toLowerCase().contains(q)) return true;
        final status = o.properties['status']?.toString().toLowerCase() ?? '';
        if (status.contains(q)) return true;
        final folder = o.properties['folder']?.toString().toLowerCase() ?? '';
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
    final columnIds = columns.map((c) => c.$1).toSet();

    // Group objects by column
    final colItems = <String, List<UniversalObject>>{};
    for (final col in columns) {
      colItems[col.$1] = [];
    }
    for (final o in objects) {
      final colId = _getObjectColumnId(o, columnIds);
      if (colItems.containsKey(colId)) {
        colItems[colId]!.add(o);
      } else {
        colItems[columns.last.$1]!.add(o);
      }
    }

    final peekSource = _peekObjectId != null
        ? widget.controller.find(_peekObjectId!)
        : null;
    final peekObj = peekSource?.isDeleted == false ? peekSource : null;
    final visibleColumns = columns
        .where(
          (col) =>
              !_hideEmpty ||
              objects.isEmpty ||
              (colItems[col.$1]?.isNotEmpty ?? false),
        )
        .toList();

    return LayoutBuilder(
      builder: (context, layout) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_peekObjectId != null) setState(() => _peekObjectId = null);
          },
        },
        child: Focus(
          focusNode: _boardFocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sub-toolbar: Collection Mode, Group By, Preset, Search
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: layout.maxHeight * .4),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
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
                          onSelected: _readOnly || _adding
                              ? null
                              : _optionChange<bool>('tasksOnly'),
                        ),
                        FilterChip(
                          label: const Text('Hide empty columns'),
                          selected: _hideEmpty,
                          onSelected: _readOnly || _adding
                              ? null
                              : _optionChange<bool>('hideEmptyColumns'),
                        ),
                        // Collection Type Badge
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: math.max(0, layout.maxWidth - 48),
                          ),
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
                                      : Icons.view_kanban_outlined,
                                  size: 13,
                                  color: isManual
                                      ? colors.accent
                                      : colors.subtle,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    isManual
                                        ? 'Manual Collection (${objects.length})'
                                        : (_tasksOnly
                                              ? 'Tasks (${objects.length})'
                                              : 'All objects (${objects.length})'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isManual
                                          ? colors.accent
                                          : colors.subtle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                        SizedBox(
                          width: math.min(
                            140 *
                                MediaQuery.textScalerOf(context).scale(14) /
                                14,
                            math.max(0, layout.maxWidth - 48),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            key: ValueKey(('board-group', _view, _epoch)),
                            value: _groupBy,
                            underline: const SizedBox.shrink(),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: colors.subtle,
                            ),
                            style: OrbitTypography.metadata(context).copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                            onChanged:
                                _readOnly ||
                                    _adding ||
                                    _inlineAddColumnId != null
                                ? null
                                : _optionChange<String?>('groupBy'),
                            items: const [
                              DropdownMenuItem(
                                value: 'status',
                                child: Text('Status'),
                              ),
                              DropdownMenuItem(
                                value: 'priority',
                                child: Text('Priority'),
                              ),
                              DropdownMenuItem(
                                value: 'project',
                                child: Text('Project'),
                              ),
                              DropdownMenuItem(
                                value: 'folder',
                                child: Text('Folder'),
                              ),
                              DropdownMenuItem(
                                value: 'type',
                                child: Text('Type'),
                              ),
                            ],
                          ),
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
                          SizedBox(
                            width: math.min(
                              220 *
                                  MediaQuery.textScalerOf(context).scale(14) /
                                  14,
                              math.max(0, layout.maxWidth - 48),
                            ),
                            child: DropdownButton<String>(
                              isExpanded: true,
                              key: ValueKey(('board-preset', _view, _epoch)),
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
                              onChanged:
                                  _readOnly ||
                                      _adding ||
                                      _inlineAddColumnId != null
                                  ? null
                                  : _optionChange<String?>('preset'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'universal',
                                  child: Text('Universal'),
                                ),
                                DropdownMenuItem(
                                  value: 'software',
                                  child: Text('Software Dev'),
                                ),
                                DropdownMenuItem(
                                  value: 'gamedev',
                                  child: Text('Game Dev'),
                                ),
                                DropdownMenuItem(
                                  value: 'bugs',
                                  child: Text('Bug Tracker'),
                                ),
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
                          ),
                          const SizedBox(width: 14),
                        ],

                        // Search Box
                        SizedBox(
                          width: 240,
                          child: SizedBox(
                            height:
                                OrbitDensity.of(context).controlHeight *
                                math.max(
                                  1,
                                  MediaQuery.textScalerOf(context).scale(14) /
                                      14,
                                ),
                            child: TextField(
                              controller: _search,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              style: OrbitTypography.metadata(
                                context,
                              ).copyWith(color: colors.text),
                              decoration: InputDecoration(
                                hintText: 'Filter cards...',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: colors.subtle,
                                ),
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
                ),
              ),
              if (_addError != null && _inlineAddColumnId == null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_addError!),
                ),

              // Kanban Board Canvas & Columns
              Expanded(
                child: LayoutBuilder(
                  builder: (context, boardConstraints) => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Scrollable Column Deck
                      if (peekObj == null || boardConstraints.maxWidth >= 760)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: ListView.separated(
                              key: ValueKey(('board-deck', _view.id, _groupBy)),
                              scrollDirection: Axis.horizontal,
                              itemCount: visibleColumns.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final col = visibleColumns[i];
                                return SizedBox(
                                  width: math.min(
                                    math.max(0, boardConstraints.maxWidth - 32),
                                    OrbitDensity.of(context).boardColumn *
                                        math.max(
                                          1,
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(14) /
                                              14,
                                        ),
                                  ),
                                  child: _buildKanbanColumn(
                                    col.$1,
                                    col.$2,
                                    colItems[col.$1] ?? [],
                                    colors,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // Slide-in Object Detail Peek Panel
                      if (peekObj != null) ...[
                        if (boardConstraints.maxWidth >= 760)
                          VerticalDivider(width: 1, color: colors.divider),
                        SizedBox(
                          width: math.min(380, boardConstraints.maxWidth),
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
                                      Expanded(
                                        child: Text(
                                          'Card Preview',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colors.text,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Open in tab',
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 16,
                                        ),
                                        onPressed: () => widget.controller
                                            .openObject(peekObj.id),
                                      ),
                                      IconButton(
                                        tooltip: 'Close preview (Esc)',
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () => setState(
                                          () => _peekObjectId = null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child:
                                      peekObj.typeId == 'orbit.task' &&
                                          !_readOnly
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(
    String colId,
    String title,
    List<UniversalObject> items,
    OrbitColors colors,
  ) {
    final c = widget.controller, origin = _view;
    final generation = c.workspaceGeneration, epoch = _epoch;
    bool accepts(String id) =>
        _owns(c, origin, generation, epoch) &&
        _groupBy != 'type' &&
        _writable(id) != null;
    Future<void> submit() async {
      if (_owns(c, origin, generation, epoch)) await _submitInlineAdd(colId);
    }

    return DragTarget<String>(
      key: ValueKey(('board-column', origin.id, _groupBy, colId)),
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onAcceptWithDetails: (details) async {
        if (accepts(details.data)) await _handleCardDrop(details.data, colId);
      },
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
                    tooltip: _canCreateColumn(colId)
                        ? 'Add item to $title'
                        : colId == 'other'
                        ? 'Use New or Import for files, events and other types'
                        : 'Turn off Tasks only to create this type',
                    icon: const Icon(Icons.add, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    onPressed: _readOnly || _adding || !_canCreateColumn(colId)
                        ? null
                        : () {
                            if (!_owns(c, origin, generation, epoch)) return;
                            setState(() {
                              _inlineAddColumnId = colId;
                              _addError = null;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_owns(c, origin, generation, epoch)) {
                                _inlineAddFocus.requestFocus();
                              }
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
                        readOnly: _adding || _readOnly,
                        focusNode: _inlineAddFocus,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          errorText: _addError,
                          errorMaxLines: 4,
                          hintText: 'Enter title...',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _adding
                                ? null
                                : () {
                                    if (!_owns(c, origin, generation, epoch)) {
                                      return;
                                    }
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
                            onPressed: _readOnly || _adding ? null : submit,
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
    final c = widget.controller, origin = _view;
    final generation = c.workspaceGeneration, epoch = _epoch;
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

    final priority = o.properties['priority']?.toString().toLowerCase();
    final tags = (o.properties['tags'] is List)
        ? (o.properties['tags'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final folder = o.properties['folder']?.toString() ?? '';

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
                    onChanged: _readOnly || o.isReadOnly
                        ? null
                        : (val) {
                            if (!_owns(c, origin, generation, epoch)) return;
                            final current = _writable(o.id);
                            if (current == null ||
                                current.isCompleted == (val == true)) {
                              return;
                            }
                            widget.controller.edit(
                              current.id,
                              properties: {
                                ...current.properties,
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
                onPressed: () {
                  setState(() => _peekObjectId = o.id);
                  _boardFocus.requestFocus();
                },
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    child: Tooltip(
                      message: folder,
                      child: Text(
                        folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.subtle),
                      ),
                    ),
                  ),
                ],
                for (final t in tags.take(2))
                  Tooltip(
                    message: t,
                    child: Text(
                      '#$t',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.subtle),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Draggable<String>(
      key: ValueKey('board-card-${o.id}'),
      maxSimultaneousDrags: _readOnly || o.isReadOnly || _groupBy == 'type'
          ? 0
          : 1,
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
