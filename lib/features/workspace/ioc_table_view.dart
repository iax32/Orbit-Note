import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';

class IocTableView extends StatefulWidget {
  const IocTableView({
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
  State<IocTableView> createState() => _IocTableViewState();
}

class _IocTableViewState extends State<IocTableView> {
  String _searchQuery = '';
  String? _typeFilter;
  String? _confidenceFilter;

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

  bool _isIoc(UniversalObject o) {
    if (o.isDeleted) return false;
    if (!_matchesScope(o)) return false;
    return o.properties['category'] == 'Indicator' ||
        o.properties.containsKey('iocType');
  }

  Future<void> _createNewIoc() async {
    final valCtrl = TextEditingController();
    final ctxCtrl = TextEditingController();
    String selectedType = 'File Hash';
    String selectedConfidence = 'High';

    final targetFolder = widget.folderFilter != null
        ? (widget.folderFilter!.contains('Indicators')
              ? widget.folderFilter!
              : '${widget.folderFilter}/Indicators')
        : 'Malware Analysis/${widget.scope ?? "Sample"}/Indicators';

    final targetName =
        widget.scope ??
        widget.viewObject.properties['target']?.toString() ??
        '';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Indicator of Compromise (IOC)'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: valCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Indicator Value *',
                      hintText: 'e.g. 198.51.100.45 or evil-domain.net',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Indicator Type',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'File Hash',
                              child: Text('File Hash'),
                            ),
                            DropdownMenuItem(
                              value: 'Domain',
                              child: Text('Domain'),
                            ),
                            DropdownMenuItem(
                              value: 'IP Address',
                              child: Text('IP Address'),
                            ),
                            DropdownMenuItem(value: 'URL', child: Text('URL')),
                            DropdownMenuItem(
                              value: 'File Path',
                              child: Text('File Path'),
                            ),
                            DropdownMenuItem(
                              value: 'Registry Path',
                              child: Text('Registry Path'),
                            ),
                            DropdownMenuItem(
                              value: 'Mutex',
                              child: Text('Mutex'),
                            ),
                            DropdownMenuItem(
                              value: 'Process Name',
                              child: Text('Process Name'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedType = val);
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctxCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Context / Observation Details',
                      hintText: 'Hardcoded C2 address in dropped payload',
                    ),
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
                if (valCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Create Indicator'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await widget.controller.createIocDoc(
        folder: targetFolder,
        value: valCtrl.text.trim(),
        type: selectedType,
        confidence: selectedConfidence,
        context: ctxCtrl.text.trim(),
        target: targetName,
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final allIocs = widget.controller.activeObjects.where(_isIoc).toList();

    final filtered = allIocs.where((ioc) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final val = (ioc.properties['value'] ?? ioc.title)
            .toString()
            .toLowerCase();
        final type = (ioc.properties['iocType'] ?? '').toString().toLowerCase();
        final ctx = (ioc.properties['context'] ?? '').toString().toLowerCase();
        if (!val.contains(q) && !type.contains(q) && !ctx.contains(q)) {
          return false;
        }
      }
      if (_typeFilter != null && _typeFilter!.isNotEmpty) {
        final t = (ioc.properties['iocType'] as String?)?.toLowerCase();
        if (t != _typeFilter!.toLowerCase()) return false;
      }
      if (_confidenceFilter != null && _confidenceFilter!.isNotEmpty) {
        final c = (ioc.properties['confidence'] as String?)?.toLowerCase();
        if (c != _confidenceFilter!.toLowerCase()) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: colors.panel,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 16),
                    hintText: 'Search indicator value, context...',
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

              _TypePill(
                label: 'All',
                selected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'Hashes',
                selected: _typeFilter == 'File Hash',
                onTap: () => setState(
                  () => _typeFilter = _typeFilter == 'File Hash'
                      ? null
                      : 'File Hash',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'IP / Domain',
                selected:
                    _typeFilter == 'IP Address' || _typeFilter == 'Domain',
                onTap: () => setState(
                  () => _typeFilter = _typeFilter == 'IP Address'
                      ? null
                      : 'IP Address',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'URL',
                selected: _typeFilter == 'URL',
                onTap: () => setState(
                  () => _typeFilter = _typeFilter == 'URL' ? null : 'URL',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'Host / Reg',
                selected:
                    _typeFilter == 'Registry Path' ||
                    _typeFilter == 'File Path',
                onTap: () => setState(
                  () => _typeFilter = _typeFilter == 'Registry Path'
                      ? null
                      : 'Registry Path',
                ),
                colors: colors,
              ),
              const SizedBox(width: 4),
              _TypePill(
                label: 'Mutex',
                selected: _typeFilter == 'Mutex',
                onTap: () => setState(
                  () => _typeFilter = _typeFilter == 'Mutex' ? null : 'Mutex',
                ),
                colors: colors,
              ),

              const Spacer(),

              FilledButton.icon(
                onPressed: _createNewIoc,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Indicator'),
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
                flex: 4,
                child: Text(
                  'INDICATOR VALUE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'TYPE',
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
                flex: 4,
                child: Text(
                  'CONTEXT / OBSERVATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'ACTIONS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Rows List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    allIocs.isEmpty
                        ? 'No indicators recorded. Click "New Indicator" to document IOCs.'
                        : 'No indicators match current filters.',
                    style: TextStyle(color: colors.subtle),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final ioc = filtered[idx];
                    final val =
                        ioc.properties['value']?.toString() ?? ioc.title;
                    final type =
                        ioc.properties['iocType']?.toString() ?? 'Indicator';
                    final conf =
                        ioc.properties['confidence']?.toString() ?? 'High';
                    final ctx = ioc.properties['context']?.toString() ?? '';

                    return InkWell(
                      onTap: () => widget.controller.openObject(ioc.id),
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
                            // Value
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 16,
                                    color: colors.accent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      val,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Type
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.subtle,
                                  ),
                                ),
                              ),
                            ),
                            // Confidence
                            Expanded(
                              flex: 2,
                              child: Text(
                                conf,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: conf == 'Verified'
                                      ? OrbitColors.of(context).success
                                      : colors.text,
                                ),
                              ),
                            ),
                            // Context
                            Expanded(
                              flex: 4,
                              child: Text(
                                ctx,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.subtle,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Actions
                            SizedBox(
                              width: 80,
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Copy Indicator',
                                    icon: const Icon(Icons.copy, size: 15),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: val),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied "$val" to clipboard',
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
                                        widget.controller.openObject(ioc.id),
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

class _TypePill extends StatelessWidget {
  const _TypePill({
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
