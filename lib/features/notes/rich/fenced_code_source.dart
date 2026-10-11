import 'markdown_document.dart';

/// Keep authored fences/info strings, growing only delimiters that would close
/// the edited body. Both typing and projected Find replacement use this rule.
MarkdownBlock replaceFencedCodeContent(MarkdownBlock block, String content) {
  if (block.kind != MarkdownBlockKind.code) {
    throw ArgumentError('Expected a parsed fenced code block.');
  }
  if (content == block.content) return block;
  var prefix = block.prefix, suffix = block.suffix;
  if (!suffix.startsWith(RegExp(r'\r?\n')) && content.isNotEmpty) {
    suffix = '${block.source.contains('\r\n') ? '\r\n' : '\n'}$suffix';
  }
  final opening = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(prefix)!;
  final delimiter = opening[1]!;
  final character = delimiter[0];
  final closers = RegExp(
    '^ {0,3}(${RegExp.escape(character)}{${delimiter.length},}) *\$',
    multiLine: true,
  );
  var length = delimiter.length;
  // Strip CR only for recognition; retain every untouched source byte.
  for (final line in content.split('\n')) {
    final match = closers.firstMatch(line.replaceFirst(RegExp(r'\r$'), ''));
    if (match != null && match[1]!.length >= length) {
      length = match[1]!.length + 1;
    }
  }
  if (length > delimiter.length) {
    final replacement = List.filled(length, character).join();
    prefix = prefix.replaceRange(
      opening.start + opening[0]!.length - delimiter.length,
      opening.end,
      replacement,
    );
    // Preserve closing indentation, spaces, EOL and any already-longer fence.
    suffix = suffix.replaceFirstMapped(
      RegExp('${RegExp.escape(character)}{${delimiter.length},}'),
      (match) => match[0]!.length >= length ? match[0]! : replacement,
    );
  }
  return MarkdownBlock(
    '$prefix$content$suffix',
    MarkdownBlockKind.code,
    prefix: prefix,
    suffix: suffix,
    language: block.language,
  );
}
