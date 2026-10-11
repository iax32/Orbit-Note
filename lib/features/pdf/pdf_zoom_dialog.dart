import 'package:flutter/material.dart';
import '../../app/orbit_components.dart';

class PdfZoomDialog extends StatefulWidget {
  const PdfZoomDialog({
    super.key,
    required this.current,
    required this.minimum,
    required this.maximum,
  });
  final double current, minimum, maximum;
  @override
  State<PdfZoomDialog> createState() => _PdfZoomDialogState();
}

class _PdfZoomDialogState extends State<PdfZoomDialog> {
  late final input = TextEditingController(
    text: widget.current.toStringAsFixed(1),
  );
  String? error;
  void apply() {
    final value = double.tryParse(
      input.text.trim().replaceFirst(RegExp(r'%$'), '').trim(),
    );
    if (value == null ||
        !value.isFinite ||
        value < widget.minimum ||
        value > widget.maximum) {
      setState(
        () => error =
            'Enter ${widget.minimum.toStringAsFixed(0)}–${widget.maximum.toStringAsFixed(0)}%.',
      );
      return;
    }
    Navigator.pop(context, value / 100);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrbitDialog(
    title: const Text('Custom zoom'),
    content: TextField(
      controller: input,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Zoom percentage',
        suffixText: '%',
        error: error == null ? null : Text(error!),
      ),
      onSubmitted: (_) => apply(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: apply, child: const Text('Apply zoom')),
    ],
  );
}
