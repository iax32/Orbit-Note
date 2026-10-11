import 'package:flutter/material.dart';

/// A deliberately small editable subset of standard TeX environments.
class MathGrid {
  MathGrid(this.environment, this.rows);
  final String environment;
  final List<List<String>> rows;
  static MathGrid? parse(String source) {
    final match = RegExp(
      r'^\s*\\begin\{(pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|matrix|aligned|cases)\}([\s\S]*?)\\end\{\1\}\s*$',
    ).firstMatch(source);
    if (match == null ||
        match[2]!.contains(r'\begin') ||
        match[2]!.contains(r'\&')) {
      return null;
    }
    final rows = match[2]!
        .trim()
        .split(r'\\')
        .map((r) => r.split('&').map((c) => c.trim()).toList())
        .toList();
    if (rows.isEmpty ||
        rows.length > 8 ||
        rows.first.length > 8 ||
        rows.any((r) => r.length != rows.first.length)) {
      return null;
    }
    // Nested delimiters are preserved via source editing, never guessed here.
    for (final cell in rows.expand((r) => r)) {
      var depth = 0;
      for (final rune in cell.runes) {
        if (rune == 123) depth++;
        if (rune == 125) depth--;
        if (depth < 0) return null;
      }
      if (depth != 0) return null;
    }
    return MathGrid(match[1]!, rows);
  }

  String encode() =>
      '\\begin{$environment}\n${rows.map((r) => r.join(' & ')).join(' \\\\\n')}\n\\end{$environment}';
  String toLatex() => encode();
}

Future<String?> showMathGridEditor(
  BuildContext context, {
  MathGrid? initial,
  bool aligned = false,
}) => showMathGrid(context, initial: initial, aligned: aligned);

