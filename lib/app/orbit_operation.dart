import 'package:flutter/material.dart';
import 'orbit_components.dart';

class OrbitOperationProgress extends ChangeNotifier {
  bool canceled = false;
  double? fraction;
  String detail = 'Preparing…';
  void report(String message, {double? progress}) {
    detail = message;
    fraction = progress;
    notifyListeners();
  }

  void cancel() {
    canceled = true;
    notifyListeners();
  }
}

/// The operation owns its dialog until its current safe checkpoint finishes.
Future<T?> runOrbitOperation<T>(
  BuildContext context,
  String title,
  Future<T> Function(OrbitOperationProgress) run,
) => showOrbitDialog<T>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Operation<T>(title: title, run: run),
);

class _Operation<T> extends StatefulWidget {
  const _Operation({required this.title, required this.run});
  final String title;
  final Future<T> Function(OrbitOperationProgress) run;
  @override
  State<_Operation<T>> createState() => _OperationState<T>();
}

class _OperationState<T> extends State<_Operation<T>> {
  final progress = OrbitOperationProgress();
  String? error;
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_run);
  }

  Future<void> _run() async {
    try {
      final result = await widget.run(progress);
      if (mounted) Navigator.pop(context, result);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    }
  }

  @override
  void dispose() {
    progress.canceled = true;
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: error != null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) progress.cancel();
    },
    child: ListenableBuilder(
      listenable: progress,
      builder: (context, _) => OrbitDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error == null)
              LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 12),
            Text(error ?? progress.detail),
            if (progress.canceled && error == null)
              const Text(
                'Stopping after the current safe step. Completed items are retained.',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: error != null
                ? () => Navigator.pop(context)
                : progress.canceled
                ? null
                : progress.cancel,
            child: Text(
              error != null
                  ? 'Close'
                  : progress.canceled
                  ? 'Canceling…'
                  : 'Cancel',
            ),
          ),
        ],
      ),
    ),
  );
}
