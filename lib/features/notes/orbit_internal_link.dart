import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import '../../domain/wiki_links.dart';
import '../../domain/backlinks.dart';

/// Interactive internal link widget following Orbit's "make the content itself interactive" invariant.
///
/// Features:
/// - Text-first rendering with restrained violet accent and smooth hover underline.
/// - 300ms hover delay peek preview ([OrbitPeekCard]) with 200ms grace period.
/// - Desktop modifiers:
///   - Normal click: open in current pane.
///   - Ctrl+Click / Cmd+Click: open in new tab.
///   - Middle click: open in new tab.
///   - Right click: desktop context menu with Open, Open in New Tab, Open to Right,
///     Copy Link, Show Backlinks, Reveal in Explorer.
///   - Keyboard focusable (Tab, Enter, Ctrl+Enter, Shift+F10 / context menu).
class OrbitInternalLink extends StatefulWidget {
  const OrbitInternalLink({
    super.key,
    required this.text,
    required this.href,
    required this.onOpen,
    this.style,
    this.allObjects = const [],
    this.linkTargets = const [],
    this.onOpenInNewTab,
    this.onOpenToSide,
    this.onShowBacklinks,
    this.onRevealInExplorer,
  });

  final String text;
  final String href;
  final TextStyle? style;
  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onOpenInNewTab;
  final ValueChanged<String>? onOpenToSide;
  final ValueChanged<String>? onShowBacklinks;
  final ValueChanged<String>? onRevealInExplorer;
  final List<UniversalObject> allObjects;
  final List<NoteLinkTarget> linkTargets;

  @override
  State<OrbitInternalLink> createState() => _OrbitInternalLinkState();
}

class _OrbitInternalLinkState extends State<OrbitInternalLink> {
  bool _isHovered = false;
  bool _isFocused = false;
  Timer? _peekTimer;
  Timer? _dismissTimer;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();

  bool get _isMissing => widget.href.startsWith('orbit-missing:');
  bool get _isAmbiguous => widget.href.startsWith('orbit-ambiguous:');
  bool get _isExternal =>
      widget.href.startsWith('http://') ||
      widget.href.startsWith('https://') ||
      widget.href.startsWith('mailto:');

