import 'package:flutter/material.dart';
import 'orbit_density.dart';
import 'package:flutter/services.dart';
import 'orbit_theme.dart';
import '../domain/motion_preferences.dart';

abstract final class OrbitSpace {
  static const small = 4.0, gap = 8.0, inset = 12.0;
  static const block = 16.0, section = 24.0, page = 32.0, major = 48.0;
}

abstract final class OrbitSize {
  static const compact = 32.0, control = 36.0, large = 44.0;
  static const iconSmall = 14.0, iconInline = 16.0, icon = 18.0;
  static const iconStandard = 20.0, iconLarge = 24.0;
}

abstract final class OrbitDepth {
  static const floating = [
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 6)),
  ];
}

/// Separates tool families without introducing another enclosing surface.
class OrbitToolbarDivider extends StatelessWidget {
  const OrbitToolbarDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: OrbitSpace.gap),
    child: SizedBox(
      height: OrbitSize.iconStandard,
      child: VerticalDivider(width: 1, color: OrbitColors.of(context).border),
    ),
  );
}

/// A quiet workbench surface for dense view-specific toolbars.
///
/// The leading context label disappears when the pane is narrow, leaving the
/// existing horizontally scrollable controls untouched. This keeps the tool
/// vocabulary discoverable on desktop without stealing space on phones.
class OrbitWorkbenchToolbar extends StatelessWidget {
  const OrbitWorkbenchToolbar({
    super.key,
    required this.child,
    this.label,
    this.icon,
  });

  final Widget child;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Material(
      color: colors.workspace,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: colors.workspace,
          border: Border(
            top: BorderSide(color: colors.border.withValues(alpha: 0.55)),
            bottom: BorderSide(color: colors.border),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabel = label != null && constraints.maxWidth >= 560;
            return Row(
              children: [
                if (showLabel)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null)
                          Icon(
                            icon,
                            size: OrbitSize.iconInline,
                            color: colors.subtle,
                          ),
                        if (icon != null) const SizedBox(width: 8),
                        Text(
                          label!,
                          style: TextStyle(
                            color: colors.subtle,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Identity-first header used by contextual inspectors and side panels.
class OrbitPanelHeader extends StatelessWidget {
  const OrbitPanelHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.workspace,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(13) > 20;
          final heading = Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.selected,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: colors.accentHover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(color: colors.subtle, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (actions.isNotEmpty && !stacked)
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
                ),
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    if (actions.isNotEmpty)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: actions,
                      ),
                  ],
                )
              : heading;
        },
      ),
    );
  }
}

/// Keeps item actions beside the label when space permits, and below it when
/// narrow panels or larger text need the full line for readable content.
class OrbitActionTile extends StatelessWidget {
  const OrbitActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.actions,
    this.onTap,
    this.selected = false,
    this.dense = true,
  });

  final Widget title, subtitle, leading;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final bool selected, dense;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 460 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final controls = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            selected: selected,
            dense: dense,
            leading: leading,
            title: title,
            subtitle: subtitle,
            onTap: onTap,
            trailing: stacked
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
          if (stacked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: controls,
            ),
        ],
      );
    },
  );
}

/// Reveals secondary actions without removing them from keyboard traversal.
class OrbitHoverRegion extends StatefulWidget {
  const OrbitHoverRegion({super.key, required this.builder});
  final Widget Function(BuildContext, bool) builder;
  @override
  State<OrbitHoverRegion> createState() => _OrbitHoverRegionState();
}

class _OrbitHoverRegionState extends State<OrbitHoverRegion> {
  bool hovered = false, focused = false;
  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final touch =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => focused = value),
        child: widget.builder(context, hovered || focused || touch),
      ),
    );
  }
}

