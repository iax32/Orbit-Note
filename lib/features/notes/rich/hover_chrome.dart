import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Desktop block controls are quiet at rest but remain reachable by Tab and
/// assistive technology. Touch platforms keep the affordance visible.
class HoverChrome extends StatefulWidget {
  const HoverChrome({super.key, required this.child, this.content});
  final Widget child;
  final Widget? content;

  @override
  State<HoverChrome> createState() => _HoverChromeState();
}

class _HoverChromeState extends State<HoverChrome> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final visible =
        _hovered ||
        _focused ||
        MediaQuery.accessibleNavigationOf(context) ||
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform);
    final control = Opacity(
      opacity: visible ? 1 : 0,
      alwaysIncludeSemantics: true,
      child: IgnorePointer(ignoring: !visible, child: widget.child),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (value) => setState(() => _focused = value),
        child: widget.content == null
            ? control
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  control,
                  Expanded(child: widget.content!),
                ],
              ),
      ),
    );
  }
}
