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
    this.onKeepDraft,
    this.onDiscardDraft,
    this.hasChanges,
  });

  final bool dirty, busy;
  final Future<bool> Function()? onKeepDraft;
  final Future<bool> Function()? onDiscardDraft;
  final bool Function()? hasChanges;
  final Widget Function(BuildContext context, VoidCallback requestClose)
  builder;

  @override
  State<OrbitDraftGuard> createState() => _OrbitDraftGuardState();
}

class _OrbitDraftGuardState extends State<OrbitDraftGuard> {
  bool confirming = false;
  bool persisting = false;

  Future<bool> _persist(Future<bool> Function() action) async {
    setState(() => persisting = true);
    FocusScope.of(context).unfocus();
    try {
      return await action();
    } finally {
      if (mounted) setState(() => persisting = false);
    }
  }

  Future<void> requestClose() async {
    if (widget.busy || confirming) return;
    if (widget.hasChanges?.call() ?? widget.dirty) {
      confirming = true;
      final decision = await showOrbitDialog<String>(
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
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard changes'),
            ),
            if (widget.onKeepDraft != null)
              FilledButton(
                onPressed: () => Navigator.pop(context, 'keep'),
                child: const Text('Keep draft and close'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (decision == 'keep' && !widget.busy) {
        try {
          if (await _persist(widget.onKeepDraft!) != true) {
            confirming = false;
            return;
          }
        } catch (error) {
          confirming = false;
          if (mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text('$error')));
          }
          return;
        }
      } else if (decision == 'discard' && widget.onDiscardDraft != null) {
        try {
          if (await _persist(widget.onDiscardDraft!) != true) {
            confirming = false;
            return;
          }
        } catch (error) {
          confirming = false;
          if (mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text('$error')));
          }
          return;
        }
      } else if (decision != 'discard') {
        confirming = false;
        return;
      }
      confirming = false;
      if (!mounted || widget.busy) return;
    }
    if (mounted && !widget.busy) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop:
        widget.hasChanges == null &&
        !widget.busy &&
        !widget.dirty &&
        !persisting,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) requestClose();
    },
    child: AbsorbPointer(
      absorbing: persisting,
      child: ExcludeFocus(
        excluding: persisting,
        child: widget.builder(context, requestClose),
      ),
    ),
  );
}
