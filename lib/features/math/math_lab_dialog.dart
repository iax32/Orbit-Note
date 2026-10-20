import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/math_lab.dart';
import '../../domain/math_matrix.dart';
import '../../domain/math_result.dart';
import '../../domain/math_templates.dart';
import '../../domain/math_plot_definition.dart';
import '../../domain/math_plot_svg.dart';
import '../../platform/export_file.dart';
import 'math_plot_view.dart';
import '../notes/rich/note_math.dart';

Future<MathLabResult?> showMathLab(
  BuildContext context, {
  MathPlotDefinition? initialPlot,
}) => showDialog<MathLabResult>(
  context: context,
  builder: (_) => MathLabDialog(initialPlot: initialPlot),
);

/// Local numeric tools. Insertion is deliberate; calculations never edit a note.
class MathLabDialog extends StatefulWidget {
  const MathLabDialog({super.key, this.initialPlot});
  final MathPlotDefinition? initialPlot;
  @override
  State<MathLabDialog> createState() => _MathLabDialogState();
}

class _MathLabDialogState extends State<MathLabDialog> {
  final _expression = TextEditingController(text: 'sqrt(2)');
  final _variables = TextEditingController();
  final _point = TextEditingController(text: '1');
  final _a = TextEditingController(text: '-5');
  final _b = TextEditingController(text: '5');
  final _yMin = TextEditingController(text: '-5');
  final _yMax = TextEditingController(text: '5');
  final _matrixA = TextEditingController(text: '2 1\n1 3');
  final _matrixB = TextEditingController(text: '5\n7');
  final _search = TextEditingController();
  final _plotTitle = TextEditingController(text: 'Function plot');
  int _tab = 0;
  String _operation = 'Plot', _matrixOperation = 'Solve Ax = B';
  MathLabResult? _result;
  String? _error;
  List<TextEditingController> get _controllers => [
    _expression,
    _variables,
    _point,
    _a,
    _b,
    _yMin,
    _yMax,
    _matrixA,
    _matrixB,
    _search,
    _plotTitle,
  ];
  @override
  void initState() {
    super.initState();
    final plot = widget.initialPlot;
    if (plot != null) {
      _plotTitle.text = plot.title;
      _tab = 1;
      _operation = 'Plot';
      _expression.text = plot.functions.join('\n');
      _variables.text = plot.variables.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
      _a.text = plot.xMin.toString();
      _b.text = plot.xMax.toString();
      _yMin.text = plot.yMin.toString();
      _yMax.text = plot.yMax.toString();
    }
    for (final c in _controllers) {
      c.addListener(_invalidate);
    }
  }

