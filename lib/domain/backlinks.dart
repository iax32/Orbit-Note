import 'dart:math' as math;
import 'universal_object.dart';
import 'wiki_links.dart';
import 'object_reference.dart';
import 'study_card.dart';
import 'calendar_planning.dart';
import 'research_workspace.dart';

/// Connection type for an inbound link.
enum LinkedMentionType {
  wikilink,
  canvasElement,
  taskContext,
  eventContext,
  pdfReference,
  studyReference,
  planningResource,
  researchRelation,
}

/// A rich inbound reference to a target object.
class LinkedMention {
  const LinkedMention({
    required this.source,
    required this.targetId,
    required this.targetTitle,
    required this.snippet,
    required this.type,
    this.label,
    this.targetLocation,
    this.sourceLocation,
    this.sourceOffset,
  });

  final UniversalObject source;
  final String targetId;
  final String targetTitle;
  final String snippet;
  final LinkedMentionType type;
  final String? label;
  final ObjectReference? targetLocation, sourceLocation;
  final int? sourceOffset;
}

/// An unlinked mention of a target's title or alias in another note's prose.
class UnlinkedMention {
  const UnlinkedMention({
    required this.source,
    required this.targetId,
    required this.targetTitle,
    required this.matchedText,
    required this.snippet,
    required this.startIndex,
    required this.endIndex,
  });

  final UniversalObject source;
  final String targetId;
  final String targetTitle;
  final String matchedText;
  final String snippet;
  final int startIndex;
  final int endIndex;
}

/// Extracts contextual snippet around character range [start, end] in [text].
String extractContextSnippet(
  String text,
  int start,
  int end, {
  int maxRadius = 60,
}) {
  if (text.isEmpty) return '';
  final clampedStart = start.clamp(0, text.length);
  final clampedEnd = end.clamp(clampedStart, text.length);

  final left = math.max(0, clampedStart - maxRadius);
  final right = math.min(text.length, clampedEnd + maxRadius);

  var snippetStart = left;
  final before = text.substring(left, clampedStart);
  final lastBreak = before.lastIndexOf(RegExp(r'[\n\.\?!]'));
  if (lastBreak != -1) {
    snippetStart = left + lastBreak + 1;
  } else if (left > 0) {
    final firstSpace = before.indexOf(' ');
    if (firstSpace != -1) {
      snippetStart = left + firstSpace + 1;
    }
  }

  var snippetEnd = right;
  final after = text.substring(clampedEnd, right);
  final firstBreak = after.indexOf(RegExp(r'[\n\.\?!]'));
  if (firstBreak != -1) {
    snippetEnd = clampedEnd + firstBreak + 1;
  } else if (right < text.length) {
    final lastSpace = after.lastIndexOf(' ');
    if (lastSpace != -1) {
      snippetEnd = clampedEnd + lastSpace;
    }
  }

  var snippet = text.substring(snippetStart, snippetEnd).trim();
  snippet = snippet.replaceAll(RegExp(r'\s+'), ' ');
  if (snippetStart > 0 && !snippet.startsWith('...')) {
    snippet = '...$snippet';
  }
  if (snippetEnd < text.length && !snippet.endsWith('...')) {
    snippet = '$snippet...';
  }
  return snippet;
}

