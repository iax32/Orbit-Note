part of 'workspace_controller.dart';

extension WorkspaceTabRecovery on WorkspaceController {
  List<Map<String, dynamic>> get closedTabGroups {
    final raw = session.extra['closedTabGroups'];
    if (raw is! Map || raw['version'] != 1 || raw['groups'] is! List) return [];
    return [
      for (final g in (raw['groups'] as List).take(10))
        if (g is Map && g['ids'] is List) Map<String, dynamic>.from(g),
    ];
  }

  void rememberClosedTabGroup(List<String> ids) {
    if (ids.length < 2) return;
    final raw = session.extra['closedTabGroups'];
    if (raw != null && (raw is! Map || raw['version'] != 1)) return;
    final groups = [
      ...closedTabGroups,
      {
        'ids': List<String>.of(ids),
        'order': List<String>.of(session.tabs),
        'active': session.activeId,
        'secondary': session.secondaryId,
      },
    ];
    session = SessionState.fromJson({
      ...session.toJson(),
      'closedTabGroups': {
        ...?raw is Map ? Map<String, dynamic>.from(raw) : null,
        'version': 1,
        'groups': groups
            .skip((groups.length - 10).clamp(0, groups.length))
            .toList(),
      },
    });
  }

  bool reopenClosedTabGroup() {
    final groups = closedTabGroups;
    if (groups.isEmpty) return false;
    while (groups.isNotEmpty) {
      final group = groups.removeLast();
      final ids = (group['ids'] as List)
          .whereType<String>()
          .where((id) => find(id) != null && !find(id)!.isDeleted)
          .toSet();
      if (ids.isEmpty) continue;
      final restored = ids.where((id) => !session.tabs.contains(id)).toSet();
      final order = group['order'] is List
          ? (group['order'] as List).whereType<String>().toList()
          : ids.toList();
      for (final id in order.where(restored.contains)) {
        final at = order.indexOf(id);
        final after = order
            .skip(at + 1)
            .where(session.tabs.contains)
            .firstOrNull;
        if (after == null) {
          session.tabs.add(id);
        } else {
          session.tabs.insert(session.tabs.indexOf(after), id);
        }
      }
      for (final id in restored) {
        if (!session.tabs.contains(id)) session.tabs.add(id);
      }
      session.closedTabs.removeWhere(ids.contains);
      final active = ids.contains(group['active'])
          ? group['active'] as String
          : ids.first;
      final secondary = group['secondary'];
      if (secondary is String &&
          session.tabs.contains(secondary) &&
          secondary != active) {
        session.secondaryId = secondary;
      }
      session = SessionState.fromJson({
        ...session.toJson(),
        'closedTabGroups': {
          ...?session.extra['closedTabGroups'] is Map
              ? Map<String, dynamic>.from(
                  session.extra['closedTabGroups'] as Map,
                )
              : null,
          'version': 1,
          'groups': groups,
        },
      });
      openObject(active);
      persistSession();
      notify();
      return true;
    }
    session = SessionState.fromJson({
      ...session.toJson(),
      'closedTabGroups': {
        ...?session.extra['closedTabGroups'] is Map
            ? Map<String, dynamic>.from(session.extra['closedTabGroups'] as Map)
            : null,
        'version': 1,
        'groups': [],
      },
    });
    persistSession();
    notify();
    return false;
  }
}