/// Animates the current content only: no outgoing editor, duplicate focus tree,
/// or delayed input. Changing [identity] replays a small arrival transition.
class OrbitContentTransition extends StatefulWidget {
  const OrbitContentTransition({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object? identity;
  final Widget child;

  @override
  State<OrbitContentTransition> createState() => _OrbitContentTransitionState();
}

class _OrbitContentTransitionState extends State<OrbitContentTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this);
  Duration _duration = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _duration = OrbitMotionScope.settings(context).navigation
        ? OrbitMotionScope.duration(context, OrbitMotion.workspace)
        : Duration.zero;
    _animation.duration = _duration;
    // Preference changes settle an in-flight transition immediately.
    _animation.value = 1;
  }

  @override
  void didUpdateWidget(OrbitContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) {
      if (_duration == Duration.zero) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travel =
        OrbitMotionScope.duration(
          context,
          OrbitMotion.workspace,
          spatial: true,
        ) !=
        Duration.zero;
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (_, child) {
        final progress = OrbitMotion.ease.transform(_animation.value);
        return Opacity(
          opacity: .88 + .12 * progress,
          child: Transform.translate(
            offset: Offset(
              0,
              travel && OrbitMotionScope.settings(context).navigation
                  ? (OrbitMotionScope.settings(context).profile == 'paper'
                            ? 6
                            : OrbitMotionScope.settings(context).profile ==
                                  'experimental'
                            ? 8
                            : 4) *
                        (1 - progress)
                  : 0,
            ),
            transformHitTests: false,
            child: child,
          ),
        );
      },
    );
  }
}

/// Resizes a disclosure without keeping hidden controls in keyboard traversal.
class OrbitDisclosure extends StatelessWidget {
  const OrbitDisclosure({
    super.key,
    bool? visible,
    bool? expanded,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.duration = OrbitMotion.panel,
  }) : visible = visible ?? expanded ?? false;
  final bool visible;
  final Widget child;
  final Alignment alignment;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: OrbitMotionScope.settings(context).navigation
        ? OrbitMotionScope.duration(context, duration, spatial: true)
        : Duration.zero,
    curve: OrbitMotion.ease,
    alignment: alignment,
    child: Visibility(visible: visible, maintainState: true, child: child),
  );
}

class OrbitEntrance extends StatelessWidget {
  const OrbitEntrance({
    super.key,
    required this.child,
    this.spatial = false,
    this.offset = const Offset(0, 4),
    this.duration = OrbitMotion.panel,
  });
  final Widget child;
  final bool spatial;
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final dur = OrbitMotionScope.settings(context).navigation
        ? OrbitMotionScope.duration(context, duration)
        : Duration.zero;
    final allowTravel =
        spatial &&
        OrbitMotionScope.duration(context, duration, spatial: true) !=
            Duration.zero;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: dur == Duration.zero ? 1 : 0, end: 1),
      duration: dur,
      curve: OrbitMotion.ease,
      builder: (_, value, child) {
        final content = Opacity(
          opacity: (.85 + .15 * value).clamp(0.0, 1.0),
          child: child,
        );
        return Transform.translate(
          offset: allowTravel
              ? Offset(offset.dx * (1 - value), offset.dy * (1 - value))
              : Offset.zero,
          transformHitTests: false,
          child: content,
        );
      },
      child: child,
    );
  }
}

/// Gentle, quiet entrance: opacity and subtle scale for floating toolbars,
/// cards, minimaps, and contextual menus.
class OrbitFadeScale extends StatelessWidget {
  const OrbitFadeScale({
    super.key,
    required this.child,
    this.duration = OrbitMotion.control,
  });
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final dur = OrbitMotionScope.settings(context).navigation
        ? OrbitMotionScope.duration(context, duration)
        : Duration.zero;
    final allowTravel =
        OrbitMotionScope.duration(context, duration, spatial: true) !=
        Duration.zero;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: dur == Duration.zero ? 1 : 0, end: 1),
      duration: dur,
      curve: OrbitMotion.ease,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(
          scale: allowTravel ? (0.95 + 0.05 * value) : 1.0,
          alignment: Alignment.center,
          transformHitTests: false,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A quiet, tactile card with smooth preference-aware hover and press transitions.
class OrbitCard extends StatefulWidget {
  const OrbitCard({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(OrbitSpace.block),
    this.margin,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.hoverColor,
    this.hoverBorderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Color? borderColor;
  final Color? hoverColor;
  final Color? hoverBorderColor;

  @override
  State<OrbitCard> createState() => _OrbitCardState();
}

class _OrbitCardState extends State<OrbitCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final radius =
        widget.borderRadius ?? BorderRadius.circular(OrbitRadius.card);
    final isInteractive = widget.onTap != null;

    final border = widget.selected
        ? c.accent
        : (_hovered && isInteractive
              ? (widget.hoverBorderColor ?? c.accent.withValues(alpha: 0.35))
              : (widget.borderColor ?? c.border));

    final bg = widget.selected
        ? c.selected
        : (_hovered && isInteractive
              ? (widget.hoverColor ?? c.hover)
              : (widget.color ?? c.panel));

    Widget content = AnimatedContainer(
      duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
      curve: OrbitMotion.ease,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: widget.child,
    );

    if (isInteractive) {
      final spatial =
          OrbitMotionScope.duration(
            context,
            OrbitMotion.micro,
            spatial: true,
          ) !=
          Duration.zero;

      content = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onSecondaryTap: widget.onSecondaryTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: (spatial && _pressed) ? 0.985 : 1.0,
            duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
            curve: OrbitMotion.ease,
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

/// Tactile pill badge that animates background and text color on status changes.
class OrbitPillBadge extends StatelessWidget {
  const OrbitPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.onTap,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final bg = color ?? c.raised;
    final fg = textColor ?? c.subtle;

    Widget badge = AnimatedContainer(
      duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
      curve: OrbitMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          AnimatedDefaultTextStyle(
            duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
            curve: OrbitMotion.ease,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
            child: Text(label),
          ),
        ],
      ),
    );

    if (onTap != null) {
      badge = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: badge),
      );
    }

    if (tooltip != null) {
      badge = Tooltip(message: tooltip!, child: badge);
    }

    return badge;
  }
}

