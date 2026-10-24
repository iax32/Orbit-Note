import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/workspace_controller.dart';
import '../../platform/export_file.dart';
import 'harmonized_palette_dialog.dart';
import 'theme_palette_browser.dart';
import 'system_appearance_setting.dart';

/// Action dialog allowing users to configure and export their current customized
/// semantic theme tokens to a standalone `.orbit-theme.json` file.
Future<void> showOrbitThemeExportDialog(
  BuildContext context,
  WorkspaceController controller, {
  Future<bool> Function(String name, String content)? exportFn,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) =>
        _OrbitThemeExportContent(controller: controller, exportFn: exportFn),
  );
}

/// Action dialog allowing users to pick and import a `.orbit-theme.json` file,
/// preview the imported tokens and geometry, and apply it to their workspace session.
Future<void> showOrbitThemeImportDialog(
  BuildContext context,
  WorkspaceController controller, {
  Future<XFile?> Function()? openFileFn,
  String? directJsonContent,
}) async {
  String? content = directJsonContent;
  if (content == null) {
    final picker =
        openFileFn ??
        () => openFile(
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Orbit Theme', extensions: ['json']),
          ],
        );
    final file = await picker();
    if (file == null) return;
    content = await file.readAsString();
  }

  Map<String, dynamic> json;
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    json = decoded;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse theme: invalid JSON file.'),
        ),
      );
    }
    return;
  }

  final pack = OrbitThemePack.fromJson(json);

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) =>
        _OrbitThemeImportPreviewContent(controller: controller, pack: pack),
  );
}

class _OrbitThemeExportContent extends StatefulWidget {
  const _OrbitThemeExportContent({required this.controller, this.exportFn});

  final WorkspaceController controller;
  final Future<bool> Function(String name, String content)? exportFn;

  @override
  State<_OrbitThemeExportContent> createState() =>
      _OrbitThemeExportContentState();
}