/// Finds all explicit inbound links to [targetId] with surrounding context.
List<LinkedMention> findLinkedMentions({
  required String targetId,
  required List<UniversalObject> objects,
  required List<NoteLinkTarget> targets,
}) {
  final results = <LinkedMention>[];
  final active = objects.where((o) => !o.isDeleted).toList();

  final targetObj = active.where((o) => o.id == targetId).firstOrNull;
  final targetTitle = targetObj?.title ?? targetId;

  for (final o in active) {
    if (o.id == targetId) continue;

    // 1. Check WikiLinks in prose/body
    if (o.body.isNotEmpty) {
      final links = parseWikiLinks(o.body);
      for (final link in links) {
        final resolved = resolveWikiLink(
          link,
          targets,
          bindings: o.linkBindings,
        );
        if (resolved.target?.id == targetId) {
          final snippet = extractContextSnippet(o.body, link.start, link.end);
          results.add(
            LinkedMention(
              source: o,
              targetId: targetId,
              targetTitle: targetTitle,
              snippet: snippet,
              type: LinkedMentionType.wikilink,
              label: link.label,
              targetLocation: ObjectReference.parse(
                link.target,
              ).withId(targetId),
              sourceLocation: ObjectReference(o.id),
              sourceOffset: link.start,
            ),
          );
        }
      }
    }

    // 2. Check Canvas transcluded elements
    if (o.typeId == 'orbit.canvas') {
      final elements = o.data['elements'];
      if (elements is List) {
        for (final el in elements) {
          if (el is Map) {
            final tid = el['targetId'] ?? el['objectId'];
            if (tid == targetId) {
              final label = el['title'] ?? el['label'] ?? el['text'];
              final snippet = label != null
                  ? 'Canvas card element: "$label"'
                  : 'Embedded element on canvas';
              results.add(
                LinkedMention(
                  source: o,
                  targetId: targetId,
                  targetTitle: targetTitle,
                  snippet: snippet,
                  type: LinkedMentionType.canvasElement,
                  label: label?.toString(),
                  targetLocation: el['referenceTarget'] is String
                      ? ObjectReference.parse(el['referenceTarget'] as String)
                      : ObjectReference(targetId),
                  sourceLocation: el['id'] is String
                      ? ObjectReference(
                          o.id,
                          anchorType: 'element',
                          anchorId: el['id'] as String,
                        )
                      : ObjectReference(o.id),
                ),
              );
            }
          }
        }
      }
    }

    // 3. Check Task context link
    if (o.typeId == 'orbit.task') {
      final ctx = o.properties['contextId'] ?? o.properties['context'];
      if (ctx == targetId) {
        results.add(
          LinkedMention(
            source: o,
            targetId: targetId,
            targetTitle: targetTitle,
            snippet: 'Task context: "${o.title}"',
            type: LinkedMentionType.taskContext,
          ),
        );
      }
    }

    // 4. Check Event context link
    if (o.typeId == 'orbit.event') {
      final ctx =
          o.properties['contextId'] ??
          o.properties['context'] ??
          o.properties['linkedId'];
      if (ctx == targetId) {
        results.add(
          LinkedMention(
            source: o,
            targetId: targetId,
            targetTitle: targetTitle,
            snippet: 'Event context: "${o.title}"',
            type: LinkedMentionType.eventContext,
          ),
        );
      }
    }

    if (StudyCard.supported(o)) {
      final source = StudyCard(o).source;
      if (source?['objectId'] == targetId) {
        results.add(
          LinkedMention(
            source: o,
            targetId: targetId,
            targetTitle: targetTitle,
            snippet: 'Study card: ${o.title}',
            type: LinkedMentionType.studyReference,
            targetLocation: ObjectReference(
              targetId,
              page: targetObj?.typeId == 'orbit.file'
                  ? (source?['page'] as int?)
                  : null,
            ),
          ),
        );
      }
    }

    if (calendarResources(o).contains(targetId)) {
      results.add(
        LinkedMention(
          source: o,
          targetId: targetId,
          targetTitle: targetTitle,
          snippet: 'Linked ${calendarPlanKind(o)}: ${o.title}',
          type: LinkedMentionType.planningResource,
        ),
      );
    }
    for (final link in researchRelations(o).where((r) => r.id == targetId)) {
      results.add(
        LinkedMention(
          source: o,
          targetId: targetId,
          targetTitle: targetTitle,
          snippet: '${link.relation}: ${o.title}',
          type: LinkedMentionType.researchRelation,
          label: link.relation,
        ),
      );
    }

    // 5. Check PDF note reference
    if (o.properties['pdfSource'] is Map &&
        (o.properties['pdfSource'] as Map)['objectId'] == targetId) {
      results.add(
        LinkedMention(
          source: o,
          targetId: targetId,
          targetTitle: targetTitle,
          snippet: 'Attached PDF citation note',
          type: LinkedMentionType.pdfReference,
        ),
      );
    }
  }

  return results;
}