/// App preference is separate from the OS cap, including inside dialog routes.
class OrbitMotionScope extends InheritedWidget {
  const OrbitMotionScope({
    super.key,
    required this.preference,
    required this.osReduced,
    this.options = const {},
    required super.child,
  });
  final String preference;
  final bool osReduced;
  final Map<String, dynamic> options;
  static MotionPreferences settings(BuildContext context) => MotionPreferences(
    context.dependOnInheritedWidgetOfExactType<OrbitMotionScope>()?.options ??
        const {},
  );
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
    return reduced
        ? (spatial ? Duration.zero : OrbitMotion.micro)
        : Duration(
            microseconds:
                (normal.inMicroseconds /
                        MotionPreferences(scope?.options ?? const {}).speed)
                    .round(),
          );
  }

  static bool isReduced(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OrbitMotionScope>();
    return scope?.osReduced == true ||
        scope?.preference == 'reduced' ||
        (scope == null && MediaQuery.disableAnimationsOf(context));
  }

  static bool isOff(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OrbitMotionScope>();
    return scope?.preference == 'off';
  }

  /// Menus and sheets grow/slide, so Reduced removes that spatial transition.
  static AnimationStyle popupStyle(BuildContext context) {
    final time = settings(context).navigation
        ? duration(context, OrbitMotion.panel, spatial: true)
        : Duration.zero;
    return time == Duration.zero
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: time,
            reverseDuration: duration(
              context,
              OrbitMotion.micro,
              spatial: true,
            ),
            curve: OrbitMotion.ease,
            reverseCurve: OrbitMotion.ease,
          );
  }

  static AnimationStyle dialogStyle(BuildContext context) {
    final time = settings(context).navigation
        ? duration(context, OrbitMotion.dialog)
        : Duration.zero;
    return time == Duration.zero
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: time,
            reverseDuration: duration(context, OrbitMotion.control),
            curve: OrbitMotion.ease,
            reverseCurve: OrbitMotion.ease,
          );
  }

  @override
  bool updateShouldNotify(OrbitMotionScope oldWidget) =>
      preference != oldWidget.preference ||
      osReduced != oldWidget.osReduced ||
      options != oldWidget.options;
}

