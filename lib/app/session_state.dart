import 'app_preferences.dart';

enum OrbitDestination {
  home,
  notes,
  canvas,
  tasks,
  calendar,
  graph,
  search,
  trash,
  settings,
}

class SessionState {
  SessionState({
    this.destination = OrbitDestination.home,
    this.extra = const {},
    this.searchWorkspace = const {},
    this.spaces = const {},
    this.projectContext = const {},
    this.dashboard = const {},
    this.lifeWorkspace = const {},
    List<String> tabs = const [],
    this.activeId,
    this.secondaryId,
    List<String> recent = const [],
    this.sidebarVisible = true,
    this.inspectorVisible = false,
    this.sidebarWidth = 240,
    double fontSize = 16,
    double uiZoom = 1.0,
    double contentWidth = 1080,
    String fontFamily = 'Segoe UI',
    bool compact = false,
    String motion = 'normal',
    this.splitAxis = 'horizontal',
    this.splitRatio = .5,
    this.focusMode = false,
    this.positions = const {},
    this.cameras = const {},
    this.noteViews = const {},
    this.noteSort = 'modified-desc',
    List<String> collapsedFolders = const [],
    this.showAttachments = false,
    this.explorerCalendarCollapsed = true,
    this.reverseEngineeringEnabled = false,
    List<String> pinnedTabs = const [],
    List<String> bookmarkedTabs = const [],
    List<String> closedTabs = const [],
    List<String> archivedFolders = const [],
    this.activeWorkSession,
    List<Map<String, dynamic>> completedWorkSessions = const [],
    bool spellCheckEnabled = true,
    List<String> userDictionary = const [],
    String accentColor = 'violet',
    Map<String, int> colorOverrides = const {},
    String themePreset = 'orbit',
    String cornerStyle = 'rounded',
    String documentFontFamily = 'Segoe UI',
    String monoFontFamily = 'Consolas',
    this.autoSaveInterval = 1000,
    this.autoSnapshotOnClose = true,
    String defaultNoteMode = 'rich',
    String defaultDocumentFormat = 'markdown',
    bool bionicReadingDefault = false,
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    String defaultCanvasGrid = 'dots',
    bool canvasSnapToGrid = false,
    double defaultAudioSpeed = 1.0,
    double editorLineHeight = 1.6,
    bool showLineNumbers = true,
    List<Map<String, dynamic>> customThemes = const [],
    Map<String, int> folderColors = const {},
  }) : tabs = List.of(tabs),
       recent = List.of(recent),
       collapsedFolders = List.of(collapsedFolders),
       pinnedTabs = List.of(pinnedTabs),
       bookmarkedTabs = List.of(bookmarkedTabs),
       closedTabs = List.of(closedTabs),
       archivedFolders = List.of(archivedFolders),
       completedWorkSessions = List.of(completedWorkSessions),
       preferences = AppPreferences(
         fontSize: fontSize,
         uiZoom: uiZoom,
         contentWidth: contentWidth,
         fontFamily: fontFamily,
         documentFontFamily: documentFontFamily,
         monoFontFamily: monoFontFamily,
         themePreset: themePreset,
         cornerStyle: cornerStyle,
         compact: compact,
         motion: motion,
         spellCheckEnabled: spellCheckEnabled,
         userDictionary: userDictionary,
         accentColor: accentColor,
         colorOverrides: colorOverrides,
         defaultNoteMode: defaultNoteMode,
         defaultDocumentFormat: defaultDocumentFormat,
         bionicReadingDefault: bionicReadingDefault,
         defaultCanvasGrid: defaultCanvasGrid,
         canvasSnapToGrid: canvasSnapToGrid,
         defaultAudioSpeed: defaultAudioSpeed,
         editorLineHeight: editorLineHeight,
         showLineNumbers: showLineNumbers,
         customThemes: customThemes,
         folderColors: folderColors,
       );
  final AppPreferences preferences;
  final Map<String, dynamic> extra;
  Map<String, dynamic> searchWorkspace;
  Map<String, dynamic> spaces;
  Map<String, dynamic> projectContext;
  Map<String, dynamic> dashboard;
  Map<String, dynamic> lifeWorkspace;
  OrbitDestination destination;
  List<String> tabs;
  List<String> pinnedTabs;
  List<String> bookmarkedTabs;
  List<String> closedTabs;
  List<String> archivedFolders;
  String? activeId, secondaryId;
  List<String> recent;
  Map<String, dynamic>? activeWorkSession;
  List<Map<String, dynamic>> completedWorkSessions;
  bool sidebarVisible,
      inspectorVisible,
      showAttachments,
      explorerCalendarCollapsed,
      reverseEngineeringEnabled,
      autoSnapshotOnClose;
  double sidebarWidth;
  String splitAxis;
  double splitRatio;
  bool focusMode;
  Map<String, double> positions;
  Map<String, Map<String, dynamic>> cameras, noteViews;
  String noteSort;
  List<String> collapsedFolders;
  int autoSaveInterval, focusMinutes, shortBreakMinutes, longBreakMinutes;
  double get uiZoom => preferences.uiZoom;
  set uiZoom(double value) =>
      preferences.uiZoom = value.isFinite ? value.clamp(.75, 2.0) : 1.0;
  double get fontSize => preferences.fontSize;
  set fontSize(double value) => preferences.fontSize = value;
  double get contentWidth => preferences.contentWidth;
  set contentWidth(double value) => preferences.contentWidth = value;
  String get fontFamily => preferences.fontFamily;
  set fontFamily(String value) => preferences.fontFamily = value;
  bool get compact => preferences.compact;
  set compact(bool value) => preferences.compact = value;
  String get motion => preferences.motion;
  set motion(String value) => preferences.motion = value;
  bool get spellCheckEnabled => preferences.spellCheckEnabled;
  set spellCheckEnabled(bool value) => preferences.spellCheckEnabled = value;
  List<String> get userDictionary => preferences.userDictionary;
  set userDictionary(List<String> value) => preferences.userDictionary = value;
  String get accentColor => preferences.accentColor;
  set accentColor(String value) => preferences.accentColor = value;
  String get themePreset => preferences.themePreset;
  set themePreset(String value) => preferences.themePreset = value;
  String get cornerStyle => preferences.cornerStyle;
  set cornerStyle(String value) => preferences.cornerStyle = value;
  String get documentFontFamily => preferences.documentFontFamily;
  set documentFontFamily(String value) =>
      preferences.documentFontFamily = value;
  String get monoFontFamily => preferences.monoFontFamily;
  set monoFontFamily(String value) => preferences.monoFontFamily = value;
  Map<String, int> get colorOverrides => preferences.colorOverrides;
  set colorOverrides(Map<String, int> value) =>
      preferences.colorOverrides = value;
  String get defaultNoteMode => preferences.defaultNoteMode;
  set defaultNoteMode(String value) => preferences.defaultNoteMode = value;
  String get defaultDocumentFormat => preferences.defaultDocumentFormat;
  set defaultDocumentFormat(String value) =>
      preferences.defaultDocumentFormat = value;
  bool get bionicReadingDefault => preferences.bionicReadingDefault;
  set bionicReadingDefault(bool value) =>
      preferences.bionicReadingDefault = value;
  String get defaultCanvasGrid => preferences.defaultCanvasGrid;
  set defaultCanvasGrid(String value) => preferences.defaultCanvasGrid = value;
  bool get canvasSnapToGrid => preferences.canvasSnapToGrid;
  set canvasSnapToGrid(bool value) => preferences.canvasSnapToGrid = value;
  double get defaultAudioSpeed => preferences.defaultAudioSpeed;
  set defaultAudioSpeed(double value) => preferences.defaultAudioSpeed = value;
  double get editorLineHeight => preferences.editorLineHeight;
  set editorLineHeight(double value) => preferences.editorLineHeight = value;
  bool get showLineNumbers => preferences.showLineNumbers;
  set showLineNumbers(bool value) => preferences.showLineNumbers = value;
  List<Map<String, dynamic>> get customThemes => preferences.customThemes;
  set customThemes(List<Map<String, dynamic>> value) =>
      preferences.customThemes = value;
  Map<String, int> get folderColors => preferences.folderColors;
  set folderColors(Map<String, int> value) => preferences.folderColors = value;

