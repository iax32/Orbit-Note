import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Actual text styles, never bitmap scaling. Keep the user's size and spacing.
class NoteTypography {
  const NoteTypography({
    this.fontFamily,
    this.fontSize = 16,
    this.lineHeight = 1.6,
  });
  final String? fontFamily;
  final double fontSize, lineHeight;

  static bool isSerif(String? family) => const [
    'times new roman',
    'georgia',
    'serif',
  ].contains(family?.toLowerCase());
  FontWeight get headingWeight =>
      isSerif(fontFamily) ? FontWeight.w700 : FontWeight.w600;
  List<String> get fallbacks => isSerif(fontFamily)
      ? ['Georgia', 'Times New Roman', 'serif']
      : const ['Consolas', 'monospace'].contains(fontFamily)
      ? ['Consolas', 'Courier New', 'monospace']
      : ['Segoe UI', 'Arial', 'sans-serif'];

  TextStyle body({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fallbacks,
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: lineHeight,
    color: color,
  );

  TextStyle heading(int level, {Color? color}) => body(color: color).copyWith(
    fontSize: fontSize + (7 - level.clamp(1, 6)) * 2,
    fontWeight: headingWeight,
    height: 1.3,
  );

  MarkdownStyleSheet markdown(ThemeData theme) =>
      MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body(color: theme.colorScheme.onSurface),
        h1: heading(1, color: theme.colorScheme.onSurface),
        h2: heading(2, color: theme.colorScheme.onSurface),
        h3: heading(3, color: theme.colorScheme.onSurface),
        h4: heading(4, color: theme.colorScheme.onSurface),
        h5: heading(5, color: theme.colorScheme.onSurface),
        h6: heading(6, color: theme.colorScheme.onSurface),
        tableBody: body(color: theme.colorScheme.onSurface),
        tableHead: body(
          color: theme.colorScheme.onSurface,
        ).copyWith(fontWeight: headingWeight),
        listBullet: body(color: theme.colorScheme.onSurface),
        blockquote: body(color: theme.colorScheme.onSurface),
      );
}
