import 'package:flutter/material.dart';
import 'app_preferences.dart';
import 'orbit_density.dart';

part 'orbit_palette_catalog.dart';

abstract final class OrbitRadius {
  static const small = 4.0;
  static const control = 8.0;
  static const card = 12.0;
  static const panel = 12.0;
  static const menu = 8.0;
  static const dialog = 16.0;
  static const floating = dialog;
}

/// Dynamic corner style tokens (Rounded vs Subtle/Crisp).
class OrbitCorners extends ThemeExtension<OrbitCorners> {
  const OrbitCorners({
    this.style = 'rounded',
    this.control = 8.0,
    this.card = 12.0,
    this.panel = 12.0,
    this.menu = 8.0,
    this.dialog = 16.0,
    this.small = 4.0,
  });

  final String style;
  final double control;
  final double card;
  final double panel;
  final double menu;
  final double dialog;
  final double small;

  static const rounded = OrbitCorners(
    style: 'rounded',
    control: 8.0,
    card: 12.0,
    panel: 12.0,
    menu: 8.0,
    dialog: 16.0,
    small: 4.0,
  );

  static const subtle = OrbitCorners(
    style: 'subtle',
    control: 4.0,
    card: 6.0,
    panel: 6.0,
    menu: 4.0,
    dialog: 8.0,
    small: 2.0,
  );

  static OrbitCorners of(BuildContext context) =>
      Theme.of(context).extension<OrbitCorners>() ?? rounded;

  static OrbitCorners fromStyle(String? name) =>
      name == 'subtle' ? subtle : rounded;

  @override
  OrbitCorners copyWith({
    String? style,
    double? control,
    double? card,
    double? panel,
    double? menu,
    double? dialog,
    double? small,
  }) => OrbitCorners(
    style: style ?? this.style,
    control: control ?? this.control,
    card: card ?? this.card,
    panel: panel ?? this.panel,
    menu: menu ?? this.menu,
    dialog: dialog ?? this.dialog,
    small: small ?? this.small,
  );

  @override
  OrbitCorners lerp(covariant OrbitCorners? other, double t) {
    if (other == null) return this;
    return OrbitCorners(
      style: t < .5 ? style : other.style,
      control: control + (other.control - control) * t,
      card: card + (other.card - card) * t,
      panel: panel + (other.panel - panel) * t,
      menu: menu + (other.menu - menu) * t,
      dialog: dialog + (other.dialog - dialog) * t,
      small: small + (other.small - small) * t,
    );
  }
}

abstract final class OrbitMotion {
  static const micro = Duration(milliseconds: 110);
  static const control = Duration(milliseconds: 140);
  static const panel = Duration(milliseconds: 180);
  static const dialog = Duration(milliseconds: 200);
  static const workspace = Duration(milliseconds: 220);
  static const ease = Curves.easeOutCubic;
}

/// Utility for computing WCAG 2.1 relative luminance and contrast ratios.
abstract final class OrbitContrast {
  /// A filled control needs contrasting ink in either appearance, including
  /// bright custom accents. A fixed white foreground is not always readable.
  static Color inkOn(Color background) =>
      ratio(Colors.black, background) >= ratio(Colors.white, background)
      ? Colors.black
      : Colors.white;

  /// Computes the contrast ratio between two colors using WCAG 2.1 relative luminance.
  /// Result ranges from 1.0 (identical) to 21.0 (black vs white).
  static double ratio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whether the contrast ratio meets WCAG Level AA (>= 4.5 for normal text, >= 3.0 for large).
  static bool isWcagAa(
    Color foreground,
    Color background, {
    bool largeText = false,
  }) {
    return ratio(foreground, background) >= (largeText ? 3.0 : 4.5);
  }

  /// Whether the contrast ratio meets WCAG Level AAA (>= 7.0 for normal text, >= 4.5 for large).
  static bool isWcagAaa(
    Color foreground,
    Color background, {
    bool largeText = false,
  }) {
    return ratio(foreground, background) >= (largeText ? 4.5 : 7.0);
  }
}

/// Semantic tokens shared by the shell, views, and feature surfaces.
class OrbitColors extends ThemeExtension<OrbitColors> {
  const OrbitColors({
    this.background = const Color(0xFF141418),
    Color? workspace = const Color(0xFF19191E),
    this.panel = const Color(0xFF1D1D23),
    Color? panelSecondary = const Color(0xFF222229),
    this.raised = const Color(0xFF25252D),
    Color? floating = const Color(0xFF2B2B35),
    Color? input = const Color(0xFF202027),
    this.hover = const Color(0xFF303039),
    Color? pressed,
    Color? selected,
    Color? selectedMuted,
    this.border = const Color(0xFF40404C),
    this.divider = const Color(0xFF2B2B35),
    Color? focus,
    this.accent = const Color(0xFFB0A0FF),
    this.secondary = const Color(0xFFA1ADEA),
    this.accentHover = const Color(0xFFC3B6FF),
    this.text = const Color(0xFFF2F0F7),
    this.subtle = const Color(0xFFC9C6D3),
    this.muted = const Color(0xFFAAA5B5),
    Color? textDisabled,
    this.success = const Color(0xFF88D6B5),
    this.warning = const Color(0xFFE7C783),
    this.danger = const Color(0xFFF2A4AF),
    Color? link,
    Color? linkVisited,
    Color? canvasBackground,
    Color? canvasGrid,
    Color? graphEdge,
  }) : workspace = workspace ?? background,
       panelSecondary = panelSecondary ?? panel,
       floating = floating ?? raised,
       input = input ?? raised,
       pressed = pressed ?? const Color(0xFF383842),
       selected = selected ?? const Color(0xFF332F46),
       selectedMuted = selectedMuted ?? const Color(0xFF272535),
       focus = focus ?? accentHover,
       textDisabled = textDisabled ?? const Color(0xFF777281),
       link = link ?? const Color(0xFFB6A8FF),
       linkVisited = linkVisited ?? const Color(0xFFAEBAFF),
       canvasBackground = canvasBackground ?? background,
       canvasGrid = canvasGrid ?? border,
       graphEdge = graphEdge ?? const Color(0xFF666373);

  final Color background;
  final Color workspace;
  final Color panel;
  final Color panelSecondary;
  final Color raised;
  final Color floating;
  final Color input;
  final Color hover;
  final Color pressed;
  final Color selected;
  final Color selectedMuted;
  final Color border;
  final Color divider;
  final Color focus;
  final Color accent;
  final Color secondary;
  final Color accentHover;
  final Color text;
  final Color subtle;
  final Color muted;
  final Color textDisabled;
  final Color success;
  final Color warning;
  final Color danger;
  final Color link;
  final Color linkVisited;
  final Color canvasBackground;
  final Color canvasGrid;
  final Color graphEdge;

  // Semantic convenience aliases
  Color get textPrimary => text;
  Color get textSecondary => subtle;
  Color get textMuted => muted;
  Color get accentSecondary => secondary;
  Color get onAccent => OrbitContrast.inkOn(accent);

