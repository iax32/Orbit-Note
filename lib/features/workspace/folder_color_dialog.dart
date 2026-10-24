import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_density.dart';
import '../../app/orbit_theme.dart';

/// Modal dialog allowing users to assign an individual accent color to a
/// folder or note, with curated harmonized swatches, custom hex input,
/// live Explorer row preview, and reset/clear capabilities.
Future<Color?> showFolderColorDialog(
  BuildContext context, {
  required String folderName,
  bool isNote = false,
  Color? currentColor,
  void Function(Color? color)? onColorSelected,
  bool Function(Color? color)? onCommit,
}) async {
  return showDialog<Color?>(
    context: context,
    builder: (dialogCtx) => _FolderColorDialogContent(
      folderName: folderName,
      isNote: isNote,
      currentColor: currentColor,
      onColorSelected: onColorSelected,
      onCommit: onCommit,
    ),
  );
}

class _FolderColorDialogContent extends StatefulWidget {
  const _FolderColorDialogContent({
    required this.folderName,
    required this.isNote,
    required this.currentColor,
    required this.onColorSelected,
    required this.onCommit,
  });

  final String folderName;
  final bool isNote;
  final Color? currentColor;
  final void Function(Color? color)? onColorSelected;
  final bool Function(Color? color)? onCommit;

  @override
  State<_FolderColorDialogContent> createState() =>
      _FolderColorDialogContentState();
}

class _FolderColorDialogContentState extends State<_FolderColorDialogContent> {
  static const Map<String, Color> presetColors = {
    'Violet': Color(0xFF8B7CF6),
    'Indigo': Color(0xFF6366F1),
    'Sapphire': Color(0xFF3B82F6),
    'Cyan': Color(0xFF06B6D4),
    'Teal': Color(0xFF14B8A6),
    'Emerald': Color(0xFF10B981),
    'Amber': Color(0xFFF59E0B),
    'Orange': Color(0xFFF97316),
    'Coral': Color(0xFFFF6B6B),
    'Rose': Color(0xFFF43F5E),
    'Lavender': Color(0xFFA78BFA),
    'Slate': Color(0xFF64748B),
  };

  late Color? _selectedColor;
  late final TextEditingController _hexController;
  String? _hexError;
  String? _commitIssue;
  bool _submitted = false;

