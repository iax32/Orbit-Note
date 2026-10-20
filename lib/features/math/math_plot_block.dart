import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/math_plot_definition.dart';
import '../../domain/math_plot_svg.dart';
import '../../domain/math_lab.dart';
import '../../platform/export_file.dart';
import 'math_plot_view.dart';

class MathPlotBlock extends StatelessWidget {
  const MathPlotBlock({super.key, required this.definition, this.onEdit});
  final MathPlotDefinition definition;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(definition.title, style: theme.textTheme.titleMedium),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Edit plot'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await Clipboard.setData(
                        ClipboardData(text: definition.tableText()),
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text('Could not copy values: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy values'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await exportFile(
                        'function-plot.svg',
                        mathPlotSvg(definition),
                        mimeType: 'image/svg+xml',
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text('Could not export plot: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: const Text('Export SVG'),
                ),
              ],
            ),
            if (definition.variables.isNotEmpty)
              Text(
                'Parameters: ${definition.variables.entries.map((e) => '${e.key}=${mathNumber(e.value)}').join(', ')}',
              ),
            MathPlotView(definition: definition),
            ExpansionTile(
              title: const Text('Value table'),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('x')),
                      for (var i = 0; i < definition.functions.length; i++)
                        DataColumn(label: Text('f${i + 1}(x)')),
                    ],
                    rows: definition
                        .table()
                        .map(
                          (row) => DataRow(
                            cells: row
                                .map(
                                  (v) => DataCell(
                                    Text(
                                      v == null ? 'undefined' : mathNumber(v),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: const Text('Plot source'),
              children: [
                SelectableText(
                  definition.json,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
