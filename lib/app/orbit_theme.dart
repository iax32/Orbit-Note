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
  static const ease = Curves.easeOutCubic;
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
  Color get floating => raised;
  Color get selected => hover;
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
    if (other == null) {
      return this;
    }
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
    onSurfaceVariant: c.subtle,
    surfaceDim: c.background,
    surfaceBright: c.hover,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.panel,
    surfaceContainer: c.raised,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.hover,
    surfaceTint: Colors.transparent,
    outline: c.border,
    outlineVariant: c.divider,
    onPrimary: c.background,
    primaryContainer: c.hover,
    onPrimaryContainer: c.accentHover,
    secondaryContainer: c.hover,
    onSecondaryContainer: c.text,
    error: c.danger,
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(OrbitRadius.control),
  );
  final floatingShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(OrbitRadius.floating),
    side: BorderSide(color: c.border),
  );
  final controlOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.focused)) {
      return c.accent.withValues(alpha: .20);
    }
    if (states.contains(WidgetState.pressed)) {
      return c.accent.withValues(alpha: .16);
    }
    if (states.contains(WidgetState.hovered)) {
      return c.accent.withValues(alpha: .08);
    }
    return null;
  });
  BorderSide controlBorder(Set<WidgetState> states) => BorderSide(
    color: states.contains(WidgetState.focused) ? c.accent : c.border,
  );
  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(OrbitRadius.control),
    borderSide: BorderSide(color: color),
  );
  const labelStyle = TextStyle(
    fontFamily: 'Segoe UI',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    fontFamily: 'Segoe UI',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -.6,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.5, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, letterSpacing: 0),
      labelLarge: labelStyle,
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: .1,
      ),
    ),
    extensions: const [c],
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    dividerColor: c.border,
    splashFactory: NoSplash.splashFactory,
    hoverColor: c.hover,
    focusColor: c.accent.withValues(alpha: .18),
    disabledColor: c.muted,
    iconTheme: IconThemeData(color: c.subtle, size: 20),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: .28),
      selectionHandleColor: c.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.raised,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(OrbitRadius.control),
      ),
      textStyle: labelStyle.copyWith(color: c.text, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.raised,
      border: inputBorder(c.border),
      enabledBorder: inputBorder(c.border),
      focusedBorder: inputBorder(c.accent),
      errorBorder: inputBorder(c.danger),
      focusedErrorBorder: inputBorder(c.danger),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.subtle, fontSize: 13),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.subtle,
        disabledForegroundColor: c.muted.withValues(alpha: .5),
        shape: controlShape,
      ).copyWith(overlayColor: controlOverlay),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.subtle,
        textStyle: labelStyle,
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ).copyWith(overlayColor: controlOverlay),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: controlShape,
        textStyle: labelStyle,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        minimumSize: const Size(64, 40),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            shape: controlShape,
            foregroundColor: c.text,
            backgroundColor: c.panel,
            textStyle: labelStyle,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(64, 40),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(controlBorder),
            overlayColor: controlOverlay,
          ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: c.border),
        backgroundColor: c.panel,
        foregroundColor: c.subtle,
        selectedBackgroundColor: c.hover,
        selectedForegroundColor: c.accentHover,
        textStyle: labelStyle,
      ).copyWith(overlayColor: controlOverlay),
    ),
    chipTheme: ChipThemeData(
      shape: controlShape,
      side: BorderSide(color: c.border),
      backgroundColor: c.panel,
      selectedColor: c.hover,
      checkmarkColor: c.accentHover,
      labelStyle: labelStyle.copyWith(color: c.subtle, fontSize: 12),
      secondaryLabelStyle: labelStyle.copyWith(
        color: c.accentHover,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: c.muted, width: 1.5),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.border,
      thumbColor: c.accent,
      overlayColor: c.accent.withValues(alpha: .16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(c.border),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.accent.withValues(
                alpha: states.contains(WidgetState.disabled) ? .12 : .25,
              )
            : c.raised,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? c.muted
            : states.contains(WidgetState.selected)
            ? c.accent
            : c.subtle,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.subtle,
      textColor: c.text,
      selectedColor: c.accentHover,
      selectedTileColor: c.hover,
      shape: controlShape,
    ),
    cardTheme: CardThemeData(
      color: c.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        side: BorderSide(color: c.border),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.dragged) ||
                states.contains(WidgetState.hovered)
            ? 7
            : 4,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => c.subtle.withValues(
          alpha: states.contains(WidgetState.dragged)
              ? .65
              : states.contains(WidgetState.hovered)
              ? .45
              : .22,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: .4),
      shape: floatingShape,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.panel,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.panel,
      headerForegroundColor: c.text,
      shape: floatingShape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        side: BorderSide(color: c.border),
      ),
      color: c.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 13,
          color: states.contains(WidgetState.disabled) ? c.muted : c.text,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.raised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(controlShape),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.raised,
      contentTextStyle: labelStyle.copyWith(color: c.text),
      actionTextColor: c.accentHover,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        side: BorderSide(color: c.border),
      ),
    ),
  );
}