/// No ink splash: tone, focus outline and an anchored selection mark communicate state.
class OrbitControl extends StatefulWidget {
  const OrbitControl({
    super.key,
    this.label,
    this.icon,
    this.tooltip,
    this.disabledReason,
    this.selected = false,
    required this.onPressed,
  });
  final String? label, tooltip, disabledReason;
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
    final hint = enabled
        ? widget.tooltip
        : '${widget.tooltip ?? widget.label ?? "Action"} · ${widget.disabledReason ?? "Unavailable in the current context"}';
    final iconOnly = widget.icon != null && widget.label == null;
    final text = enabled ? (widget.selected ? c.text : c.subtle) : c.muted;
    Widget control = Semantics(
      button: true,
      selected: widget.selected,
      enabled: enabled,
      label: hint ?? widget.label,
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
            constraints: BoxConstraints(
              minHeight: OrbitDensity.of(context).controlHeight,
              minWidth: OrbitDensity.of(context).controlHeight,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: OrbitSpace.inset,
              vertical: OrbitSpace.gap,
            ),
            decoration: BoxDecoration(
              color: pressed
                  ? c.pressed
                  : widget.selected
                  ? c.selected
                  : hover
                  ? c.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              border: Border.all(
                color: focus
                    ? c.focus
                    : widget.selected
                    ? c.accent.withValues(alpha: .32)
                    : hover
                    ? c.border
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null)
                      AnimatedScale(
                        scale:
                            OrbitMotionScope.isReduced(context) ||
                                OrbitMotionScope.isOff(context)
                            ? 1
                            : pressed
                            ? .9
                            : hover || widget.selected
                            ? 1
                            : .94,
                        duration: OrbitMotionScope.duration(
                          context,
                          OrbitMotion.control,
                          spatial: true,
                        ),
                        curve: OrbitMotion.ease,
                        child: Icon(
                          widget.icon,
                          size: OrbitDensity.of(context).icon,
                          color: widget.selected ? c.accentHover : text,
                        ),
                      ),
                    if (widget.icon != null && widget.label != null)
                      const SizedBox(width: OrbitSpace.gap),
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.2,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: text,
                        ),
                      ),
                  ],
                ),
                AnimatedContainer(
                  duration: OrbitMotionScope.duration(
                    context,
                    OrbitMotion.control,
                  ),
                  curve: OrbitMotion.ease,
                  margin: const EdgeInsets.only(top: 3),
                  height: 2,
                  width: iconOnly ? 0 : (widget.selected ? 14 : 0),
                  decoration: BoxDecoration(
                    color: widget.selected ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (hint != null) {
      control = Tooltip(message: hint, child: control);
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
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
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
    this.contentSlivers,
    this.contentScrollController,
    this.actions = const [],
    this.maxWidth = 560,
  });
  final Widget? title, content;

  /// Lazy content sharing the heading's scroll surface, for long inspector lists.
  final List<Widget>? contentSlivers;
  final ScrollController? contentScrollController;
  final List<Widget> actions;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 480 ? 12 : OrbitSpace.section,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || content != null || contentSlivers != null)
              Flexible(
                child: contentSlivers != null
                    ? CustomScrollView(
                        controller: contentScrollController,
                        shrinkWrap: true,
                        slivers: [
                          if (title != null)
                            SliverToBoxAdapter(
                              child: Semantics(
                                namesRoute: true,
                                child: DefaultTextStyle(
                                  style: OrbitTypography.object(context),
                                  child: title!,
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: OrbitSpace.section),
                          ),
                          ...contentSlivers!,
                          const SliverToBoxAdapter(
                            child: SizedBox(height: OrbitSpace.section),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (title != null)
                              Semantics(
                                namesRoute: true,
                                child: DefaultTextStyle(
                                  style: OrbitTypography.object(context),
                                  child: title!,
                                ),
                              ),
                            if (content != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: OrbitSpace.section,
                                ),
                                child: content,
                              ),
                          ],
                        ),
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

/// Reveals the selected row in a lazy list whose wrapping text has variable
/// height. Scan by viewport until it is built, then use its actual geometry.
/// Call [cancel] on disposal or when another selection supersedes the request.
class OrbitListSelectionReveal {
  final marker = GlobalKey();
  int _generation = 0;

  void cancel() => _generation++;

  void reveal(ScrollController scroll, {bool forward = true}) {
    final generation = ++_generation;
    void step(Duration _) {
      if (generation != _generation || !scroll.hasClients) return;
      final context = marker.currentContext;
      if (context != null) {
        final box = context.findRenderObject();
        final tallerThanViewport =
            box is RenderBox &&
            box.size.height > scroll.position.viewportDimension;
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: tallerThanViewport
              ? ScrollPositionAlignmentPolicy.explicit
              : forward
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return;
      }
      final position = scroll.position;
      final next =
          (position.pixels + (forward ? 1 : -1) * position.viewportDimension)
              .clamp(0.0, position.maxScrollExtent);
      if (next == position.pixels) return;
      scroll.jumpTo(next);
      WidgetsBinding.instance.addPostFrameCallback(step);
    }

    WidgetsBinding.instance.addPostFrameCallback(step);
  }
}

class OrbitSearchField extends StatefulWidget {
  const OrbitSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
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
                focusNode: widget.focusNode,
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

/// Renders a calm, tactile keyboard key badge for shortcuts.
class OrbitKeyBadge extends StatelessWidget {
  const OrbitKeyBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          color: c.text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Formats a sequence of keys (e.g. `['Ctrl', 'Shift', 'D']`).
class OrbitShortcutRow extends StatelessWidget {
  const OrbitShortcutRow({super.key, required this.keys});
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: c.muted,
                ),
              ),
            ),
          OrbitKeyBadge(label: keys[i]),
        ],
      ],
    );
  }
}