  /// A restrained status surface that retains readable role-colored text.
  /// Explicit unreadable custom colors remain user-owned; recovery stays separate.
  Color tinted(Color foreground, {Color? surface, double opacity = .12}) {
    final base = surface ?? panel;
    var amount = opacity.clamp(0.0, 1.0);
    for (var i = 0; i < 24; i++) {
      final result = Color.alphaBlend(
        foreground.withValues(alpha: amount),
        base,
      );
      if (OrbitContrast.ratio(foreground, result) >= 4.5) return result;
      amount /= 2;
    }
    return base;
  }

  /// Shared object/status vocabulary across navigation, collections and graphs.
  Color objectType(String type) => switch (type) {
    'orbit.task' => warning,
    'orbit.canvas' => secondary,
    'orbit.event' => success,
    'orbit.file' => subtle,
    _ => accent,
  };

  Color status(String value) => switch (value.toLowerCase()) {
    'done' || 'closed' || 'confirmed' || 'passed' || 'verified' => success,
    'in-progress' || 'testing' || 'investigating' || 'learning' => accent,
    'review' || 'verify' || 'uncertain' => warning,
    'blocked' || 'rejected' || 'failed' || 'disproved' => danger,
    _ => subtle,
  };

  Color priority(String value) => switch (value.toLowerCase()) {
    'urgent' || 'blocker' || 'critical' => danger,
    'high' || 'major' => warning,
    'medium' || 'minor' => accent,
    _ => subtle,
  };

