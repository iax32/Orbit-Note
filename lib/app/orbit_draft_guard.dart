import 'package:flutter/material.dart';

import 'orbit_components.dart';

/// Protects temporary form edits on barrier, Escape, back and explicit cancel.
/// Successful saves use Navigator.pop directly; they have already committed.
class OrbitDraftGuard extends StatefulWidget {
  const OrbitDraftGuard({
    super.key,
    required this.dirty,
    required this.builder,
    this.busy = false,
  });

  final bool dirty, busy;
  final Widget Function(BuildContext context, VoidCallback requestClose)
  builder;

  @override
  State<OrbitDraftGuard> createState() => _OrbitDraftGuardState();
}

class _OrbitDraftGuardState extends State<OrbitDraftGuard> {
  bool confirming = false;

  Future<void> requestClose() async {
    if (widget.busy || confirming) return;
    if (widget.dirty) {
      confirming = true;
      final discard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OrbitDialog(
          maxWidth: 440,
          title: const Text('Discard unapplied changes?'),
          content: const Text(
            'Your edits are still in this form. Keep editing to apply them, or discard them to close.',
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      confirming = false;
      if (!mounted || widget.busy || discard != true) return;
    }
    if (mounted && !widget.busy) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.busy && !widget.dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) requestClose();
    },
    child: widget.builder(context, requestClose),
  );
}
