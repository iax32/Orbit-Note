import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import 'workspace_views.dart';

enum PropertyType { text, number, boolean, date, tags, url, other }

class ObjectInspector extends ConsumerStatefulWidget {
  const ObjectInspector({
    super.key,
    required this.controller,
    required this.onRename,
    this.onClose,
  });

  final WorkspaceController controller;
  final void Function(UniversalObject object) onRename;
  final VoidCallback? onClose;

  @override
  ConsumerState<ObjectInspector> createState() => _ObjectInspectorState();
}

class _ObjectInspectorState extends ConsumerState<ObjectInspector> {
  int _relationTab = 0; // 0: Backlinks, 1: Outbound, 2: Related

  bool _isInternalProp(String key) => key == 'orbitLinkBindings';

  PropertyType _inferPropertyType(String key, dynamic value) {
    if (value is bool) return PropertyType.boolean;
    if (value is num) return PropertyType.number;
    if (value is List) return PropertyType.tags;
    if (value is String) {
      if (key.toLowerCase() == 'url' ||
          value.startsWith('http://') ||
          value.startsWith('https://')) {
        return PropertyType.url;
      }
      final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (dateRegex.hasMatch(value) ||
          key.toLowerCase() == 'due' ||
          key.toLowerCase() == 'date' ||
          key.toLowerCase() == 'deadline') {
        return PropertyType.date;
      }
      return PropertyType.text;
    }
    return PropertyType.other;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workspaceProvider);
    final c = widget.controller;
    final o = c.find(c.session.activeId);
    final colors = OrbitColors.of(context);

