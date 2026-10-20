import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/knowledge_insights.dart';
import 'package:orbit_note/domain/object_connections.dart';
import 'package:orbit_note/domain/object_reference.dart';
import 'package:orbit_note/domain/universal_object.dart';
import 'package:orbit_note/domain/wiki_links.dart';

UniversalObject object(
  String id, {
  String title = 'Note',
  String type = 'orbit.note',
  Map<String, dynamic> properties = const {},
  DateTime? deleted,
}) => UniversalObject(
  id: id,
  workspaceId: 'w',
  typeId: type,
  title: title,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 13),
  properties: properties,
  deletedAt: deleted,
);
ObjectConnection edge(UniversalObject from, String to, {int? at}) =>
    ObjectConnection(
      source: from,
      target: ObjectReference(to),
      location: ObjectReference(from.id),
      label: 'Mention',
      offset: at,
    );

void main() {
  test('one-link repair preserves labels, fragments and surrounding source', () {
    const source =
        '😀 before [[Old#Heading%20One| keep my label ]] and [[Old]].\r\n';
    final finding = checkDocument(
      source,
      catalog: InsightLinkCatalog([]),
    ).first;
    expect(
      repairDocumentLink(source, finding, 'stable-id'),
      '😀 before [[stable-id#Heading%20One| keep my label ]] and [[Old]].\r\n',
    );
    expect(
      repairDocumentLink(
        '[[Old]]',
        const DocumentFinding('Links', '', 0, 7),
        'new',
      ),
      '[[new|Old]]',
    );
    expect(
      () => repairDocumentLink('changed', finding, 'new'),
      throwsFormatException,
    );
    expect(
      () => repairDocumentLink(source, finding, 'bad|id'),
      throwsFormatException,
    );
  });
  test(
    'insights distinguish occurrences, pairs, trash and missing sources',
    () {
      final a = object('a'),
          b = object('b'),
          c = object('c'),
          deleted = object('deleted', deleted: DateTime.utc(2026));
      final r = VaultInsights(
        [a, b, c, deleted],
        [
          edge(a, 'b'),
          edge(a, 'b', at: 5),
          edge(b, 'a'),
          edge(a, 'deleted'),
          edge(a, 'deleted', at: 4),
          edge(deleted, 'c'),
          edge(a, 'a'),
        ],
        now: DateTime.utc(2026, 10, 14),
      );
      expect(r.referenceCount, 3);
      expect(r.connectionPairs, 1);
      expect(r.components, 2);
      expect(r.isolatedNotes.map((o) => o.id), ['c']);
      expect(r.missingSources, [a]);
      expect(r.trash, 1);
      expect(r.degree, {'a': 1, 'b': 1, 'c': 0});
    },
  );
  test('counts are safe for empty Vaults and exclude deleted tasks', () {
    expect(VaultInsights([], []).aggregateReport()['objects'], 0);
    final r = VaultInsights([
      object('a', type: 'orbit.task', properties: {'completed': true}),
      object('b', type: 'orbit.task'),
      object('c', type: 'orbit.task', deleted: DateTime.utc(2026)),
    ], []);
    expect(r.tasks, 2);
    expect(r.completedTasks, 1);
  });
  test('aggregate reports omit object names, IDs and paths', () {
    final r = VaultInsights([
      object(
        'private-id',
        title: 'private title',
        properties: {'folder': '/private/path'},
      ),
    ], []);
    expect(r.aggregateReport().toString(), isNot(contains('private')));
    expect(r.duplicateGroups, isEmpty);
    expect(
      VaultInsights([
        object('a', title: ' Same '),
        object('b', title: 'same'),
      ], []).duplicateGroups.length,
      1,
    );
  });
  test(
    'five thousand objects with repeated references retain correct groups',
    () {
      final objects = List.generate(
        5000,
        (i) => object('n$i', title: 'Note $i'),
      );
      final r = VaultInsights(objects, [
        for (var i = 1; i < 5000; i++) ...[
          edge(objects[i - 1], objects[i].id),
          edge(objects[i - 1], objects[i].id, at: 5),
        ],
      ]);
      expect(r.components, 1);
      expect(r.connectionPairs, 4999);
      expect(r.referenceCount, 9998);
      expect(r.isolatedNotes, isEmpty);
    },
  );
  test(
    'link catalog matches stable IDs, aliases, ambiguity and stale bindings',
    () {
      final objects = [
        object(
          'a',
          title: 'Same',
          properties: {
            'aliases': ['Old'],
          },
        ),
        object('b', title: 'same'),
      ];
      final catalog = InsightLinkCatalog(objects);
      for (final target in ['a', 'Old', 'same', 'missing', 'a#section']) {
        final link = WikiLink(
          target: target,
          label: target,
          start: 0,
          end: target.length,
        );
        for (final bindings in [
          <String, String>{},
          {'same': 'a'},
          {'Old': 'deleted'},
        ]) {
          expect(
            catalog.status(link, bindings),
            resolveWikiLink(
              link,
              objects.map(
                (o) => NoteLinkTarget(
                  id: o.id,
                  title: o.title,
                  aliases: (o.properties['aliases'] as List? ?? [])
                      .cast<String>(),
                ),
              ),
              bindings: bindings,
            ).status,
          );
        }
      }
    },
  );
  test('checks skip code, frontmatter, escaped links and HTML comments', () {
    const source =
        '---\nname: [[Missing]]\n---\n<!-- [[Missing]] -->\n\\[[Missing]] `[[Missing]]`\n```md\n[[Missing]]\n[^no]\n# Example\n```\n[[Missing]]\r\n';
    final findings = checkDocument(source, catalog: InsightLinkCatalog([]));
    expect(findings.length, 1);
    expect(
      source.substring(findings.single.start, findings.single.end),
      '[[Missing]]',
    );
  });
  test('checks retain UTF-16/CRLF offsets and footnote navigation ranges', () {
    const source =
        '# Start\r\n😀 prose [^lost].\r\n### Jump\r\n## Start\r\n[^unused]: old\r\n[^unused]: again\r\n';
    final r = checkDocument(source);
    expect(
      r.where((f) => f.message.startsWith('Missing definition')).length,
      1,
    );
    expect(
      r.where((f) => f.message.startsWith('Duplicate definition')).length,
      1,
    );
    expect(r.where((f) => f.message.startsWith('Heading jumps')).length, 1);
    expect(r.where((f) => f.message.startsWith('Repeated heading')).length, 1);
    final missing = r.firstWhere(
      (f) => f.message.startsWith('Missing definition'),
    );
    expect(source.substring(missing.start, missing.end), '[^lost]');
    expect(
      r.every(
        (f) => f.start >= 0 && f.end <= source.length && f.end >= f.start,
      ),
      true,
    );
  });
  test('valid definitions and literal footnotes remain unflagged', () {
    expect(
      checkDocument(
        '# One\n## Two\nText [^a]. `[^literal]`\n\n[^a]: Answer\n    A continuation.\n',
      ),
      isEmpty,
    );
  });
}
