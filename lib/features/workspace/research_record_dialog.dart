import 'package:flutter/material.dart';

import '../../app/workspace_controller.dart';
import '../../domain/reverse_engineering.dart';

Future<void> showResearchRecordDialog(
  BuildContext context,
  WorkspaceController controller, {
  required String folder,
  String? initialCategory,
}) async {
  final fields = <String, TextEditingController>{
    for (final key in [
      'title',
      'summary',
      'address',
      'rva',
      'module',
      'moduleBase',
      'binaryVersion',
    ])
      key: TextEditingController(),
  };
  var category = initialCategory ?? 'Binary';
  var space = 'virtual';
  var binaryId = '';
  var moduleId = '';
  var confidence = 'Low';
  final supporting = <String>{};
  final contradicting = <String>{};
  String? error;
  var saving = false;
  var evidenceQuery = '';
  final objects = controller.activeObjects.toList();
  try {
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          Widget field(String key, String label, {int lines = 1}) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: fields[key],
              maxLines: lines,
              decoration: InputDecoration(labelText: label),
            ),
          );
          Widget identity(
            String label,
            String type,
            String value,
            void Function(String) update,
          ) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: [
                const DropdownMenuItem(value: '', child: Text('Not specified')),
                for (final object in objects.where(
                  (o) => o.properties['category'] == type,
                ))
                  DropdownMenuItem(value: object.id, child: Text(object.title)),
              ],
              onChanged: (value) => refresh(() => update(value ?? '')),
            ),
          );
          return PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: const Text('Research record'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Record type',
                        ),
                        items: [
                          for (final value in researchRecordCategories)
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) =>
                            refresh(() => category = value ?? category),
                      ),
                      const SizedBox(height: 12),
                      field('title', 'Name'),
                      field('summary', 'Observation or proposal', lines: 3),
                      DropdownButtonFormField<String>(
                        initialValue: confidence,
                        decoration: const InputDecoration(
                          labelText: 'Confidence',
                        ),
                        items: [
                          for (final value in [
                            'Low',
                            'Medium',
                            'High',
                            'Verified',
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) =>
                            refresh(() => confidence = value ?? confidence),
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Binary and address context'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          identity(
                            'Binary',
                            'Binary',
                            binaryId,
                            (id) => binaryId = id,
                          ),
                          field('binaryVersion', 'Build / version identity'),
                          identity(
                            'Module record',
                            'Module',
                            moduleId,
                            (id) => moduleId = id,
                          ),
                          field('module', 'Module name'),
                          DropdownButtonFormField<String>(
                            initialValue: space,
                            decoration: const InputDecoration(
                              labelText: 'Address space',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'virtual',
                                child: Text('Virtual address'),
                              ),
                              DropdownMenuItem(
                                value: 'rva',
                                child: Text('Relative virtual address'),
                              ),
                              DropdownMenuItem(
                                value: 'file',
                                child: Text('File offset'),
                              ),
                            ],
                            onChanged: (value) =>
                                refresh(() => space = value ?? space),
                          ),
                          const SizedBox(height: 12),
                          field('address', 'Address / file offset (hex)'),
                          field('rva', 'RVA (hex, optional)'),
                          field('moduleBase', 'Module base (hex, optional)'),
                        ],
                      ),
                      ExpansionTile(
                        title: const Text(
                          'Supporting and contradicting evidence',
                        ),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Find evidence',
                            ),
                            onChanged: (value) => refresh(
                              () => evidenceQuery = value.toLowerCase(),
                            ),
                          ),
                          const Text(
                            'Showing up to 30 matching records. Search to find others.',
                          ),
                          for (final object
                              in objects
                                  .where(
                                    (o) =>
                                        o.title.toLowerCase().contains(
                                          evidenceQuery,
                                        ) ||
                                        o.id == evidenceQuery,
                                  )
                                  .take(30))
                            ListTile(
                              dense: true,
                              title: Text(object.title),
                              subtitle: Text(
                                object.properties['category']?.toString() ??
                                    object.typeId,
                              ),
                              trailing: SizedBox(
                                width: 155,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: supporting.contains(object.id)
                                      ? 'for'
                                      : contradicting.contains(object.id)
                                      ? 'against'
                                      : '',
                                  items: const [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text('Unlinked'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'for',
                                      child: Text('Supports'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'against',
                                      child: Text('Contradicts'),
                                    ),
                                  ],
                                  onChanged: (value) => refresh(() {
                                    supporting.remove(object.id);
                                    contradicting.remove(object.id);
                                    if (value == 'for') {
                                      supporting.add(object.id);
                                    }
                                    if (value == 'against') {
                                      contradicting.add(object.id);
                                    }
                                  }),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (category == 'Patch')
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Records a proposed change and rollback notes. Binary files are never modified.',
                          ),
                        ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
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
                  onPressed: saving
                      ? null
                      : () async {
                          refresh(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            final object = await controller
                                .createResearchRecord(
                                  folder: folder,
                                  category: category,
                                  title: fields['title']!.text,
                                  summary: fields['summary']!.text,
                                  confidence: confidence,
                                  location: ResearchAddress(
                                    binaryId: binaryId,
                                    moduleId: moduleId,
                                    binaryVersion: fields['binaryVersion']!.text
                                        .trim(),
                                    module: fields['module']!.text.trim(),
                                    addressSpace: space,
                                    address: fields['address']!.text.trim(),
                                    rva: fields['rva']!.text.trim(),
                                    moduleBase: fields['moduleBase']!.text
                                        .trim(),
                                  ),
                                  supportingIds: supporting.toList(),
                                  contradictingIds: contradicting.toList(),
                                );
                            if (object == null) {
                              throw StateError(
                                controller.error ??
                                    'Record could not be saved.',
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              refresh(() {
                                saving = false;
                                error = '$e';
                              });
                            }
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Create record'),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
  } finally {
    for (final field in fields.values) {
      field.dispose();
    }
  }
}
