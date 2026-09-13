import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

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
    return o.properties['category'] == 'Function' ||
        o.properties.containsKey('address') ||
        o.properties.containsKey('rva');
  }

  Future<void> _createNewFunction() async {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController(text: '0x1400');
    final modCtrl = TextEditingController(text: 'target.exe');
    final purposeCtrl = TextEditingController();
    String selectedConfidence = 'Medium';
    String selectedStatus = 'Investigating';

    final targetFolder = widget.folderFilter != null
        ? (widget.folderFilter!.contains('Functions')
              ? widget.folderFilter!
              : '${widget.folderFilter}/Functions')
        : 'Reverse Engineering/${widget.scope ?? "Target"}/Functions';

    final targetName =
        widget.scope ??
        widget.viewObject.properties['target']?.toString() ??
        '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Function'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Function Name / Symbol *',
                      hintText: 'e.g. DecryptPacket or sub_140024B20',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address / RVA',
                            hintText: '0x140024B20',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: modCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Module',
                            hintText: 'target.exe',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: purposeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Purpose / Description',
                      hintText: 'Decrypts incoming network buffer',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Unknown',
                              child: Text('Unknown'),
                            ),
                            DropdownMenuItem(
                              value: 'Interesting',
                              child: Text('Interesting'),
                            ),
                            DropdownMenuItem(
                              value: 'Investigating',
                              child: Text('Investigating'),
                            ),
                            DropdownMenuItem(
                              value: 'Partially Understood',
                              child: Text('Partially Understood'),
                            ),
                            DropdownMenuItem(
                              value: 'Confirmed',
                              child: Text('Confirmed'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedStatus = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedConfidence,
                          decoration: const InputDecoration(
                            labelText: 'Confidence',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'Verified',
                              child: Text('Verified'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedConfidence = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Create Function'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await widget.controller.createFunctionDoc(
        folder: targetFolder,
        name: nameCtrl.text.trim(),
        address: addrCtrl.text.trim(),
        module: modCtrl.text.trim(),
        purpose: purposeCtrl.text.trim(),
        status: selectedStatus,
        confidence: selectedConfidence,
        target: targetName,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _showImportDialog() async {
    final textCtrl = TextEditingController();
    String format = 'csv';

    final targetFolder = widget.folderFilter != null
        ? (widget.folderFilter!.contains('Functions')
              ? widget.folderFilter!
              : '${widget.folderFilter}/Functions')
        : 'Reverse Engineering/${widget.scope ?? "Target"}/Functions';

    final targetName =
        widget.scope ??
        widget.viewObject.properties['target']?.toString() ??
        '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import Functions (CSV or JSON)'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('CSV Format'),
                      selected: format == 'csv',
                      onSelected: (val) {
                        if (val) setDialogState(() => format = 'csv');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('JSON Array'),
                      selected: format == 'json',
                      onSelected: (val) {
                        if (val) setDialogState(() => format = 'json');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  format == 'csv'
                      ? 'Expected CSV columns: Name, Address, Module, Purpose, Status, Confidence'
                      : 'Expected JSON: [{"name":"Sub_01", "address":"0x1400", "module":"app.exe", "purpose":"init"}]',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste CSV or JSON content here...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (textCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Import Functions'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      int count = 0;
      if (format == 'csv') {
        count = await widget.controller.importFunctionsFromCsv(
          textCtrl.text,
          folder: targetFolder,
          target: targetName,
        );
      } else {
        count = await widget.controller.importFunctionsFromJson(
          textCtrl.text,
          folder: targetFolder,
          target: targetName,
        );
      }
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Imported $count functions.')));
      }
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
        if (!name.contains(q) &&
            !addr.contains(q) &&
            !mod.contains(q) &&
            !purp.contains(q)) {
          return false;
        }
      }
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        final s = (f.properties['status'] as String?)?.toLowerCase();
        if (s != _statusFilter!.toLowerCase()) return false;
      }
      if (_confidenceFilter != null && _confidenceFilter!.isNotEmpty) {
        final c = (f.properties['confidence'] as String?)?.toLowerCase();
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
          child: Row(
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

              // Status Filter Pills
              _StatusPill(
                label: 'All',
                selected: _statusFilter == null,
                onTap: () => setState(() => _statusFilter = null),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label: 'Unknown',
                selected: _statusFilter == 'Unknown',
                onTap: () => setState(
                  () => _statusFilter = _statusFilter == 'Unknown'
                      ? null
                      : 'Unknown',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label: 'Interesting',
                selected: _statusFilter == 'Interesting',
                onTap: () => setState(
                  () => _statusFilter = _statusFilter == 'Interesting'
                      ? null
                      : 'Interesting',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label: 'Investigating',
                selected: _statusFilter == 'Investigating',
                onTap: () => setState(
                  () => _statusFilter = _statusFilter == 'Investigating'
                      ? null
                      : 'Investigating',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label: 'Partially Understood',
                selected: _statusFilter == 'Partially Understood',
                onTap: () => setState(
                  () => _statusFilter = _statusFilter == 'Partially Understood'
                      ? null
                      : 'Partially Understood',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label: 'Confirmed',
                selected: _statusFilter == 'Confirmed',
                onTap: () => setState(
                  () => _statusFilter = _statusFilter == 'Confirmed'
                      ? null
                      : 'Confirmed',
                ),
                colors: colors,
              ),

              const Spacer(),

              // Import button
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

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: colors.raised,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'FUNCTION / SYMBOL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'ADDRESS / RVA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'MODULE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'PURPOSE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'CONFIDENCE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'ACTIONS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                        '0x0';
                    final mod =
                        f.properties['module']?.toString() ?? 'target.exe';
                    final purpose = f.properties['purpose']?.toString() ?? '';
                    final conf =
                        f.properties['confidence']?.toString() ?? 'Medium';
                    final status =
                        f.properties['status']?.toString() ?? 'Investigating';

                    return InkWell(
                      onTap: () => widget.controller.openObject(f.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: idx.isEven
                              ? Colors.transparent
                              : colors.panel.withValues(alpha: 0.3),
                          border: Border(
                            bottom: BorderSide(
                              color: colors.divider.withValues(alpha: 0.5),
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
                                      f.title.isEmpty ? 'sub_$addr' : f.title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Address
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatAddress(addr),
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
                                mod,
                                style: const TextStyle(fontSize: 12.5),
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
                                padding: const EdgeInsets.symmetric(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: status.toLowerCase() == 'confirmed'
                                      ? Colors.green.shade400.withValues(
                                          alpha: 0.15,
                                        )
                                      : colors.raised,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: status.toLowerCase() == 'confirmed'
                                        ? Colors.green.shade400
                                        : colors.subtle,
                                  ),
                                ),
                              ),
                            ),
                            // Actions
                            SizedBox(
                              width: 120,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip:
                                        'Copy Address (${formatAddress(addr)})',
                                    icon: const Icon(Icons.tag, size: 16),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: formatAddress(addr),
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied ${formatAddress(addr)} to clipboard',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip:
                                        'Copy Module+Offset (${formatModuleOffset(mod, addr)})',
                                    icon: const Icon(Icons.copy, size: 15),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: formatModuleOffset(mod, addr),
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied ${formatModuleOffset(mod, addr)} to clipboard',
                                          ),
                                          duration: const Duration(seconds: 1),
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
                                    onPressed: () =>
                                        widget.controller.openObject(f.id),
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final OrbitColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? colors.accent : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.accent : colors.text,
          ),
        ),
      ),
    );
  }
}
