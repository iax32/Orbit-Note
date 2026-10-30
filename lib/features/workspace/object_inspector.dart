import '../../domain/object_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/orbit_theme.dart';
import '../../app/orbit_components.dart';
import '../../app/workspace_controller.dart';
import '../../domain/backlinks.dart';
import '../../domain/universal_object.dart';
import 'local_context_graph.dart';
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
  int _relationTab = 0; // 0: Linked, 1: Unlinked, 2: Outbound, 3: Related
  bool _showLocalGraph = false;
  final _linkingMentions = <String>{};

  bool _writeProperty(
    UniversalObject expected,
    String key,
    dynamic value,
    int generation, {
    bool remove = false,
  }) {
    if (!mounted) return false;
    final c = widget.controller;
    final ok = c.editObjectMetadata(
      expected,
      generation: generation,
      changes: remove ? const {} : {key: value},
      remove: remove ? {key} : const {},
    );
    if (!ok) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            generation == c.workspaceGeneration
                ? c.error ?? 'Could not update this property.'
                : 'The Vault changed. Your draft is retained; close and reopen the dialog.',
          ),
        ),
      );
    }
    return ok;
  }

  bool _isInternalProp(String key) =>
      key == 'orbitLinkBindings' || key == 'orbitConnections';

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
    return OrbitPanelHeader(
      icon: Icons.tune_outlined,
      title: 'Context',
      subtitle: o == null
          ? 'Select an object to inspect'
          : 'Properties and links',
      actions: [
        IconButton(
          tooltip: 'Close inspector',
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
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(objectIcon(o.typeId), size: 18, color: colors.subtle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(typeName, style: OrbitTypography.metadata(context)),
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
                ),
              ),
              IconButton(
                tooltip: 'Copy UUID',
                iconSize: 13,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
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
    final generation = widget.controller.workspaceGeneration;
    final type = _inferPropertyType(key, value);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(
            key,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.subtle,
            ),
          );
          final editor = _buildPropertyValueWidget(colors, o, key, value, type);
          final remove = IconButton(
            tooltip: 'Remove $key',
            iconSize: 13,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {
              _writeProperty(o, key, null, generation, remove: true);
            },
            icon: Icon(Icons.close, color: colors.subtle),
          );
          if (constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(11) > 16) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: label),
                    remove,
                  ],
                ),
                editor,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: editor),
              remove,
            ],
          );
        },
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
    final generation = widget.controller.workspaceGeneration;
    switch (type) {
      case PropertyType.boolean:
        final boolVal = value == true;
        return Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: key,
            child: Switch(
              value: boolVal,
              activeThumbColor: colors.accent,
              onChanged: (v) {
                _writeProperty(o, key, v, generation);
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
                    child: Text(dateStr, style: const TextStyle(fontSize: 11)),
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
                ),
              ),
            ),
            IconButton(
              tooltip: 'Edit URL',
              iconSize: 12,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                    Flexible(
                      child: Text(
                        '#$tag',
                        style: TextStyle(fontSize: 10, color: colors.accent),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove tag $tag',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final next = List<String>.from(tagsList)..remove(tag);
                        _writeProperty(o, key, next, generation);
                      },
                      icon: const Icon(Icons.close, size: 14),
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
              ),
            ),
          ),
        );
    }
  }

  Widget _buildRelationsSection(OrbitColors colors, UniversalObject o) {
    final c = widget.controller;
    final linkedMentions = c.linkedMentions(o.id);
    final unlinkedMentions = c.unlinkedMentions(o.id);
    final outbound = c.outboundLinks(o.id);
    final related = c.relatedObjects(o.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'RELATIONS & REFERENCES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: colors.subtle,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: _showLocalGraph
                  ? 'Hide Local Graph'
                  : 'Show Local Graph',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() => _showLocalGraph = !_showLocalGraph),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showLocalGraph ? Icons.hub : Icons.hub_outlined,
                        size: 13,
                        color: _showLocalGraph ? colors.accent : colors.subtle,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Graph',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _showLocalGraph
                              ? colors.accent
                              : colors.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showLocalGraph) ...[
          const SizedBox(height: 8),
          LocalContextGraph(
            controller: widget.controller,
            focusId: o.id,
            height: 200,
            onOpenObject: (id) => widget.controller.openObject(id),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: colors.raised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildRelationTabButton(
                colors,
                0,
                'Linked',
                linkedMentions.length,
              ),
              _buildRelationTabButton(
                colors,
                1,
                'Unlinked',
                unlinkedMentions.length,
              ),
              _buildRelationTabButton(colors, 2, 'Outbound', outbound.length),
              _buildRelationTabButton(colors, 3, 'Related', related.length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (context) {
            if (_relationTab == 0) {
              if (linkedMentions.isEmpty) {
                return _buildEmptyRelationBox(
                  colors,
                  'No inbound linked references found.',
                );
              }
              return Column(
                children: linkedMentions
                    .map((m) => _buildLinkedMentionCard(colors, m))
                    .toList(),
              );
            } else if (_relationTab == 1) {
              if (unlinkedMentions.isEmpty) {
                return _buildEmptyRelationBox(
                  colors,
                  'No unlinked mentions of "${o.title}" found.',
                );
              }
              return Column(
                children: unlinkedMentions
                    .map((m) => _buildUnlinkedMentionCard(colors, m, o.id))
                    .toList(),
              );
            } else if (_relationTab == 2) {
              if (outbound.isEmpty) {
                return _buildEmptyRelationBox(
                  colors,
                  'No outbound references found.',
                );
              }
              return Column(
                children: outbound
                    .map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ObjectRow(
                          wrapTitle: true,
                          object: v,
                          onTap: () => widget.controller.openObject(v.id),
                        ),
                      ),
                    )
                    .toList(),
              );
            } else {
              if (related.isEmpty) {
                return _buildEmptyRelationBox(
                  colors,
                  'No related objects in this project/folder/tags.',
                );
              }
              return Column(
                children: related
                    .map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ObjectRow(
                          wrapTitle: true,
                          object: v,
                          onTap: () => widget.controller.openObject(v.id),
                        ),
                      ),
                    )
                    .toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildEmptyRelationBox(OrbitColors colors, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.raised.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 11, color: colors.subtle),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLinkedMentionCard(OrbitColors colors, LinkedMention m) {
    final typeIcon = switch (m.source.typeId) {
      'orbit.note' => Icons.description_outlined,
      'orbit.task' => Icons.check_circle_outline,
      'orbit.canvas' => Icons.dashboard_outlined,
      'orbit.event' => Icons.event_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

    final typeBadge = switch (m.type) {
      LinkedMentionType.wikilink => 'wikilink',
      LinkedMentionType.canvasElement => 'canvas card',
      LinkedMentionType.taskContext => 'task context',
      LinkedMentionType.eventContext => 'event context',
      LinkedMentionType.pdfReference => 'pdf citation',
      LinkedMentionType.studyReference => 'study source',
      LinkedMentionType.planningResource => 'planning resource',
      LinkedMentionType.researchRelation => m.label ?? 'research link',
      LinkedMentionType.objectReference => m.label ?? 'live reference',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          widget.controller.requestLocation(
            m.sourceLocation ?? ObjectReference(m.source.id),
            offset: m.sourceOffset,
          );
          widget.controller.openObject(m.source.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, size: 14, color: colors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.source.title.isEmpty ? 'Untitled' : m.source.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$typeBadge${m.targetLocation?.isPrecise == true ? ' · ${m.targetLocation!.fragment}' : ''}',
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.subtle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (m.snippet.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  m.snippet,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.text.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlinkedMentionCard(
    OrbitColors colors,
    UnlinkedMention m,
    String targetId,
  ) {
    final c = widget.controller,
        generation = widget.controller.workspaceGeneration;
    final pendingKey = '$generation:${m.source.id}:${m.startIndex}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: colors.subtle,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.controller.openObject(m.source.id),
                        child: Text(
                          m.source.title.isEmpty ? 'Untitled' : m.source.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: ValueKey(
                    'orbit-link-mention-${m.source.id}-${m.startIndex}',
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _linkingMentions.contains(pendingKey)
                      ? null
                      : () async {
                          if (!mounted ||
                              generation != c.workspaceGeneration ||
                              !_linkingMentions.add(pendingKey)) {
                            return;
                          }
                          setState(() {});
                          final ok = await c.linkUnlinkedMention(
                            m,
                            targetId,
                            expectedGeneration: generation,
                          );
                          _linkingMentions.remove(pendingKey);
                          if (mounted && generation == c.workspaceGeneration) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Linked mention in "${m.source.title}"'
                                      : 'Mention not saved. The passage changed or its save needs attention. Refresh and review the source.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            setState(() {});
                          }
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_link, size: 13, color: colors.accent),
                      const SizedBox(width: 3),
                      Text('Link', style: TextStyle(color: colors.accent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '"${m.matchedText}"',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
            if (m.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                m.snippet,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.text.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelationTabButton(
    OrbitColors colors,
    int index,
    String label,
    int count,
  ) {
    final isSelected = _relationTab == index;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _relationTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
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
          onPressed: () => widget.controller.trash(o.id, expected: o),
          icon: const Icon(Icons.delete_outline, size: 15),
          label: const Text('Move to Trash', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _showPropertyDialog({
    required BuildContext context,
    required List<TextEditingController> controllers,
    required WidgetBuilder builder,
  }) => showOrbitDialog<void>(
    context: context,
    builder: (context) =>
        _PropertyDialogScope(controllers: controllers, builder: builder),
  );

  Future<void> _showAddPropertyDialog(
    BuildContext context,
    UniversalObject o,
  ) async {
    final generation = widget.controller.workspaceGeneration;
    final formKey = GlobalKey<FormState>();
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    var selectedType = PropertyType.text;
    var boolVal = true;
    DateTime? pickedDate;

    await _showPropertyDialog(
      context: context,
      controllers: [keyController, valueController],
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return OrbitDialog(
              title: const Text('Add Property', style: TextStyle(fontSize: 16)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: keyController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Property Name',
                        errorMaxLines: 6,
                        hintText: 'e.g. priority, status, author',
                      ),
                      errorBuilder: _propertyValidationMessage,
                      validator: (v) {
                        final trimmed = v?.trim() ?? '';
                        if (trimmed.isEmpty) return 'Name cannot be empty';
                        if (_isInternalProp(trimmed)) {
                          return 'This property is managed by Orbit Note';
                        }
                        if (o.properties.containsKey(trimmed)) {
                          return 'Property "$trimmed" already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PropertyType>(
                      initialValue: selectedType,
                      isExpanded: true,
                      itemHeight: null,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            pickedDate != null
                                ? '${pickedDate!.year.toString().padLeft(4, '0')}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}'
                                : 'Select date',
                            style: const TextStyle(fontSize: 13),
                          ),

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
                              if (res != null && ctx.mounted) {
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
                          errorMaxLines: 6,
                          labelText: selectedType == PropertyType.tags
                              ? 'Tags (comma separated)'
                              : 'Value',
                          hintText: selectedType == PropertyType.tags
                              ? 'deep-work, research, q3'
                              : selectedType == PropertyType.url
                              ? 'https://example.com'
                              : null,
                        ),
                        errorBuilder: _propertyValidationMessage,
                        validator: (v) {
                          if (selectedType == PropertyType.number) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a number';
                            }
                            if (num.tryParse(v.trim())?.isFinite != true) {
                              return 'Enter a finite number';
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!mounted ||
                        !dialogCtx.mounted ||
                        formKey.currentState?.validate() != true) {
                      return;
                    }
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
                    if (!_writeProperty(o, key, parsedValue, generation)) {
                      return;
                    }
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
    final generation = widget.controller.workspaceGeneration;
    final controller = TextEditingController(text: currentValue);
    await _showPropertyDialog(
      context: context,
      controllers: [controller],
      builder: (dialogCtx) => OrbitDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Value',
            errorMaxLines: 6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!mounted || !dialogCtx.mounted) return;
              if (!_writeProperty(o, key, controller.text.trim(), generation)) {
                return;
              }
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
    final generation = widget.controller.workspaceGeneration;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '$currentValue');
    await _showPropertyDialog(
      context: context,
      controllers: [controller],
      builder: (dialogCtx) => OrbitDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Value',
              errorMaxLines: 6,
            ),
            errorBuilder: _propertyValidationMessage,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Enter a number';
              }
              if (num.tryParse(v.trim())?.isFinite != true) {
                return 'Enter a finite number';
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
              if (!mounted ||
                  !dialogCtx.mounted ||
                  formKey.currentState?.validate() != true) {
                return;
              }
              final parsed = num.parse(controller.text.trim());
              if (!_writeProperty(o, key, parsed, generation)) return;
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
    final generation = widget.controller.workspaceGeneration;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentUrl);
    await _showPropertyDialog(
      context: context,
      controllers: [controller],
      builder: (dialogCtx) => OrbitDialog(
        title: Text('Edit $key', style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Value',
              errorMaxLines: 6,
            ),
            errorBuilder: _propertyValidationMessage,
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
              if (!mounted ||
                  !dialogCtx.mounted ||
                  formKey.currentState?.validate() != true) {
                return;
              }
              if (!mounted || !dialogCtx.mounted) return;
              if (!_writeProperty(o, key, controller.text.trim(), generation)) {
                return;
              }
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
    final generation = widget.controller.workspaceGeneration;
    final controller = TextEditingController();
    await _showPropertyDialog(
      context: context,
      controllers: [controller],
      builder: (dialogCtx) => OrbitDialog(
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
              if (!mounted || !dialogCtx.mounted) return;
              final newTag = controller.text.trim().replaceAll('#', '');
              if (newTag.isNotEmpty && !currentTags.contains(newTag)) {
                if (!_writeProperty(o, key, [
                  ...currentTags,
                  newTag,
                ], generation)) {
                  return;
                }
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
    final generation = widget.controller.workspaceGeneration;
    final parsed = DateTime.tryParse(currentDateStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed.isBefore(DateTime(2000))
          ? DateTime(2000)
          : parsed.isAfter(DateTime(2100))
          ? DateTime(2100)
          : parsed,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _writeProperty(o, key, formatted, generation);
    }
  }
}

/// Keep controllers alive through the dialog's closing transition, then dispose
/// them with the route rather than leaking them on every property edit.
class _PropertyDialogScope extends StatefulWidget {
  const _PropertyDialogScope({
    required this.controllers,
    required this.builder,
  });
  final List<TextEditingController> controllers;
  final WidgetBuilder builder;

  @override
  State<_PropertyDialogScope> createState() => _PropertyDialogScopeState();
}

class _PropertyDialogScopeState extends State<_PropertyDialogScope> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget _propertyValidationMessage(BuildContext context, String message) => Text(
  message,
  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
);
