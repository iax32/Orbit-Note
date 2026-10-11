import 'object_discovery.dart';
import 'orbit_search.dart';

enum SearchOrder { relevance, modified, title }

/// Generated anchor metadata stays in source, not in reading excerpts.
/// Navigation still uses the original result and offsets.
String readableSearchExcerpt(OrbitSearchResult result) {
  if (result.matchKind == 'Source' ||
      result.matchKind == 'PDF text' ||
      result.matchKind == 'Recognized text' ||
      result.matchKind == 'Name' ||
      result.object.properties['documentFormat'] == 'latex') {
    return result.matchedText;
  }
  return result.matchedText
      .replaceAll(RegExp(r'(?:^|\s)\^orbit-[A-Za-z0-9_-]*(?:…)?'), '')
      .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
      .trim();
}

/// View options refine complete location results before the UI paginates them.
class SearchOptions {
  const SearchOptions({
    this.kind,
    this.project,
    this.folder,
    this.tag,
    this.matchKind,
    this.hideCompleted = false,
    this.order = SearchOrder.relevance,
  });
  final String? kind, project, folder, tag, matchKind;
  final bool hideCompleted;
  final SearchOrder order;
  bool get hasFilters =>
      kind != null ||
      project != null ||
      folder != null ||
      tag != null ||
      matchKind != null ||
      hideCompleted;
  factory SearchOptions.fromJson(Map<String, dynamic> json) {
    String? text(String key) =>
        json[key] is String && (json[key] as String).isNotEmpty
        ? json[key] as String
        : null;
    return SearchOptions(
      kind: text('kind'),
      project: text('project'),
      folder: text('folder'),
      tag: text('tag'),
      matchKind: text('matchKind'),
      hideCompleted: json['hideCompleted'] == true,
      order: SearchOrder.values.firstWhere(
        (v) => v.name == json['order'],
        orElse: () => SearchOrder.relevance,
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'project': project,
    'folder': folder,
    'tag': tag,
    'matchKind': matchKind,
    'hideCompleted': hideCompleted,
    'order': order.name,
  };
  List<OrbitSearchResult> apply(List<OrbitSearchResult> results) {
    final shown = results.where((r) {
      final o = r.object;
      final tags = o.properties['tags'];
      return !o.isDeleted &&
          (kind == null || objectKindLabel(o) == kind) &&
          (project == null || o.properties['project'] == project) &&
          (folder == null || o.properties['folder'] == folder) &&
          (tag == null || tags is List && tags.contains(tag)) &&
          (matchKind == null || r.matchKind == matchKind) &&
          (!hideCompleted || o.typeId != 'orbit.task' || !o.isCompleted);
    }).toList();
    if (order != SearchOrder.relevance) {
      final positions = {
        for (var i = 0; i < results.length; i++) results[i]: i,
      };
      shown.sort((a, b) {
        final compared = order == SearchOrder.modified
            ? b.object.updatedAt.compareTo(a.object.updatedAt)
            : a.object.title.toLowerCase().compareTo(
                b.object.title.toLowerCase(),
              );
        return compared != 0
            ? compared
            : positions[a]!.compareTo(positions[b]!);
      });
    }
    return shown;
  }
}

class SavedSearch {
  const SavedSearch(
    this.name,
    this.query,
    this.options, {
    this.extra = const {},
  });
  final String name, query;
  final SearchOptions options;
  final Map<String, dynamic> extra;
  static SavedSearch? parse(dynamic raw) {
    if (raw is! Map || raw['name'] is! String || raw['query'] is! String) {
      return null;
    }
    final name = (raw['name'] as String).trim(),
        query = (raw['query'] as String).trim();
    if (name.isEmpty ||
        query.isEmpty ||
        (raw['version'] != null && raw['version'] != 1)) {
      return null;
    }
    return SavedSearch(
      name,
      query,
      SearchOptions.fromJson(Map<String, dynamic>.from(raw)),
      extra: Map<String, dynamic>.from(raw),
    );
  }

  Map<String, dynamic> toJson() => {
    ...extra,
    'version': 1,
    'name': name,
    'query': query,
    ...options.toJson(),
  };
}

/// Device-local search recipes. Unrecognized entries survive changes to known ones.
class SearchLibrary {
  const SearchLibrary(this.json);
  final Map<String, dynamic> json;
  bool get editable => json['version'] == null || json['version'] == 1;
  List<dynamic> get _rawSaved =>
      json['saved'] is List ? List.of(json['saved']) : [];
  List<SavedSearch> get saved =>
      _rawSaved.map(SavedSearch.parse).whereType<SavedSearch>().toList();
  List<String> get recent => json['recent'] is List
      ? (json['recent'] as List)
            .whereType<String>()
            .where((q) => q.trim().isNotEmpty)
            .take(10)
            .toList()
      : [];
  Map<String, dynamic> remember(String query) {
    if (!editable || query.trim().isEmpty) return json;
    final q = query.trim();
    return {
      ...json,
      'version': 1,
      'recent': [
        q,
        ...recent.where((v) => v.toLowerCase() != q.toLowerCase()),
      ].take(10).toList(),
    };
  }

  Map<String, dynamic> save(SavedSearch search) {
    if (!editable) {
      throw StateError('This search library belongs to a newer Orbit version.');
    }
    if (search.name.trim().isEmpty || search.query.trim().isEmpty) {
      throw ArgumentError('A name and query are required.');
    }
    search = SavedSearch(
      search.name.trim(),
      search.query.trim(),
      search.options,
      extra: search.extra,
    );
    final raw = _rawSaved;
    final index = raw.indexWhere(
      (r) =>
          SavedSearch.parse(r)?.name.toLowerCase() == search.name.toLowerCase(),
    );
    if (index < 0 && saved.length >= 24) {
      throw StateError('You can save up to 24 searches.');
    }
    if (index >= 0) {
      raw[index] = {
        ...Map<String, dynamic>.from(raw[index] as Map),
        ...search.toJson(),
      };
    } else {
      raw.add(search.toJson());
    }
    return {...remember(search.query), 'saved': raw};
  }

  Map<String, dynamic> remove(String name) => !editable
      ? json
      : {
          ...json,
          'saved': _rawSaved
              .where((r) => SavedSearch.parse(r)?.name != name)
              .toList(),
        };
  Map<String, dynamic> restore(SavedSearch search) {
    if (!editable) throw StateError('This search library is read-only.');
    if (saved.any((s) => s.name.toLowerCase() == search.name.toLowerCase())) {
      return json;
    }
    if (saved.length >= 24) throw StateError('You can save up to 24 searches.');
    return {
      ...json,
      'version': 1,
      'saved': [..._rawSaved, search.toJson()],
    };
  }

  Map<String, dynamic> clearRecent() =>
      !editable ? json : {...json, 'recent': <String>[]};
}
