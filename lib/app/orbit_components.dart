import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'orbit_theme.dart';

abstract final class OrbitSpace {
  static const small = 4.0, gap = 8.0, inset = 12.0, section = 20.0;
}

abstract final class OrbitSize {
  static const control = 34.0, icon = 17.0;
}

abstract final class OrbitDepth {
  static const floating = [
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 6)),
  ];
}

class OrbitEntrance extends StatelessWidget {
  const OrbitEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: OrbitMotionScope.duration(context, OrbitMotion.panel),
    curve: OrbitMotion.ease,
    builder: (_, value, child) => Opacity(opacity: value, child: child),
    child: child,
  );
}

/// App preference is separate from the OS cap, including inside dialog routes.
class OrbitMotionScope extends InheritedWidget {
  const OrbitMotionScope({
    super.key,
    required this.preference,
    required this.osReduced,
    required super.child,
  });
  final String preference;
  final bool osReduced;
  static Duration duration(
    BuildContext context,
    Duration normal, {
    bool spatial = false,
  }) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OrbitMotionScope>();
    if (scope?.preference == 'off') return Duration.zero;
    final reduced =
        scope?.osReduced == true ||
        scope?.preference == 'reduced' ||
        (scope == null && MediaQuery.disableAnimationsOf(context));
    return reduced ? (spatial ? Duration.zero : OrbitMotion.micro) : normal;
  }

  @override
  bool updateShouldNotify(OrbitMotionScope oldWidget) =>
      preference != oldWidget.preference || osReduced != oldWidget.osReduced;
}

/// No ink splash: tone, focus outline and an anchored selection mark communicate state.
class OrbitControl extends StatefulWidget {
  const OrbitControl({
    super.key,
    this.label,
    this.icon,
    this.tooltip,
    this.selected = false,
    required this.onPressed,
  });
  final String? label, tooltip;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  State<OrbitControl> createState() => _OrbitControlState();
}

class _OrbitControlState extends State<OrbitControl> {
  bool hover = false, focus = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final enabled = widget.onPressed != null;
    final text = enabled ? (widget.selected ? c.text : c.subtle) : c.muted;
    Widget control = Semantics(
      button: true,
      selected: widget.selected,
      enabled: enabled,
      label: widget.tooltip ?? widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => hover = v),
        onShowFocusHighlight: (v) => setState(() => focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
          onTapCancel: () => setState(() => pressed = false),
          onTapUp: (_) => setState(() => pressed = false),
          child: AnimatedContainer(
            duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(
              minHeight: OrbitSize.control,
              minWidth: OrbitSize.control,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: OrbitSpace.inset,
              vertical: OrbitSpace.gap,
            ),
            decoration: BoxDecoration(
              color: pressed
                  ? c.hover
                  : widget.selected
                  ? c.raised
                  : hover
                  ? c.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              border: Border.all(color: focus ? c.accent : Colors.transparent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        size: OrbitSize.icon,
                        color: widget.selected ? c.accentHover : text,
                      ),
                    if (widget.icon != null && widget.label != null)
                      const SizedBox(width: OrbitSpace.gap),
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: text,
                        ),
                      ),
                  ],
                ),
                if (widget.selected)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    height: 2,
                    width: 12,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      control = Tooltip(message: widget.tooltip!, child: control);
    }
    return control;
  }
}

class OrbitModeControl<T> extends StatelessWidget {
  const OrbitModeControl({
    super.key,
    required this.values,
    required this.value,
    required this.onChanged,
  });
  final Map<T, String> values;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: OrbitColors.of(context).panel,
      borderRadius: BorderRadius.circular(OrbitRadius.card),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in values.entries)
            OrbitControl(
              label: entry.value,
              selected: entry.key == value,
              onPressed: () => onChanged(entry.key),
            ),
        ],
      ),
    ),
  );
}

class OrbitDialog extends StatelessWidget {
  const OrbitDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });
  final Widget? title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(OrbitSpace.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: OrbitColors.of(context).accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: OrbitSpace.inset),
                if (title != null)
                  Expanded(
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.titleMedium!,
                      child: title!,
                    ),
                  ),
              ],
            ),
            if (content != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: OrbitSpace.section,
                  ),
                  child: SingleChildScrollView(child: content),
                ),
              ),
            if (actions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: OrbitSpace.gap,
                runSpacing: OrbitSpace.gap,
                children: actions,
              ),
          ],
        ),
      ),
    ),
  );
}

class OrbitSearchField extends StatefulWidget {
  const OrbitSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  @override
  State<OrbitSearchField> createState() => _OrbitSearchFieldState();
}

class _OrbitSearchFieldState extends State<OrbitSearchField> {
  bool focused = false;
  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return Focus(
      onFocusChange: (value) => setState(() => focused = value),
      child: AnimatedContainer(
        duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
        padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.inset),
        decoration: BoxDecoration(
          color: focused ? c.raised : c.panel,
          borderRadius: BorderRadius.circular(OrbitRadius.control),
          border: Border(
            bottom: BorderSide(color: focused ? c.accent : c.border),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: OrbitSize.icon,
              color: focused ? c.accentHover : c.muted,
            ),
            const SizedBox(width: OrbitSpace.gap),
            Expanded(
              child: TextField(
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: TextStyle(fontSize: 12, color: c.text),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(color: c.muted, fontSize: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