  void _invalidate() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_invalidate);
      c.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController c) => parseMathNumber(c.text);
  void _example(String expression, {String variables = '', String? operation}) {
    _expression.text = expression;
    _variables.text = variables;
    setState(() {
      if (operation != null) _operation = operation;
      _result = null;
      _error = null;
    });
  }

  void _calculate() {
    // Enter in template search must not calculate a hidden function.
    if (_tab == 3) {
      return;
    }
    if (_controllers.any((c) => !c.value.composing.isCollapsed)) return;
    try {
      MathLabResult result;
      var parameters = <String, double>{};
      if (_tab == 2) {
        final a = MathMatrix.parse(_matrixA.text);
        final aTex = a.tex;
        result = switch (_matrixOperation) {
          'Transpose' => MathLabResult(
            '$aTex^{T} = ${a.transpose.tex}',
            'Matrix transpose',
          ),
          'Determinant' => MathLabResult(
            '\\det $aTex = ${mathNumberTex(a.determinant)}',
            'Numeric determinant',
          ),
          'Inverse' => MathLabResult(
            '$aTex^{-1} \\approx ${a.inverse.tex}',
            'Numeric matrix inverse',
          ),
          'Multiply A × B' => MathLabResult(
            '$aTex ${MathMatrix.parse(_matrixB.text).tex} = ${a.multiply(MathMatrix.parse(_matrixB.text)).tex}',
            'Matrix product',
          ),
          _ => MathLabResult(
            'A=$aTex,\\quad b=${MathMatrix.parse(_matrixB.text).tex},\\quad x\\approx ${a.solve(MathMatrix.parse(_matrixB.text)).tex}',
            'Numeric solution of Ax = b',
          ),
        };
      } else {
        final variables = mathVariables(_variables.text);
        if (_tab == 1) variables.remove('x'); // The function tools control x.
        parameters = variables;
        final settings = variables.isEmpty
            ? ''
            : '; parameters: ${variables.entries.map((e) => '${e.key}=${mathNumber(e.value)}').join(', ')}';
        if (_tab == 1 && ['Plot', 'Table'].contains(_operation)) {
          final definition = MathPlotDefinition.create(
            functions: _expression.text
                .split(RegExp(r'\r?\n'))
                .map((f) => f.trim())
                .where((f) => f.isNotEmpty)
                .toList(),
            variables: variables,
            xMin: _number(_a),
            xMax: _number(_b),
            yMin: _operation == 'Table' ? -1 : _number(_yMin),
            yMax: _operation == 'Table' ? 1 : _number(_yMax),
            original: _operation == 'Table'
                ? const {}
                : {...?(widget.initialPlot?.data), 'title': _plotTitle.text},
          );
          final plots = _operation == 'Plot'
              ? definition.sample()
              : <MathPlot>[];
          if (_operation == 'Plot' && plots.every((p) => p.segments.isEmpty)) {
            throw const FormatException(
              'No visible curves. Change the ranges.',
            );
          }
          final equations = List.generate(
            definition.functions.length,
            (i) =>
                'f_{${i + 1}}(x)&=${MathExpression.parse(definition.functions[i]).tex}',
          ).join(r' \\ ');
          final tex = definition.functions.length == 1
              ? 'f(x)=${MathExpression.parse(definition.functions.first).tex}'
              : r'\begin{aligned}' + equations + r'\end{aligned}';
          result = _operation == 'Plot'
              ? MathLabResult(
                  tex,
                  'Function comparison$settings\nx: [${definition.xMin}, ${definition.xMax}]; y: [${definition.yMin}, ${definition.yMax}]. 257 samples per curve; gaps may be missed.',
                  plot: plots.first,
                  plotDefinition: definition,
                )
              : MathLabResult(
                  definition.tableTex(),
                  'Value table (11 equally spaced x values, radians)$settings\nFunctions: ${definition.functions.join('; ')}. Undefined cells indicate invalid real domains.',
                  tableDefinition: definition,
                );
        } else {
          if (_expression.text.contains(RegExp(r'[\r\n]'))) {
            throw const FormatException(
              'Use one expression for values, calculus or the calculator. Plot and Table accept one function per line.',
            );
          }
          final expression = MathExpression.parse(_expression.text);
          if (_tab == 0) {
            result = MathLabResult(
              '${expression.tex} \\approx ${mathNumberTex(expression.evaluate(variables))}',
              'Calculator (real numbers, radians)$settings',
            );
          } else if (_operation == 'Value') {
            final x = _number(_point);
            result = MathLabResult(
              'f(x)=${expression.tex},\\quad f(${mathNumberTex(x)})\\approx ${mathNumberTex(expression.evaluate({...variables, 'x': x}))}',
              'Function value$settings',
            );
          } else {
            final estimate = switch (_operation) {
              'Derivative' => numericDerivative(
                expression,
                _number(_point),
                variables,
              ),
              'Integral' => numericIntegral(
                expression,
                _number(_a),
                _number(_b),
                variables,
              ),
              _ => numericRoot(expression, _number(_a), _number(_b), variables),
            };
            final lhs = switch (_operation) {
              'Derivative' =>
                '\\left.\\frac{d}{dx}\\left(${expression.tex}\\right)\\right|_{x=${mathNumberTex(_number(_point))}}',
              'Integral' =>
                '\\int_{${mathNumberTex(_number(_a))}}^{${mathNumberTex(_number(_b))}} ${expression.tex}\\,dx',
              _ => 'f(x)=${expression.tex}=0,\\quad x',
            };
            result = MathLabResult(
              '$lhs\\approx ${mathNumberTex(estimate.value)}',
              'Numerical $_operation$settings\n${_operation == 'Root' ? 'Residual' : 'Refinement difference estimate'}: ${mathNumber(estimate.error)}; ${estimate.samples} evaluations. Approximation, not a guaranteed error bound or symbolic proof.${_operation == 'Root' ? ' Bracket: [${_a.text}, ${_b.text}].' : ''}',
            );
          }
        }
      }
      setState(() {
        _result = result.withVariables(parameters);
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _result = null;
        _error = error.message;
      });
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: ValueKey('math-$label'),
      controller: controller,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: lines == 1 ? (_) => _calculate() : null,
    ),
  );
  Widget _choices(
    List<String> items,
    String selected,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items
          .map(
            (s) => ChoiceChip(
              label: Text(s),
              selected: selected == s,
              onSelected: (_) {
                setState(() {
                  changed(s);
                  _result = null;
                  _error = null;
                });
              },
            ),
          )
          .toList(),
    ),
  );
  List<Widget> _inputs() {
    if (_tab == 3) {
      return [
        _field('Search templates', _search),
        for (final template in mathLabTemplates.where(
          (t) => '${t.name} ${t.category}'.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        ))
          ListTile(
            title: Text(template.name),
            subtitle: Text(template.category),
            trailing: const Icon(Icons.add),
            selected: _result?.tex == template.tex,
            onTap: () => setState(() {
              _result = MathLabResult(template.tex, template.name);
            }),
          ),
      ];
    }
    if (_tab == 2) {
      return [
        _choices(
          [
            'Solve Ax = B',
            'Multiply A × B',
            'Inverse',
            'Determinant',
            'Transpose',
          ],
          _matrixOperation,
          (s) => _matrixOperation = s,
        ),
        const Text(
          'Up to 6×6. Spaces or commas separate cells; new lines or semicolons separate rows. B is a column vector for solving systems.',
        ),
        const SizedBox(height: 12),
        _field('Matrix A', _matrixA, lines: 4),
        if (['Solve Ax = B', 'Multiply A × B'].contains(_matrixOperation))
          _field('Matrix B', _matrixB, lines: 4),
      ];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (_tab == 0) ...[
            ActionChip(
              label: const Text('Force'),
              onPressed: () => _example(
                'mass*acceleration',
                variables: 'mass=2; acceleration=9.81',
              ),
            ),
            ActionChip(
              label: const Text('Jump height'),
              onPressed: () =>
                  _example('v*t - g*t^2/2', variables: 'v=8; t=0.5; g=9.81'),
            ),
            ActionChip(
              label: const Text('Vector length'),
              onPressed: () =>
                  _example('sqrt(a^2+b^2+c^2)', variables: 'a=3; b=4; c=0'),
            ),
          ] else ...[
            ActionChip(
              label: const Text('Compare waves'),
              onPressed: () => _example('sin(x)\ncos(x)', operation: 'Plot'),
            ),
            ActionChip(
              label: const Text('Projectile'),
              onPressed: () {
                _a.text = '0';
                _b.text = '2';
                _yMin.text = '-5';
                _yMax.text = '5';
                _example(
                  'v*x-g*x^2/2',
                  variables: 'v=8; g=9.81',
                  operation: 'Plot',
                );
              },
            ),
            ActionChip(
              label: const Text('Sine wave'),
              onPressed: () => _example('sin(x)', operation: 'Plot'),
            ),
            ActionChip(
              label: const Text('Parabola'),
              onPressed: () => _example('x^2', operation: 'Plot'),
            ),
            if (widget.initialPlot == null)
              ActionChip(
                label: const Text('Square root of 2'),
                onPressed: () {
                  _a.text = '0';
                  _b.text = '2';
                  _example('x^2-2', operation: 'Root');
                },
              ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _field(
        'Expression',
        _expression,
        lines: _tab == 1 && ['Plot', 'Table'].contains(_operation) ? 4 : 1,
        hint: 'One function per line for plots/tables (up to four)',
      ),
      const Text(
        'Real numbers • radians • pi/π, e • + − * / ^ (× and ÷ also work)\nsin, cos, tan, asin, acos, atan, sqrt, abs, exp, ln, log, floor, ceil',
      ),
      const SizedBox(height: 12),
      _field(
        'Variables',
        _variables,
        lines: 2,
        hint: 'a=2; b=3 (numeric values only)',
      ),
      if (_tab == 1) ...[
        if (_operation == 'Plot') _field('Plot title', _plotTitle),
        _choices(
          widget.initialPlot != null
              ? ['Plot']
              : ['Plot', 'Table', 'Value', 'Derivative', 'Integral', 'Root'],
          _operation,
          (s) => _operation = s,
        ),
        if (['Value', 'Derivative'].contains(_operation)) _field('x', _point),
        if (['Plot', 'Table', 'Integral', 'Root'].contains(_operation)) ...[
          _field('Lower x bound', _a),
          _field('Upper x bound', _b),
        ],
        if (_operation == 'Plot') ...[
          _field('Lower y bound', _yMin),
          _field('Upper y bound', _yMax),
        ],
        const Text(
          'Use continuous functions for calculus. Root finding requires a sign-changing bracket. Singularities and oscillation can defeat sampled estimates.',
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final values = result?.plotDefinition ?? result?.tableDefinition;
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.all(12),
      title: const Text('Math Lab'),
      content: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .66,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, name) in [
                      'Calculator',
                      'Functions',
                      'Matrices',
                      'Templates',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(name),
                          selected: i == _tab,
                          onSelected: (_) => setState(() {
                            _tab = i;
                            _result = null;
                            _error = null;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._inputs(),
              if (_tab != 3)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilledButton.icon(
                    key: const ValueKey('math-calculate'),
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(
                      _tab == 1 && _operation == 'Plot'
                          ? 'Plot function'
                          : 'Calculate',
                    ),
                  ),
                ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (result != null) ...[
                const Divider(),
                Semantics(
                  liveRegion: true,
                  child: SelectableText(result.description),
                ),
                const SizedBox(height: 12),
                if (result.plotDefinition case final definition?)
                  MathPlotView(definition: definition),
                if (values != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await Clipboard.setData(
                              ClipboardData(
                                text: values.tableText(
                                  rows: result.tableDefinition != null
                                      ? 11
                                      : 21,
                                ),
                              ),
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not copy values: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Copy values'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await exportFile(
                              'function-values.csv',
                              values.tableText(
                                separator: ',',
                                rows: result.tableDefinition != null ? 11 : 21,
                              ),
                              mimeType: 'text/csv',
                            );
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not export values: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Export CSV'),
                      ),
                      if (result.plotDefinition != null)
                        TextButton(
                          onPressed: () async {
                            try {
                              await exportFile(
                                'function-plot.svg',
                                mathPlotSvg(values),
                                mimeType: 'image/svg+xml',
                              );
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.maybeOf(
                                  context,
                                )?.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not export plot: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Export SVG'),
                        ),
                    ],
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: NoteMath(result.tex, display: true),
                  ),
                ),
                ExpansionTile(
                  title: const Text('LaTeX source'),
                  children: [SelectableText(result.tex)],
                ),
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: result.tex)),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy LaTeX'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('math-insert'),
          onPressed: result == null
              ? null
              : () => Navigator.pop(context, result),
          child: const Text('Insert result'),
        ),
      ],
    );
  }
}
