import '../../app/orbit_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/reverse_engineering.dart';
import 'research_record_dialog.dart';
import 'workspace_views.dart';
import 'research_comparison_dialog.dart';

class FunctionTableView extends StatefulWidget {
  const FunctionTableView({
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
  State<FunctionTableView> createState() => _FunctionTableViewState();
}

class _FunctionTableViewState extends State<FunctionTableView> {
  final _horizontalScroll = ScrollController();
  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  String _searchQuery = '';
  String? _statusFilter;
  String? _confidenceFilter;
  String? _moduleFilter;

  bool _matchesScope(UniversalObject o) {
    final ff = widget.folderFilter;
    final sc = widget.scope;
    if (ff != null && ff.isNotEmpty) {
      final f = o.properties['folder'];
      if (f is String && (f == ff || f.startsWith('$ff/'))) {
        return true;
      }
      final p = widget.controller.repository.objectPath(o.id);
      if (p != null && (p == ff || p.startsWith('$ff/'))) {
        return true;
      }
    }
    if (sc != null && sc.isNotEmpty) {
      final target = o.properties['target']?.toString().toLowerCase();
      final project = o.properties['project']?.toString().toLowerCase();
      final contextVal = o.properties['context']?.toString().toLowerCase();
      final lowerScope = sc.toLowerCase();
      if (target == lowerScope ||
          project == lowerScope ||
          contextVal == lowerScope) {
        return true;
      }
    }
    if ((ff == null || ff.isEmpty) && (sc == null || sc.isEmpty)) {
      return true;
    }
    return false;
  }

  bool _isFunction(UniversalObject o) {
    if (o.isDeleted) return false;
    if (!_matchesScope(o)) return false;
    return o.properties['category'] == 'Function';
  }

  Future<void> _createNewFunction() async {
    await showResearchRecordDialog(
      context,
      widget.controller,
      folder:
          widget.folderFilter ??
          'Reverse Engineering/${widget.scope ?? "Target"}/Functions',
      initialCategory: 'Function',
    );
  }

  Future<void> _showImportDialog() async {
    final textCtrl = TextEditingController();
    var format = 'csv';
    FunctionImportPlan? plan;
    String? error;
    var saving = false;
    var partialFailure = false;
    final folder = widget.folderFilter == null
        ? 'Reverse Engineering/${widget.scope ?? "Target"}/Functions'
        : widget.folderFilter!.endsWith('/Functions')
        ? widget.folderFilter!
        : '${widget.folderFilter}/Functions';
    final target =
        widget.scope ??
        widget.viewObject.properties['target']?.toString() ??
        '';
    try {
      final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, refresh) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('Import functions'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in ['csv', 'json'])
                            ChoiceChip(
                              label: Text(value.toUpperCase()),
                              selected: format == value,
                              onSelected: saving
                                  ? null
                                  : (_) => refresh(() {
                                      format = value;
                                      plan = null;
                                      error = null;
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        format == 'csv'
                            ? 'Name, Address or RVA, Module, Purpose. Optional context: BinaryId, BinaryVersion, ModuleId, ModuleBase, AddressSpace. Quoted comments and multiline fields are supported.'
                            : 'Array of functions, or {"version":1,"tool":"Ghidra","source":"export.json","context":{…},"functions":[…]}. Build and address context are preserved.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: textCtrl,
                        enabled: !saving,
                        maxLines: 8,
                        onChanged: (_) => refresh(() {
                          plan = null;
                          error = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Export content',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (plan != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${plan!.functions.length} functions ready to import',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final function in plan!.functions.take(8))
                          Text(
                            '${function.name} · ${function.location.address.isEmpty ? function.location.rva : function.location.address} · ${function.location.module}',
                          ),
                        if (plan!.functions.any(
                          (f) => f.location.identity == null,
                        ))
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Some records lack binary, build or module identity. They will remain separate records; addresses will not be merged.',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || partialFailure
                      ? null
                      : () async {
                          if (plan == null) {
                            try {
                              final parsed = format == 'csv'
                                  ? FunctionImportPlan.csv(textCtrl.text)
                                  : FunctionImportPlan.json(textCtrl.text);
                              if (parsed.functions.isEmpty) {
                                throw const FormatException(
                                  'No functions found.',
                                );
                              }
                              refresh(() {
                                plan = parsed;
                                error = null;
                              });
                            } catch (e) {
                              refresh(() => error = '$e');
                            }
                            return;
                          }
                          refresh(() => saving = true);
                          final count = await widget.controller
                              .importFunctionPlan(
                                plan!,
                                folder: folder,
                                target: target,
                              );
                          if (!dialogContext.mounted) return;
                          if (count != plan!.functions.length) {
                            refresh(() {
                              saving = false;
                              partialFailure = true;
                              error =
                                  'Saved $count of ${plan!.functions.length}. ${widget.controller.error ?? "Save failed."} Close this dialog before retrying to avoid duplicating saved records.';
                            });
                            plan = null;
                            return;
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Imported $count functions.'),
                              ),
                            );
                          }
                        },
                  child: Text(
                    saving
                        ? 'Importing…'
                        : plan == null
                        ? 'Validate and preview'
                        : 'Import ${plan!.functions.length} functions',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await Navigator.of(context, rootNavigator: true).push(route);
      await route.completed;
    } finally {
      textCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final allFunctions = widget.controller.activeObjects
        .where(_isFunction)
        .toList();

    // Collect available modules for filter dropdown
    final modules = <String>{};
    for (final f in allFunctions) {
      final m = f.properties['module']?.toString();
      if (m != null && m.isNotEmpty) modules.add(m);
    }

    // Filter functions
    final filtered = allFunctions.where((f) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = f.title.toLowerCase();
        final addr = f.properties['address']?.toString().toLowerCase() ?? '';
        final mod = f.properties['module']?.toString().toLowerCase() ?? '';
        final purp = f.properties['purpose']?.toString().toLowerCase() ?? '';
        final context =
            ['rva', 'binaryVersion', 'binaryId', 'moduleId', 'addressSpace']
                .map((key) => f.properties[key]?.toString().toLowerCase() ?? '')
                .join(' ');
        if (!name.contains(q) &&
            !addr.contains(q) &&
            !mod.contains(q) &&
            !purp.contains(q) &&
            !context.contains(q)) {
          return false;
        }
      }
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        final s = f.properties['status']?.toString().toLowerCase();
        if (s != _statusFilter!.toLowerCase()) return false;
      }
      if (_confidenceFilter != null && _confidenceFilter!.isNotEmpty) {
        final c = f.properties['confidence']?.toString().toLowerCase();
        if (c != _confidenceFilter!.toLowerCase()) return false;
      }
      if (_moduleFilter != null && _moduleFilter!.isNotEmpty) {
        final m = f.properties['module']?.toString().toLowerCase();
        if (m != _moduleFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Table Action & Filter Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 16),
                    hintText: 'Search function, address, module...',
                    hintStyle: TextStyle(fontSize: 12, color: colors.subtle),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12.5),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 12),

              for (final field in ['status', 'confidence', 'module'])
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: field == 'status'
                        ? _statusFilter
                        : field == 'confidence'
                        ? _confidenceFilter
                        : _moduleFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: field == 'status'
                          ? 'Status'
                          : field == 'confidence'
                          ? 'Confidence'
                          : 'Module',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All'),
                      ),
                      for (final value
                          in (allFunctions
                              .map((f) => f.properties[field]?.toString() ?? '')
                              .where((v) => v.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort()))
                        DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      if (field == 'status') {
                        _statusFilter = value;
                      } else if (field == 'confidence') {
                        _confidenceFilter = value;
                      } else {
                        _moduleFilter = value;
                      }
                    }),
                  ),
                ),
              Text(
                '${filtered.length} of ${allFunctions.length} functions',
                style: TextStyle(color: colors.subtle),
              ),
              // Import button
              OutlinedButton.icon(
                onPressed: () => showResearchComparison(
                  context,
                  widget.controller,
                  matchesScope: _matchesScope,
                  folder:
                      widget.folderFilter ??
                      'Reverse Engineering/${widget.scope ?? 'Target'}/Sessions',
                  target: widget.scope ?? '',
                ),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare builds'),
              ),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Import CSV/JSON'),
              ),
              const SizedBox(width: 8),

              // + New Function button
              FilledButton.icon(
                onPressed: _createNewFunction,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Function'),
              ),
            ],
          ),
        ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              controller: _horizontalScroll,
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.depth == 0,
              child: SingleChildScrollView(
                controller: _horizontalScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width:
                      constraints.maxWidth <
                          1080 * MediaQuery.textScalerOf(context).scale(14) / 14
                      ? 1080 * MediaQuery.textScalerOf(context).scale(14) / 14
                      : constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.raised,
                          border: Border(
                            bottom: BorderSide(color: colors.divider),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'FUNCTION / SYMBOL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'ADDRESS / RVA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'MODULE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'PURPOSE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'CONFIDENCE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'STATUS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(
                              width:
                                  3 *
                                  (OrbitDensity.of(context).smallControl < 48
                                      ? 48
                                      : OrbitDensity.of(context).smallControl),
                              child: Text(
                                'ACTIONS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Function Rows List
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  allFunctions.isEmpty
                                      ? 'No functions recorded. Click "New Function" or "Import CSV/JSON" to document binary functions.'
                                      : 'No functions match current filters.',
                                  style: TextStyle(color: colors.subtle),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final f = filtered[idx];
                                  final addr =
                                      f.properties['address']?.toString() ??
                                      f.properties['rva']?.toString() ??
                                      '';
                                  final mod =
                                      f.properties['module']?.toString() ?? '';
                                  final relative =
                                      f.properties['rva']?.toString() ??
                                      (f.properties['addressSpace'] == 'rva'
                                          ? addr
                                          : '');
                                  final moduleOffset =
                                      relative.isEmpty || mod.isEmpty
                                      ? null
                                      : formatModuleOffset(mod, relative);
                                  final purpose =
                                      f.properties['purpose']?.toString() ?? '';
                                  final conf =
                                      f.properties['confidence']?.toString() ??
                                      'Medium';
                                  final status =
                                      f.properties['status']?.toString() ??
                                      'Investigating';

                                  return InkWell(
                                    onTap: () =>
                                        widget.controller.openObject(f.id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: idx.isEven
                                            ? Colors.transparent
                                            : colors.panel.withValues(
                                                alpha: 0.3,
                                              ),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: colors.divider.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Function Name
                                          Expanded(
                                            flex: 3,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.code,
                                                  size: 15,
                                                  color: colors.accent,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    f.title.isEmpty
                                                        ? 'sub_$addr'
                                                        : f.title,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Address
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              addr.isEmpty
                                                  ? 'Not recorded'
                                                  : formatAddress(addr),
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 12.5,
                                                color: colors.accent,
                                              ),
                                            ),
                                          ),
                                          // Module
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              mod.isEmpty ? '—' : mod,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Purpose
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              purpose,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.subtle,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Confidence
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              child: Text(
                                                conf,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: conf == 'Verified'
                                                      ? Colors.green.shade400
                                                      : colors.text,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Status
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    status.toLowerCase() ==
                                                        'confirmed'
                                                    ? Colors.green.shade400
                                                          .withValues(
                                                            alpha: 0.15,
                                                          )
                                                    : colors.raised,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      status.toLowerCase() ==
                                                          'confirmed'
                                                      ? Colors.green.shade400
                                                      : colors.subtle,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Actions
                                          SizedBox(
                                            width:
                                                3 *
                                                (OrbitDensity.of(
                                                          context,
                                                        ).smallControl <
                                                        48
                                                    ? 48
                                                    : OrbitDensity.of(
                                                        context,
                                                      ).smallControl),
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  tooltip: addr.isEmpty
                                                      ? 'Address not recorded'
                                                      : 'Copy Address (${formatAddress(addr)})',
                                                  icon: const Icon(
                                                    Icons.tag,
                                                    size: 16,
                                                  ),
                                                  onPressed: addr.isEmpty
                                                      ? null
                                                      : () {
                                                          Clipboard.setData(
                                                            ClipboardData(
                                                              text:
                                                                  formatAddress(
                                                                    addr,
                                                                  ),
                                                            ),
                                                          );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Copied ${formatAddress(addr)} to clipboard',
                                                              ),
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 1,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                ),
                                                IconButton(
                                                  tooltip: moduleOffset == null
                                                      ? 'RVA unavailable; add module/base context'
                                                      : 'Copy Module+RVA ($moduleOffset)',
                                                  icon: const Icon(
                                                    Icons.copy,
                                                    size: 15,
                                                  ),
                                                  onPressed:
                                                      moduleOffset == null
                                                      ? null
                                                      : () {
                                                          Clipboard.setData(
                                                            ClipboardData(
                                                              text:
                                                                  moduleOffset,
                                                            ),
                                                          );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Copied $moduleOffset to clipboard',
                                                              ),
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 1,
                                                                  ),
                                                            ),
                                                          );
                                                        },
                                                ),
                                                IconButton(
                                                  tooltip: 'Open Note',
                                                  icon: const Icon(
                                                    Icons.open_in_new,
                                                    size: 15,
                                                  ),
                                                  onPressed: () => widget
                                                      .controller
                                                      .openObject(f.id),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
