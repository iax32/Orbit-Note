import 'dart:convert';

import 'universal_object.dart';
import 'json_values.dart';

/// Per-installation records avoid whole-settings-file conflicts between devices.
/// Only explicitly portable, Vault-scoped values cross this boundary.
class PortablePreferences {
  static const typeId = 'orbit.preferences';
  static const keys = {
    'fontSize',
    'contentWidth',
    'fontFamily',
    'documentFontFamily',
    'monoFontFamily',
    'themePreset',
    'followSystemAppearance',
    'cornerStyle',
    'compact',
    'motion',
    'motionOptions',
    'spellCheckEnabled',
    'userDictionary',
    'accentColor',
    'colorOverrides',
    'defaultNoteMode',
    'defaultDocumentFormat',
    'bionicReadingDefault',
    'defaultCanvasGrid',
    'canvasSnapToGrid',
    'defaultAudioSpeed',
    'editorLineHeight',
    'showLineNumbers',
    'defaultCodeWrap',
    'codeFontSize',
    'autoSaveInterval',
    'autoSnapshotOnClose',
    'reverseEngineeringEnabled',
    'customThemes',
    'folderColors',
    'collapsedFolders',
    'noteSort',
    'showAttachments',
    'explorerCalendarCollapsed',
    'focusMinutes',
    'shortBreakMinutes',
    'longBreakMinutes',
  };

  static Map<String, dynamic> select(Map<String, dynamic> settings) =>
      Map<String, dynamic>.from(
        jsonDecode(
              jsonEncode({
                for (final key in keys)
                  key:
                      settings[key] ??
                      switch (key) {
                        'customThemes' ||
                        'collapsedFolders' ||
                        'userDictionary' => <dynamic>[],
                        'folderColors' ||
                        'colorOverrides' ||
                        'motionOptions' => <String, dynamic>{},
                        _ => null,
                      },
              }),
            )
            as Map,
      );

  static bool equal(Object? a, Object? b) => jsonValuesEqual(a, b);

  static Map<String, dynamic> fields(UniversalObject record) {
    if (record.isReadOnly ||
        record.data['version'] != 1 ||
        record.data['fields'] is! Map ||
        jsonEncode(record.data).length > 500000) {
      throw const FormatException(
        'Unsupported or damaged synchronized preferences; original preserved.',
      );
    }
    final result = Map<String, dynamic>.from(record.data['fields'] as Map);
    for (final field in result.values) {
      if (field is! Map ||
          field['clock'] is! int ||
          (field['clock'] as int) < 1 ||
          (field['clock'] as int) > 9007199254740000 ||
          !field.containsKey('value')) {
        throw const FormatException('Invalid synchronized preference field.');
      }
    }
    return result;
  }

  static ({Map<String, dynamic> values, int clock}) merge(
    Iterable<UniversalObject> records,
  ) {
    final winners = <String, ({int clock, String owner, dynamic value})>{};
    var clock = 0;
    for (final record in records.where((r) => !r.isDeleted)) {
      for (final entry in fields(record).entries) {
        final field = entry.value as Map;
        final tick = field['clock'] as int;
        if (tick > clock) clock = tick;
        if (!keys.contains(entry.key)) continue;
        final prior = winners[entry.key];
        if (prior == null ||
            tick > prior.clock ||
            (tick == prior.clock && record.id.compareTo(prior.owner) > 0)) {
          winners[entry.key] = (
            clock: tick,
            owner: record.id,
            value: field['value'],
          );
        }
      }
    }
    return (
      values: {for (final e in winners.entries) e.key: e.value.value},
      clock: clock,
    );
  }
}