  static OrbitColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<OrbitColors>() ??
        (theme.brightness == Brightness.light
            ? OrbitThemePack.fromId('paper').colors
            : const OrbitColors());
  }

  static const Map<String, Color> accentPresets = {
    'violet': Color(0xFF8B7CF6),
    'cyan': Color(0xFF06B6D4),
    'emerald': Color(0xFF10B981),
    'amber': Color(0xFFF59E0B),
    'rose': Color(0xFFF43F5E),
    'blue': Color(0xFF3B82F6),
  };

  static Color accentFromPreset(String? name) =>
      accentPresets[name] ?? const OrbitColors().accent;

  static const roleLabels = <String, String>{
    'background': 'Workspace background',
    'workspace': 'Center workspace area',
    'panel': 'Sidebar & panels',
    'panelSecondary': 'Secondary panels & inspector',
    'raised': 'Cards & menus',
    'floating': 'Floating popovers & dialogs',
    'input': 'Input fields',
    'hover': 'Hover surfaces',
    'pressed': 'Pressed & active surfaces',
    'selected': 'Selected items & tabs',
    'selectedMuted': 'Subtle & inactive selection',
    'border': 'Borders',
    'divider': 'Dividers',
    'focus': 'Focus rings & active borders',
    'accent': 'Buttons & primary accent',
    'accentHover': 'Focus & accent highlight',
    'secondary': 'Secondary accent',
    'text': 'Main text',
    'subtle': 'Secondary text',
    'muted': 'Muted text',
    'textDisabled': 'Disabled text',
    'success': 'Success & completion',
    'warning': 'Warnings',
    'danger': 'Errors & destructive actions',
    'link': 'Links & wiki links',
    'linkVisited': 'Visited links',
    'canvasBackground': 'Canvas background',
    'canvasGrid': 'Canvas grid',
    'graphEdge': 'Graph links & edges',
  };

  Map<String, Color> get roles => {
    'background': background,
    'workspace': workspace,
    'panel': panel,
    'panelSecondary': panelSecondary,
    'raised': raised,
    'floating': floating,
    'input': input,
    'hover': hover,
    'pressed': pressed,
    'selected': selected,
    'selectedMuted': selectedMuted,
    'border': border,
    'divider': divider,
    'focus': focus,
    'accent': accent,
    'accentHover': accentHover,
    'secondary': secondary,
    'text': text,
    'subtle': subtle,
    'muted': muted,
    'textDisabled': textDisabled,
    'success': success,
    'warning': warning,
    'danger': danger,
    'link': link,
    'linkVisited': linkVisited,
    'canvasBackground': canvasBackground,
    'canvasGrid': canvasGrid,
    'graphEdge': graphEdge,
  };

  OrbitColors withOverrides(Map<String, int> values) {
    Color pick(String key) {
      final value = values[key];
      return value != null && value >= 0xff000000 && value <= 0xffffffff
          ? Color(value)
          : roles[key]!;
    }

    final nextAccent = pick('accent');
    return OrbitColors(
      background: pick('background'),
      workspace: pick('workspace'),
      panel: pick('panel'),
      panelSecondary: pick('panelSecondary'),
      raised: pick('raised'),
      floating: pick('floating'),
      input: pick('input'),
      hover: pick('hover'),
      pressed: pick('pressed'),
      selected: pick('selected'),
      selectedMuted: pick('selectedMuted'),
      border: pick('border'),
      divider: pick('divider'),
      focus: pick('focus'),
      accent: nextAccent,
      secondary: pick('secondary'),
      accentHover: values.containsKey('accentHover')
          ? pick('accentHover')
          : values.containsKey('accent')
          ? Color.alphaBlend(Colors.white.withValues(alpha: .12), nextAccent)
          : pick('accentHover'),
      text: pick('text'),
      subtle: pick('subtle'),
      muted: pick('muted'),
      textDisabled: pick('textDisabled'),
      success: pick('success'),
      warning: pick('warning'),
      danger: pick('danger'),
      link: pick('link'),
      linkVisited: pick('linkVisited'),
      canvasBackground: pick('canvasBackground'),
      canvasGrid: pick('canvasGrid'),
      graphEdge: pick('graphEdge'),
    );
  }

  /// Generates a complete set of harmonized, WCAG-accessible semantic tokens
  /// from a single user-chosen seed color.
  factory OrbitColors.fromSeed(
    Color seed, {
    Brightness brightness = Brightness.dark,
  }) {
    final hsv = HSVColor.fromColor(seed);
    final hue = hsv.hue;
    final seedSat = hsv.saturation;
    final seedVal = hsv.value;

    if (brightness == Brightness.dark) {
      final tintSat = (seedSat * 0.18).clamp(0.015, 0.14);
      final bg = HSVColor.fromAHSV(1.0, hue, tintSat, 0.055).toColor();
      final ws = HSVColor.fromAHSV(1.0, hue, tintSat * 0.9, 0.075).toColor();
      final pan = HSVColor.fromAHSV(1.0, hue, tintSat * 1.1, 0.095).toColor();
      final panSec = HSVColor.fromAHSV(
        1.0,
        hue,
        tintSat * 1.1,
        0.115,
      ).toColor();
      final rsd = HSVColor.fromAHSV(1.0, hue, tintSat * 1.2, 0.14).toColor();
      final flt = HSVColor.fromAHSV(1.0, hue, tintSat * 1.25, 0.17).toColor();
      final inp = HSVColor.fromAHSV(1.0, hue, tintSat * 1.1, 0.11).toColor();
      final hvr = HSVColor.fromAHSV(1.0, hue, tintSat * 1.3, 0.19).toColor();
      final prs = HSVColor.fromAHSV(1.0, hue, tintSat * 1.4, 0.24).toColor();
      final sel = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 2.5).clamp(0.12, 0.35),
        0.22,
      ).toColor();
      final selMuted = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 1.8).clamp(0.08, 0.25),
        0.16,
      ).toColor();
      final brd = HSVColor.fromAHSV(1.0, hue, tintSat * 1.4, 0.19).toColor();
      final div = HSVColor.fromAHSV(1.0, hue, tintSat * 1.2, 0.15).toColor();

      final acc = HSVColor.fromAHSV(
        1.0,
        hue,
        seedSat < 0.15 ? 0.75 : seedSat.clamp(0.60, 0.95),
        seedVal < 0.2 ? 0.85 : seedVal.clamp(0.75, 0.96),
      ).toColor();

      final accHover = HSVColor.fromAHSV(
        1.0,
        hue,
        (seedSat * 0.85).clamp(0.50, 0.85),
        (seedVal * 1.1).clamp(0.85, 1.0),
      ).toColor();

      final sec = HSVColor.fromAHSV(
        1.0,
        (hue + 32) % 360,
        (seedSat * 0.85).clamp(0.5, 0.85),
        0.88,
      ).toColor();

      final txt = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.4).clamp(0.01, 0.05),
        0.95,
      ).toColor();
      final sbt = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.6).clamp(0.02, 0.08),
        0.78,
      ).toColor();
      final mut = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.8).clamp(0.03, 0.10),
        0.60,
      ).toColor();
      final dis = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.8).clamp(0.03, 0.10),
        0.40,
      ).toColor();

      final lnk = HSVColor.fromAHSV(1.0, (hue + 8) % 360, 0.70, 0.90).toColor();
      final lnkVis = HSVColor.fromAHSV(
        1.0,
        (hue + 28) % 360,
        0.60,
        0.85,
      ).toColor();

      return OrbitColors(
        background: bg,
        workspace: ws,
        panel: pan,
        panelSecondary: panSec,
        raised: rsd,
        floating: flt,
        input: inp,
        hover: hvr,
        pressed: prs,
        selected: sel,
        selectedMuted: selMuted,
        border: brd,
        divider: div,
        focus: accHover,
        accent: acc,
        secondary: sec,
        accentHover: accHover,
        text: txt,
        subtle: sbt,
        muted: mut,
        textDisabled: dis,
        success: const Color(0xFF4ADE80),
        warning: const Color(0xFFFACC15),
        danger: const Color(0xFFFB7185),
        link: lnk,
        linkVisited: lnkVis,
        canvasBackground: bg,
        canvasGrid: div,
        graphEdge: HSVColor.fromAHSV(1.0, hue, tintSat * 1.3, 0.26).toColor(),
      );
    } else {
      final tintSat = (seedSat * 0.14).clamp(0.015, 0.10);
      final bg = HSVColor.fromAHSV(1.0, hue, tintSat, 0.98).toColor();
      final ws = HSVColor.fromAHSV(1.0, hue, tintSat * 0.7, 0.995).toColor();
      final pan = HSVColor.fromAHSV(1.0, hue, tintSat * 1.1, 0.94).toColor();
      final panSec = HSVColor.fromAHSV(1.0, hue, tintSat * 1.1, 0.91).toColor();
      const rsd = Color(0xFFFFFFFF);
      const flt = Color(0xFFFFFFFF);
      const inp = Color(0xFFFFFFFF);
      final hvr = HSVColor.fromAHSV(1.0, hue, tintSat * 1.3, 0.90).toColor();
      final prs = HSVColor.fromAHSV(1.0, hue, tintSat * 1.4, 0.86).toColor();
      final sel = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 2.2).clamp(0.08, 0.25),
        0.88,
      ).toColor();
      final selMuted = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 1.5).clamp(0.05, 0.18),
        0.92,
      ).toColor();
      final brd = HSVColor.fromAHSV(1.0, hue, tintSat * 1.5, 0.82).toColor();
      final div = HSVColor.fromAHSV(1.0, hue, tintSat * 1.2, 0.87).toColor();

      final acc = HSVColor.fromAHSV(
        1.0,
        hue,
        seedSat < 0.15 ? 0.80 : seedSat.clamp(0.65, 0.95),
        seedVal > 0.8 ? 0.52 : seedVal.clamp(0.40, 0.62),
      ).toColor();

      final accHover = HSVColor.fromAHSV(
        1.0,
        hue,
        seedSat.clamp(0.75, 1.0),
        (seedVal * 0.9).clamp(0.35, 0.58),
      ).toColor();

      final sec = HSVColor.fromAHSV(
        1.0,
        (hue + 32) % 360,
        (seedSat * 0.8).clamp(0.5, 0.85),
        0.50,
      ).toColor();

      final txt = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.8).clamp(0.02, 0.10),
        0.13,
      ).toColor();
      final sbt = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.7).clamp(0.02, 0.08),
        0.35,
      ).toColor();
      final mut = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.6).clamp(0.02, 0.08),
        0.52,
      ).toColor();
      final dis = HSVColor.fromAHSV(
        1.0,
        hue,
        (tintSat * 0.5).clamp(0.02, 0.06),
        0.70,
      ).toColor();

      final lnk = HSVColor.fromAHSV(1.0, (hue + 8) % 360, 0.85, 0.48).toColor();
      final lnkVis = HSVColor.fromAHSV(
        1.0,
        (hue + 28) % 360,
        0.75,
        0.42,
      ).toColor();

      return OrbitColors(
        background: bg,
        workspace: ws,
        panel: pan,
        panelSecondary: panSec,
        raised: rsd,
        floating: flt,
        input: inp,
        hover: hvr,
        pressed: prs,
        selected: sel,
        selectedMuted: selMuted,
        border: brd,
        divider: div,
        focus: accHover,
        accent: acc,
        secondary: sec,
        accentHover: accHover,
        text: txt,
        subtle: sbt,
        muted: mut,
        textDisabled: dis,
        success: const Color(0xFF16A34A),
        warning: const Color(0xFFD97706),
        danger: const Color(0xFFE11D48),
        link: lnk,
        linkVisited: lnkVis,
        canvasBackground: bg,
        canvasGrid: div,
        graphEdge: brd,
      );
    }
  }

  @override
  OrbitColors copyWith({
    Color? background,
    Color? workspace,
    Color? panel,
    Color? panelSecondary,
    Color? raised,
    Color? floating,
    Color? input,
    Color? hover,
    Color? pressed,
    Color? selected,
    Color? selectedMuted,
    Color? border,
    Color? divider,
    Color? focus,
    Color? accent,
    Color? secondary,
    Color? accentHover,
    Color? text,
    Color? subtle,
    Color? muted,
    Color? textDisabled,
    Color? success,
    Color? warning,
    Color? danger,
    Color? link,
    Color? linkVisited,
    Color? canvasBackground,
    Color? canvasGrid,
    Color? graphEdge,
  }) {
    final nextAccent = accent ?? this.accent;
    return OrbitColors(
      background: background ?? this.background,
      workspace: workspace ?? this.workspace,
      panel: panel ?? this.panel,
      panelSecondary: panelSecondary ?? this.panelSecondary,
      raised: raised ?? this.raised,
      floating: floating ?? this.floating,
      input: input ?? this.input,
      hover: hover ?? this.hover,
      pressed: pressed ?? this.pressed,
      selected: selected ?? this.selected,
      selectedMuted: selectedMuted ?? this.selectedMuted,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      focus: focus ?? this.focus,
      accent: nextAccent,
      secondary: secondary ?? this.secondary,
      accentHover:
          accentHover ??
          (accent != null
              ? Color.alphaBlend(
                  Colors.white.withValues(alpha: .12),
                  nextAccent,
                )
              : this.accentHover),
      text: text ?? this.text,
      subtle: subtle ?? this.subtle,
      muted: muted ?? this.muted,
      textDisabled: textDisabled ?? this.textDisabled,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      link: link ?? this.link,
      linkVisited: linkVisited ?? this.linkVisited,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      canvasGrid: canvasGrid ?? this.canvasGrid,
      graphEdge: graphEdge ?? this.graphEdge,
    );
  }

  @override
  OrbitColors lerp(covariant OrbitColors? other, double t) {
    if (other == null) return this;
    return OrbitColors(
      background: Color.lerp(background, other.background, t)!,
      workspace: Color.lerp(workspace, other.workspace, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelSecondary: Color.lerp(panelSecondary, other.panelSecondary, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      floating: Color.lerp(floating, other.floating, t)!,
      input: Color.lerp(input, other.input, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      selectedMuted: Color.lerp(selectedMuted, other.selectedMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      text: Color.lerp(text, other.text, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      link: Color.lerp(link, other.link, t)!,
      linkVisited: Color.lerp(linkVisited, other.linkVisited, t)!,
      canvasBackground: Color.lerp(
        canvasBackground,
        other.canvasBackground,
        t,
      )!,
      canvasGrid: Color.lerp(canvasGrid, other.canvasGrid, t)!,
      graphEdge: Color.lerp(graphEdge, other.graphEdge, t)!,
    );
  }
}

/// A structured theme pack specifying palette, typography, brightness, and corner style.
class OrbitThemePack {
  const OrbitThemePack({
    required this.id,
    required this.name,
    required this.description,
    this.brightness = Brightness.dark,
    required this.colors,
    this.fontFamily = 'Segoe UI',
    this.documentFontFamily = 'Segoe UI',
    this.monoFontFamily = 'Consolas',
    this.cornerStyle = 'rounded',
    this.familyId,
    this.category = 'Originals',
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final OrbitColors colors;
  final String fontFamily;
  final String documentFontFamily;
  final String monoFontFamily;
  final String cornerStyle;

  /// Catalog metadata; authored theme files continue to use the existing format.
  final String? familyId;
  final String category;

  OrbitThemePack? get companion {
    if (familyId == null) return null;
    for (final pack in builtIn) {
      if (pack.familyId == familyId && pack.brightness != brightness) {
        return pack;
      }
    }
    return null;
  }

  /// Resolve appearance without rewriting the saved family or user styling.
  /// Original/custom themes without a catalog pair retain their authored look.
  static OrbitThemePack forPreferences(
    AppPreferences preferences,
    Brightness platformBrightness,
  ) {
    final selected = fromId(
      preferences.themePreset,
      customPacks: preferences.customThemes,
    );
    if (!preferences.followSystemAppearance ||
        selected.brightness == platformBrightness) {
      return selected;
    }
    return selected.companion ?? selected;
  }

  /// Default Orbit Graphite + Violet theme pack
  static const orbit = OrbitThemePack(
    id: 'orbit',
    name: 'Orbit Graphite',
    description:
        'A quiet observatory for your thoughts with graphite surfaces and violet highlights.',
    brightness: Brightness.dark,
    colors: OrbitColors(),
  );

  /// Deep space near-black theme pack with cyan and indigo accents
  static const observatory = OrbitThemePack(
    id: 'observatory',
    name: 'Observatory Space',
    description:
        'Deep spatial atmosphere with stellar cyan and indigo accents.',
    brightness: Brightness.dark,
    colors: OrbitColors(
      background: Color(0xFF080B10),
      workspace: Color(0xFF0B0F16),
      panel: Color(0xFF0F151F),
      panelSecondary: Color(0xFF131A27),
      raised: Color(0xFF17202E),
      floating: Color(0xFF1C2738),
      input: Color(0xFF141C29),
      hover: Color(0xFF1E2B3E),
      pressed: Color(0xFF25354D),
      selected: Color(0xFF132B3C),
      selectedMuted: Color(0xFF10202E),
      border: Color(0xFF1E2D42),
      divider: Color(0xFF172333),
      focus: Color(0xFF22D3EE),
      accent: Color(0xFF06B6D4),
      secondary: Color(0xFF6366F1),
      accentHover: Color(0xFF22D3EE),
      text: Color(0xFFE6F1F8),
      subtle: Color(0xFF9DB8CE),
      muted: Color(0xFF627F99),
      textDisabled: Color(0xFF415668),
      success: Color(0xFF34D399),
      warning: Color(0xFFFBBF24),
      danger: Color(0xFFF87171),
      link: Color(0xFF38BDF8),
      linkVisited: Color(0xFF818CF8),
      canvasBackground: Color(0xFF080B10),
      canvasGrid: Color(0xFF1E2D42),
      graphEdge: Color(0xFF2B3F5B),
    ),
  );

  /// Warm editorial cream/parchment light theme pack
  static const paper = OrbitThemePack(
    id: 'paper',
    name: 'Paper Warm Light',
    description:
        'Warm editorial workspace on parchment and clean linen paper with rich typography.',
    brightness: Brightness.light,
    documentFontFamily: 'Georgia',
    colors: OrbitColors(
      background: Color(0xFFF7F5EE),
      workspace: Color(0xFFFDFCFA),
      panel: Color(0xFFEFECE2),
      panelSecondary: Color(0xFFE8E4D8),
      raised: Color(0xFFFFFFFF),
      floating: Color(0xFFFFFFFF),
      input: Color(0xFFFFFFFF),
      hover: Color(0xFFE5E1D4),
      pressed: Color(0xFFDDD7C8),
      selected: Color(0xFFE4DFD0),
      selectedMuted: Color(0xFFEDEAE0),
      border: Color(0xFFD6D0C0),
      divider: Color(0xFFDFD9CA),
      focus: Color(0xFF7B5233),
      accent: Color(0xFF8B5E3C),
      secondary: Color(0xFF5C7080),
      accentHover: Color(0xFF6E4A2F),
      text: Color(0xFF24211E),
      subtle: Color(0xFF5C5750),
      muted: Color(0xFF888277),
      textDisabled: Color(0xFFB0AAA0),
      success: Color(0xFF2D7D54),
      warning: Color(0xFFB46A15),
      danger: Color(0xFFC0392B),
      link: Color(0xFF20639B),
      linkVisited: Color(0xFF5B487A),
      canvasBackground: Color(0xFFF5F2E9),
      canvasGrid: Color(0xFFDDD7C8),
      graphEdge: Color(0xFFC2BCAD),
    ),
  );

  /// Pure OLED deep black high-focus theme pack
  static const midnight = OrbitThemePack(
    id: 'midnight',
    name: 'Midnight OLED',
    description:
        'Pure black OLED environment designed for deep focus and maximum contrast.',
    brightness: Brightness.dark,
    colors: OrbitColors(
      background: Color(0xFF000000),
      workspace: Color(0xFF050507),
      panel: Color(0xFF0A0A0E),
      panelSecondary: Color(0xFF101015),
      raised: Color(0xFF14141A),
      floating: Color(0xFF181822),
      input: Color(0xFF101016),
      hover: Color(0xFF1C1C26),
      pressed: Color(0xFF242432),
      selected: Color(0xFF1E1A33),
      selectedMuted: Color(0xFF161424),
      border: Color(0xFF20202C),
      divider: Color(0xFF181822),
      focus: Color(0xFFA597FB),
      accent: Color(0xFF9384FA),
      secondary: Color(0xFF38BDF8),
      accentHover: Color(0xFFA597FB),
      text: Color(0xFFF5F5F7),
      subtle: Color(0xFFA8A8B4),
      muted: Color(0xFF707080),
      textDisabled: Color(0xFF484856),
      success: Color(0xFF4ADE80),
      warning: Color(0xFFFACC15),
      danger: Color(0xFFFB7185),
      link: Color(0xFF818CF8),
      linkVisited: Color(0xFFA78BFA),
      canvasBackground: Color(0xFF000000),
      canvasGrid: Color(0xFF1A1A24),
      graphEdge: Color(0xFF2E2E3E),
    ),
  );

  /// Cool atmospheric twilight pine & emerald theme pack
  static const aurora = OrbitThemePack(
    id: 'aurora',
    name: 'Aurora Forest',
    description:
        'Cool atmospheric spruce and twilight tones with luminous mint and emerald accents.',
    brightness: Brightness.dark,
    colors: OrbitColors(
      background: Color(0xFF0A1210),
      workspace: Color(0xFF0D1714),
      panel: Color(0xFF111E1A),
      panelSecondary: Color(0xFF142420),
      raised: Color(0xFF182B26),
      floating: Color(0xFF1D332D),
      input: Color(0xFF14241F),
      hover: Color(0xFF213A33),
      pressed: Color(0xFF28463E),
      selected: Color(0xFF132F27),
      selectedMuted: Color(0xFF0F241E),
      border: Color(0xFF213932),
      divider: Color(0xFF1A2E28),
      focus: Color(0xFF34D399),
      accent: Color(0xFF10B981),
      secondary: Color(0xFF2DD4BF),
      accentHover: Color(0xFF34D399),
      text: Color(0xFFEAF5F1),
      subtle: Color(0xFFA8C7BC),
      muted: Color(0xFF6C8F83),
      textDisabled: Color(0xFF486158),
      success: Color(0xFF34D399),
      warning: Color(0xFFF59E0B),
      danger: Color(0xFFF43F5E),
      link: Color(0xFF2DD4BF),
      linkVisited: Color(0xFF14B8A6),
      canvasBackground: Color(0xFF0A1210),
      canvasGrid: Color(0xFF1D342D),
      graphEdge: Color(0xFF28483F),
    ),
  );

  /// Curated first-party palette families. The generated packs intentionally
  /// use the same semantic token contract as custom themes, so every surface
  /// (notes, canvas, graph, PDF, and shell) changes together.
  static final List<OrbitThemePack> builtIn = List.unmodifiable(
    [
      orbit,
      observatory,
      paper,
      midnight,
      aurora,
      OrbitThemePack.fromSeed(
        const Color(0xFFD08A3A),
        id: 'obsidian-ember',
        name: 'Obsidian Ember',
        description:
            'Slate surfaces, warm amber focus, and the tactile contrast of a handcrafted vault.',
        documentFontFamily: 'Georgia',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFF88C0D0),
        id: 'nord-mist',
        name: 'Nord Mist',
        description:
            'Cool blue-grey workspace with icy links and a quiet northern palette.',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFBD93F9),
        id: 'dracula-velvet',
        name: 'Dracula Velvet',
        description:
            'Deep plum graphite with expressive violet focus and readable warm text.',
        monoFontFamily: 'Consolas',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFCBA6F7),
        id: 'catppuccin-mocha',
        name: 'Catppuccin Mocha',
        description:
            'Soft mocha surfaces and pastel accents tuned for long evening sessions.',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFEBBCBA),
        id: 'rose-pine',
        name: 'Rosé Pine',
        description:
            'Muted pine, rose, and lavender tones for a calm, literary workspace.',
        documentFontFamily: 'Georgia',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFB58900),
        id: 'solarized-paper',
        name: 'Solarized Paper',
        description:
            'A warm light reading mode with carefully balanced amber and blue accents.',
        brightness: Brightness.light,
        documentFontFamily: 'Georgia',
        cornerStyle: 'subtle',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFD79921),
        id: 'gruvbox-night',
        name: 'Gruvbox Night',
        description:
            'Earthy low-light contrast with orange focus and familiar notebook warmth.',
        cornerStyle: 'subtle',
      ),
      OrbitThemePack.fromSeed(
        const Color(0xFFA8DADC),
        id: 'coastal-light',
        name: 'Coastal Light',
        description:
            'Bright sea-glass surfaces with generous contrast for daytime planning.',
        brightness: Brightness.light,
        cornerStyle: 'subtle',
      ),
      ..._additionalOrbitPalettes,
    ].map(_readableBuiltIn),
  );

  /// Older built-ins retain their surfaces and identity while their semantic
  /// foregrounds meet the same contract as the coordinated catalog. Authored
  /// custom-theme colors and explicit overrides never pass through this step.
  static OrbitThemePack _readableBuiltIn(OrbitThemePack pack) {
    final c = pack.colors;
    final surfaces = [
      c.background,
      c.workspace,
      c.panel,
      c.panelSecondary,
      c.raised,
      c.floating,
      c.input,
      c.hover,
      c.pressed,
      c.selected,
      c.selectedMuted,
    ];
    final toward = pack.brightness == Brightness.light
        ? Colors.black
        : Colors.white;
    Color ink(Color value, {double minimum = 4.5}) =>
        _paletteInk(value, surfaces, toward, minimum: minimum);
    return OrbitThemePack(
      id: pack.id,
      name: pack.name,
      description: pack.description,
      brightness: pack.brightness,
      familyId: pack.familyId,
      category: pack.category,
      fontFamily: pack.fontFamily,
      documentFontFamily: pack.documentFontFamily,
      monoFontFamily: pack.monoFontFamily,
      cornerStyle: pack.cornerStyle,
      colors: c.copyWith(
        text: ink(c.text, minimum: 7),
        subtle: ink(c.subtle),
        muted: ink(c.muted),
        accent: ink(c.accent),
        secondary: ink(c.secondary),
        accentHover: ink(c.accentHover),
        link: ink(c.link),
        linkVisited: ink(c.linkVisited),
        success: ink(c.success),
        warning: ink(c.warning),
        danger: ink(c.danger),
        focus: ink(c.focus, minimum: 3),
      ),
    );
  }

  static OrbitThemePack fromId(
    String? id, {
    List<Map<String, dynamic>> customPacks = const [],
  }) {
    if (id == null) return orbit;
    for (final pack in builtIn) {
      if (pack.id == id) return pack;
    }
    for (final map in customPacks) {
      if (map['id'] == id) {
        return OrbitThemePack.fromJson(map);
      }
    }
    return orbit;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'brightness': brightness == Brightness.light ? 'light' : 'dark',
    'fontFamily': fontFamily,
    'documentFontFamily': documentFontFamily,
    'monoFontFamily': monoFontFamily,
    'cornerStyle': cornerStyle,
    'colors': {
      for (final entry in colors.roles.entries)
        entry.key:
            '#${entry.value.toARGB32().toRadixString(16).padLeft(8, '0')}',
    },
  };

  factory OrbitThemePack.fromJson(Map<String, dynamic> json) {
    final baseId = json['id'] as String? ?? 'custom';
    final basePreset = fromId(baseId);
    final brightness = json['brightness'] == 'light'
        ? Brightness.light
        : (json['brightness'] == 'dark'
              ? Brightness.dark
              : basePreset.brightness);

    final rawColors = json['colors'];
    final overrides = <String, int>{};
    if (rawColors is Map) {
      for (final entry in rawColors.entries) {
        if (entry.key is String) {
          final c = _parseColor(entry.value);
          if (c != null) overrides[entry.key as String] = c;
        }
      }
    }

    final resolvedColors = basePreset.colors.withOverrides(overrides);

    return OrbitThemePack(
      id: baseId,
      name: (json['name'] as String?) ?? basePreset.name,
      description: (json['description'] as String?) ?? basePreset.description,
      brightness: brightness,
      colors: resolvedColors,
      fontFamily: (json['fontFamily'] as String?) ?? basePreset.fontFamily,
      documentFontFamily:
          (json['documentFontFamily'] as String?) ??
          basePreset.documentFontFamily,
      monoFontFamily:
          (json['monoFontFamily'] as String?) ?? basePreset.monoFontFamily,
      cornerStyle:
          (json['cornerStyle'] == 'subtle' || json['cornerStyle'] == 'rounded')
          ? json['cornerStyle'] as String
          : basePreset.cornerStyle,
      familyId: basePreset.familyId,
      category: basePreset.category,
    );
  }

  /// Generates a complete harmonized theme pack from a single seed color.
  factory OrbitThemePack.fromSeed(
    Color seed, {
    String? id,
    String? name,
    String? description,
    Brightness brightness = Brightness.dark,
    String cornerStyle = 'rounded',
    String fontFamily = 'Segoe UI',
    String documentFontFamily = 'Segoe UI',
    String monoFontFamily = 'Consolas',
  }) {
    final hexStr = seed
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
    final modeLabel = brightness == Brightness.light ? 'Light' : 'Dark';
    final autoId =
        id ?? 'harmonized-${hexStr.toLowerCase()}-${brightness.name}';
    final autoName = name ?? 'Harmonized $modeLabel (#$hexStr)';
    final autoDesc =
        description ??
        'Algorithmically harmonized $modeLabel theme derived from seed accent #$hexStr.';

    return OrbitThemePack(
      id: autoId,
      name: autoName,
      description: autoDesc,
      brightness: brightness,
      colors: OrbitColors.fromSeed(seed, brightness: brightness),
      fontFamily: fontFamily,
      documentFontFamily: documentFontFamily,
      monoFontFamily: monoFontFamily,
      cornerStyle: cornerStyle,
    );
  }

  static int? _parseColor(dynamic value) {
    if (value is int) {
      if (value >= 0x00000000 && value <= 0xffffffff) {
        return value < 0xff000000 ? (value | 0xff000000) : value;
      }
      return null;
    }
    if (value is String) {
      var hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
      if (hex.length == 6) hex = 'ff$hex';
      if (hex.length == 8) {
        final parsed = int.tryParse(hex, radix: 16);
        if (parsed != null && parsed >= 0x00000000 && parsed <= 0xffffffff) {
          return parsed < 0xff000000 ? (parsed | 0xff000000) : parsed;
        }
      }
    }
    return null;
  }
}

