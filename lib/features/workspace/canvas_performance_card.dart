import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/canvas_performance.dart';
import '../../platform/export_file.dart';

class CanvasPerformanceCard extends StatefulWidget {
  const CanvasPerformanceCard({super.key, this.monitor});
  final CanvasPerformance? monitor;
  @override
  State<CanvasPerformanceCard> createState() => _CanvasPerformanceCardState();
}

class _CanvasPerformanceCardState extends State<CanvasPerformanceCard> {
  CanvasPerformance get monitor => widget.monitor ?? CanvasPerformance.instance;
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await work();
    } on Object {
      if (mounted) {
        setState(() => _message = 'Could not access the local diagnostic log.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: monitor,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Canvas performance logging'),
          subtitle: const Text(
            'Record local frame timings, repaint reasons and cache counts. No note text, drawings or account data. Logs rotate automatically and stay outside your Vault.',
          ),
          value: monitor.enabled,
          onChanged: _busy
              ? null
              : (value) => _run(() => monitor.setEnabled(value)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('Save diagnostic log'),
              onPressed: _busy || monitor.path == null
                  ? null
                  : () => _run(() async {
                      final content = await monitor.read();
                      if (content.isEmpty) {
                        if (mounted) {
                          setState(
                            () => _message =
                                'Open a Canvas and use it briefly to collect timings.',
                          );
                        }
                        return;
                      }
                      await exportFile(
                        'Orbit-Canvas-Performance.jsonl',
                        content,
                        mimeType: 'application/x-ndjson',
                      );
                    }),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy log location'),
              onPressed: monitor.path == null
                  ? null
                  : () => _run(() async {
                      await Clipboard.setData(
                        ClipboardData(text: monitor.path!),
                      );
                      if (mounted) {
                        setState(() => _message = 'Local log location copied.');
                      }
                    }),
            ),
          ],
        ),
        if (_message ?? monitor.error case final String message)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(message)),
      ],
    ),
  );
}