class _OrbitThemeExportContentState extends State<_OrbitThemeExportContent> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isExporting = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final basePreset = OrbitThemePack.forPreferences(
      widget.controller.session.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    final isCustom = widget.controller.session.colorOverrides.isNotEmpty;
    _nameController = TextEditingController(
      text: isCustom ? '${basePreset.name} (Custom)' : basePreset.name,
    );
    _descController = TextEditingController(text: basePreset.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final s = widget.controller.session;
    final basePreset = OrbitThemePack.forPreferences(
      s.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    final effectiveColors = orbitThemeForPreferences(
      s.preferences,
      MediaQuery.platformBrightnessOf(context),
    ).extension<OrbitColors>()!;

    return OrbitDialog(
      maxWidth: 520,
      title: const Row(
        children: [
          Icon(Icons.palette_outlined, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('Export Theme')),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Package your workspace color palette, typography and corner geometry into a standalone .orbit-theme.json file.',
            style: TextStyle(fontSize: 13, color: colors.subtle),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('theme-export-name-input'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Theme Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('theme-export-desc-input'),
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Included Palette & Specs',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _swatch(effectiveColors.background, 'Background', colors),
              _swatch(effectiveColors.panel, 'Panel', colors),
              _swatch(effectiveColors.raised, 'Raised', colors),
              _swatch(effectiveColors.accent, 'Accent', colors),
              _swatch(effectiveColors.text, 'Text', colors),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _specBadge(
                basePreset.brightness == Brightness.light ? 'Light' : 'Dark',
                Icons.brightness_6_outlined,
                colors,
              ),
              _specBadge(
                s.cornerStyle == 'subtle' ? 'Subtle (4px)' : 'Rounded (8px)',
                Icons.rounded_corner,
                colors,
              ),
              _specBadge(
                s.documentFontFamily,
                Icons.font_download_outlined,
                colors,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('theme-export-confirm-button'),
          icon: const Icon(Icons.file_upload_outlined, size: 16),
          label: const Text('Export (.orbit-theme.json)'),
          onPressed: _isExporting
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _isExporting = true);

                  final pack = OrbitThemePack(
                    id: 'custom-${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-')}',
                    name: name,
                    description: _descController.text.trim(),
                    brightness: basePreset.brightness,
                    colors: effectiveColors,
                    fontFamily: s.fontFamily,
                    documentFontFamily: s.documentFontFamily,
                    monoFontFamily: s.monoFontFamily,
                    cornerStyle: s.cornerStyle,
                  );

                  final jsonString = const JsonEncoder.withIndent(
                    '  ',
                  ).convert(pack.toJson());
                  final slug = name.toLowerCase().replaceAll(
                    RegExp(r'[^a-z0-9_]'),
                    '_',
                  );
                  final fileName = '$slug.orbit-theme.json';

                  final exporter = widget.exportFn ?? exportFile;
                  final success = await exporter(fileName, jsonString);

                  if (!context.mounted) return;
                  Navigator.of(context).pop();

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Theme "$name" exported to $fileName'),
                      ),
                    );
                  }
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
          width: 48,
          height: 28,
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

  Widget _specBadge(String label, IconData icon, OrbitColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.subtle),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitThemeImportPreviewContent extends StatefulWidget {
  const _OrbitThemeImportPreviewContent({
    required this.controller,
    required this.pack,
  });

  final WorkspaceController controller;
  final OrbitThemePack pack;

  @override
  State<_OrbitThemeImportPreviewContent> createState() =>
      _OrbitThemeImportPreviewContentState();
}

class _OrbitThemeImportPreviewContentState
    extends State<_OrbitThemeImportPreviewContent> {
  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final p = widget.pack;

    return OrbitDialog(
      maxWidth: 520,
      title: Row(
        children: [
          const Icon(Icons.color_lens_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Import: ${p.name}')),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.description.isNotEmpty) ...[
            Text(
              p.description,
              style: TextStyle(fontSize: 13, color: colors.subtle),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Theme Palette Preview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _swatch(p.colors.background, 'Background', colors),
              _swatch(p.colors.panel, 'Panel', colors),
              _swatch(p.colors.raised, 'Raised', colors),
              _swatch(p.colors.accent, 'Accent', colors),
              _swatch(p.colors.text, 'Text', colors),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _specBadge(
                p.brightness == Brightness.light ? 'Light theme' : 'Dark theme',
                Icons.brightness_6_outlined,
                colors,
              ),
              _specBadge(
                p.cornerStyle == 'subtle' ? 'Subtle (4px)' : 'Rounded (8px)',
                Icons.rounded_corner,
                colors,
              ),
              _specBadge(
                p.documentFontFamily,
                Icons.font_download_outlined,
                colors,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: colors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Applying this theme updates workspace colors, typography, and corner style immediately.',
                    style: TextStyle(fontSize: 11.5, color: colors.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('theme-import-apply-button'),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Apply Theme'),
          onPressed: () {
            widget.controller.updateSession((s) {
              s.themePreset = p.id;
              s.followSystemAppearance = false;
              s.cornerStyle = p.cornerStyle;
              s.fontFamily = p.fontFamily;
              s.documentFontFamily = p.documentFontFamily;
              s.monoFontFamily = p.monoFontFamily;
              s.colorOverrides = {
                for (final entry in p.colors.roles.entries)
                  entry.key: entry.value.toARGB32(),
              };
              final isBuiltIn = OrbitThemePack.builtIn.any((b) => b.id == p.id);
              if (!isBuiltIn) {
                s.customThemes = [
                  ...s.customThemes.where((m) => m['id'] != p.id),
                  p.toJson(),
                ];
              }
            });

            Navigator.of(context).pop();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Theme "${p.name}" applied successfully.'),
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
          width: 48,
          height: 28,
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

  Widget _specBadge(String label, IconData icon, OrbitColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.subtle),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action dialog displaying all installed built-in and imported custom theme packs,
/// with capabilities to preview palettes and specs, activate themes, rename custom packs,
/// and remove custom packs.
Future<void> showOrbitThemeGalleryDialog(
  BuildContext context,
  WorkspaceController controller, {
  Future<XFile?> Function()? openFileFn,
  Future<bool> Function(String name, String content)? exportFn,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => _OrbitThemeGalleryContent(
      controller: controller,
      openFileFn: openFileFn,
      exportFn: exportFn,
    ),
  );
}

class _OrbitThemeGalleryContent extends StatefulWidget {
  const _OrbitThemeGalleryContent({
    required this.controller,
    this.openFileFn,
    this.exportFn,
  });

  final WorkspaceController controller;
  final Future<XFile?> Function()? openFileFn;
  final Future<bool> Function(String name, String content)? exportFn;

  @override
  State<_OrbitThemeGalleryContent> createState() =>
      _OrbitThemeGalleryContentState();
}

class _OrbitThemeGalleryContentState extends State<_OrbitThemeGalleryContent> {
  Future<void> _renameTheme(OrbitThemePack pack) async {
    final textController = TextEditingController(text: pack.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (promptCtx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(16),
        actionsOverflowButtonSpacing: 8,
        title: const Text('Rename Theme'),
        content: TextField(
          key: const ValueKey('theme-rename-input'),
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Theme Name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(promptCtx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(promptCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('theme-rename-confirm-button'),
            onPressed: () =>
                Navigator.of(promptCtx).pop(textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != pack.name) {
      widget.controller.updateSession((s) {
        final updated = <Map<String, dynamic>>[];
        for (final item in s.customThemes) {
          if (item['id'] == pack.id) {
            final m = Map<String, dynamic>.from(item);
            m['name'] = newName;
            updated.add(m);
          } else {
            updated.add(item);
          }
        }
        s.customThemes = updated;
      });
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteTheme(OrbitThemePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.all(16),
        actionsOverflowButtonSpacing: 8,
        title: const Text('Delete Theme'),
        content: Text('Are you sure you want to delete "${pack.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('theme-delete-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: OrbitColors.of(confirmCtx).danger,
            ),
            onPressed: () => Navigator.of(confirmCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.controller.updateSession((s) {
        s.customThemes = s.customThemes
            .where((m) => m['id'] != pack.id)
            .toList();
        if (s.themePreset == pack.id) {
          final fallback = OrbitThemePack.orbit;
          s.themePreset = fallback.id;
          s.followSystemAppearance = false;
          s.cornerStyle = fallback.cornerStyle;
          s.fontFamily = fallback.fontFamily;
          s.documentFontFamily = fallback.documentFontFamily;
          s.monoFontFamily = fallback.monoFontFamily;
          s.colorOverrides = {};
        }
      });
      if (mounted) setState(() {});
    }
  }

  void _applyTheme(OrbitThemePack pack) {
    widget.controller.updateSession((s) {
      s.themePreset = pack.id;
      s.followSystemAppearance = false;
      s.accentColor = 'theme';
      if (pack.familyId == null) {
        s.cornerStyle = pack.cornerStyle;
        s.fontFamily = pack.fontFamily;
        s.documentFontFamily = pack.documentFontFamily;
        s.monoFontFamily = pack.monoFontFamily;
      }
      s.colorOverrides = {...s.colorOverrides}
        ..removeWhere((key, _) => OrbitColors.roleLabels.containsKey(key));
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final s = widget.controller.session;
    final activeId = OrbitThemePack.forPreferences(
      s.preferences,
      MediaQuery.platformBrightnessOf(context),
    ).id;

    final builtInIds = OrbitThemePack.builtIn.map((p) => p.id).toSet();
    final customPacks = <OrbitThemePack>[];
    for (final raw in s.customThemes) {
      try {
        final p = OrbitThemePack.fromJson(raw);
        if (!builtInIds.contains(p.id)) {
          customPacks.add(p);
        }
      } catch (_) {}
    }

    final allPacks = [...customPacks, ...OrbitThemePack.builtIn];

    return OrbitDialog(
      maxWidth: 620,
      title: const Row(
        children: [
          Icon(Icons.collections_bookmark_outlined, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('Theme Gallery')),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Explore built-in palettes and imported custom themes. Apply any theme instantly or manage custom themes.',
            style: TextStyle(fontSize: 13, color: colors.subtle),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('theme-gallery-generate-button'),
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Generate...'),
                onPressed: () async {
                  await showHarmonizedPaletteDialog(
                    context,
                    widget.controller,
                    exportFn: widget.exportFn,
                  );
                  if (mounted) setState(() {});
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('theme-gallery-import-button'),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Import Theme...'),
                onPressed: () async {
                  await showOrbitThemeImportDialog(
                    context,
                    widget.controller,
                    openFileFn: widget.openFileFn,
                  );
                  if (mounted) setState(() {});
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('theme-gallery-export-button'),
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Export Active...'),
                onPressed: () async {
                  await showOrbitThemeExportDialog(
                    context,
                    widget.controller,
                    exportFn: widget.exportFn,
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SystemAppearanceSetting(
            controller: widget.controller,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 12),
          ThemePaletteBrowser(
            packs: allPacks,
            activeId: activeId,
            grid: false,
            onApply: _applyTheme,
            categoryOf: (pack) =>
                builtInIds.contains(pack.id) ? pack.category : 'My themes',
            itemBuilder: (pack, width, active, apply) => SizedBox(
              width: width,
              child: _themeCard(
                pack,
                colors,
                active,
                !builtInIds.contains(pack.id),
              ),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const ValueKey('theme-gallery-close-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _themeCard(
    OrbitThemePack pack,
    OrbitColors colors,
    bool isActive,
    bool isCustom,
  ) {
    return Container(
      key: ValueKey('theme-gallery-card-${pack.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(OrbitRadius.card),
        border: Border.all(
          color: isActive ? colors.accent : colors.border,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: pack.colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pack.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: colors.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCustom
                      ? colors.accent.withValues(alpha: 0.12)
                      : colors.raised,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCustom
                        ? colors.accent.withValues(alpha: 0.3)
                        : colors.border,
                  ),
                ),
                child: Text(
                  isCustom ? 'CUSTOM' : 'BUILT-IN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isCustom ? colors.accent : colors.subtle,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check,
                        size: 11,
                        color: OrbitContrast.inkOn(colors.accent),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: OrbitContrast.inkOn(colors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (pack.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pack.description,
              style: TextStyle(fontSize: 11.5, color: colors.subtle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _swatchDot(pack.colors.background, colors),
              const SizedBox(width: 4),
              _swatchDot(pack.colors.panel, colors),
              const SizedBox(width: 4),
              _swatchDot(pack.colors.raised, colors),
              const SizedBox(width: 4),
              _swatchDot(pack.colors.accent, colors),
              const SizedBox(width: 4),
              _swatchDot(pack.colors.text, colors),
              _cardBadge(
                pack.brightness == Brightness.light ? 'Light' : 'Dark',
                Icons.brightness_6_outlined,
                colors,
              ),
              const SizedBox(width: 6),
              _cardBadge(
                pack.cornerStyle == 'subtle' ? 'Subtle (4px)' : 'Rounded (8px)',
                Icons.rounded_corner,
                colors,
              ),
              const SizedBox(width: 6),
              _cardBadge(
                pack.documentFontFamily,
                Icons.font_download_outlined,
                colors,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isCustom) ...[
                TextButton.icon(
                  key: ValueKey('theme-gallery-rename-${pack.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Rename'),
                  onPressed: () => _renameTheme(pack),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  key: ValueKey('theme-gallery-delete-${pack.id}'),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  onPressed: () => _deleteTheme(pack),
                ),
                const SizedBox(width: 6),
              ],
              if (!isActive)
                FilledButton.icon(
                  key: ValueKey('theme-gallery-apply-${pack.id}'),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Apply'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => _applyTheme(pack),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatchDot(Color c, OrbitColors colors) {
    return Container(
      width: 24,
      height: 18,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: colors.border, width: 0.8),
      ),
    );
  }

  Widget _cardBadge(String label, IconData icon, OrbitColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.subtle),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 10.5, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}