/// Device-local defaults for real code controls; local pane toggles can override.
class OrbitCodePreferences extends ThemeExtension<OrbitCodePreferences> {
  const OrbitCodePreferences({
    this.fontFamily = 'monospace',
    this.fontSize = 14,
    this.lineNumbers = true,
    this.wrap = false,
  });
  final String fontFamily;
  final double fontSize;
  final bool lineNumbers, wrap;
  static OrbitCodePreferences of(BuildContext context) =>
      Theme.of(context).extension<OrbitCodePreferences>() ??
      const OrbitCodePreferences();
  @override
  OrbitCodePreferences copyWith({
    String? fontFamily,
    double? fontSize,
    bool? lineNumbers,
    bool? wrap,
  }) => OrbitCodePreferences(
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    lineNumbers: lineNumbers ?? this.lineNumbers,
    wrap: wrap ?? this.wrap,
  );
  @override
  OrbitCodePreferences lerp(covariant OrbitCodePreferences? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// UI roles inherit the user's font family. Document typography stays in editors.
abstract final class OrbitTypography {
  static TextStyle workspaceTitle(BuildContext context) => Theme.of(
    context,
  ).textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700);

  static TextStyle pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;

  static TextStyle h1(BuildContext context) => Theme.of(
    context,
  ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700);

  static TextStyle h2(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w600);

  static TextStyle h3(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);

  static TextStyle page(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall!;

  static TextStyle section(BuildContext context) => Theme.of(
    context,
  ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600);

  static TextStyle object(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  static TextStyle bodySecondary(BuildContext context) =>
      body(context).copyWith(color: OrbitColors.of(context).subtle);

  static TextStyle secondary(BuildContext context) =>
      body(context).copyWith(color: OrbitColors.of(context).subtle);

  static TextStyle metadata(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodySmall!.copyWith(color: OrbitColors.of(context).subtle);

  static TextStyle caption(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelSmall!.copyWith(color: OrbitColors.of(context).subtle);

  static TextStyle toolbar(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w500);

  static TextStyle code(BuildContext context) =>
      body(context).copyWith(fontFamily: 'Consolas');
}

/// Color editing/recovery follows the selected family but ignores potentially
/// unreadable overrides. Unreadable imported base themes get a readable fallback.
ThemeData orbitRecoveryThemeForPreferences(
  AppPreferences preferences,
  Brightness platformBrightness,
) {
  final pack = OrbitThemePack.forPreferences(preferences, platformBrightness);
  final colors = pack.colors;
  final readable =
      OrbitContrast.ratio(colors.text, colors.panel) >= 4.5 &&
      OrbitContrast.ratio(colors.subtle, colors.panel) >= 4.5 &&
      OrbitContrast.ratio(colors.accent, colors.panel) >= 4.5;
  return orbitTheme(
    preset: readable
        ? pack.id
        : (pack.brightness == Brightness.light ? 'paper' : 'orbit'),
    fontFamily: preferences.fontFamily,
    customPacks: preferences.customThemes,
  );
}

/// Shared by the app, live preview and export so system appearance and explicit
/// user accents/overrides resolve identically everywhere.
ThemeData orbitThemeForPreferences(
  AppPreferences preferences,
  Brightness platformBrightness,
) => orbitTheme(
  preset: OrbitThemePack.forPreferences(preferences, platformBrightness).id,
  compact: preferences.compact,
  uiZoom: preferences.uiZoom,
  fontFamily: preferences.fontFamily,
  documentFontFamily: preferences.documentFontFamily,
  monoFontFamily: preferences.monoFontFamily,
  codeFontSize: preferences.codeFontSize,
  showLineNumbers: preferences.showLineNumbers,
  defaultCodeWrap: preferences.defaultCodeWrap,
  cornerStyle: preferences.cornerStyle,
  accentColor: preferences.accentColor == 'theme'
      ? null
      : OrbitColors.accentFromPreset(preferences.accentColor),
  colorOverrides: preferences.colorOverrides,
  customPacks: preferences.customThemes,
);

/// Creates a cohesive ThemeData given theme pack, typography, density, and overrides.
ThemeData orbitTheme({
  String preset = 'orbit',
  bool compact = false,
  double uiZoom = 1,
  String fontFamily = 'Segoe UI',
  String? documentFontFamily,
  String? monoFontFamily,
  double codeFontSize = 14,
  bool showLineNumbers = true,
  bool defaultCodeWrap = false,
  String cornerStyle = 'rounded',
  Color? accentColor,
  Map<String, int> colorOverrides = const {},
  List<Map<String, dynamic>> customPacks = const [],
}) {
  final pack = OrbitThemePack.fromId(preset, customPacks: customPacks);
  final isLight = pack.brightness == Brightness.light;
  final serif = const ['Times New Roman', 'Georgia'].contains(fontFamily);
  final density = OrbitDensity(compact: compact, scale: uiZoom);
  final corners = OrbitCorners.fromStyle(cornerStyle);

  final headingWeight = serif ? FontWeight.w700 : FontWeight.w600;
  final controlWeight = serif ? FontWeight.w400 : FontWeight.w500;

  var colors = pack.colors;
  if (accentColor != null) {
    final surfaces = [
      colors.background,
      colors.workspace,
      colors.panel,
      colors.panelSecondary,
      colors.raised,
      colors.floating,
      colors.input,
      colors.hover,
      colors.pressed,
      colors.selected,
      colors.selectedMuted,
    ];
    final toward = isLight ? Colors.black : Colors.white;
    final accent = _paletteInk(accentColor, surfaces, toward);
    colors = colors.copyWith(
      accent: accent,
      accentHover: _paletteInk(
        _paletteMix(accent, toward, .12),
        surfaces,
        toward,
      ),
    );
  }
  colors = colors.withOverrides(colorOverrides);

  final scheme = isLight
      ? ColorScheme(
          brightness: Brightness.light,
          primary: colors.accent,
          onPrimary: OrbitContrast.inkOn(colors.accent),
          primaryContainer: colors.selected,
          onPrimaryContainer: colors.accentHover,
          secondary: colors.secondary,
          onSecondary: OrbitContrast.inkOn(colors.secondary),
          tertiary: colors.success,
          onTertiary: OrbitContrast.inkOn(colors.success),
          secondaryContainer: colors.hover,
          onSecondaryContainer: colors.text,
          surface: colors.panel,
          onSurface: colors.text,
          onSurfaceVariant: colors.subtle,
          surfaceDim: colors.background,
          surfaceBright: colors.raised,
          surfaceContainerLowest: colors.background,
          surfaceContainerLow: colors.panel,
          surfaceContainer: colors.raised,
          surfaceContainerHigh: colors.raised,
          surfaceContainerHighest: colors.hover,
          surfaceTint: Colors.transparent,
          outline: colors.border,
          outlineVariant: colors.divider,
          error: colors.danger,
          onError: OrbitContrast.inkOn(colors.danger),
          errorContainer: colors.tinted(colors.danger),
          onErrorContainer: colors.danger,
        )
      : ColorScheme(
          brightness: Brightness.dark,
          primary: colors.accent,
          onPrimary: OrbitContrast.inkOn(colors.accent),
          primaryContainer: colors.hover,
          onPrimaryContainer: colors.accentHover,
          secondary: colors.secondary,
          onSecondary: OrbitContrast.inkOn(colors.secondary),
          tertiary: colors.success,
          onTertiary: OrbitContrast.inkOn(colors.success),
          secondaryContainer: colors.hover,
          onSecondaryContainer: colors.text,
          surface: colors.panel,
          onSurface: colors.text,
          onSurfaceVariant: colors.subtle,
          surfaceDim: colors.background,
          surfaceBright: colors.hover,
          surfaceContainerLowest: colors.background,
          surfaceContainerLow: colors.panel,
          surfaceContainer: colors.raised,
          surfaceContainerHigh: colors.raised,
          surfaceContainerHighest: colors.hover,
          surfaceTint: Colors.transparent,
          outline: colors.border,
          outlineVariant: colors.divider,
          error: colors.danger,
          onError: OrbitContrast.inkOn(colors.danger),
          errorContainer: colors.tinted(colors.danger),
          onErrorContainer: colors.danger,
        );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(corners.control),
  );
  final floatingShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(corners.dialog),
    side: BorderSide(color: colors.border),
  );

  final controlOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return Colors.transparent;
    }
    if (states.contains(WidgetState.focused)) {
      return colors.focus.withValues(alpha: .20);
    }
    if (states.contains(WidgetState.pressed)) {
      return colors.text.withValues(alpha: .10);
    }
    if (states.contains(WidgetState.hovered)) {
      return colors.text.withValues(alpha: .05);
    }
    return null;
  });

