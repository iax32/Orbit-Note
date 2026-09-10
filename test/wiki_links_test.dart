import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_note/domain/wiki_links.dart';

void main() {
  const targets = [
    NoteLinkTarget(
      id: 'note-1',
      title: 'Orbit Architecture',
      aliases: ['Design'],
    ),
    NoteLinkTarget(id: 'note-2', title: 'Research'),
    NoteLinkTarget(id: 'note-3', title: 'Research'),
  ];

  test('parses title links and stable IDs with source locations', () {
    const source = 'See [[Orbit Architecture]] and [[note-1|The plan]].';
    final links = parseWikiLinks(source);
    expect(links.map((link) => link.target), ['Orbit Architecture', 'note-1']);
    expect(links.last.label, 'The plan');
    expect(
      source.substring(links.last.start, links.last.end),
      '[[note-1|The plan]]',
    );
  });

  test('ignores fenced code, inline code, escaped and indented examples', () {
    const source = '''[[Design]]
`[[inline]]` and ``[[another]]``
\\[[escaped]]
```markdown
[[fenced]]
```
~~~
[[tilde fence]]
~~~
    [[indented]]
[[note-1|Real reference]]
''';
    expect(parseWikiLinks(source).map((link) => link.target), [
      'Design',
      'note-1',
    ]);
  });

  test('literal backticks inside longer inline fences do not end code', () {
    expect(
      parseWikiLinks('``some ` [[hidden]]`` [[visible]]').single.target,
      'visible',
    );
  });

  test(
    'resolves ID even after rename, aliases, and ambiguity without guessing',
    () {
      WikiLinkResolution resolve(String text) =>
          resolveWikiLink(parseWikiLinks(text).single, targets);
      expect(resolve('[[note-1]]').target!.id, 'note-1');
      expect(resolve('[[design]]').target!.id, 'note-1');
      expect(resolve('[[Research]]').status, WikiLinkStatus.ambiguous);
      expect(resolve('[[Research]]').candidates.length, 2);
      expect(resolve('[[Missing]]').status, WikiLinkStatus.unresolved);
      expect(resolve('[[Missing]]').target, isNull);
    },
  );

  test(
    'display transformation leaves source code and unresolved information intact',
    () {
      const source = '[[note-1|Plan]] [[Missing]] [[Research]] `[[Design]]`';
      final result = wikiLinksToMarkdown(source, targets);
      expect(result, contains('[Plan](orbit-object:note-1)'));
      expect(result, contains('[Missing · missing](orbit-missing:Missing)'));
      expect(
        result,
        contains('[Research · choose target](orbit-ambiguous:Research)'),
      );
      expect(result, contains('`[[Design]]`'));
      expect(source, contains('[[note-1|Plan]]'));
    },
  );

  test(
    'rejects empty or incomplete syntax without changing ordinary prose',
    () {
      expect(
        parseWikiLinks(
          '[[ ]] [[unfinished and [ordinary](https://example.com)',
        ),
        isEmpty,
      );
      expect(wikiLinksToMarkdown('Ordinary text', targets), 'Ordinary text');
    },
  );
}
