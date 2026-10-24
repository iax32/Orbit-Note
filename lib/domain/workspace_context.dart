import 'dart:convert';

/// Personal context descriptors never contain object bodies or attachment bytes.
class WorkspaceContext {
  static const contextKeys = [
    'destination',
    'tabs',
    'activeId',
    'secondaryId',
    'sidebarVisible',
    'inspectorVisible',
    'sidebarWidth',
    'splitAxis',
    'splitRatio',
    'focusMode',
    'positions',
    'cameras',
    'noteViews',
    'collapsedFolders',
    'noteSort',
    'searchWorkspace',
  ];
  static const layoutKeys = [
    'sidebarVisible',
    'inspectorVisible',
    'sidebarWidth',
    'splitAxis',
    'splitRatio',
    'focusMode',
  ];
  static const appearanceKeys = [
    'fontSize',
    'fontFamily',
    'compact',
    'themePreset',
    'followSystemAppearance',
    'accentColor',
    'cornerStyle',
    'documentFontFamily',
    'monoFontFamily',
    'colorOverrides',
  ];
  static Map<String, dynamic> capture(
    Map<String, dynamic> session, {
    bool layoutOnly = false,
  }) => Map<String, dynamic>.from(
    jsonDecode(
          jsonEncode({
            for (final key in layoutOnly ? layoutKeys : contextKeys)
              if (session.containsKey(key)) key: session[key],
          }),
        )
        as Map,
  );
  static bool supported(Map<String, dynamic> library) =>
      library.isEmpty ||
      library['version'] == 1 &&
          library['items'] is List &&
          (library['items'] as List).length <= 30 &&
          (library['items'] as List).every(
            (r) => r is Map && r['id'] is String && r['name'] is String,
          );
  static List<Map<String, dynamic>> items(Map<String, dynamic> library) =>
      supported(library) && library['items'] is List
      ? (library['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
      : [];
  static void validate(Map<String, dynamic> record) {
    if (record['version'] != 1 ||
        record['id'] is! String ||
        record['name'] is! String ||
        (record['name'] as String).trim().isEmpty ||
        (record['name'] as String).length > 100 ||
        record['context'] is! Map ||
        !{'space', 'layout'}.contains(record['kind'])) {
      throw const FormatException('Unsupported context descriptor.');
    }
    final context = record['context'] as Map;
    for (final key in ['project', 'folder']) {
      if (record[key] != null && record[key] is! String) {
        throw const FormatException('Unsupported Space scope.');
      }
    }
    if (record['appearance'] != null && record['appearance'] is! Map ||
        record['dashboard'] != null && record['dashboard'] is! Map) {
      throw const FormatException('Unsupported context settings.');
    }
    for (final key in [
      'positions',
      'cameras',
      'noteViews',
      'searchWorkspace',
    ]) {
      if (context[key] != null && context[key] is! Map) {
        throw const FormatException('Unsupported context view state.');
      }
    }
    for (final key in ['tabs', 'collapsedFolders']) {
      if (context[key] != null &&
          (context[key] is! List ||
              !(context[key] as List).every((id) => id is String))) {
        throw const FormatException('Unsupported context navigation.');
      }
    }
    if (context['tabs'] is List && (context['tabs'] as List).length > 30 ||
        context['noteViews'] is Map &&
            (context['noteViews'] as Map).length > 1000) {
      throw const FormatException(
        'This context exceeds the supported view limits.',
      );
    }
  }
}

class DashboardDefinition {
  static const kinds = [
    'tasks',
    'recent',
    'projects',
    'inbox',
    'views',
    'view',
  ];
  static List<Map<String, dynamic>> defaults() => [
    {'id': 'tasks', 'kind': 'tasks', 'span': 2},
    {'id': 'recent', 'kind': 'recent', 'span': 1},
    {'id': 'projects', 'kind': 'projects', 'span': 1},
  ];
  static void validate(Map<String, dynamic> value) {
    if (value['version'] != 1 ||
        value['widgets'] is! List ||
        (value['widgets'] as List).length > 16) {
      throw const FormatException('A dashboard supports up to 16 widgets.');
    }
    final ids = <String>{};
    for (final w in value['widgets'] as List) {
      if (w is! Map ||
          w['id'] is! String ||
          !ids.add(w['id'] as String) ||
          w['kind'] is! String ||
          w['viewId'] != null && w['viewId'] is! String ||
          w['span'] is! int ||
          (w['span'] as int) < 1 ||
          (w['span'] as int) > 3) {
        throw const FormatException('Invalid dashboard widget.');
      }
      // Unknown widget kinds are preserved as recovery placeholders.
    }
  }
}