  BorderSide controlBorder(Set<WidgetState> states) => BorderSide(
    color: states.contains(WidgetState.focused) ? colors.focus : colors.border,
  );

  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(corners.control),
    borderSide: BorderSide(color: color),
  );

  final labelStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: controlWeight,
    letterSpacing: 0,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: pack.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.panel,
    cardColor: colors.raised,
    fontFamily: fontFamily,
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: headingWeight,
        letterSpacing: serif ? 0 : -.8,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: headingWeight,
        letterSpacing: serif ? 0 : -.6,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: headingWeight,
        letterSpacing: serif ? 0 : -.4,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: headingWeight,
        letterSpacing: serif ? 0 : -.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: headingWeight,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: headingWeight,
        letterSpacing: 0,
      ),
      bodyLarge: const TextStyle(fontSize: 15, height: 1.5, letterSpacing: 0),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
      bodySmall: const TextStyle(fontSize: 12, height: 1.4, letterSpacing: 0),
      labelLarge: labelStyle,
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: controlWeight,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: controlWeight,
        letterSpacing: .1,
      ),
    ).apply(bodyColor: colors.text, displayColor: colors.text),
    extensions: [
      colors,
      density,
      corners,
      OrbitCodePreferences(
        fontFamily: monoFontFamily ?? pack.monoFontFamily,
        fontSize: codeFontSize.isFinite ? codeFontSize.clamp(10.0, 26.0) : 14.0,
        lineNumbers: showLineNumbers,
        wrap: defaultCodeWrap,
      ),
    ],
    visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    dividerColor: colors.border,
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
    splashFactory: NoSplash.splashFactory,
    hoverColor: colors.hover,
    focusColor: colors.focus.withValues(alpha: .18),
    disabledColor: colors.muted,
    iconTheme: IconThemeData(color: colors.subtle, size: density.icon),
    appBarTheme: AppBarThemeData(
      backgroundColor: colors.workspace,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colors.text,
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: controlWeight,
        letterSpacing: -.1,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: compact ? 64 : 72,
      indicatorColor: colors.selected,
      indicatorShape: controlShape,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          color: colors.subtle,
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: controlWeight,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.panel,
      indicatorColor: colors.selected,
      indicatorShape: controlShape,
      selectedIconTheme: IconThemeData(color: colors.accentHover),
      unselectedIconTheme: IconThemeData(color: colors.subtle),
      selectedLabelTextStyle: TextStyle(
        color: colors.accentHover,
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: controlWeight,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colors.subtle,
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: controlWeight,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.panel,
      modalBarrierColor: Colors.black.withValues(alpha: .45),
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(corners.dialog),
        ),
        side: BorderSide(color: colors.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.border,
      circularTrackColor: colors.border,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: .28),
      selectionHandleColor: colors.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.floating,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(corners.control),
      ),
      textStyle: labelStyle.copyWith(color: colors.text, fontSize: 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.input,
      border: inputBorder(colors.border),
      enabledBorder: inputBorder(colors.border),
      focusedBorder: inputBorder(colors.focus),
      errorBorder: inputBorder(colors.danger),
      focusedErrorBorder: inputBorder(colors.danger),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: labelStyle,
      hintStyle: TextStyle(
        color: colors.subtle,
        fontSize: 13,
        fontFamily: fontFamily,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style:
          IconButton.styleFrom(
            minimumSize: Size.square(density.smallControl),
            foregroundColor: colors.subtle,
            disabledForegroundColor: colors.muted.withValues(alpha: .5),
            shape: controlShape,
          ).copyWith(
            overlayColor: controlOverlay,
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.selected
                  : null,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? colors.muted.withValues(alpha: .5)
                  : states.contains(WidgetState.selected)
                  ? colors.accentHover
                  : colors.subtle,
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.subtle,
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
        minimumSize: Size(64, density.controlHeight),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            shape: controlShape,
            foregroundColor: colors.text,
            backgroundColor: colors.panel,
            textStyle: labelStyle,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: Size(64, density.controlHeight),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(controlBorder),
            overlayColor: controlOverlay,
          ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: controlShape,
        side: BorderSide(color: colors.border),
        backgroundColor: colors.panel,
        foregroundColor: colors.subtle,
        selectedBackgroundColor: colors.selected,
        selectedForegroundColor: colors.accentHover,
        textStyle: labelStyle,
      ).copyWith(overlayColor: controlOverlay),
    ),
    chipTheme: ChipThemeData(
      shape: controlShape,
      side: BorderSide(color: colors.border),
      backgroundColor: colors.panel,
      selectedColor: colors.selected,
      checkmarkColor: colors.accentHover,
      labelStyle: labelStyle.copyWith(color: colors.subtle, fontSize: 12),
      secondaryLabelStyle: labelStyle.copyWith(
        color: colors.accentHover,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: colors.muted, width: 1.5),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.border,
      thumbColor: colors.accent,
      overlayColor: colors.accent.withValues(alpha: .16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(colors.border),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent.withValues(
                alpha: states.contains(WidgetState.disabled) ? .12 : .25,
              )
            : colors.raised,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.muted
            : states.contains(WidgetState.selected)
            ? colors.accent
            : colors.subtle,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.subtle,
      textColor: colors.text,
      selectedColor: colors.accentHover,
      selectedTileColor: colors.selected,
      minVerticalPadding: 8,
      shape: controlShape,
    ),
    cardTheme: CardThemeData(
      color: colors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.card),
        side: BorderSide(color: colors.border),
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
        (states) => colors.subtle.withValues(
          alpha: states.contains(WidgetState.dragged)
              ? .65
              : states.contains(WidgetState.hovered)
              ? .45
              : .22,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.floating,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: .4),
      shape: floatingShape,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: colors.panel,
      headerForegroundColor: colors.text,
      shape: floatingShape,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.menu),
        side: BorderSide(color: colors.border),
      ),
      color: colors.floating,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: states.contains(WidgetState.disabled)
              ? colors.muted
              : colors.text,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.floating),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(controlShape),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.raised,
      contentTextStyle: labelStyle.copyWith(color: colors.text),
      actionTextColor: colors.accentHover,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(corners.control),
        side: BorderSide(color: colors.border),
      ),
    ),
  );
}

/// Backwards-compatible signature for dark themes.
ThemeData orbitDarkTheme({
  String preset = 'orbit',
  bool compact = false,
  double uiZoom = 1,
  String fontFamily = 'Segoe UI',
  String? documentFontFamily,
  String? monoFontFamily,
  String cornerStyle = 'rounded',
  Color? accentColor,
  Map<String, int> colorOverrides = const {},
}) => orbitTheme(
  preset: preset,
  compact: compact,
  uiZoom: uiZoom,
  fontFamily: fontFamily,
  documentFontFamily: documentFontFamily,
  monoFontFamily: monoFontFamily,
  cornerStyle: cornerStyle,
  accentColor: accentColor,
  colorOverrides: colorOverrides,
);
