import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';

/// One action menu shared by the visible button, right click and Shift+F10.
class OrbitExplorerRow extends StatefulWidget {
  const OrbitExplorerRow({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    required this.menu,
    this.selected = false,
    this.multiSelected = false,
    this.onExpand,
    this.onCollapse,
  });
  final Widget leading, title;
  final VoidCallback onTap;
  final PopupMenuButton<String> menu;
  final bool selected;
  final bool multiSelected;
  final VoidCallback? onExpand, onCollapse;
  @override
  State<OrbitExplorerRow> createState() => _OrbitExplorerRowState();
}

class _OrbitExplorerRowState extends State<OrbitExplorerRow> {
  final _menu = GlobalKey<PopupMenuButtonState<String>>();
  final _focus = FocusNode();
  bool _focused = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (widget.menu.enabled) _menu.currentState?.showButtonMenu();
  }

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return Semantics(
      selected: widget.selected,
      child: Focus(
        focusNode: _focus,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent || !_focus.hasPrimaryFocus) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
              event.logicalKey == LogicalKeyboardKey.f10 &&
                  HardwareKeyboard.instance.isShiftPressed) {
            _openMenu();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              widget.onExpand != null) {
            widget.onExpand!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.onCollapse != null) {
            widget.onCollapse!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onSecondaryTapUp: (_) {
            _focus.requestFocus();
            _openMenu();
          },
          child: AnimatedContainer(
            duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              border: Border.all(
                color: _focused
                    ? c.accent.withValues(alpha: .6)
                    : Colors.transparent,
              ),
            ),
            child: Material(
              color: widget.multiSelected
                  ? c.accent.withValues(alpha: .22)
                  : (widget.selected ? c.selected : Colors.transparent),
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              child: InkWell(
                canRequestFocus: false,
                splashFactory: NoSplash.splashFactory,
                borderRadius: BorderRadius.circular(OrbitRadius.control),
                hoverColor: c.hover,
                onTap: () {
                  _focus.requestFocus();
                  widget.onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: widget.selected ? c.accentHover : c.subtle,
                          size: 16,
                        ),
                        child: widget.leading,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: widget.selected ? c.text : c.subtle,
                            fontSize: 12,
                          ),
                          child: widget.title,
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: _menu,
                        tooltip: widget.menu.tooltip,
                        enabled: widget.menu.enabled,
                        onSelected: widget.menu.onSelected,
                        itemBuilder: widget.menu.itemBuilder,
                        popUpAnimationStyle: AnimationStyle(
                          duration: OrbitMotionScope.duration(
                            context,
                            OrbitMotion.panel,
                          ),
                          curve: OrbitMotion.ease,
                        ),
                        icon: const Icon(Icons.more_horiz, size: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
