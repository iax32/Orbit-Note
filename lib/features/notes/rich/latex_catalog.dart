// The renderer has no public symbol-registry API. Keep this version-coupled
// adapter isolated and cover registry parity in tests when updating the package.
// ignore_for_file: implementation_imports
import 'package:flutter_math_fork/src/parser/tex/symbols.dart';
import 'package:flutter_math_fork/src/ast/types.dart';

class LatexEntry {
  const LatexEntry(this.name, this.source, this.category, [this.glyph = '']);
  final String name, source, category, glyph;
}

const latexTemplates = [
  LatexEntry('Fraction', r'\frac{\square}{\square}', 'Structures'),
  LatexEntry('Square root', r'\sqrt{\square}', 'Structures'),
  LatexEntry('Nth root', r'\sqrt[\square]{\square}', 'Structures'),
  LatexEntry('Superscript power', r'{\square}^{\square}', 'Structures'),
  LatexEntry('Subscript index', r'{\square}_{\square}', 'Structures'),
  LatexEntry(
    'Sum with limits',
    r'\sum_{\square}^{\square} \square',
    'Structures',
  ),
  LatexEntry(
    'Product with limits',
    r'\prod_{\square}^{\square} \square',
    'Structures',
  ),
  LatexEntry(
    'Definite integral',
    r'\int_{\square}^{\square} \square\,dx',
    'Structures',
  ),
  LatexEntry('Double integral', r'\iint \square\,dx\,dy', 'Structures'),
  LatexEntry('Limit', r'\lim_{\square\to\square} \square', 'Structures'),
  LatexEntry(
    'Matrix 2 by 2',
    r'\begin{pmatrix}\square & \square \\ \square & \square\end{pmatrix}',
    'Structures',
  ),
  LatexEntry(
    'Cases',
    r'\begin{cases}\square & \square \\ \square & \square\end{cases}',
    'Structures',
  ),
  LatexEntry(
    'Aligned equations',
    r'\begin{aligned}\square &= \square \\ \square &= \square\end{aligned}',
    'Structures',
  ),
  LatexEntry('Vector', r'\vec{\square}', 'Structures'),
  LatexEntry('Hat accent', r'\hat{\square}', 'Structures'),
  LatexEntry('Overline', r'\overline{\square}', 'Structures'),
  LatexEntry('Binomial coefficient', r'\binom{\square}{\square}', 'Structures'),
  LatexEntry('Scalable parentheses', r'\left(\square\right)', 'Structures'),
  LatexEntry('Set builder', r'\left\{\square\mid\square\right\}', 'Structures'),
  LatexEntry('Real numbers', r'\mathbb{R}', 'Sets and logic'),
  LatexEntry('Natural numbers', r'\mathbb{N}', 'Sets and logic'),
  LatexEntry('Integer numbers', r'\mathbb{Z}', 'Sets and logic'),
  LatexEntry('Complex numbers', r'\mathbb{C}', 'Sets and logic'),
  LatexEntry('Sine', r'\sin{\square}', 'Functions'),
  LatexEntry('Cosine', r'\cos{\square}', 'Functions'),
  LatexEntry('Tangent', r'\tan{\square}', 'Functions'),
  LatexEntry('Logarithm', r'\log{\square}', 'Functions'),
  LatexEntry('Natural logarithm', r'\ln{\square}', 'Functions'),
];

final latexCatalog = List<LatexEntry>.unmodifiable([
  ...latexTemplates,
  for (final entry in texSymbolCommandConfigs[Mode.math]!.entries)
    LatexEntry(
      entry.key.startsWith('\\') ? entry.key.substring(1) : entry.key,
      entry.key,
      _category(entry.key, entry.value),
      entry.value.symbol,
    ),
]);

String _category(String command, TexSymbolConfig config) {
  if (RegExp(
    r'alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega',
    caseSensitive: false,
  ).hasMatch(command.replaceFirst('\\', ''))) {
    return 'Greek';
  }
  if (command.toLowerCase().contains('arrow') || command.contains('harpoon')) {
    return 'Arrows';
  }
  return switch (config.type?.toString().split('.').last) {
    'rel' => 'Relations',
    'bin' => 'Operators',
    'op' => 'Operators',
    'open' || 'close' => 'Delimiters',
    _ => 'Other symbols',
  };
}
