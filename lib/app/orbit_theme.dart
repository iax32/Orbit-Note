import 'package:flutter/material.dart';

abstract final class OrbitRadius {
  static const control = 8.0;
  static const card = 12.0;
  static const floating = 16.0;
}

abstract final class OrbitMotion {
  static const micro = Duration(milliseconds: 110);
  static const panel = Duration(milliseconds: 180);
  static const dialog = Duration(milliseconds: 200);
}

/// Semantic colors shared by the shell and feature surfaces.
class OrbitColors extends ThemeExtension<OrbitColors> {
  const OrbitColors({
    this.background = const Color(0xFF0D0D12),
    this.panel = const Color(0xFF13131A),
    this.raised = const Color(0xFF1A1922),
    this.hover = const Color(0xFF211F2B),
    this.accent = const Color(0xFF8B7CF6),
    this.secondary = const Color(0xFF6F7FEA),
    this.text = const Color(0xFFECEAF2),
    this.subtle = const Color(0xFFB6B2C2),
    this.border = const Color(0xFF262430),
    this.success = const Color(0xFF65C6A3),
    this.accentHover = const Color(0xFF9B8CF8),
    this.muted = const Color(0xFF7D788A),
    this.divider = const Color(0xFF201E28),
    this.warning = const Color(0xFFD8B56A),
    this.danger = const Color(0xFFE57582),
  });
  final Color background, panel, raised, hover, accent, secondary;
  final Color text, subtle, border, success;
  final Color accentHover, muted, divider, warning, danger;
  static OrbitColors of(BuildContext context) =>
      Theme.of(context).extension<OrbitColors>() ?? const OrbitColors();
  @override
  OrbitColors copyWith({Color? accent}) => OrbitColors(
    background: background,
    panel: panel,
    raised: raised,
    hover: hover,
    accent: accent ?? this.accent,
    secondary: secondary,
    text: text,
    subtle: subtle,
    border: border,
    success: success,
    accentHover: accentHover,
    muted: muted,
    divider: divider,
    warning: warning,
    danger: danger,
  );
  @override
  OrbitColors lerp(covariant OrbitColors? other, double t) {
    if (other == null) return this;
    return OrbitColors(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

ThemeData orbitDarkTheme({bool compact = false}) {
  const c = OrbitColors();
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: Brightness.dark,
    surface: c.panel,
    primary: c.accent,
    secondary: c.secondary,
    onSurface: c.text,
    error: const Color(0xFFE57582),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: 'Segoe UI',
    extensions: const [c],
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    dividerColor: c.border,
    splashFactory: NoSplash.splashFactory,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: c.text, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.accent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.subtle, fontSize: 13),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.subtle),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.subtle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OrbitRadius.control),
        ),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(4),
      thickness: const WidgetStatePropertyAll(5),
      thumbColor: WidgetStatePropertyAll(c.subtle.withValues(alpha: .3)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.floating),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.card),
      ),
      color: c.raised,
    ),
  );
}
