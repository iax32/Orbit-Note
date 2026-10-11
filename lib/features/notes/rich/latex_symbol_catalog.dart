import 'package:flutter/material.dart';
import '../../../app/orbit_theme.dart';
import 'latex_catalog.dart';
import 'note_math.dart';

/// The full existing registry, shared by the document palette and Equation Studio.
class LatexSymbolCatalog extends StatefulWidget {
  const LatexSymbolCatalog({super.key, required this.onInsert});
  final ValueChanged<LatexEntry> onInsert;
  @override
  State<LatexSymbolCatalog> createState() => _LatexSymbolCatalogState();
}

class _LatexSymbolCatalogState extends State<LatexSymbolCatalog> {
  String query = '', category = 'All';
  @override
  Widget build(BuildContext context) {
    final colors = OrbitColors.of(context);
    final entries = latexCatalog
        .where(
          (entry) =>
              (category == 'All' || entry.category == category) &&
              '${entry.name} ${entry.source} ${entry.glyph}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('latex-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Search symbols, names or LaTeX…',
            isDense: true,
          ),
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final name in {
                'All',
                ...latexCatalog.map((e) => e.category),
              })
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(name, style: const TextStyle(fontSize: 11)),
                    selected: category == name,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => category = name),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('No matching symbols'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    return ListTile(
                      key: ValueKey('latex-entry-${entry.source}'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        entry.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        entry.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.subtle),
                      ),
                      leading: SizedBox(
                        width: 44,
                        child: FittedBox(child: NoteMath(entry.source)),
                      ),
                      onTap: () => widget.onInsert(entry),
                    );
                  },
                ),
        ),
        Text(
          '${entries.length} entries · click to insert',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