  factory SessionState.fromJson(Map<String, dynamic> json) {
    final rawFolderColors = json['folderColors'];
    final folderColors = <String, int>{};
    if (rawFolderColors is Map) {
      for (final entry in rawFolderColors.entries) {
        if (entry.key is String &&
            entry.value is int &&
            entry.value >= 0x00000000 &&
            entry.value <= 0xffffffff) {
          folderColors[entry.key as String] = entry.value as int;
        }
      }
    }
    final rawColors = json['colorOverrides'];
    final colors = <String, int>{};
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        if (entry.key is String &&
            entry.value is int &&
            entry.value >= 0xff000000 &&
            entry.value <= 0xffffffff) {
          colors[entry.key as String] = entry.value as int;
        }
      }
    }
    double bounded(String key, double fallback, double min, double max) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
          : fallback;
    }

    int boundedInt(String key, int fallback, int min, int max) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toInt().clamp(min, max)
          : fallback;
    }

    List<String> ids(String key) =>
        (json[key] is List ? json[key] as List : const [])
            .whereType<String>()
            .toSet()
            .take(30)
            .toList();
    final positions = <String, double>{};
    if (json['positions'] is Map) {
      for (final entry in (json['positions'] as Map).entries) {
        if (entry.key is String &&
            entry.value is num &&
            (entry.value as num).isFinite) {
          positions[entry.key as String] = (entry.value as num)
              .toDouble()
              .clamp(0, 1e8);
        }
      }
    }
    final cameras = <String, Map<String, dynamic>>{};
    if (json['cameras'] is Map) {
      for (final entry in (json['cameras'] as Map).entries) {
        if (entry.key is String && entry.value is Map) {
          cameras[entry.key as String] = Map<String, dynamic>.from(
            entry.value as Map,
          );
        }
      }
    }
    final knownKeys = SessionState().toJson().keys.toSet();
    return SessionState(
      projectContext: json['projectContext'] is Map
          ? Map<String, dynamic>.from(json['projectContext'] as Map)
          : const {},
      spaces: json['spaces'] is Map
          ? Map<String, dynamic>.from(json['spaces'] as Map)
          : const {},
      lifeWorkspace: json['lifeWorkspace'] is Map
          ? Map<String, dynamic>.from(json['lifeWorkspace'] as Map)
          : const {},
      dashboard: json['dashboard'] is Map
          ? Map<String, dynamic>.from(json['dashboard'] as Map)
          : const {},
      searchWorkspace: json['searchWorkspace'] is Map
          ? Map<String, dynamic>.from(json['searchWorkspace'] as Map)
          : const {},
      extra: {
        for (final entry in json.entries)
          if (!knownKeys.contains(entry.key)) entry.key: entry.value,
      },
      destination: OrbitDestination.values.firstWhere(
        (v) => v.name == json['destination'],
        orElse: () => OrbitDestination.home,
      ),
      tabs: ids('tabs'),
      activeId: json['activeId'] is String ? json['activeId'] as String : null,
      secondaryId: json['secondaryId'] is String
          ? json['secondaryId'] as String
          : null,
      recent: ids('recent'),
      collapsedFolders:
          (json['collapsedFolders'] is List
                  ? json['collapsedFolders'] as List
                  : const [])
              .whereType<String>()
              .take(1000)
              .toList(),
      sidebarVisible: json['sidebarVisible'] != false,
      inspectorVisible: json['inspectorVisible'] == true,
      sidebarWidth: bounded('sidebarWidth', 240, 180, 380),
      fontSize: bounded('fontSize', 16, 12, 26),
      uiZoom: bounded('uiZoom', 1, .75, 2),
      contentWidth: bounded('contentWidth', 1080, 520, 2000),
      fontFamily:
          [
            'Segoe UI',
            'Times New Roman',
            'Georgia',
            'Consolas',
          ].contains(json['fontFamily'])
          ? json['fontFamily'] as String
          : 'Segoe UI',
      compact: json['compact'] == true,
      splitAxis: json['splitAxis'] == 'vertical' ? 'vertical' : 'horizontal',
      splitRatio: bounded('splitRatio', .5, .25, .75),
      focusMode: json['focusMode'] == true,
      motion: ['normal', 'reduced', 'off'].contains(json['motion'])
          ? json['motion'] as String
          : 'normal',
      positions: positions,
      cameras: cameras,
      noteViews: {
        if (json['noteViews'] is Map)
          for (final entry in (json['noteViews'] as Map).entries)
            if (entry.key is String && entry.value is Map)
              entry.key as String: Map<String, dynamic>.from(
                entry.value as Map,
              ),
      },
      noteSort:
          [
            'name-asc',
            'name-desc',
            'modified-desc',
            'modified-asc',
            'created-desc',
            'created-asc',
          ].contains(json['noteSort'])
          ? json['noteSort'] as String
          : 'modified-desc',
      showAttachments: json['showAttachments'] == true,
      explorerCalendarCollapsed: json['explorerCalendarCollapsed'] != false,
      reverseEngineeringEnabled: json['reverseEngineeringEnabled'] == true,
      pinnedTabs: ids('pinnedTabs'),
      bookmarkedTabs: ids('bookmarkedTabs'),
      closedTabs: ids('closedTabs'),
      archivedFolders: ids('archivedFolders'),
      spellCheckEnabled: json['spellCheckEnabled'] != false,
      userDictionary:
          (json['userDictionary'] is List
                  ? json['userDictionary'] as List
                  : const [])
              .whereType<String>()
              .take(1000)
              .toList(),
      activeWorkSession: json['activeWorkSession'] is Map
          ? Map<String, dynamic>.from(json['activeWorkSession'] as Map)
          : null,
      completedWorkSessions:
          (json['completedWorkSessions'] is List
                  ? json['completedWorkSessions'] as List
                  : const [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .take(30)
              .toList(),
      accentColor:
          [
            'violet',
            'cyan',
            'emerald',
            'amber',
            'rose',
            'blue',
          ].contains(json['accentColor'])
          ? json['accentColor'] as String
          : 'violet',
      themePreset: json['themePreset'] is String
          ? json['themePreset'] as String
          : 'orbit',
      cornerStyle: ['rounded', 'subtle'].contains(json['cornerStyle'])
          ? json['cornerStyle'] as String
          : 'rounded',
      documentFontFamily: json['documentFontFamily'] is String
          ? json['documentFontFamily'] as String
          : (json['fontFamily'] is String
                ? json['fontFamily'] as String
                : 'Segoe UI'),
      monoFontFamily: json['monoFontFamily'] is String
          ? json['monoFontFamily'] as String
          : 'Consolas',
      autoSaveInterval: boundedInt('autoSaveInterval', 1000, 200, 10000),
      colorOverrides: colors,
      autoSnapshotOnClose: json['autoSnapshotOnClose'] != false,
      defaultNoteMode:
          ['rich', 'write', 'split', 'read'].contains(json['defaultNoteMode'])
          ? json['defaultNoteMode'] as String
          : 'rich',
      defaultDocumentFormat:
          ['markdown', 'latex'].contains(json['defaultDocumentFormat'])
          ? json['defaultDocumentFormat'] as String
          : 'markdown',
      bionicReadingDefault: json['bionicReadingDefault'] == true,
      focusMinutes: boundedInt('focusMinutes', 25, 5, 120),
      shortBreakMinutes: boundedInt('shortBreakMinutes', 5, 1, 30),
      longBreakMinutes: boundedInt('longBreakMinutes', 15, 5, 60),
      defaultCanvasGrid:
          [
            'dots',
            'grid',
            'graph',
            'cornell',
            'lines',
            'ruled',
            'isometric',
            'cross',
            'hex',
            'blueprint',
            'music',
            'ledger',
            'triangular',
            'blank',
          ].contains(json['defaultCanvasGrid'])
          ? json['defaultCanvasGrid'] as String
          : 'dots',
      canvasSnapToGrid: json['canvasSnapToGrid'] == true,
      defaultAudioSpeed:
          [1.0, 1.25, 1.5, 2.0].contains(json['defaultAudioSpeed'])
          ? (json['defaultAudioSpeed'] as num).toDouble()
          : 1.0,
      editorLineHeight: bounded('editorLineHeight', 1.6, 1.2, 2.4),
      showLineNumbers: json['showLineNumbers'] != false,
      customThemes: (json['customThemes'] is List
          ? (json['customThemes'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
          : const []),
      folderColors: folderColors,
    );
  }
  Map<String, dynamic> toJson() => {
    ...extra,
    'version': 1,
    'searchWorkspace': searchWorkspace,
    'spaces': spaces,
    'projectContext': projectContext,
    'dashboard': dashboard,
    'lifeWorkspace': lifeWorkspace,
    'destination': destination.name,
    'tabs': tabs,
    'pinnedTabs': pinnedTabs,
    'bookmarkedTabs': bookmarkedTabs,
    'closedTabs': closedTabs,
    'activeId': activeId,
    'secondaryId': secondaryId,
    'recent': recent,
    'activeWorkSession': activeWorkSession,
    'completedWorkSessions': completedWorkSessions,
    'sidebarVisible': sidebarVisible,
    'inspectorVisible': inspectorVisible,
    'sidebarWidth': sidebarWidth,
    'fontSize': fontSize,
    'uiZoom': uiZoom,
    'contentWidth': contentWidth,
    'fontFamily': fontFamily,
    'compact': compact,
    'splitAxis': splitAxis,
    'splitRatio': splitRatio,
    'focusMode': focusMode,
    'motion': motion,
    'positions': positions,
    'cameras': cameras,
    'noteViews': noteViews,
    'noteSort': noteSort,
    'collapsedFolders': collapsedFolders,
    'showAttachments': showAttachments,
    'explorerCalendarCollapsed': explorerCalendarCollapsed,
    'reverseEngineeringEnabled': reverseEngineeringEnabled,
    'archivedFolders': archivedFolders,
    'spellCheckEnabled': spellCheckEnabled,
    'userDictionary': userDictionary,
    'accentColor': accentColor,
    'themePreset': themePreset,
    'cornerStyle': cornerStyle,
    'documentFontFamily': documentFontFamily,
    'monoFontFamily': monoFontFamily,
    'colorOverrides': Map<String, int>.from(colorOverrides),
    'autoSaveInterval': autoSaveInterval,
    'autoSnapshotOnClose': autoSnapshotOnClose,
    'defaultNoteMode': defaultNoteMode,
    'defaultDocumentFormat': defaultDocumentFormat,
    'bionicReadingDefault': bionicReadingDefault,
    'focusMinutes': focusMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'defaultCanvasGrid': defaultCanvasGrid,
    'canvasSnapToGrid': canvasSnapToGrid,
    'defaultAudioSpeed': defaultAudioSpeed,
    'editorLineHeight': editorLineHeight,
    'showLineNumbers': showLineNumbers,
    if (customThemes.isNotEmpty) 'customThemes': customThemes,
    if (folderColors.isNotEmpty)
      'folderColors': Map<String, int>.from(folderColors),
  };
}