/// Keeps Flutter's modal barrier, focus traversal, results and navigator contract.
/// A single mounted dialog gains a small, preference-aware surface arrival.
Future<T?> showOrbitDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
  AnimationStyle? animationStyle,
}) {
  final fallback = context.getInheritedWidgetOfExactType<OrbitMotionScope>();
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    fullscreenDialog: fullscreenDialog,
    requestFocus: requestFocus,
    animationStyle:
        OrbitMotionScope.isOff(context) ||
            !OrbitMotionScope.settings(context).navigation ||
            OrbitMotionScope.isReduced(context)
        ? OrbitMotionScope.dialogStyle(context)
        : animationStyle ?? OrbitMotionScope.dialogStyle(context),
    builder: (routeContext) {
      Widget content = _OrbitDialogArrival(child: Builder(builder: builder));
      // Scopes below a nested navigator are not inherited by its modal route.
      // Prefer the live root scope; capture only when the route has none.
      if (routeContext.getInheritedWidgetOfExactType<OrbitMotionScope>() ==
              null &&
          fallback != null) {
        content = OrbitMotionScope(
          preference: fallback.preference,
          osReduced: fallback.osReduced,
          options: fallback.options,
          child: content,
        );
      }
      return content;
    },
  );
}

class _OrbitDialogArrival extends StatelessWidget {
  const _OrbitDialogArrival({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    final spatial =
        OrbitMotionScope.settings(context).navigation &&
        OrbitMotionScope.duration(context, OrbitMotion.dialog, spatial: true) !=
            Duration.zero;
    final paper = OrbitMotionScope.settings(context).profile == 'paper';
    return AnimatedBuilder(
      animation: animation ?? kAlwaysCompleteAnimation,
      child: child,
      builder: (_, child) {
        final t = spatial && animation != null
            ? OrbitMotion.ease.transform(animation.value.clamp(0, 1))
            : 1.0;
        return Transform.translate(
          offset: Offset(0, (paper ? 8 : 5) * (1 - t)),
          transformHitTests: false,
          child: Transform.scale(
            scale: .985 + .015 * t,
            transformHitTests: false,
            child: child,
          ),
        );
      },
    );
  }
}

/// Finite state feedback; a new label replaces the old semantics immediately.
/// Only the active child is mounted, suitable for save/sync and result labels.
class OrbitStateMotion extends StatefulWidget {
  const OrbitStateMotion({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object? identity;
  final Widget child;
  @override
  State<OrbitStateMotion> createState() => _OrbitStateMotionState();
}

/// Keeps the action's slot stable while removing hidden input/focus/semantics
/// immediately. Fading out must never leave a clickable invisible control.
class OrbitActionReveal extends StatelessWidget {
  const OrbitActionReveal({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: OrbitMotionScope.settings(context).navigation
              ? OrbitMotionScope.duration(context, OrbitMotion.control)
              : Duration.zero,
          curve: OrbitMotion.ease,
          child: child,
        ),
      ),
    ),
  );
}

class _OrbitStateMotionState extends State<OrbitStateMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = OrbitMotionScope.settings(context).navigation
        ? OrbitMotionScope.duration(context, OrbitMotion.control)
        : Duration.zero;
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(OrbitStateMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: .72 + .28 * OrbitMotion.ease.transform(_controller.value),
      child: child,
    ),
  );
}

/// Animates numeric value changes with a smooth rolling counter.
/// Respects [OrbitMotionScope] preferences.
class OrbitAnimatedCounter extends StatelessWidget {
  const OrbitAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? formatter;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = OrbitMotionScope.duration(
      context,
      duration,
      spatial: false,
    );
    return _OrbitAnimatedCounterCore(
      value: value,
      style: style,
      formatter: formatter,
      duration: effectiveDuration,
      curve: curve,
    );
  }
}

