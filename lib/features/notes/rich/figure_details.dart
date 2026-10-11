class FigureCitation {
  const FigureCitation(this.label, this.destination);
  final String label, destination;
  void validate() {
    final uri = Uri.tryParse(destination);
    if (label.trim().isEmpty ||
        label.length > 200 ||
        label.contains(RegExp(r'[\r\n]')) ||
        destination.isEmpty ||
        destination.length > 2048 ||
        destination.contains(RegExp(r'[<>\s\x00-\x1f]')) ||
        uri == null ||
        !['', 'https', 'http', 'orbit-object'].contains(uri.scheme) ||
        (['http', 'https'].contains(uri.scheme) && uri.host.isEmpty) ||
        (uri.scheme == 'orbit-object' && uri.path.isEmpty)) {
      throw const FormatException(
        'Use a source label and an HTTPS/HTTP link, local attachment path, or linked note. Encode spaces in addresses as %20.',
      );
    }
  }
}

/// Caption/source data is ordinary readable Markdown, bounded by comments.
/// Invalid or unfamiliar forms remain in the prose instead of being discarded.
class FigureDetails {
  FigureDetails(
    this.caption,
    this.citations, {
    this.original = '',
    this.rest = '',
  });
  final String caption, original, rest;
  final List<FigureCitation> citations;
  static const start = '<!-- orbit:figure -->', end = '<!-- /orbit:figure -->';
  static String escape(String value) =>
      value.replaceAllMapped(RegExp(r'[\\\[\]*_`<>]'), (m) => '\\${m[0]}');
  static String unescape(String value) =>
      value.replaceAllMapped(RegExp(r'\\([\\\[\]*_`<>])'), (m) => m[1]!);
  static FigureDetails? parse(String body) {
    final first = RegExp(
      r'^(?:\r?\n)*<!-- orbit:figure -->\r?\n',
    ).firstMatch(body);
    if (first == null) return null;
    final finish = RegExp(
      r'^<!-- /orbit:figure -->(?:\r?\n|$)',
      multiLine: true,
    ).firstMatch(body.substring(first.end));
    if (finish == null) return null;
    final content = body
        .substring(first.end, first.end + finish.start)
        .split(RegExp(r'\r?\n'));
    var caption = '';
    final citations = <FigureCitation>[];
    try {
      for (final line in content) {
        if (line.isEmpty) continue;
        if (line.startsWith('Caption: ') && caption.isEmpty) {
          caption = unescape(line.substring(9));
          continue;
        }
        final link = RegExp(
          r'^- \[((?:\\.|[^\]\\])+)\]\(<([^>]+)>\)$',
        ).firstMatch(line);
        if (link == null) return null;
        final citation = FigureCitation(unescape(link[1]!), link[2]!);
        citation.validate();
        citations.add(citation);
      }
      final cut = first.end + finish.end;
      final result = FigureDetails(
        caption,
        citations,
        original: body.substring(0, cut),
        rest: body.substring(cut),
      );
      result.validate();
      return result;
    } on FormatException {
      return null;
    }
  }

  void validate() {
    if (caption.length > 2000 ||
        caption.contains(RegExp(r'[\r\n]')) ||
        citations.length > 20) {
      throw const FormatException(
        'Use a single-line caption (up to 2,000 characters) and at most 20 sources.',
      );
    }
    for (final source in citations) {
      source.validate();
    }
  }

  String encode(String eol) {
    validate();
    if (caption.isEmpty && citations.isEmpty) return '';
    return '$start$eol${caption.isEmpty ? '' : 'Caption: ${escape(caption)}$eol'}${citations.map((s) => '- [${escape(s.label)}](<${s.destination}>)$eol').join()}$end$eol';
  }
}
