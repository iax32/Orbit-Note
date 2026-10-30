import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../canvas/research_diagrams.dart';
import '../../canvas/scene.dart';
import 'canvas_diagram_preview.dart';

class ResearchDiagramChoice {
  const ResearchDiagramChoice(this.kind, {this.calculation});
  final ResearchDiagramKind kind;
  final String? calculation;
}

Future<ResearchDiagramChoice?> showResearchDiagramDialog(
  BuildContext context, {
  bool allowCalculation = false,
}) => showOrbitDialog<ResearchDiagramChoice>(
  context: context,
  builder: (_) => _ResearchDiagramDialog(allowCalculation: allowCalculation),
);

class _ResearchDiagramDialog extends StatefulWidget {
  const _ResearchDiagramDialog({required this.allowCalculation});
  final bool allowCalculation;
  @override
  State<_ResearchDiagramDialog> createState() => _ResearchDiagramDialogState();
}

class _ResearchDiagramDialogState extends State<_ResearchDiagramDialog> {
  ResearchDiagramKind kind = ResearchDiagramKind.memoryLayout;
  final base = TextEditingController(text: '0x140000000'),
      rva = TextEditingController(text: '0x1234');
  int bits = 64;
  String? notice;
  @override
  void dispose() {
    base.dispose();
    rva.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var serial = 0;
    final scene = CanvasScene.fromJson({
      'schemaVersion': 1,
      'elements': researchDiagram(
        kind,
        () => 'preview-${serial++}',
      ).map((e) => e.data).toList(),
    });
    AddressCalculation? calculation;
    String? problem;
    try {
      calculation = AddressCalculation(base.text, rva.text, bits: bits);
    } on FormatException catch (failure) {
      problem = failure.message;
    }
    final ready = calculation;
    return OrbitDialog(
      maxWidth: 820,
      title: const Text('Research diagrams and addresses'),
      content: SizedBox(
        width: 740,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .65,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Start from a diagram, then edit its shapes, labels and connectors on Canvas. Numbers and relationships are illustrative recorded examples.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ResearchDiagramKind>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Diagram preset',
                  ),
                  items: [
                    for (final k in ResearchDiagramKind.values)
                      DropdownMenuItem(
                        value: k,
                        child: Text(researchDiagramTitle(k)),
                      ),
                  ],
                  onChanged: (v) => setState(() => kind = v!),
                ),
                const SizedBox(height: 12),
                CanvasDiagramPreview(
                  scene: scene,
                  title: researchDiagramTitle(kind),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recorded address calculator',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Text(
                  'Unsigned base + RVA arithmetic. This does not read a process, resolve a pointer, or verify an address.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: bits,
                  decoration: const InputDecoration(labelText: 'Address width'),
                  items: [
                    for (final width in [32, 64])
                      DropdownMenuItem(value: width, child: Text('$width-bit')),
                  ],
                  onChanged: (v) => setState(() => bits = v!),
                ),
                TextField(
                  key: const ValueKey('address-base'),
                  controller: base,
                  maxLength: 18,
                  decoration: const InputDecoration(
                    labelText: 'Module base (hex)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  key: const ValueKey('address-rva'),
                  controller: rva,
                  maxLength: 18,
                  decoration: const InputDecoration(
                    labelText: 'Relative virtual address (hex)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (ready != null)
                  SelectableText(
                    'Virtual address: ${ready.hex}\nLittle-endian address bytes: ${ready.littleEndian}',
                  )
                else
                  Text(problem ?? 'Enter valid addresses.'),
                TextButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy calculation as Markdown'),
                  onPressed: ready == null
                      ? null
                      : () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: ready.markdown),
                            );
                            if (mounted) {
                              setState(() => notice = 'Calculation copied.');
                            }
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => notice =
                                    'Clipboard unavailable. Your inputs are retained.',
                              );
                            }
                          }
                        },
                ),
                if (notice != null)
                  Semantics(liveRegion: true, child: Text(notice!)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (widget.allowCalculation)
          OutlinedButton(
            onPressed: ready == null
                ? null
                : () => Navigator.pop(
                    context,
                    ResearchDiagramChoice(kind, calculation: ready.markdown),
                  ),
            child: const Text('Insert calculation'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, ResearchDiagramChoice(kind)),
          child: const Text('Insert diagram'),
        ),
      ],
    );
  }
}
