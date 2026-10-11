import 'figure_details.dart';

/// Ordinary Markdown enclosed by optional layout comments. Other readers retain
/// the image and prose. Unrecognized/unfinished markers are never rewritten.
class MediaSectionSource {
  MediaSectionSource(
    this.prefix,
    this.body,
    this.suffix,
    this.image,
    this.alt,
    this.side,
    this.width,
  );
  final String prefix, body, suffix, image, alt, side;
  final int width;
  FigureDetails? get figure => FigureDetails.parse(body);
  String get textBody => figure?.rest ?? body;
  String withFigure(FigureDetails details) => replaceBody(
    '${details.encode(prefix.contains('\r\n') ? '\r\n' : '\n')}$textBody',
  );
  String replaceTextBody(String value) =>
      replaceBody('${figure?.original ?? ''}$value');
  String get imageMarkdown => prefix
      .substring(prefix.indexOf('\n') + 1)
      .replaceFirst(RegExp(r'\r?\n$'), '');
  static final opening = RegExp(
    r'^<!-- orbit:media (left|right) width=(160|200|260) -->$',
  );
  static const closing = '<!-- /orbit:media -->';
  static int? endLine(List<String> lines, int start) {
    String clean(String s) => s.replaceFirst(RegExp(r'\r?\n$'), '');
    if (!opening.hasMatch(clean(lines[start]))) return null;
    String? fence;
    for (var i = start + 1; i < lines.length; i++) {
      final line = clean(lines[i]);
      final run = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line)?[1];
      if (fence != null) {
        if (RegExp(
          '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}[ \\t]*\$',
        ).hasMatch(line)) {
          fence = null;
        }
        continue;
      }
      if (run != null) {
        fence = run;
        continue;
      }
      if (opening.hasMatch(line)) return null;
      if (line == closing) return i;
    }
    return null;
  }

  static MediaSectionSource? parse(String source) {
    final lines = RegExp(
      r'[^\n]*\n|[^\n]+$',
    ).allMatches(source).map((m) => m[0]!).toList();
    if (lines.length < 3) return null;
    String clean(String s) => s.replaceFirst(RegExp(r'\r?\n$'), '');
    final config = opening.firstMatch(clean(lines.first));
    final image = RegExp(
      r'^!\[([^\]\r\n]*)\]\((?:<([^>\r\n]+)>|([^ )\r\n]+))(?: +"[^"\r\n]*")?\)$',
    ).firstMatch(clean(lines[1]));
    if (config == null ||
        image == null ||
        endLine(lines, 0) != lines.length - 1) {
      return null;
    }
    return MediaSectionSource(
      lines.take(2).join(),
      lines.sublist(2, lines.length - 1).join(),
      lines.last,
      image[2] ?? image[3]!,
      image[1]!,
      config[1]!,
      int.parse(config[2]!),
    );
  }

  static String create(
    String image, {
    String body = '### Title\n\n- Add a detail\n',
    String alt = 'Image',
    String? imageMarkdown,
    String eol = '\n',
  }) {
    if (image.contains(RegExp(r'[<>\r\n]'))) {
      throw const FormatException(
        'This image address cannot be used in a media section.',
      );
    }
    return '<!-- orbit:media left width=200 -->$eol${imageMarkdown ?? '![$alt](<$image>)'}$eol$eol${body.replaceAll(RegExp(r'\r?\n'), eol)}${body.endsWith('\n') ? '' : eol}$closing$eol';
  }

  String replaceBody(String value) =>
      '$prefix${value.endsWith('\n') ? value : '$value${prefix.contains('\r\n') ? '\r\n' : '\n'}'}$suffix';
  String configure(String newSide, int newWidth) =>
      '${prefix.replaceFirst(RegExp(r'^<!-- orbit:media [^\r\n]+ -->'), '<!-- orbit:media $newSide width=$newWidth -->')}$body$suffix';
}