  void _commit(Color? color) {
    if (!mounted || _submitted) return;
    if (widget.onCommit?.call(color) == false) {
      setState(
        () => _commitIssue =
            'This item changed or is no longer editable. Your color choice is retained; cancel and reopen to review it.',
      );
      return;
    }
    widget.onColorSelected?.call(color);
    _submitted = true;
    Navigator.of(context).pop(color);
  }

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
    final hexString = widget.currentColor != null
        ? widget.currentColor!
              .toARGB32()
              .toRadixString(16)
              .padLeft(8, '0')
              .substring(2)
              .toUpperCase()
        : '';
    _hexController = TextEditingController(text: hexString);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _onHexChanged(String value) {
    final trimmed = value.trim();
    final clean = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
    if (clean.isEmpty) {
      setState(() {
        _hexError = null;
        _selectedColor = null;
      });
      return;
    }
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(clean)) {
      final parsed = int.tryParse('FF$clean', radix: 16);
      if (parsed != null) {
        setState(() {
          _hexError = null;
          _selectedColor = Color(parsed);
        });
        return;
      }
    }
    setState(() {
      _hexError = 'Invalid hex (e.g. 8B7CF6)';
    });
  }

  void _selectPreset(Color color) {
    setState(() {
      _selectedColor = color;
      _hexError = null;
      _hexController.text = color
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final density = OrbitDensity.of(context);

    return OrbitDialog(
      key: const ValueKey('folder-color-dialog'),
      title: Row(
        children: [
          Icon(
            widget.isNote ? Icons.description_outlined : Icons.folder_outlined,
            size: 20,
            color: _selectedColor ?? colors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isNote ? 'Note Color Accent' : 'Folder Color Identity',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isNote
                    ? 'Assign a subtle accent color to “${widget.folderName}”.'
                    : 'Assign a subtle accent color to “${widget.folderName}”. Contained notes and subfolders inherit this context cue in the Explorer.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'HARMONIC PALETTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in presetColors.entries)
                    Tooltip(
                      message: entry.key,
                      child: InkWell(
                        key: ValueKey(
                          'folder-color-swatch-${entry.key.toLowerCase()}',
                        ),
                        onTap: () => _selectPreset(entry.value),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  _selectedColor?.toARGB32() ==
                                      entry.value.toARGB32()
                                  ? OrbitContrast.inkOn(entry.value)
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (_selectedColor?.toARGB32() ==
                                  entry.value.toARGB32())
                                BoxShadow(
                                  color: entry.value.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child:
                              _selectedColor?.toARGB32() ==
                                  entry.value.toARGB32()
                              ? Center(
                                  child: Icon(
                                    Icons.check,
                                    size: 16,
                                    color: OrbitContrast.inkOn(entry.value),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTOM HEX CODE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('folder-color-hex-field'),
                          controller: _hexController,
                          onChanged: _onHexChanged,
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '# ',
                            prefixStyle: TextStyle(
                              color: colors.muted,
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.w600,
                            ),
                            hintText: '8B7CF6',
                            errorText: _hexError,
                            filled: true,
                            fillColor: colors.input,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                OrbitRadius.control,
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                OrbitRadius.control,
                              ),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                OrbitRadius.control,
                              ),
                              borderSide: BorderSide(
                                color: colors.accent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _selectedColor ?? colors.panelSecondary,
                        borderRadius: BorderRadius.circular(
                          OrbitRadius.control,
                        ),
                        border: Border.all(color: colors.border),
                      ),
                      child: _selectedColor == null
                          ? Center(
                              child: Icon(
                                Icons.format_color_reset,
                                size: 16,
                                color: colors.muted,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'LIVE EXPLORER PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(OrbitRadius.panel),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    // Target Row Preview
                    Container(
                      height:
                          density.controlHeight +
                          (MediaQuery.textScalerOf(context).scale(13) - 13)
                              .clamp(0, 100),
                      decoration: BoxDecoration(
                        color: _selectedColor != null
                            ? Color.alphaBlend(
                                _selectedColor!.withValues(alpha: 0.12),
                                colors.selected,
                              )
                            : colors.selected,
                        borderRadius: BorderRadius.circular(
                          OrbitRadius.control,
                        ),
                        border: Border.all(
                          color: _selectedColor != null
                              ? Colors.transparent
                              : colors.accent.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (_selectedColor != null)
                            Positioned(
                              left: 0,
                              top: 3,
                              bottom: 3,
                              width: 2.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Icon(
                                  widget.isNote
                                      ? Icons.description_outlined
                                      : Icons.expand_more,
                                  size: 16,
                                  color: _selectedColor ?? colors.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.folderName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isNote) ...[
                      const SizedBox(height: 4),
                      // Child note preview with inherited cue
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Container(
                          height:
                              density.controlHeight -
                              2 +
                              (MediaQuery.textScalerOf(context).scale(12) - 12)
                                  .clamp(0, 100),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              OrbitRadius.control,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (_selectedColor != null)
                                Positioned(
                                  left: 0,
                                  top: 3,
                                  bottom: 3,
                                  width: 2.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _selectedColor,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 15,
                                      color: _selectedColor ?? colors.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Child Note (inherits accent)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Subtle left edge accent & icon tint without overwhelming the reading area.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: colors.muted,
                ),
              ),
              if (_commitIssue != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_commitIssue!),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.currentColor != null || _selectedColor != null)
          TextButton.icon(
            key: const ValueKey('folder-color-clear-button'),
            onPressed: () => _commit(null),
            icon: const Icon(Icons.format_color_reset_outlined, size: 16),
            label: const Text('Reset color'),
          ),
        TextButton(
          key: const ValueKey('folder-color-cancel-button'),
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('folder-color-apply-button'),
          onPressed: _hexError != null ? null : () => _commit(_selectedColor),
          child: const Text('Apply Color'),
        ),
      ],
    );
  }
}