class _OrbitAnimatedCounterCore extends ImplicitlyAnimatedWidget {
  const _OrbitAnimatedCounterCore({
    required this.value,
    this.style,
    this.formatter,
    required super.duration,
    super.curve = Curves.easeOutCubic,
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? formatter;

  @override
  ImplicitlyAnimatedWidgetState<_OrbitAnimatedCounterCore> createState() =>
      _OrbitAnimatedCounterCoreState();
}

class _OrbitAnimatedCounterCoreState
    extends AnimatedWidgetBaseState<_OrbitAnimatedCounterCore> {
  IntTween? _intTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _intTween =
        visitor(
              _intTween,
              widget.value,
              (dynamic value) => IntTween(begin: value as int),
            )
            as IntTween?;
  }

  @override
  Widget build(BuildContext context) {
    final count = _intTween?.evaluate(animation) ?? widget.value;
    final text = widget.formatter != null
        ? widget.formatter!(count)
        : count.toString();
    return Text(text, style: widget.style);
  }
}

/// Tactile card with subtle translateY micro-lift, border accent brightening,
/// and ambient shadow bloom on mouse hover.
class OrbitHoverLiftCard extends StatefulWidget {
  const OrbitHoverLiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(OrbitSpace.block),
    this.margin,
    this.color,
    this.borderColor,
    this.accentBorderColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final Color? accentBorderColor;
  final BorderRadius? borderRadius;