/// Identifies character ranges in text where matching should NOT occur:
/// code blocks, inline code, math, markdown links, wikilinks, URLs.
List<(int, int)> findForbiddenRanges(String text) {
  final ranges = <(int, int)>[];

  // Fenced code blocks ```...``` or ~~~...~~~
  final fenceRegex = RegExp(r'```[\s\S]*?```|~~~[\s\S]*?~~~');
  for (final match in fenceRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  // Inline code `...`
  final inlineCodeRegex = RegExp(r'`[^`\n]+`');
  for (final match in inlineCodeRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  // Math blocks $$...$$ and $...$
  final mathRegex = RegExp(r'\$\$[\s\S]*?\$\$|\$[^$\n]+\$');
  for (final match in mathRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  // Markdown links [label](url)
  final mdLinkRegex = RegExp(r'\[.*?\]\(.*?\)');
  for (final match in mdLinkRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  // WikiLinks [[target|label]] or [[target]]
  final wikiRegex = RegExp(r'\[\[.*?\]\]');
  for (final match in wikiRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  // URLs https:// or http://
  final urlRegex = RegExp(r'https?:\/\/[^\s\)\>]+');
  for (final match in urlRegex.allMatches(text)) {
    ranges.add((match.start, match.end));
  }

  return ranges;
}

/// Finds unlinked mentions of [targetId]'s title or aliases in other notes.
List<UnlinkedMention> findUnlinkedMentions({
  required String targetId,
  required List<UniversalObject> objects,
  required List<NoteLinkTarget> targets,
}) {
  final results = <UnlinkedMention>[];
  final active = objects.where((o) => !o.isDeleted).toList();

  final targetObj = active.where((o) => o.id == targetId).firstOrNull;
  if (targetObj == null) return results;

  final terms = <String>{};
  if (targetObj.title.trim().length >= 2) {
    terms.add(targetObj.title.trim());
  }
  if (targetObj.properties['aliases'] is List) {
    for (final a in (targetObj.properties['aliases'] as List)) {
      if (a is String && a.trim().length >= 2) {
        terms.add(a.trim());
      }
    }
  }

  if (terms.isEmpty) return results;

  // Sort terms by length descending so longer phrases match before shorter subphrases
  final sortedTerms = terms.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final o in active) {
    if (o.id == targetId) continue;
    if (o.body.isEmpty) continue;

    final forbidden = findForbiddenRanges(o.body);
    final bodyLower = o.body.toLowerCase();

    for (final term in sortedTerms) {
      final termLower = term.toLowerCase();
      var startIndex = 0;

      while (startIndex < o.body.length) {
        final matchIdx = bodyLower.indexOf(termLower, startIndex);
        if (matchIdx == -1) break;

        final matchEnd = matchIdx + term.length;
        startIndex = matchEnd;

        // Verify word boundaries
        if (matchIdx > 0) {
          final charBefore = o.body[matchIdx - 1];
          if (RegExp(r'[a-zA-Z0-9_]').hasMatch(charBefore)) {
            continue;
          }
        }
        if (matchEnd < o.body.length) {
          final charAfter = o.body[matchEnd];
          if (RegExp(r'[a-zA-Z0-9_]').hasMatch(charAfter)) {
            continue;
          }
        }

        // Check if within forbidden ranges
        final isForbidden = forbidden.any(
          (r) => matchIdx < r.$2 && matchEnd > r.$1,
        );
        if (isForbidden) continue;

        final matchedText = o.body.substring(matchIdx, matchEnd);
        final snippet = extractContextSnippet(o.body, matchIdx, matchEnd);

        results.add(
          UnlinkedMention(
            source: o,
            targetId: targetId,
            targetTitle: targetObj.title,
            matchedText: matchedText,
            snippet: snippet,
            startIndex: matchIdx,
            endIndex: matchEnd,
          ),
        );
      }
    }
  }

  return results;
}

/// Rewrites an unlinked mention in markdown text to an explicit wikilink.
///
/// Uses `[[$targetId|${mention.matchedText}]]` to preserve exact user phrasing
/// while binding explicitly to the target's stable UUID.
String linkMentionInMarkdown(
  String body,
  UnlinkedMention mention,
  String targetId,
) {
  if (mention.matchedText.isEmpty) return body;
  // If exact offset matches
  if (mention.startIndex >= 0 &&
      mention.endIndex <= body.length &&
      body.substring(mention.startIndex, mention.endIndex) ==
          mention.matchedText) {
    return body.replaceRange(
      mention.startIndex,
      mention.endIndex,
      '[[$targetId|${mention.matchedText}]]',
    );
  }

  // Fallback: search for first unlinked occurrence of matchedText
  final idx = body.indexOf(mention.matchedText);
  if (idx != -1) {
    return body.replaceRange(
      idx,
      idx + mention.matchedText.length,
      '[[$targetId|${mention.matchedText}]]',
    );
  }

  return body;
}
