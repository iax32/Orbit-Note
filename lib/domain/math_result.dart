import 'math_lab.dart';
import 'math_plot_definition.dart';

class MathLabResult {
  const MathLabResult(
    this.tex,
    this.description, {
    this.plot,
    this.plotDefinition,
    this.tableDefinition,
  });
  final String tex, description;
  final MathPlot? plot;
  final MathPlotDefinition? plotDefinition;
  final MathPlotDefinition? tableDefinition;
  String get equationMarkdown => '$description\n\n\$\$\n$tex\n\$\$';
  String get markdown => plotDefinition?.markdown ?? equationMarkdown;

  /// Keep the inputs with the result even in a TeX-only host.
  MathLabResult withVariables(Map<String, double> variables) {
    if (variables.isEmpty) return this;
    final definitions = variables.entries
        .map((e) {
          if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,39}$').hasMatch(e.key)) {
            throw const FormatException('Invalid variable name.');
          }
          final name = '\\mathrm{${e.key.replaceAll('_', r'\_')}}';
          return '$name=${mathNumberTex(e.value)}';
        })
        .join(r',\quad ');
    return MathLabResult(
      '$tex,\\quad $definitions',
      description,
      plot: plot,
      plotDefinition: plotDefinition,
      tableDefinition: tableDefinition,
    );
  }
}