  @override
  State<OrbitHoverLiftCard> createState() => _OrbitHoverLiftCardState();
}

class _OrbitHoverLiftCardState extends State<OrbitHoverLiftCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final allowTravel =
        OrbitMotionScope.duration(context, OrbitMotion.micro, spatial: true) !=
        Duration.zero;
    final duration = OrbitMotionScope.duration(context, OrbitMotion.control);
    final br = widget.borderRadius ?? BorderRadius.circular(OrbitRadius.card);
    final border = _hovered
        ? (widget.accentBorderColor ?? c.accent.withValues(alpha: 0.45))
        : (widget.borderColor ?? c.border);
    final bg = widget.color ?? c.panel;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: OrbitMotion.ease,
          margin: widget.margin,
          transform: Matrix4.translationValues(
            0,
            (allowTravel && _hovered) ? -3.0 : 0.0,
            0,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: br,
            border: Border.all(color: border),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: (widget.accentBorderColor ?? c.accent).withValues(
                        alpha: 0.14,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Ambient breathing ring pulse for active status, focus sessions, or audio recording.
class OrbitBreathingGlow extends StatefulWidget {
  const OrbitBreathingGlow({
    super.key,
    required this.child,
    this.glowColor,
    this.active = true,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final Color? glowColor;
  final bool active;
  final BorderRadius? borderRadius;
  final Duration duration;

  @override
  State<OrbitBreathingGlow> createState() => _OrbitBreathingGlowState();
}

class _OrbitBreathingGlowState extends State<OrbitBreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  void _sync() {
    final duration = OrbitMotionScope.duration(
      context,
      widget.duration,
      spatial: true,
    );
    final allowed =
        widget.active &&
        duration != Duration.zero &&
        OrbitMotionScope.settings(context).navigation &&
        TickerMode.valuesOf(context).enabled;
    final changed = _controller.duration != duration;
    if (duration != Duration.zero) _controller.duration = duration;
    if (allowed) {
      if (!_controller.isAnimating || changed) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OrbitBreathingGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        widget.active &&
        !OrbitMotionScope.isOff(context) &&
        !OrbitMotionScope.isReduced(context) &&
        OrbitMotionScope.settings(context).navigation;
    final c = OrbitColors.of(context);
    final glow = widget.glowColor ?? c.accent;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(OrbitRadius.control);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOutSine.transform(_controller.value);
        final spread = 1.0 + (t * 2.5);
        final blur = 4.0 + (t * 8.0);
        final alpha = 0.12 + (t * 0.22);

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: alpha),
                      spreadRadius: spread,
                      blurRadius: blur,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Implicitly animated linear progress bar that smoothly glides to new values,
/// honoring [OrbitMotionScope] motion preferences.
class OrbitAnimatedProgress extends ImplicitlyAnimatedWidget {
  const OrbitAnimatedProgress({
    super.key,
    required this.value,
    this.minHeight = 5.0,
    this.backgroundColor,
    this.color,
    this.borderRadius,
    super.duration = OrbitMotion.workspace,
    super.curve = OrbitMotion.ease,
  });

  final double value;
  final double minHeight;
  final Color? backgroundColor;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  ImplicitlyAnimatedWidgetState<OrbitAnimatedProgress> createState() =>
      _OrbitAnimatedProgressState();
}

class _OrbitAnimatedProgressState
    extends AnimatedWidgetBaseState<OrbitAnimatedProgress> {
  Tween<double>? _tween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _tween =
        visitor(
              _tween,
              widget.value.clamp(0.0, 1.0),
              (dynamic value) =>
                  Tween<double>(begin: (value as num).toDouble()),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _tween?.evaluate(animation) ?? widget.value.clamp(0.0, 1.0);
    final c = OrbitColors.of(context);
    final bg = widget.backgroundColor ?? c.raised;
    final fg = widget.color ?? c.accent;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.minHeight / 2);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: widget.minHeight,
        color: bg,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(color: fg, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}

/// Tactile animated badge with an ambient pulsing ping halo around a status pip.
class OrbitPulseBadge extends StatefulWidget {
  const OrbitPulseBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
    this.pulseColor,
    this.active = true,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final Color? pulseColor;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<OrbitPulseBadge> createState() => _OrbitPulseBadgeState();
}

class _OrbitPulseBadgeState extends State<OrbitPulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _sync() {
    final duration = OrbitMotionScope.duration(
      context,
      const Duration(milliseconds: 1400),
      spatial: true,
    );
    final allowed =
        widget.active &&
        duration != Duration.zero &&
        OrbitMotionScope.settings(context).navigation &&
        TickerMode.valuesOf(context).enabled;
    final changed = _pulseController.duration != duration;
    if (duration != Duration.zero) _pulseController.duration = duration;
    if (allowed) {
      if (!_pulseController.isAnimating || changed) _pulseController.repeat();
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(OrbitPulseBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = OrbitColors.of(context);
    final bg = widget.color ?? c.raised;
    final fg = widget.textColor ?? c.text;
    final pulse = widget.pulseColor ?? c.accent;
    final motionOff =
        OrbitMotionScope.isOff(context) ||
        OrbitMotionScope.isReduced(context) ||
        !OrbitMotionScope.settings(context).navigation;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OrbitRadius.control),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.active && !motionOff)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = _pulseController.value;
                return SizedBox(
                  width: 10,
                  height: 10,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 6 + (t * 4),
                        height: 6 + (t * 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pulse.withValues(alpha: (1.0 - t) * 0.5),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pulse,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.active ? pulse : c.subtle,
              ),
            ),
          ],
          const SizedBox(width: 6),
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      badge = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: widget.onTap, child: badge),
      );
    }

    return badge;
  }
}

/// Tactile micro-scale feedback container for interactive buttons, chips, or cards.
/// Compresses smoothly on tap down and springs back on release/cancel.
class OrbitBounceButton extends StatefulWidget {
  const OrbitBounceButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.shrinkScale = 0.94,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double shrinkScale;
  final MouseCursor cursor;

  @override
  State<OrbitBounceButton> createState() => _OrbitBounceButtonState();
}

class _OrbitBounceButtonState extends State<OrbitBounceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final allowTravel =
        OrbitMotionScope.duration(context, OrbitMotion.micro, spatial: true) !=
        Duration.zero;

    return MouseRegion(
      cursor: widget.onTap != null ? widget.cursor : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _pressed = false)
            : null,
        child: AnimatedScale(
          scale: (allowTravel && _pressed) ? widget.shrinkScale : 1.0,
          duration: OrbitMotionScope.duration(context, OrbitMotion.micro),
          curve: OrbitMotion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Smooth crossfade view switcher for quiet transitions between layout modes or panels.
class OrbitFadeSwitcher extends StatelessWidget {
  const OrbitFadeSwitcher({
    super.key,
    required this.child,
    this.duration = OrbitMotion.workspace,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final dur = OrbitMotionScope.duration(context, duration);
    if (dur == Duration.zero) return child;

    return AnimatedSwitcher(
      duration: dur,
      switchInCurve: OrbitMotion.ease,
      switchOutCurve: OrbitMotion.ease,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: child,
    );
  }
}
