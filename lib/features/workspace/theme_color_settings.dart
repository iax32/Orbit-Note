import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import 'harmonized_palette_dialog.dart';
import 'theme_interchange_dialog.dart';

/// Live interactive preview card displaying typography, colors, button styles, and corner radius.
class LiveThemePreviewCard extends StatelessWidget {
  const LiveThemePreviewCard({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final corners = OrbitCorners.of(context);
    final s = controller.session;

    return Container(
      key: const ValueKey('theme-live-preview'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.workspace,
        borderRadius: BorderRadius.circular(corners.card),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fake window chrome
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(corners.card),
              ),
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Orbit Observatory · ${s.themePreset.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.subtle,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz, size: 14, color: colors.subtle),
              ],
            ),
          ),

          // Main preview content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Aa Heading',
                      style: OrbitTypography.pageTitle(context).copyWith(
                        fontFamily: s.documentFontFamily,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.selected,
                        borderRadius: BorderRadius.circular(corners.small),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        s.cornerStyle == 'subtle'
                            ? 'Subtle 4px'
                            : 'Rounded 8px',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colors.accentHover,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                    style: OrbitTypography.body(context).copyWith(
                      fontFamily: s.documentFontFamily,
                      color: colors.text,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Orbit is a quiet observatory for your thoughts. Link knowledge to ',
                      ),
                      TextSpan(
                        text: '[[Universal Knowledge]]',
                        style: TextStyle(
                          color: colors.link,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(
                        text: ' and personalize your working environment.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.star, size: 14),
                      label: const Text('Primary Action'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.accent.computeLuminance() > 0.35
                            ? Colors.black
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(corners.control),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_outline, size: 14),
                      label: const Text('Secondary Tag'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.text,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(corners.control),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.raised,
                        borderRadius: BorderRadius.circular(corners.control),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        'code.fn()',
                        style: TextStyle(
                          fontFamily: s.monoFontFamily,
                          fontSize: 12,
                          color: colors.accentHover,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector for first-party theme packs.
class ThemePresetSelector extends StatelessWidget {
  const ThemePresetSelector({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final activeId = controller.session.themePreset;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final pack in OrbitThemePack.builtIn)
          InkWell(
            key: ValueKey('theme-preset-${pack.id}'),
            borderRadius: BorderRadius.circular(OrbitRadius.card),
            onTap: () => controller.updateSession((s) {
              s.themePreset = pack.id;
              s.fontFamily = pack.fontFamily;
              s.documentFontFamily = pack.documentFontFamily;
              s.monoFontFamily = pack.monoFontFamily;
              s.cornerStyle = pack.cornerStyle;
            }),
            child: AnimatedContainer(
              duration: OrbitMotion.control,
              width: 172,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pack.colors.panel,
                borderRadius: BorderRadius.circular(OrbitRadius.card),
                border: Border.all(
                  color: activeId == pack.id ? colors.accent : colors.border,
                  width: activeId == pack.id ? 2 : 1,
                ),
                boxShadow: activeId == pack.id
                    ? [
                        BoxShadow(
                          color: colors.accent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 34,
                      child: Stack(
                        children: [
                          ColoredBox(color: pack.colors.background),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 26,
                            child: ColoredBox(color: pack.colors.panel),
                          ),
                          Positioned(
                            left: 34,
                            right: 0,
                            top: 0,
                            height: 7,
                            child: ColoredBox(color: pack.colors.raised),
                          ),
                          Positioned(
                            left: 40,
                            right: 34,
                            top: 16,
                            height: 3,
                            child: ColoredBox(color: pack.colors.accent),
                          ),
                          Positioned(
                            left: 40,
                            right: 58,
                            top: 25,
                            height: 3,
                            child: ColoredBox(color: pack.colors.subtle),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: pack.colors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: activeId == pack.id
                            ? const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pack.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: activeId == pack.id
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: pack.colors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pack.description,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: pack.colors.subtle,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Swatch row
                  Row(
                    children: [
                      _miniSwatch(pack.colors.background),
                      const SizedBox(width: 4),
                      _miniSwatch(pack.colors.panel),
                      const SizedBox(width: 4),
                      _miniSwatch(pack.colors.raised),
                      const SizedBox(width: 4),
                      _miniSwatch(pack.colors.accent),
                      const SizedBox(width: 4),
                      _miniSwatch(pack.colors.secondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _miniSwatch(Color c) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
    );
  }
}

/// Selector for Corner Style (Rounded vs Subtle).
class CornerStyleSelector extends StatelessWidget {
  const CornerStyleSelector({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final style = controller.session.cornerStyle;
    return LayoutBuilder(
      builder: (context, constraints) => SegmentedButton<String>(
        direction:
            constraints.maxWidth < 440 ||
                MediaQuery.textScalerOf(context).scale(14) > 21
            ? Axis.vertical
            : Axis.horizontal,
        key: const ValueKey('settings-corner-style'),
        segments: const [
          ButtonSegment(
            value: 'rounded',
            label: Text('Rounded (8px)'),
            icon: Icon(Icons.rounded_corner_outlined, size: 16),
          ),
          ButtonSegment(
            value: 'subtle',
            label: Text('Subtle (4px)'),
            icon: Icon(Icons.crop_square_outlined, size: 16),
          ),
        ],
        selected: {style},
        onSelectionChanged: (val) {
          if (val.isNotEmpty) {
            controller.updateSession((s) => s.cornerStyle = val.first);
          }
        },
      ),
    );
  }
}

/// Token-based custom color editor for advanced workspace ownership.
class ThemeColorSettings extends StatelessWidget {
  const ThemeColorSettings({super.key, required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final overrides = controller.session.colorOverrides;
    // Recovery controls stay readable even with an unreadable custom palette.
    return Theme(
      data: orbitDarkTheme(fontFamily: controller.session.fontFamily),
      child: Material(
        color: const OrbitColors().panel,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ExpansionTile(
            key: const ValueKey('settings-custom-colors'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Customize interface colors'),
            subtitle: Text(
              '${overrides.length} custom colors · changes save locally',
            ),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Choose colors for shared UI elements. Document ink, PDF paper tones and individual canvas objects keep their own colors.',
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final role in OrbitColors.roleLabels.entries)
                    OutlinedButton.icon(
                      key: ValueKey('theme-color-${role.key}'),
                      icon: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: colors.roles[role.key],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xffb6b2c2)),
                        ),
                      ),
                      label: Text(
                        '${role.value}${overrides.containsKey(role.key) ? ' •' : ''}',
                      ),
                      onPressed: () async {
                        final result = await showDialog<_ColorChoice>(
                          context: context,
                          builder: (_) => Theme(
                            data: orbitDarkTheme(
                              fontFamily: controller.session.fontFamily,
                            ),
                            child: _ColorEditor(
                              label: role.value,
                              initial: colors.roles[role.key]!,
                            ),
                          ),
                        );
                        if (result == null) return;
                        controller.updateSession((s) {
                          final next = Map<String, int>.from(s.colorOverrides);
                          if (result.color == null) {
                            next.remove(role.key);
                          } else {
                            next[role.key] = result.color!.toARGB32();
                          }
                          s.colorOverrides = next;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Theme packs', style: OrbitTypography.metadata(context)),
              const SizedBox(height: 8),
              ThemePresetSelector(controller: controller),
              const SizedBox(height: 14),
              Text('Corner style', style: OrbitTypography.metadata(context)),
              const SizedBox(height: 8),
              CornerStyleSelector(controller: controller),
              const SizedBox(height: 14),
              LiveThemePreviewCard(controller: controller),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('theme-gallery-button'),
                    icon: const Icon(
                      Icons.collections_bookmark_outlined,
                      size: 16,
                    ),
                    label: const Text('Theme Gallery...'),
                    onPressed: () =>
                        showOrbitThemeGalleryDialog(context, controller),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('theme-generate-palette-button'),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Generate from Seed...'),
                    onPressed: () =>
                        showHarmonizedPaletteDialog(context, controller),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('theme-export-button'),
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Export Theme...'),
                    onPressed: () =>
                        showOrbitThemeExportDialog(context, controller),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('theme-import-button'),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Import Theme...'),
                    onPressed: () =>
                        showOrbitThemeImportDialog(context, controller),
                  ),
                  TextButton.icon(
                    key: const ValueKey('theme-colors-reset'),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset all custom colors'),
                    onPressed: overrides.isEmpty
                        ? null
                        : () => controller.updateSession(
                            (s) => s.colorOverrides = {},
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorChoice {
  const _ColorChoice(this.color);
  final Color? color;
}

class _ColorEditor extends StatefulWidget {
  const _ColorEditor({required this.label, required this.initial});
  final String label;
  final Color initial;
  @override
  State<_ColorEditor> createState() => _ColorEditorState();
}

class _ColorEditorState extends State<_ColorEditor> {
  late HSVColor _hsv;
  late TextEditingController _hex;
  String? _error;
  String hex(Color color) =>
      color.toARGB32().toRadixString(16).substring(2).toUpperCase();
  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
    _hex = TextEditingController(text: hex(widget.initial));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void setColor(HSVColor color) => setState(() {
    _hsv = color;
    _hex.text = hex(color.toColor());
    _error = null;
  });
  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final foreground = color.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(16),
      actionsOverflowButtonSpacing: 8,
      title: Text(widget.label),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Aa  ·  ${hex(color)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: foreground, fontSize: 24),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('theme-color-hex'),
              controller: _hex,
              decoration: InputDecoration(
                labelText: 'Hex color',
                prefixText: '#',
                errorText: _error,
              ),
              onChanged: (value) {
                final cleaned = value.trim().replaceFirst('#', '');
                final valid = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned);
                setState(() {
                  _error = valid ? null : 'Enter six hexadecimal characters';
                  if (valid) {
                    _hsv = HSVColor.fromColor(
                      Color(0xff000000 | int.parse(cleaned, radix: 16)),
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            for (final item
                in <(String, double, double, void Function(double))>[
                  ('Hue', _hsv.hue, 360, (v) => setColor(_hsv.withHue(v))),
                  (
                    'Saturation',
                    _hsv.saturation,
                    1,
                    (v) => setColor(_hsv.withSaturation(v)),
                  ),
                  (
                    'Brightness',
                    _hsv.value,
                    1,
                    (v) => setColor(_hsv.withValue(v)),
                  ),
                ]) ...[
              Align(alignment: Alignment.centerLeft, child: Text(item.$1)),
              Slider(value: item.$2, max: item.$3, onChanged: item.$4),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in [
                  ...OrbitColors.accentPresets.values,
                  Colors.white,
                  Colors.black,
                ])
                  IconButton(
                    tooltip: '#${hex(swatch)}',
                    icon: Icon(Icons.circle, color: swatch),
                    onPressed: () => setColor(HSVColor.fromColor(swatch)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const _ColorChoice(null)),
          child: const Text('Use default'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('theme-color-apply'),
          onPressed: _error == null
              ? () => Navigator.pop(context, _ColorChoice(color))
              : null,
          child: const Text('Apply color'),
        ),
      ],
    );
  }
}
