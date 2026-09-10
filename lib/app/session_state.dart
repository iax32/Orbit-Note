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
    this.tabs = const [],
    this.activeId,
    this.secondaryId,
    this.recent = const [],
    this.sidebarVisible = true,
    this.inspectorVisible = false,
    this.sidebarWidth = 240,
    this.fontSize = 16,
    this.contentWidth = 800,
    this.compact = false,
    this.motion = 'normal',
    this.splitAxis = 'horizontal',
    this.splitRatio = .5,
    this.focusMode = false,
    this.positions = const {},
    this.cameras = const {},
    this.noteViews = const {},
    this.noteSort = 'modified-desc',
    this.collapsedFolders = const [],
  });
  OrbitDestination destination;
  List<String> tabs;
  String? activeId, secondaryId;
  List<String> recent;
  bool sidebarVisible, inspectorVisible, compact;
  double sidebarWidth, fontSize, contentWidth;
  String motion;
  String splitAxis;
  double splitRatio;
  bool focusMode;
  Map<String, double> positions;
  Map<String, Map<String, dynamic>> cameras;
  Map<String, Map<String, dynamic>> noteViews;
  String noteSort;
  List<String> collapsedFolders;

  factory SessionState.fromJson(Map<String, dynamic> json) {
    double bounded(String key, double fallback, double min, double max) {
      final value = json[key];
      return value is num && value.isFinite
          ? value.toDouble().clamp(min, max)
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
    return SessionState(
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
      contentWidth: bounded('contentWidth', 800, 520, 1200),
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
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'destination': destination.name,
    'tabs': tabs,
    'activeId': activeId,
    'secondaryId': secondaryId,
    'recent': recent,
    'sidebarVisible': sidebarVisible,
    'inspectorVisible': inspectorVisible,
    'sidebarWidth': sidebarWidth,
    'fontSize': fontSize,
    'contentWidth': contentWidth,
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
  };
}