Future<String?> showMathGrid(
  BuildContext context, {
  MathGrid? initial,
  bool aligned = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _MathGridDialog(
    initial:
        initial ??
        MathGrid(aligned ? 'aligned' : 'pmatrix', [
          ['', ''],
          ['', ''],
        ]),
  ),
);

class MathGridPreset {
  const MathGridPreset({
    required this.name,
    required this.environment,
    required this.rows,
  });
  final String name;
  final String environment;
  final List<List<String>> rows;
}

const mathGridPresets = [
  MathGridPreset(
    name: '2×2 Identity',
    environment: 'pmatrix',
    rows: [
      ['1', '0'],
      ['0', '1'],
    ],
  ),
  MathGridPreset(
    name: '3×3 Identity',
    environment: 'pmatrix',
    rows: [
      ['1', '0', '0'],
      ['0', '1', '0'],
      ['0', '0', '1'],
    ],
  ),
  MathGridPreset(
    name: '2×2 Zero',
    environment: 'pmatrix',
    rows: [
      ['0', '0'],
      ['0', '0'],
    ],
  ),
  MathGridPreset(
    name: '2D Rotation Matrix',
    environment: 'pmatrix',
    rows: [
      [r'\cos\theta', r'-\sin\theta'],
      [r'\sin\theta', r'\cos\theta'],
    ],
  ),
  MathGridPreset(
    name: '3D Column Vector',
    environment: 'pmatrix',
    rows: [
      ['x'],
      ['y'],
      ['z'],
    ],
  ),
  MathGridPreset(
    name: '2×2 Transformation',
    environment: 'pmatrix',
    rows: [
      ['a', 'b'],
      ['c', 'd'],
    ],
  ),
  MathGridPreset(
    name: '2-Case Piecewise',
    environment: 'cases',
    rows: [
      ['f(x)', r'x \ge 0'],
      ['-f(x)', 'x < 0'],
    ],
  ),
  MathGridPreset(
    name: '3-Case Piecewise',
    environment: 'cases',
    rows: [
      ['1', 'x > 0'],
      ['0', 'x = 0'],
      ['-1', 'x < 0'],
    ],
  ),
  MathGridPreset(
    name: '2×2 Linear System',
    environment: 'aligned',
    rows: [
      ['a_1 x + b_1 y', '= c_1'],
      ['a_2 x + b_2 y', '= c_2'],
    ],
  ),
];

class _MathGridDialog extends StatefulWidget {
  const _MathGridDialog({required this.initial});
  final MathGrid initial;
  @override
  State<_MathGridDialog> createState() => _MathGridDialogState();
}

class _MathGridDialogState extends State<_MathGridDialog> {
  late String environment = widget.initial.environment;
  late final rows = widget.initial.rows.map((r) => List<String>.of(r)).toList();
  int revision = 0;
  String? error;
  void structure(VoidCallback action) => setState(() {
    action();
    revision++;
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        Text(
          environment == 'aligned'
              ? 'Aligned equations'
              : environment == 'cases'
              ? 'Piecewise cases'
              : 'Matrix',
        ),
        const Spacer(),
        PopupMenuButton<MathGridPreset>(
          key: const ValueKey('math-grid-preset-button'),
          tooltip: 'Grid presets',
          onSelected: (preset) {
            structure(() {
              environment = preset.environment;
              rows.clear();
              for (final r in preset.rows) {
                rows.add(List<String>.of(r));
              }
            });
          },
          itemBuilder: (_) => [
            for (final p in mathGridPresets)
              PopupMenuItem(value: p, child: Text(p.name)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_awesome, size: 14),
                SizedBox(width: 4),
                Text('Presets', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (environment != 'aligned' && environment != 'cases')
              DropdownButton<String>(
                value:
                    [
                      'pmatrix',
                      'bmatrix',
                      'Bmatrix',
                      'vmatrix',
                      'Vmatrix',
                      'matrix',
                    ].contains(environment)
                    ? environment
                    : 'pmatrix',
                items: [
                  for (final type in [
                    'pmatrix',
                    'bmatrix',
                    'Bmatrix',
                    'vmatrix',
                    'Vmatrix',
                    'matrix',
                  ])
                    DropdownMenuItem(
                      value: type,
                      child: Text(
                        {
                          'pmatrix': 'Parentheses ( )',
                          'bmatrix': 'Brackets [ ]',
                          'Bmatrix': 'Braces { }',
                          'vmatrix': 'Determinant | |',
                          'Vmatrix': 'Norm || ||',
                          'matrix': 'Plain (no brackets)',
                        }[type]!,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => environment = v!),
              ),
            if (environment == 'aligned')
              const Text(
                'Left and right columns align at the relation (&). Tab moves between cells.',
              ),
            if (environment == 'cases')
              const Text('Piecewise cases: expression & condition.'),
            for (var r = 0; r < rows.length; r++)
              Row(
                children: [
                  for (var c = 0; c < rows[r].length; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextFormField(
                          key: ValueKey('math-cell-$revision-$r-$c'),
                          initialValue: rows[r][c],
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: '${r + 1}, ${c + 1}',
                          ),
                          onChanged: (v) => rows[r][c] = v,
                        ),
                      ),
                    ),
                ],
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: rows.length < 8
                      ? () => structure(
                          () => rows.add(
                            List.filled(rows.first.length, '', growable: true),
                          ),
                        )
                      : null,
                  child: const Text('Add row'),
                ),
                TextButton(
                  onPressed: rows.length > 1
                      ? () => structure(() => rows.removeLast())
                      : null,
                  child: const Text('Remove last row'),
                ),
                if (environment != 'aligned') ...[
                  TextButton(
                    onPressed: rows.first.length < 8
                        ? () => structure(() {
                            for (final row in rows) {
                              row.add('');
                            }
                          })
                        : null,
                    child: const Text('Add column'),
                  ),
                  TextButton(
                    onPressed: rows.first.length > 1
                        ? () => structure(() {
                            for (final row in rows) {
                              row.removeLast();
                            }
                          })
                        : null,
                    child: const Text('Remove last column'),
                  ),
                ],
              ],
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
        onPressed: () {
          final grid = MathGrid(environment, rows);
          final source = grid.encode();
          if (rows
                  .expand((r) => r)
                  .any((c) => c.contains('&') || c.contains(r'\\')) ||
              MathGrid.parse(source) == null) {
            setState(
              () => error =
                  'Use the row and column buttons for structure; balance braces within each cell.',
            );
            return;
          }
          Navigator.pop(context, source);
        },
        child: const Text('Apply grid'),
      ),
    ],
  );
}