    return Material(
      color: colors.panel,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          _buildHeader(colors, o),
          const SizedBox(height: 16),
          if (o == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Open an object to inspect properties and context.',
                style: TextStyle(color: colors.subtle, height: 1.5),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            _buildIdentityCard(colors, o),
            const SizedBox(height: 16),
            _buildPropertiesSection(colors, o),
            const SizedBox(height: 16),
            _buildRelationsSection(colors, o),
            const SizedBox(height: 20),
            _buildActions(colors, o),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(OrbitColors colors, UniversalObject? o) {
    return Row(
      children: [
        Text(
          'CONTEXT INSPECTOR',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: colors.subtle,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Close inspector',
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed:
              widget.onClose ??
              () => widget.controller.updateSession(
                (s) => s.inspectorVisible = false,
              ),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildIdentityCard(OrbitColors colors, UniversalObject o) {
    final typeName = o.typeId.replaceFirst('orbit.', '').toUpperCase();
    final updatedText = o.updatedAt.toLocal().toString().split('.').first;
    final createdText = o.createdAt.toLocal().toString().split('.').first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  objectIcon(o.typeId),
                  size: 18,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            o.title.isEmpty ? 'Untitled' : o.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ID: ${o.id}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: colors.subtle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Copy UUID',
                iconSize: 13,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: o.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied object ID to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(Icons.schedule, size: 11, color: colors.subtle),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Updated $updatedText',
                  style: TextStyle(fontSize: 10, color: colors.subtle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.history, size: 11, color: colors.subtle),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Created $createdText',
                  style: TextStyle(fontSize: 10, color: colors.subtle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesSection(OrbitColors colors, UniversalObject o) {
    final entries =
        o.properties.entries.where((e) => !_isInternalProp(e.key)).toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PROPERTIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colors.subtle,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: colors.raised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length}',
                style: TextStyle(fontSize: 10, color: colors.subtle),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                textStyle: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _showAddPropertyDialog(context, o),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: colors.raised.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              'No properties defined.\nTap + Add to add typed metadata.',
              style: TextStyle(fontSize: 11, color: colors.subtle, height: 1.4),
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.raised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _buildPropertyRow(
                    colors,
                    o,
                    entries[i].key,
                    entries[i].value,
                  ),
                  if (i < entries.length - 1)
                    Divider(
                      height: 1,
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPropertyRow(
    OrbitColors colors,
    UniversalObject o,
    String key,
    dynamic value,
  ) {
    final type = _inferPropertyType(key, value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              key,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.subtle,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildPropertyValueWidget(colors, o, key, value, type),
          ),
          IconButton(
            tooltip: 'Remove $key',
            iconSize: 13,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            onPressed: () {
              widget.controller.removeProperty(o.id, key);
              setState(() {});
            },
            icon: Icon(Icons.close, color: colors.subtle),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyValueWidget(
    OrbitColors colors,
    UniversalObject o,
    String key,
    dynamic value,
    PropertyType type,
  ) {
    switch (type) {
      case PropertyType.boolean:
        final boolVal = value == true;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 24,
            child: Switch(
              value: boolVal,
              activeThumbColor: colors.accent,
              onChanged: (v) {
                widget.controller.updateProperty(o.id, key, v);
                setState(() {});
              },
            ),
          ),
        );

      case PropertyType.number:
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _showEditNumberDialog(context, o, key, value as num),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.numbers, size: 12, color: colors.accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case PropertyType.date:
        final dateStr = value.toString();
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _pickDate(context, o, key, dateStr),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined, size: 12, color: colors.accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case PropertyType.url:
        final urlStr = value.toString();
        return Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  final uri = Uri.tryParse(urlStr);
                  if (uri != null && uri.hasScheme) {
                    launchUrl(uri);
                  }
                },
                child: Text(
                  urlStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.accent,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit URL',
              iconSize: 12,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              onPressed: () => _showEditUrlDialog(context, o, key, urlStr),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        );

      case PropertyType.tags:
        final tagsList = (value as List).map((e) => e.toString()).toList();
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in tagsList)
              Container(
                padding: const EdgeInsets.only(
                  left: 6,
                  right: 2,
                  top: 1,
                  bottom: 1,
                ),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: TextStyle(fontSize: 10, color: colors.accent),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        final next = List<String>.from(tagsList)..remove(tag);
                        widget.controller.updateProperty(o.id, key, next);
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showAddTagDialog(context, o, key, tagsList),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 11, color: colors.accent),
                    const SizedBox(width: 2),
                    Text(
                      'Tag',
                      style: TextStyle(fontSize: 9, color: colors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case PropertyType.text:
      case PropertyType.other:
        final textVal = value.toString();
        return Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => _showEditStringDialog(context, o, key, textVal),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                textVal.isEmpty ? 'Empty' : textVal,
                style: TextStyle(
                  fontSize: 11,
                  color: textVal.isEmpty ? colors.subtle : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildRelationsSection(OrbitColors colors, UniversalObject o) {
    final c = widget.controller;
    final backlinks = c.backlinks(o.id);
    final outbound = c.outboundLinks(o.id);
    final related = c.relatedObjects(o.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RELATIONS & REFERENCES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: colors.subtle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              _buildRelationTabButton(colors, 0, 'Backlinks', backlinks.length),
              _buildRelationTabButton(colors, 1, 'Outbound', outbound.length),
              _buildRelationTabButton(colors, 2, 'Related', related.length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            final List<UniversalObject> items;
            final String emptyMsg;
            if (_relationTab == 0) {
              items = backlinks;
              emptyMsg = 'No inbound backlinks found.';
            } else if (_relationTab == 1) {
              items = outbound;
              emptyMsg = 'No outbound wiki-links found.';
            } else {
              items = related;
              emptyMsg = 'No related objects in this project/folder/tags.';
            }

            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.raised.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  emptyMsg,
                  style: TextStyle(fontSize: 11, color: colors.subtle),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: items
                  .map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ObjectRow(
                        object: v,
                        onTap: () => widget.controller.openObject(v.id),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRelationTabButton(
    OrbitColors colors,
    int index,
    String label,
    int count,
  ) {
    final isSelected = _relationTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _relationTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? colors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? colors.text : colors.subtle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withValues(alpha: 0.2)
                      : colors.panel,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? colors.accent : colors.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(OrbitColors colors, UniversalObject o) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => widget.onRename(o),
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Rename Object', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            visualDensity: VisualDensity.compact,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => widget.controller.trash(o.id),
          icon: const Icon(Icons.delete_outline, size: 15),
          label: const Text('Move to Trash', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _showAddPropertyDialog(
    BuildContext context,
    UniversalObject o,
  ) async {
    final formKey = GlobalKey<FormState>();
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    var selectedType = PropertyType.text;
    var boolVal = true;
    DateTime? pickedDate;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add Property', style: TextStyle(fontSize: 16)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: keyController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Property Name',
                          hintText: 'e.g. priority, status, author',
                        ),
                        validator: (v) {
                          final trimmed = v?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Name cannot be empty';
                          if (o.properties.containsKey(trimmed)) {
                            return 'Property "$trimmed" already exists';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PropertyType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                            value: PropertyType.text,
                            child: Text('Text'),
                          ),
                          DropdownMenuItem(
                            value: PropertyType.number,
                            child: Text('Number'),
                          ),
                          DropdownMenuItem(
                            value: PropertyType.boolean,
                            child: Text('Checkbox (Boolean)'),
                          ),
                          DropdownMenuItem(
                            value: PropertyType.date,
                            child: Text('Date (YYYY-MM-DD)'),
                          ),
                          DropdownMenuItem(
                            value: PropertyType.tags,
                            child: Text('Tags (List)'),
                          ),
                          DropdownMenuItem(
                            value: PropertyType.url,
                            child: Text('URL (Link)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              if (selectedType == PropertyType.date &&
                                  pickedDate == null) {
                                pickedDate = DateTime.now();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (selectedType == PropertyType.boolean)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Initial state: checked',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: boolVal,
                          onChanged: (v) =>
                              setDialogState(() => boolVal = v ?? false),
                        )
                      else if (selectedType == PropertyType.date)
                        Row(
                          children: [
                            Text(
                              pickedDate != null
                                  ? '${pickedDate!.year.toString().padLeft(4, '0')}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select date',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: const Text('Pick Date'),
                              onPressed: () async {
                                final now = DateTime.now();
                                final res = await showDatePicker(
                                  context: ctx,
                                  initialDate: pickedDate ?? now,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (res != null) {
                                  setDialogState(() => pickedDate = res);
                                }
                              },
                            ),
                          ],
                        )
                      else
                        TextFormField(
                          controller: valueController,
                          keyboardType: selectedType == PropertyType.number
                              ? TextInputType.number
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: selectedType == PropertyType.tags
                                ? 'Tags (comma separated)'
                                : 'Value',
                            hintText: selectedType == PropertyType.tags
                                ? 'deep-work, research, q3'
                                : selectedType == PropertyType.url
                                ? 'https://example.com'
                                : null,
                          ),
                          validator: (v) {
                            if (selectedType == PropertyType.number) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter a number';
                              }
                              if (num.tryParse(v.trim()) == null) {
                                return 'Must be a valid number';
                              }
                            } else if (selectedType == PropertyType.url) {
                              final trimmed = v?.trim() ?? '';
                              if (trimmed.isNotEmpty) {
                                final uri = Uri.tryParse(trimmed);
                                if (uri == null || !uri.hasScheme) {
                                  return 'Must be a valid URL with scheme (e.g. https://)';
                                }
                              }
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final key = keyController.text.trim();
                    dynamic parsedValue;
                    switch (selectedType) {
                      case PropertyType.boolean:
                        parsedValue = boolVal;
                        break;
                      case PropertyType.number:
                        parsedValue = num.parse(valueController.text.trim());
                        break;
                      case PropertyType.date:
                        final d = pickedDate ?? DateTime.now();
                        parsedValue =
                            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        break;
                      case PropertyType.tags:
                        parsedValue = valueController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        break;
                      case PropertyType.url:
                      case PropertyType.text:
                      case PropertyType.other:
                        parsedValue = valueController.text.trim();
                        break;
                    }
                    widget.controller.updateProperty(o.id, key, parsedValue);
                    setState(() {});
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Add Property'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditStringDialog(
    BuildContext context,
    UniversalObject o,
    String key,
    String currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: key),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.controller.updateProperty(
                o.id,
                key,
                controller.text.trim(),
              );
              setState(() {});
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNumberDialog(
    BuildContext context,
    UniversalObject o,
    String key,
    num currentValue,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '$currentValue');
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: key),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Enter a number';
              }
              if (num.tryParse(v.trim()) == null) {
                return 'Must be a valid number';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final parsed = num.parse(controller.text.trim());
              widget.controller.updateProperty(o.id, key, parsed);
              setState(() {});
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUrlDialog(
    BuildContext context,
    UniversalObject o,
    String key,
    String currentUrl,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentUrl);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: key),
            validator: (v) {
              final trimmed = v?.trim() ?? '';
              if (trimmed.isNotEmpty) {
                final uri = Uri.tryParse(trimmed);
                if (uri == null || !uri.hasScheme) {
                  return 'Must be a valid URL with scheme (e.g. https://)';
                }
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              widget.controller.updateProperty(
                o.id,
                key,
                controller.text.trim(),
              );
              setState(() {});
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTagDialog(
    BuildContext context,
    UniversalObject o,
    String key,
    List<String> currentTags,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Tag', style: TextStyle(fontSize: 16)),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            hintText: 'e.g. priority-high',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newTag = controller.text.trim().replaceAll('#', '');
              if (newTag.isNotEmpty && !currentTags.contains(newTag)) {
                widget.controller.updateProperty(o.id, key, [
                  ...currentTags,
                  newTag,
                ]);
                setState(() {});
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    UniversalObject o,
    String key,
    String currentDateStr,
  ) async {
    final parsed = DateTime.tryParse(currentDateStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      widget.controller.updateProperty(o.id, key, formatted);
      setState(() {});
    }
  }
}
