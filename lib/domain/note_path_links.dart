import 'package:path/path.dart' as p;

/// Rebase ordinary Markdown destinations for an explicit file move. Autosave
/// never calls this. Code fences, inline code and absolute/URI targets stay exact.
String rebaseNoteLinks(
  String source,
  String oldPath,
  String newPath, {
  String? movedSource,
  String? movedTarget,
}) {
  if (p.posix.dirname(oldPath) == p.posix.dirname(newPath)) return source;
  String destination(String raw) {
    final angle = raw.startsWith('<') && raw.endsWith('>');
    final value = angle ? raw.substring(1, raw.length - 1) : raw;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        value.startsWith('/') ||
        value.startsWith('#') ||
        value.isEmpty) {
      return raw;
    }
    final suffixAt = value.indexOf(RegExp(r'[?#]'));
    final path = suffixAt < 0 ? value : value.substring(0, suffixAt);
    final suffix = suffixAt < 0 ? '' : value.substring(suffixAt);
    var resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(oldPath), path),
    );
    if (resolved == '..' || resolved.startsWith('../')) return raw;
    if (movedSource != null &&
        movedTarget != null &&
        (resolved == movedSource || resolved.startsWith('$movedSource/'))) {
      resolved = '$movedTarget${resolved.substring(movedSource.length)}';
    }
    final next =
        p.posix.relative(resolved, from: p.posix.dirname(newPath)) + suffix;
    return angle ? '<$next>' : next;
  }

  String? fence;
  var length = 0;
  return source
      .split('\n')
      .map((line) {
        final marker = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$').firstMatch(line);
        if (fence != null) {
          if (marker != null &&
              marker[1]!.startsWith(fence!) &&
              marker[1]!.length >= length &&
              marker[2]!.trim().isEmpty) {
            fence = null;
          }
          return line;
        }
        if (marker != null) {
          fence = marker[1]![0];
          length = marker[1]!.length;
          return line;
        }
        if (line.startsWith('    ') || line.startsWith('\t')) return line;
        // Keep inline code opaque, including delimiters with multiple backticks.
        final code = RegExp(r'(`+)[\s\S]*?\1');
        String prose(String text) => text.replaceAllMapped(
          RegExp(r'(?<!\\)(\]\(\s*)(<[^>\r\n]+>|[^\s()]+)(?=\s|\))'),
          (m) => '${m[1]}${destination(m[2]!)}',
        );
        final out = StringBuffer();
        var offset = 0;
        for (final match in code.allMatches(line)) {
          out.write(prose(line.substring(offset, match.start)));
          out.write(match[0]);
          offset = match.end;
        }
        out.write(prose(line.substring(offset)));
        return out.toString().replaceFirstMapped(
          RegExp(r'^( {0,3}\[[^\]]+\]:\s*)(<[^>\r\n]+>|\S+)'),
          (m) => '${m[1]}${destination(m[2]!)}',
        );
      })
      .join('\n');
}
