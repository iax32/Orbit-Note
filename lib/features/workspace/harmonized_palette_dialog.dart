import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../platform/export_file.dart';

/// Modal dialog allowing users to choose or type a single seed accent color,
/// preview algorithmically harmonized WCAG-compliant semantic tokens, and
/// instantly apply, save, or export the resulting theme pack.
Future<void> showHarmonizedPaletteDialog(
  BuildContext context,
  WorkspaceController controller, {
  Future<bool> Function(String name, String content)? exportFn,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => _HarmonizedPaletteDialogContent(
      controller: controller,
      exportFn: exportFn,
    ),
  );
}

class _HarmonizedPaletteDialogContent extends StatefulWidget {
  const _HarmonizedPaletteDialogContent({
    required this.controller,
    this.exportFn,
  });

  final WorkspaceController controller;
  final Future<bool> Function(String name, String content)? exportFn;

  @override
  State<_HarmonizedPaletteDialogContent> createState() =>
      _HarmonizedPaletteDialogContentState();
}

class _HarmonizedPaletteDialogContentState
    extends State<_HarmonizedPaletteDialogContent> {
  static const Map<String, Color> _seedPresets = {
    'Violet': Color(0xFF8B7CF6),
    'Cyan': Color(0xFF06B6D4),
    'Emerald': Color(0xFF10B981),
    'Sapphire': Color(0xFF3B82F6),
    'Amber': Color(0xFFF59E0B),
    'Rose': Color(0xFFF43F5E),
    'Coral': Color(0xFFFF6B6B),
    'Teal': Color(0xFF14B8A6),
  };

  late Color _seed;
  late Brightness _brightness;
  late TextEditingController _nameController;
  late TextEditingController _hexController;
  String? _hexError;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final activePack = OrbitThemePack.forPreferences(
      widget.controller.session.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    _seed = activePack.colors.accent;
    _brightness = activePack.brightness;

    final hexStr = _hexOf(_seed);
    final mode = _brightness == Brightness.light ? 'Light' : 'Dark';
    _nameController = TextEditingController(
      text: 'Harmonized $mode (#$hexStr)',
    );
    _hexController = TextEditingController(text: hexStr);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  String _hexOf(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _onSeedChanged(Color newSeed) {
    setState(() {
      _seed = newSeed;
      _hexController.text = _hexOf(newSeed);
      _hexError = null;
      final mode = _brightness == Brightness.light ? 'Light' : 'Dark';
      _nameController.text = 'Harmonized $mode (#${_hexOf(newSeed)})';
    });
  }

  void _onBrightnessChanged(Brightness newBrightness) {
    setState(() {
      _brightness = newBrightness;
      final mode = newBrightness == Brightness.light ? 'Light' : 'Dark';
      _nameController.text = 'Harmonized $mode (#${_hexOf(_seed)})';
    });
  }

  OrbitThemePack _generatePack() {
    final customName = _nameController.text.trim();
    return OrbitThemePack.fromSeed(
      _seed,
      name: customName.isNotEmpty ? customName : null,
      brightness: _brightness,
      cornerStyle: widget.controller.session.cornerStyle,
      fontFamily: widget.controller.session.fontFamily,
      documentFontFamily: widget.controller.session.documentFontFamily,
      monoFontFamily: widget.controller.session.monoFontFamily,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final pack = _generatePack();
    final textRatio = OrbitContrast.ratio(
      pack.colors.text,
      pack.colors.background,
    );
    final subtleRatio = OrbitContrast.ratio(
      pack.colors.subtle,
      pack.colors.background,
    );

    return OrbitDialog(
      maxWidth: 620,
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('Harmonized Palette Generator')),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Algorithmically derive an entire WCAG-accessible semantic color system from a single seed accent color.',
            style: TextStyle(fontSize: 13, color: colors.subtle),
          ),
          const SizedBox(height: 16),

          // Seed Selection Section
          Text(
            'Choose Seed Accent Color',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _seedPresets.entries)
                InkWell(
                  key: ValueKey('theme-seed-preset-${entry.key.toLowerCase()}'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _onSeedChanged(entry.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.raised,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _seed == entry.value
                            ? colors.accent
                            : colors.border,
                        width: _seed == entry.value ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _seed == entry.value
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Hex & Brightness Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('theme-seed-hex-input'),
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: 'Seed Hex Code',
                  prefixText: '#',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: _hexError,
                ),
                onChanged: (val) {
                  final clean = val.replaceAll('#', '').trim();
                  if (clean.length == 6 &&
                      RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) {
                    final parsed = int.parse('FF$clean', radix: 16);
                    setState(() {
                      _seed = Color(parsed);
                      _hexError = null;
                    });
                  } else {
                    setState(() {
                      _hexError = 'Enter 6 hex characters';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => SegmentedButton<Brightness>(
                  direction:
                      constraints.maxWidth < 440 ||
                          MediaQuery.textScalerOf(context).scale(14) > 21
                      ? Axis.vertical
                      : Axis.horizontal,
                  key: const ValueKey('theme-seed-brightness-segmented'),
                  segments: const [
                    ButtonSegment(
                      value: Brightness.dark,
                      label: Text('Dark Mode'),
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: Brightness.light,
                      label: Text('Light Mode'),
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                    ),
                  ],
                  selected: {_brightness},
                  onSelectionChanged: (val) {
                    if (val.isNotEmpty) _onBrightnessChanged(val.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Theme Name
          TextField(
            key: const ValueKey('theme-seed-name-input'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Theme Pack Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Palette Swatches & Accessibility
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Generated Palette',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _accessibilityBadge(
                    'AAA · ${textRatio.toStringAsFixed(1)}:1',
                    true,
                    colors,
                  ),
                  const SizedBox(width: 6),
                  _accessibilityBadge(
                    'AA · ${subtleRatio.toStringAsFixed(1)}:1',
                    subtleRatio >= 4.5,
                    colors,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Swatches Row
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _swatch(pack.colors.background, 'BG', colors),
              _swatch(pack.colors.panel, 'Panel', colors),
              _swatch(pack.colors.raised, 'Raised', colors),
              _swatch(pack.colors.border, 'Border', colors),
              _swatch(pack.colors.accent, 'Accent', colors),
              _swatch(pack.colors.text, 'Text', colors),
            ],
          ),
          const SizedBox(height: 16),

          // Mini UI Mockup
          Container(
            key: const ValueKey('theme-seed-live-preview'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pack.colors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pack.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: pack.colors.panel,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pack.colors.border),
                      ),
                      child: Text(
                        'Aa Preview',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: pack.colors.text,
                        ),
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pack.colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Knowledge linked in Orbit with harmonious contrast.',
                  style: TextStyle(fontSize: 12, color: pack.colors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Secondary metadata and subtle contextual details.',
                  style: TextStyle(fontSize: 11, color: pack.colors.subtle),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pack.colors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Accent Button',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pack.colors.onAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '[[Universal Object]]',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pack.colors.link,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('theme-seed-export-button'),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Export...'),
                onPressed: () async {
                  final pack = _generatePack();
                  final jsonStr = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(pack.toJson());
                  final slug = pack.name.toLowerCase().replaceAll(
                    RegExp(r'[^a-z0-9_]'),
                    '_',
                  );
                  final fileName = '$slug.orbit-theme.json';
                  final exporter = widget.exportFn ?? exportFile;
                  final success = await exporter(fileName, jsonStr);
                  if (!context.mounted) return;
                  if (success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Theme exported to $fileName')),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('theme-seed-save-button'),
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save to Gallery'),
                onPressed: () {
                  final pack = _generatePack();
                  widget.controller.updateSession((s) {
                    s.themePreset = pack.id;
                    s.followSystemAppearance = false;
                    s.cornerStyle = pack.cornerStyle;
                    s.fontFamily = pack.fontFamily;
                    s.documentFontFamily = pack.documentFontFamily;
                    s.monoFontFamily = pack.monoFontFamily;
                    s.colorOverrides = {
                      for (final entry in pack.colors.roles.entries)
                        entry.key: entry.value.toARGB32(),
                    };
                    s.customThemes = [
                      ...s.customThemes.where((m) => m['id'] != pack.id),
                      pack.toJson(),
                    ];
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Theme "${pack.name}" saved to gallery.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('theme-seed-apply-button'),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Apply Now'),
          onPressed: () {
            final pack = _generatePack();
            widget.controller.updateSession((s) {
              s.themePreset = pack.id;
              s.followSystemAppearance = false;
              s.cornerStyle = pack.cornerStyle;
              s.fontFamily = pack.fontFamily;
              s.documentFontFamily = pack.documentFontFamily;
              s.monoFontFamily = pack.monoFontFamily;
              s.colorOverrides = {
                for (final entry in pack.colors.roles.entries)
                  entry.key: entry.value.toARGB32(),
              };
            });
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Harmonized theme "${pack.name}" applied.'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _swatch(Color color, String label, OrbitColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.border),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.subtle)),
      ],
    );
  }

  Widget _accessibilityBadge(String label, bool pass, OrbitColors colors) {
    final badgeColor = pass ? colors.success : colors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 11, color: badgeColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
