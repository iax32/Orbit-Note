import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/orbit_density.dart';

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
    this.accentColor,
    this.onExpand,
    this.onCollapse,
    this.fullDescription,
  });
  final Widget leading, title;
  final String? fullDescription;
  final VoidCallback onTap;
  final PopupMenuButton<String> menu;
  final bool selected;
  final bool multiSelected;
  final Color? accentColor;
  final VoidCallback? onExpand, onCollapse;
  @override
  State<OrbitExplorerRow> createState() => _OrbitExplorerRowState();
}

class _OrbitExplorerRowState extends State<OrbitExplorerRow> {
  final _menu = GlobalKey<PopupMenuButtonState<String>>();
  final _focus = FocusNode();
  bool _focused = false;
  bool _hovered = false;
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
    return Tooltip(
      message:
          widget.fullDescription ??
          (widget.title is Text ? (widget.title as Text).data ?? '' : ''),
      triggerMode: TooltipTriggerMode.longPress,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
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
                curve: OrbitMotion.ease,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: widget.multiSelected
                      ? c.accent.withValues(alpha: .22)
                      : (widget.selected
                            ? (widget.accentColor != null
                                  ? Color.alphaBlend(
                                      widget.accentColor!.withValues(
                                        alpha: .15,
                                      ),
                                      c.selected,
                                    )
                                  : c.selected)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(OrbitRadius.control),
                  border: Border.all(
                    color: _focused
                        ? c.accent.withValues(alpha: .6)
                        : Colors.transparent,
                  ),
                ),
                child: Stack(
                  children: [
                    if (widget.accentColor != null)
                      Positioned(
                        left: 0,
                        top: 3,
                        bottom: 3,
                        width: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(OrbitRadius.control),
                      child: InkWell(
                        canRequestFocus: false,
                        splashFactory: NoSplash.splashFactory,
                        borderRadius: BorderRadius.circular(
                          OrbitRadius.control,
                        ),
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
                                  color:
                                      widget.accentColor ??
                                      (widget.selected
                                          ? c.accentHover
                                          : c.subtle),
                                  size: 16,
                                ),
                                child: widget.leading,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DefaultTextStyle(
                                  style: OrbitTypography.body(context).copyWith(
                                    color: widget.selected ? c.text : c.subtle,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                  child: widget.title,
                                ),
                              ),
                              Visibility(
                                visible:
                                    _hovered ||
                                    _focused ||
                                    widget.selected ||
                                    widget.multiSelected,
                                maintainState: true,
                                maintainAnimation: true,
                                maintainSize: true,
                                child: SizedBox(
                                  width: OrbitDensity.of(context).smallControl,
                                  height: OrbitDensity.of(context).rowHeight,
                                  child: PopupMenuButton<String>(
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
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
