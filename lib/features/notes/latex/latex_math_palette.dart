import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import '../../../domain/math_templates.dart';
import '../../notes/rich/math_grid_editor.dart';

class LatexSymbolItem {
  const LatexSymbolItem({
    required this.name,
    required this.latex,
    required this.category,
    required this.symbol,
    this.aliases = const [],
    this.isTemplate = false,
  });

  final String name;
  final String latex;
  final String category;
  final String symbol;
  final List<String> aliases;
  final bool isTemplate;
}

class LatexMathPaletteData {
  static final List<LatexSymbolItem> items = List.unmodifiable([
    ..._legacyItems,
    for (final t in mathLabTemplates)
      LatexSymbolItem(
        name: t.name,
        latex: t.tex,
        category: t.category,
        symbol: '∑',
        isTemplate: true,
      ),
  ]);
  static const List<LatexSymbolItem> _legacyItems = [
    // BASIC
    LatexSymbolItem(
      name: 'Fraction',
      latex: r'\frac{\square}{\square}',
      category: 'Basic',
      symbol: '½',
      aliases: ['fraction', 'divide', 'over', 'frac'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Square root',
      latex: r'\sqrt{\square}',
      category: 'Basic',
      symbol: '√',
      aliases: ['square root', 'sqrt', 'root', 'radical'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Nth root',
      latex: r'\sqrt[\square]{\square}',
      category: 'Basic',
      symbol: '∛',
      aliases: ['nth root', 'cbrt', 'cube root', 'root'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Exponent / Power',
      latex: r'{\square}^{\square}',
      category: 'Basic',
      symbol: 'x²',
      aliases: ['exponent', 'power', 'superscript', 'caret'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Subscript',
      latex: r'{\square}_{\square}',
      category: 'Basic',
      symbol: 'x₁',
      aliases: ['subscript', 'index'],
      isTemplate: true,
    ),

    // OPERATORS
    LatexSymbolItem(
      name: 'Plus-minus',
      latex: r'\pm',
      category: 'Operators',
      symbol: '±',
      aliases: ['plus minus', 'pm'],
    ),
    LatexSymbolItem(
      name: 'Minus-plus',
      latex: r'\mp',
      category: 'Operators',
      symbol: '∓',
      aliases: ['minus plus', 'mp'],
    ),
    LatexSymbolItem(
      name: 'Times (cross)',
      latex: r'\times',
      category: 'Operators',
      symbol: '×',
      aliases: ['times', 'cross', 'multiply'],
    ),
    LatexSymbolItem(
      name: 'Divide',
      latex: r'\div',
      category: 'Operators',
      symbol: '÷',
      aliases: ['divide', 'div'],
    ),
    LatexSymbolItem(
      name: 'Center dot',
      latex: r'\cdot',
      category: 'Operators',
      symbol: '·',
      aliases: ['dot', 'cdot', 'multiply'],
    ),
    LatexSymbolItem(
      name: 'Composition',
      latex: r'\circ',
      category: 'Operators',
      symbol: '∘',
      aliases: ['compose', 'circle', 'ring'],
    ),
    LatexSymbolItem(
      name: 'Infinity',
      latex: r'\infty',
      category: 'Operators',
      symbol: '∞',
      aliases: ['infinity', 'inf'],
    ),

    // RELATIONS
    LatexSymbolItem(
      name: 'Equal',
      latex: '=',
      category: 'Relations',
      symbol: '=',
      aliases: ['equals', 'eq'],
    ),
    LatexSymbolItem(
      name: 'Not equal',
      latex: r'\neq',
      category: 'Relations',
      symbol: '≠',
      aliases: ['not equal', 'ne', '!='],
    ),
    LatexSymbolItem(
      name: 'Approximately equal',
      latex: r'\approx',
      category: 'Relations',
      symbol: '≈',
      aliases: ['approx', 'almost equal', '~='],
    ),
    LatexSymbolItem(
      name: 'Equivalent / Congruent',
      latex: r'\equiv',
      category: 'Relations',
      symbol: '≡',
      aliases: ['equiv', 'congruent', 'triple equal'],
    ),
    LatexSymbolItem(
      name: 'Less than or equal',
      latex: r'\le',
      category: 'Relations',
      symbol: '≤',
      aliases: ['less equal', 'le', '<='],
    ),
    LatexSymbolItem(
      name: 'Greater than or equal',
      latex: r'\ge',
      category: 'Relations',
      symbol: '≥',
      aliases: ['greater equal', 'ge', '>='],
    ),
    LatexSymbolItem(
      name: 'Proportional to',
      latex: r'\propto',
      category: 'Relations',
      symbol: '∝',
      aliases: ['proportional', 'propto'],
    ),
    LatexSymbolItem(
      name: 'Much less than',
      latex: r'\ll',
      category: 'Relations',
      symbol: '≪',
      aliases: ['much less', 'll', '<<'],
    ),
    LatexSymbolItem(
      name: 'Much greater than',
      latex: r'\gg',
      category: 'Relations',
      symbol: '≫',
      aliases: ['much greater', 'gg', '>>'],
    ),

    // SETS
    LatexSymbolItem(
      name: 'Element of / Belongs to',
      latex: r'\in',
      category: 'Sets',
      symbol: '∈',
      aliases: ['in', 'belongs to', 'member of', 'element of'],
    ),
    LatexSymbolItem(
      name: 'Not element of',
      latex: r'\notin',
      category: 'Sets',
      symbol: '∉',
      aliases: ['not in', 'does not belong to', 'notin'],
    ),
    LatexSymbolItem(
      name: 'Subset',
      latex: r'\subset',
      category: 'Sets',
      symbol: '⊂',
      aliases: ['subset', 'proper subset'],
    ),
    LatexSymbolItem(
      name: 'Subset or equal',
      latex: r'\subseteq',
      category: 'Sets',
      symbol: '⊆',
      aliases: ['subset equal', 'subseteq'],
    ),
    LatexSymbolItem(
      name: 'Superset',
      latex: r'\supset',
      category: 'Sets',
      symbol: '⊃',
      aliases: ['superset'],
    ),
    LatexSymbolItem(
      name: 'Superset or equal',
      latex: r'\supseteq',
      category: 'Sets',
      symbol: '⊇',
      aliases: ['superset equal', 'supseteq'],
    ),
    LatexSymbolItem(
      name: 'Union',
      latex: r'\cup',
      category: 'Sets',
      symbol: '∪',
      aliases: ['union', 'cup', 'or'],
    ),
    LatexSymbolItem(
      name: 'Intersection',
      latex: r'\cap',
      category: 'Sets',
      symbol: '∩',
      aliases: ['intersection', 'cap', 'and'],
    ),
    LatexSymbolItem(
      name: 'Empty set',
      latex: r'\emptyset',
      category: 'Sets',
      symbol: '∅',
      aliases: ['empty set', 'null set', 'emptyset', 'nothing'],
    ),
    LatexSymbolItem(
      name: 'Real numbers',
      latex: r'\mathbb{R}',
      category: 'Sets',
      symbol: 'ℝ',
      aliases: ['real numbers', 'reals', 'R'],
    ),
    LatexSymbolItem(
      name: 'Natural numbers',
      latex: r'\mathbb{N}',
      category: 'Sets',
      symbol: 'ℕ',
      aliases: ['natural numbers', 'naturals', 'N'],
    ),
    LatexSymbolItem(
      name: 'Integers',
      latex: r'\mathbb{Z}',
      category: 'Sets',
      symbol: 'ℤ',
      aliases: ['integers', 'Z'],
    ),
    LatexSymbolItem(
      name: 'Rational numbers',
      latex: r'\mathbb{Q}',
      category: 'Sets',
      symbol: 'ℚ',
      aliases: ['rational numbers', 'rationals', 'Q'],
    ),
    LatexSymbolItem(
      name: 'Complex numbers',
      latex: r'\mathbb{C}',
      category: 'Sets',
      symbol: 'ℂ',
      aliases: ['complex numbers', 'C'],
    ),

    // LOGIC
    LatexSymbolItem(
      name: 'For all (Universal quantifier)',
      latex: r'\forall',
      category: 'Logic',
      symbol: '∀',
      aliases: ['for all', 'forall', 'every'],
    ),
    LatexSymbolItem(
      name: 'There exists (Existential quantifier)',
      latex: r'\exists',
      category: 'Logic',
      symbol: '∃',
      aliases: ['there exists', 'exists'],
    ),
    LatexSymbolItem(
      name: 'Not / Negation',
      latex: r'\neg',
      category: 'Logic',
      symbol: '¬',
      aliases: ['not', 'neg', 'negation'],
    ),
    LatexSymbolItem(
      name: 'Logical And (Conjunction)',
      latex: r'\land',
      category: 'Logic',
      symbol: '∧',
      aliases: ['and', 'land', 'conjunction'],
    ),
    LatexSymbolItem(
      name: 'Logical Or (Disjunction)',
      latex: r'\lor',
      category: 'Logic',
      symbol: '∨',
      aliases: ['or', 'lor', 'disjunction'],
    ),
    LatexSymbolItem(
      name: 'Implies',
      latex: r'\implies',
      category: 'Logic',
      symbol: '⇒',
      aliases: ['implies', 'then', '=>'],
    ),
    LatexSymbolItem(
      name: 'If and only if (Iff)',
      latex: r'\iff',
      category: 'Logic',
      symbol: '⇔',
      aliases: ['iff', 'if and only if', 'equivalent', '<=>'],
    ),

    // CALCULUS
    LatexSymbolItem(
      name: 'Definite integral',
      latex: r'\int_{\square}^{\square} \square \, dx',
      category: 'Calculus',
      symbol: '∫',
      aliases: ['integral', 'integrate', 'int'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Double integral',
      latex: r'\iint_{\square} \square \, dA',
      category: 'Calculus',
      symbol: '∬',
      aliases: ['double integral', 'iint'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Summation',
      latex: r'\sum_{\square}^{\square} \square',
      category: 'Calculus',
      symbol: '∑',
      aliases: ['sum', 'summation', 'sigma'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Product with limits',
      latex: r'\prod_{\square}^{\square} \square',
      category: 'Calculus',
      symbol: '∏',
      aliases: ['product', 'pi product', 'prod'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Limit',
      latex: r'\lim_{\square \to \square} \square',
      category: 'Calculus',
      symbol: 'lim',
      aliases: ['limit', 'lim', 'approaches'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Partial derivative',
      latex: r'\partial',
      category: 'Calculus',
      symbol: '∂',
      aliases: ['partial', 'del', 'derivative'],
    ),
    LatexSymbolItem(
      name: 'Nabla / Gradient',
      latex: r'\nabla',
      category: 'Calculus',
      symbol: '∇',
      aliases: ['gradient', 'nabla', 'grad', 'curl'],
    ),

    // GREEK (LOWERCASE)
    LatexSymbolItem(
      name: 'Alpha',
      latex: r'\alpha',
      category: 'Greek',
      symbol: 'α',
      aliases: ['alpha'],
    ),
    LatexSymbolItem(
      name: 'Beta',
      latex: r'\beta',
      category: 'Greek',
      symbol: 'β',
      aliases: ['beta'],
    ),
    LatexSymbolItem(
      name: 'Gamma',
      latex: r'\gamma',
      category: 'Greek',
      symbol: 'γ',
      aliases: ['gamma'],
    ),
    LatexSymbolItem(
      name: 'Delta',
      latex: r'\delta',
      category: 'Greek',
      symbol: 'δ',
      aliases: ['delta'],
    ),
    LatexSymbolItem(
      name: 'Epsilon',
      latex: r'\epsilon',
      category: 'Greek',
      symbol: 'ε',
      aliases: ['epsilon'],
    ),
    LatexSymbolItem(
      name: 'Theta',
      latex: r'\theta',
      category: 'Greek',
      symbol: 'θ',
      aliases: ['theta', 'angle'],
    ),
    LatexSymbolItem(
      name: 'Lambda',
      latex: r'\lambda',
      category: 'Greek',
      symbol: 'λ',
      aliases: ['lambda', 'eigenvalue'],
    ),
    LatexSymbolItem(
      name: 'Mu',
      latex: r'\mu',
      category: 'Greek',
      symbol: 'μ',
      aliases: ['mu', 'mean', 'micro'],
    ),
    LatexSymbolItem(
      name: 'Pi',
      latex: r'\pi',
      category: 'Greek',
      symbol: 'π',
      aliases: ['pi', '3.14'],
    ),
    LatexSymbolItem(
      name: 'Rho',
      latex: r'\rho',
      category: 'Greek',
      symbol: 'ρ',
      aliases: ['rho', 'density'],
    ),
    LatexSymbolItem(
      name: 'Sigma',
      latex: r'\sigma',
      category: 'Greek',
      symbol: 'σ',
      aliases: ['sigma', 'std dev'],
    ),
    LatexSymbolItem(
      name: 'Tau',
      latex: r'\tau',
      category: 'Greek',
      symbol: 'τ',
      aliases: ['tau'],
    ),
    LatexSymbolItem(
      name: 'Phi',
      latex: r'\phi',
      category: 'Greek',
      symbol: 'φ',
      aliases: ['phi'],
    ),
    LatexSymbolItem(
      name: 'Psi',
      latex: r'\psi',
      category: 'Greek',
      symbol: 'ψ',
      aliases: ['psi'],
    ),
    LatexSymbolItem(
      name: 'Omega',
      latex: r'\omega',
      category: 'Greek',
      symbol: 'ω',
      aliases: ['omega'],
    ),

    // GREEK (UPPERCASE)
    LatexSymbolItem(
      name: 'Gamma (cap)',
      latex: r'\Gamma',
      category: 'Greek',
      symbol: 'Γ',
      aliases: ['gamma capital'],
    ),
    LatexSymbolItem(
      name: 'Delta (cap)',
      latex: r'\Delta',
      category: 'Greek',
      symbol: 'Δ',
      aliases: ['delta capital', 'difference', 'laplacian'],
    ),
    LatexSymbolItem(
      name: 'Theta (cap)',
      latex: r'\Theta',
      category: 'Greek',
      symbol: 'Θ',
      aliases: ['theta capital'],
    ),
    LatexSymbolItem(
      name: 'Lambda (cap)',
      latex: r'\Lambda',
      category: 'Greek',
      symbol: 'Λ',
      aliases: ['lambda capital'],
    ),
    LatexSymbolItem(
      name: 'Sigma (cap)',
      latex: r'\Sigma',
      category: 'Greek',
      symbol: 'Σ',
      aliases: ['sigma capital'],
    ),
    LatexSymbolItem(
      name: 'Phi (cap)',
      latex: r'\Phi',
      category: 'Greek',
      symbol: 'Φ',
      aliases: ['phi capital'],
    ),
    LatexSymbolItem(
      name: 'Psi (cap)',
      latex: r'\Psi',
      category: 'Greek',
      symbol: 'Ψ',
      aliases: ['psi capital'],
    ),
    LatexSymbolItem(
      name: 'Omega (cap)',
      latex: r'\Omega',
      category: 'Greek',
      symbol: 'Ω',
      aliases: ['omega capital', 'ohm'],
    ),

    // ARROWS
    LatexSymbolItem(
      name: 'Right arrow / To',
      latex: r'\to',
      category: 'Arrows',
      symbol: '→',
      aliases: ['right arrow', 'to', '->'],
    ),
    LatexSymbolItem(
      name: 'Left arrow',
      latex: r'\leftarrow',
      category: 'Arrows',
      symbol: '←',
      aliases: ['left arrow', '<-'],
    ),
    LatexSymbolItem(
      name: 'Left-right arrow',
      latex: r'\leftrightarrow',
      category: 'Arrows',
      symbol: '↔',
      aliases: ['left right arrow', '<->'],
    ),
    LatexSymbolItem(
      name: 'Maps to',
      latex: r'\mapsto',
      category: 'Arrows',
      symbol: '↦',
      aliases: ['maps to', 'mapsto'],
    ),
    LatexSymbolItem(
      name: 'Double right arrow',
      latex: r'\Rightarrow',
      category: 'Arrows',
      symbol: '⇒',
      aliases: ['implies', '=>'],
    ),
    LatexSymbolItem(
      name: 'Double left-right arrow',
      latex: r'\Leftrightarrow',
      category: 'Arrows',
      symbol: '⇔',
      aliases: ['iff', '<=>'],
    ),

    // LINEAR ALGEBRA
    LatexSymbolItem(
      name: 'Matrix 2x2 (Round)',
      latex:
          r'\begin{pmatrix} \square & \square \\ \square & \square \end{pmatrix}',
      category: 'Linear Algebra',
      symbol: '[M]',
      aliases: ['matrix', 'pmatrix', '2x2'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Matrix 2x2 (Square)',
      latex:
          r'\begin{bmatrix} \square & \square \\ \square & \square \end{bmatrix}',
      category: 'Linear Algebra',
      symbol: '[B]',
      aliases: ['matrix', 'bmatrix', 'brackets'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Determinant 2x2',
      latex:
          r'\begin{vmatrix} \square & \square \\ \square & \square \end{vmatrix}',
      category: 'Linear Algebra',
      symbol: '|M|',
      aliases: ['determinant', 'det', 'vmatrix'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Cases / Piecewise',
      latex:
          r'\begin{cases} \square & \text{if } \square \\ \square & \text{if } \square \end{cases}',
      category: 'Linear Algebra',
      symbol: '{fx',
      aliases: ['cases', 'piecewise', 'condition'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Aligned equations',
      latex:
          r'\begin{aligned} \square &= \square \\ \square &= \square \end{aligned}',
      category: 'Linear Algebra',
      symbol: '&=',
      aliases: ['aligned', 'align', 'system of equations'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Vector',
      latex: r'\vec{\square}',
      category: 'Linear Algebra',
      symbol: 'v⃗',
      aliases: ['vector', 'arrow'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Norm',
      latex: r'\|\square\|',
      category: 'Linear Algebra',
      symbol: '‖v‖',
      aliases: ['norm', 'length'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Transpose',
      latex: r'{\square}^{\top}',
      category: 'Linear Algebra',
      symbol: 'Aᵀ',
      aliases: ['transpose', 'top'],
      isTemplate: true,
    ),

    // BRACKETS
    LatexSymbolItem(
      name: 'Scalable Parentheses',
      latex: r'\left( \square \right)',
      category: 'Brackets',
      symbol: '( )',
      aliases: ['parentheses', 'parens'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Scalable Brackets',
      latex: r'\left[ \square \right]',
      category: 'Brackets',
      symbol: '[ ]',
      aliases: ['brackets', 'square brackets'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Scalable Braces',
      latex: r'\left\{ \square \right\}',
      category: 'Brackets',
      symbol: '{ }',
      aliases: ['braces', 'curly brackets'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Angle Brackets',
      latex: r'\langle \square \rangle',
      category: 'Brackets',
      symbol: '⟨ ⟩',
      aliases: ['angle brackets', 'inner product', 'bra ket'],
      isTemplate: true,
    ),
    LatexSymbolItem(
      name: 'Absolute Value',
      latex: r'|\square|',
      category: 'Brackets',
      symbol: '|x|',
      aliases: ['abs', 'absolute value', 'bars'],
      isTemplate: true,
    ),
  ];

  static const List<String> categories = [
    'All',
    'Basic',
    'Operators',
    'Relations',
    'Sets',
    'Logic',
    'Calculus',
    'Greek',
    'Linear Algebra',
    'Brackets',
    'Arrows',
  ];
}

typedef LatexMathPalette = LatexMathPaletteDialog;

class LatexMathPaletteDialog extends StatefulWidget {
  const LatexMathPaletteDialog({super.key, required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  State<LatexMathPaletteDialog> createState() => _LatexMathPaletteDialogState();
}

class _LatexMathPaletteDialogState extends State<LatexMathPaletteDialog> {
  String _query = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final q = _query.toLowerCase().trim();
    final filtered = LatexMathPaletteData.items.where((item) {
      if (_selectedCategory != 'All' && item.category != _selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      if (item.name.toLowerCase().contains(q)) return true;
      if (item.latex.toLowerCase().contains(q)) return true;
      if (item.symbol.toLowerCase().contains(q)) return true;
      for (final a in item.aliases) {
        if (a.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();

    return Dialog(
      backgroundColor: OrbitColors.of(context).panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.functions,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Math symbols',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search bar
              TextField(
                key: const ValueKey('math-palette-search'),
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText:
                      'Search by symbol, name, alias (e.g. "belongs to", "real numbers", "\\forall")...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),

              // Categories scroll
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: LatexMathPaletteData.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final cat = LatexMathPaletteData.categories[i];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Grid of symbols
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No symbols match "$_query"',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 105,
                              childAspectRatio: 1.15,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onInsert(item.latex);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF262638)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: FittedBox(
                                        child: Text(
                                          item.symbol,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const Divider(),

              // Quick Structure Builders footer
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} symbols found',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.grid_on, size: 14),
                          label: const Text(
                            'Matrix / Grid',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final result = await showMathGrid(context);
                            if (result != null && context.mounted) {
                              Navigator.of(context).pop();
                              widget.onInsert(result);
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.alt_route, size: 14),
                          label: const Text(
                            'Cases',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onInsert(
                              r'\begin{cases} \square & \text{if } \square \\ \square & \text{if } \square \end{cases}',
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.format_align_left, size: 14),
                          label: const Text(
                            'Aligned',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final result = await showMathGrid(
                              context,
                              aligned: true,
                            );
                            if (result != null && context.mounted) {
                              Navigator.of(context).pop();
                              widget.onInsert(result);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
