import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';

/// The saved palette remains the family anchor. Turning automatic appearance off
/// pins the currently visible member, avoiding an unexpected color change.
class SystemAppearanceSetting extends StatefulWidget {
  const SystemAppearanceSetting({
    super.key,
    required this.controller,
    this.onChanged,
  });
  final WorkspaceController controller;
  final VoidCallback? onChanged;

  @override
  State<SystemAppearanceSetting> createState() =>
      _SystemAppearanceSettingState();
}

class _SystemAppearanceSettingState extends State<SystemAppearanceSetting> {
  @override
  Widget build(BuildContext context) {
    final s = widget.controller.session;
    final selected = OrbitThemePack.fromId(
      s.themePreset,
      customPacks: s.customThemes,
    );
    final effective = OrbitThemePack.forPreferences(
      s.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    final companion = selected.companion;
    final light = selected.brightness == Brightness.light
        ? selected
        : companion;
    final dark = selected.brightness == Brightness.dark ? selected : companion;
    return SwitchListTile.adaptive(
      key: const ValueKey('settings-follow-system-appearance'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Follow system appearance'),
      subtitle: Text(
        companion == null
            ? 'Choose a paired palette family in Theme packs or Theme Gallery to switch automatically. Keeping ${effective.name}.'
            : '${light!.name} / ${dark!.name}. Now: ${effective.name}. Choosing a palette manually turns this off.',
      ),
      value: s.followSystemAppearance,
      onChanged: companion != null || s.followSystemAppearance
          ? (value) {
              widget.controller.updateSession((session) {
                session.followSystemAppearance = value;
                if (!value && companion != null) {
                  session.themePreset = effective.id;
                }
              });
              setState(() {});
              widget.onChanged?.call();
            }
          : null,
    );
  }
}