  @override
  void dispose() {
    _peekTimer?.cancel();
    _dismissTimer?.cancel();
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _peekTimer?.cancel();
    _dismissTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _schedulePeek() {
    _dismissTimer?.cancel();
    _peekTimer?.cancel();
    _peekTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _isHovered && _overlayEntry == null) {
        _showPeekOverlay();
      }
    });
  }

  void _scheduleDismiss() {
    _peekTimer?.cancel();
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        _removeOverlay();
      }
    });
  }

  void _showPeekOverlay() {
    if (_overlayEntry != null || !mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final linkRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const cardWidth = 350.0;
    const estimatedHeight = 190.0;

    // Flip above link if near bottom of screen
    final showAbove =
        linkRect.bottom + estimatedHeight + 16 > screenSize.height &&
        linkRect.top > estimatedHeight + 16;
    final top = showAbove
        ? linkRect.top - estimatedHeight - 6
        : linkRect.bottom + 6;
    final left = (linkRect.left)
        .clamp(12.0, math.max(12.0, screenSize.width - cardWidth - 12.0))
        .toDouble();

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Dismiss on pointer down outside
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _removeOverlay(),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            child: MouseRegion(
              onEnter: (_) {
                _dismissTimer?.cancel();
              },
              onExit: (_) {
                _scheduleDismiss();
              },
              child: OrbitPeekCard(
                href: widget.href,
                label: widget.text,
                allObjects: widget.allObjects,
                linkTargets: widget.linkTargets,
                onOpen: (target) {
                  _removeOverlay();
                  widget.onOpen(target);
                },
                onOpenInNewTab: (target) {
                  _removeOverlay();
                  if (widget.onOpenInNewTab != null) {
                    widget.onOpenInNewTab!(target);
                  } else {
                    widget.onOpen(target);
                  }
                },
                onClose: _removeOverlay,
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _handleTap() {
    _removeOverlay();
    final keyboard = HardwareKeyboard.instance;
    final isCommand = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (isCommand && widget.onOpenInNewTab != null) {
      widget.onOpenInNewTab!(widget.href);
    } else {
      widget.onOpen(widget.href);
    }
  }

  void _handleTertiaryTap() {
    _removeOverlay();
    if (widget.onOpenInNewTab != null) {
      widget.onOpenInNewTab!(widget.href);
    } else {
      widget.onOpen(widget.href);
    }
  }

  Future<void> _showContextMenu(Offset globalPosition) async {
    _removeOverlay();
    final colors = OrbitColors.of(context);
    final targetId = _extractTargetId(widget.href);

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
      items: [
        PopupMenuItem<String>(
          value: 'open',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              const Expanded(child: Text('Open')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'open_tab',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.tab_outlined, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              const Expanded(child: Text('Open in new tab')),
            ],
          ),
        ),
        if (!_isExternal)
          PopupMenuItem<String>(
            value: 'open_side',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.vertical_split_outlined,
                  size: 16,
                  color: colors.subtle,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Open to the right')),
              ],
            ),
          ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<String>(
          value: 'copy',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.copy_outlined, size: 16, color: colors.subtle),
              const SizedBox(width: 10),
              const Expanded(child: Text('Copy link')),
            ],
          ),
        ),
        if (!_isExternal && targetId.isNotEmpty) ...[
          PopupMenuItem<String>(
            value: 'backlinks',
            height: 36,
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 16, color: colors.subtle),
                const SizedBox(width: 10),
                const Expanded(child: Text('Show backlinks')),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'explorer',
            height: 36,
            child: Row(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 16,
                  color: colors.subtle,
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Reveal in Explorer')),
              ],
            ),
          ),
        ],
      ],
    );

    if (!mounted || result == null) return;

    switch (result) {
      case 'open':
        widget.onOpen(widget.href);
      case 'open_tab':
        if (widget.onOpenInNewTab != null) {
          widget.onOpenInNewTab!(widget.href);
        } else {
          widget.onOpen(widget.href);
        }
      case 'open_side':
        if (widget.onOpenToSide != null) {
          widget.onOpenToSide!(widget.href);
        } else {
          widget.onOpen(widget.href);
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: widget.href));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      case 'backlinks':
        widget.onShowBacklinks?.call(targetId);
      case 'explorer':
        widget.onRevealInExplorer?.call(targetId);
    }
  }

  String _extractTargetId(String href) {
    if (href.startsWith('orbit-object:')) {
      final raw = href.substring('orbit-object:'.length);
      final hashIndex = raw.indexOf('#');
      return hashIndex >= 0 ? raw.substring(0, hashIndex) : raw;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkColor = _isMissing || _isAmbiguous
        ? OrbitColors.of(context).warning
        : theme.colorScheme.primary;

    final effectiveStyle = (widget.style ?? const TextStyle()).copyWith(
      color: linkColor,
      fontWeight: FontWeight.w500,
      decoration: _isHovered || _isFocused
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationColor: linkColor.withValues(alpha: _isHovered ? 0.9 : 0.4),
      decorationStyle: _isMissing
          ? TextDecorationStyle.dashed
          : TextDecorationStyle.solid,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        label: '${widget.text}, internal link',
        link: true,
        button: true,
        child: Focus(
          focusNode: _focusNode,
          onFocusChange: (f) => setState(() => _isFocused = f),
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent) {
              final keyboard = HardwareKeyboard.instance;
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                if (keyboard.isControlPressed || keyboard.isMetaPressed) {
                  if (widget.onOpenInNewTab != null) {
                    widget.onOpenInNewTab!(widget.href);
                  } else {
                    widget.onOpen(widget.href);
                  }
                } else {
                  widget.onOpen(widget.href);
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  (event.logicalKey == LogicalKeyboardKey.f10 &&
                      keyboard.isShiftPressed)) {
                final box = context.findRenderObject() as RenderBox?;
                if (box != null) {
                  final pos = box.localToGlobal(
                    Offset(box.size.width / 2, box.size.height),
                  );
                  _showContextMenu(pos);
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.escape &&
                  _overlayEntry != null) {
                _removeOverlay();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              setState(() => _isHovered = true);
              _schedulePeek();
            },
            onExit: (_) {
              setState(() => _isHovered = false);
              _scheduleDismiss();
            },
            child: GestureDetector(
              onTap: _handleTap,
              onTertiaryTapUp: (_) => _handleTertiaryTap(),
              onSecondaryTapUp: (details) =>
                  _showContextMenu(details.globalPosition),
              child: AnimatedContainer(
                duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? linkColor.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(widget.text, style: effectiveStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rich peek card displayed when hovering over a link for 300ms.
class OrbitPeekCard extends StatelessWidget {
  const OrbitPeekCard({
    super.key,
    required this.href,
    required this.label,
    required this.onOpen,
    required this.onOpenInNewTab,
    required this.onClose,
    this.allObjects = const [],
    this.linkTargets = const [],
  });

  final String href;
  final String label;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onOpenInNewTab;
  final VoidCallback onClose;
  final List<UniversalObject> allObjects;
  final List<NoteLinkTarget> linkTargets;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);

    // Resolve target object if any
    final (resolvedObject, resolvedBadge, resolvedIcon, isMissing, isExternal) =
        _resolveObject();

    final title = resolvedObject?.title.isNotEmpty == true
        ? resolvedObject!.title
        : (label.isNotEmpty ? label : 'Untitled');
    final folder = resolvedObject?.properties['folder'] as String?;
    final backlinkCount = resolvedObject != null
        ? findLinkedMentions(
            targetId: resolvedObject.id,
            objects: allObjects,
            targets: linkTargets,
          ).length
        : 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 350,
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: colors.floating,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
          boxShadow: OrbitDepth.floating,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.raised,
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Icon(resolvedIcon, size: 16, color: colors.accent),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        resolvedBadge.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    if (folder != null && folder.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          folder,
                          style: TextStyle(fontSize: 11, color: colors.subtle),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (backlinkCount > 0)
                      Tooltip(
                        message: '$backlinkCount backlinks',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.hub_outlined,
                              size: 12,
                              color: colors.subtle,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$backlinkCount',
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.subtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Title and Snippet
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _buildContentSnippet(
                      colors,
                      resolvedObject,
                      isMissing,
                      isExternal,
                    ),
                  ],
                ),
              ),

              // Footer Action Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => onOpen(href),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 13),
                      label: Text(isMissing ? 'Create' : 'Open'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => onOpenInNewTab(href),
                      icon: const Icon(Icons.tab_outlined, size: 13),
                      label: const Text('New tab'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Ctrl+Click',
                      style: TextStyle(fontSize: 10, color: colors.subtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentSnippet(
    OrbitColors colors,
    UniversalObject? obj,
    bool isMissing,
    bool isExternal,
  ) {
    if (isMissing) {
      return Text(
        'This note does not exist yet. Click to create and link it immediately.',
        style: TextStyle(
          fontSize: 12,
          color: colors.subtle,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    if (isExternal) {
      return Text(
        href,
        style: TextStyle(fontSize: 12, color: colors.subtle),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (obj == null) {
      return Text(
        'Reference: $href',
        style: TextStyle(fontSize: 12, color: colors.subtle),
      );
    }

    if (obj.typeId == 'orbit.task') {
      final completed = obj.properties['completed'] == true;
      final priority = obj.properties['priority'] as String?;
      final dueDate = obj.properties['dueDate'] as String?;
      return Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: completed ? colors.success : colors.subtle,
          ),
          const SizedBox(width: 6),
          Text(
            completed ? 'Completed' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              color: completed ? colors.success : colors.subtle,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (priority != null) ...[
            const SizedBox(width: 10),
            Text(
              '•  Priority: $priority',
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
          ],
          if (dueDate != null) ...[
            const SizedBox(width: 10),
            Text(
              '•  Due: $dueDate',
              style: TextStyle(fontSize: 11, color: colors.subtle),
            ),
          ],
        ],
      );
    }

    if (obj.typeId == 'orbit.canvas') {
      final elements = (obj.data['elements'] as List?)?.length ?? 0;
      return Text(
        elements > 0
            ? '$elements visual diagram elements on board'
            : 'Visual diagram board',
        style: TextStyle(fontSize: 12, color: colors.subtle),
      );
    }

    final cleanBody = _stripMarkdown(obj.body);
    if (cleanBody.isEmpty) {
      return Text(
        'Empty note',
        style: TextStyle(
          fontSize: 12,
          color: colors.subtle,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      cleanBody,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: colors.subtle, height: 1.4),
    );
  }

  (UniversalObject?, String, IconData, bool, bool) _resolveObject() {
    if (href.startsWith('orbit-missing:')) {
      return (null, 'Unresolved', Icons.add_circle_outline, true, false);
    }
    if (href.startsWith('orbit-ambiguous:')) {
      return (null, 'Ambiguous', Icons.help_outline, false, false);
    }
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return (null, 'Web Link', Icons.public, false, true);
    }

    String targetId = '';
    if (href.startsWith('orbit-object:')) {
      final raw = href.substring('orbit-object:'.length);
      final hash = raw.indexOf('#');
      targetId = Uri.decodeComponent(hash >= 0 ? raw.substring(0, hash) : raw);
    } else {
      targetId = href;
    }

    UniversalObject? obj;
    for (final o in allObjects) {
      if (o.id == targetId && !o.isDeleted) {
        obj = o;
        break;
      }
    }

    if (obj == null) {
      // Check linkTargets by id or title
      for (final t in linkTargets) {
        if (t.id == targetId || t.title.toLowerCase() == label.toLowerCase()) {
          for (final o in allObjects) {
            if (o.id == t.id && !o.isDeleted) {
              obj = o;
              break;
            }
          }
          break;
        }
      }
    }

    if (obj == null) {
      return (null, 'Reference', Icons.link, false, false);
    }

    final badge = switch (obj.typeId) {
      'orbit.note' => 'Note',
      'orbit.canvas' => 'Canvas',
      'orbit.file' =>
        (obj.properties['mimeType'] == 'application/pdf') ? 'PDF' : 'File',
      'orbit.task' => 'Task',
      'orbit.project' => 'Project',
      'orbit.latex' => 'LaTeX',
      'orbit.event' => 'Event',
      'orbit.view' => 'View',
      _ => 'Object',
    };

    final icon = switch (obj.typeId) {
      'orbit.note' => Icons.description_outlined,
      'orbit.canvas' => Icons.gesture_outlined,
      'orbit.file' =>
        (obj.properties['mimeType'] == 'application/pdf')
            ? Icons.picture_as_pdf_outlined
            : Icons.attach_file_outlined,
      'orbit.task' => Icons.check_circle_outline,
      'orbit.project' => Icons.folder_special_outlined,
      'orbit.latex' => Icons.functions_outlined,
      'orbit.event' => Icons.event_outlined,
      'orbit.view' => Icons.dashboard_outlined,
      _ => Icons.article_outlined,
    };

    return (obj, badge, icon, false, false);
  }

  String _stripMarkdown(String md) {
    var text = md.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    text = text.replaceAll(RegExp(r'~~([^~]+)~~'), r'$1');
    text = text.replaceAll(RegExp(r'==([^=]+)=='), r'$1');
    text = text.replaceAll(
      RegExp(r'\[\[([^|\]]+)(?:\|([^\]]+))?\]\]'),
      r'$2$1',
    );
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    text = text.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Markdown element builder for inline `<a>` tags in Read and Split modes.
class OrbitLinkElementBuilder extends MarkdownElementBuilder {
  OrbitLinkElementBuilder({
    required this.onOpen,
    required this.allObjects,
    required this.linkTargets,
    this.onOpenInNewTab,
    this.onOpenToSide,
    this.onShowBacklinks,
    this.onRevealInExplorer,
  });

  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onOpenInNewTab;
  final ValueChanged<String>? onOpenToSide;
  final ValueChanged<String>? onShowBacklinks;
  final ValueChanged<String>? onRevealInExplorer;
  final List<UniversalObject> allObjects;
  final List<NoteLinkTarget> linkTargets;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final href = element.attributes['href'] ?? '';
    final text = element.textContent;
    return OrbitInternalLink(
      text: text,
      href: href,
      onOpen: onOpen,
      onOpenInNewTab: onOpenInNewTab,
      onOpenToSide: onOpenToSide,
      onShowBacklinks: onShowBacklinks,
      onRevealInExplorer: onRevealInExplorer,
      allObjects: allObjects,
      linkTargets: linkTargets,
      style: preferredStyle ?? parentStyle,
    );
  }
}
