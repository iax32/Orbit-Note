import 'package:flutter/material.dart';
import '../domain/json_values.dart';
import 'app_preferences.dart';
import 'orbit_theme.dart';

/// MaterialApp must receive the same theme object when only navigation, save,
/// clock or sync state changes. Newly allocated equivalent theme extensions
/// otherwise restart AnimatedTheme and repaint every saved Canvas layer.
class OrbitThemeCache {
  List<Object?>? _inputs;
  ThemeData? _theme;
  ThemeData resolve(AppPreferences p, Brightness platform) {
    final next = <Object?>[
      p.themePreset,
      p.followSystemAppearance,
      p.followSystemAppearance ? platform : null,
      p.compact,
      p.uiZoom,
      p.fontFamily,
      p.documentFontFamily,
      p.monoFontFamily,
      p.codeFontSize,
      p.showLineNumbers,
      p.defaultCodeWrap,
      p.cornerStyle,
      p.accentColor,
      p.colorOverrides,
      p.customThemes,
    ];
    if (_theme != null && jsonValuesEqual(next, _inputs)) return _theme!;
    _inputs = next.map(_snapshot).toList(growable: false);
    return _theme = orbitThemeForPreferences(p, platform);
  }

  static Object? _snapshot(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key: _snapshot(entry.value),
      };
    }
    if (value is List) return value.map(_snapshot).toList(growable: false);
    return value;
  }
}
