import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';

/// One bounded browser shared by appearance settings and the import gallery.
/// Its enclosing settings/dialog owns scrolling, including at large text sizes.
class ThemePaletteBrowser extends StatefulWidget {
  const ThemePaletteBrowser({
    super.key,
    required this.packs,
    required this.activeId,
    required this.onApply,
    required this.itemBuilder,
    this.grid = true,
    this.categoryOf,
  });
  final List<OrbitThemePack> packs;
  final String activeId;
  final ValueChanged<OrbitThemePack> onApply;
  final Widget Function(
    OrbitThemePack pack,
    double width,
    bool selected,
    VoidCallback apply,
  )
  itemBuilder;
  final String Function(OrbitThemePack)? categoryOf;
  final bool grid;
  @override
  State<ThemePaletteBrowser> createState() => _ThemePaletteBrowserState();
}

class _ThemePaletteBrowserState extends State<ThemePaletteBrowser> {
  final _search = TextEditingController();
  String _mode = 'all', _category = 'All families';
  late String _activeId = widget.activeId;
  int _page = 0;
  static const _pageSize = 6;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ThemePaletteBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeId != widget.activeId) _activeId = widget.activeId;
  }

  String category(OrbitThemePack pack) =>
      widget.categoryOf?.call(pack) ?? pack.category;
  void apply(OrbitThemePack pack) {
    widget.onApply(pack);
    setState(() => _activeId = pack.id);
  }

  void switchPair(OrbitThemePack pack) {
    apply(pack);
    setState(() {
      _search.clear();
      _mode = pack.brightness.name;
      _category = category(pack);
      final siblings = widget.packs
          .where(
            (p) => p.brightness == pack.brightness && category(p) == _category,
          )
          .toList();
      _page = siblings.indexWhere((p) => p.id == pack.id) ~/ _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final categories = {'All families', ...widget.packs.map(category)};
    if (!categories.contains(_category)) _category = 'All families';
    final filtered = widget.packs
        .where(
          (pack) =>
              (_mode == 'all' || pack.brightness.name == _mode) &&
              (_category == 'All families' || category(pack) == _category) &&
              '${pack.name} ${pack.description} ${category(pack)}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final pages = ((filtered.length + _pageSize - 1) ~/ _pageSize).clamp(
      1,
      1000000,
    );
    _page = _page.clamp(0, pages - 1);
    OrbitThemePack? active;
    for (final pack in widget.packs) {
      if (pack.id == _activeId) {
        active = pack;
        break;
      }
    }
    final companion = active?.companion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('theme-palette-search'),
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Find a palette',
            hintText: 'Sage, warm, blue, studio…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear palette search',
                    onPressed: () => setState(() {
                      _search.clear();
                      _page = 0;
                    }),
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (_) => setState(() => _page = 0),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in const [
              ('all', 'All modes'),
              ('light', 'Light'),
              ('dark', 'Dark'),
            ])
              ChoiceChip(
                key: ValueKey('theme-mode-${entry.$1}'),
                label: Text(entry.$2),
                selected: _mode == entry.$1,
                onSelected: (_) => setState(() {
                  _mode = entry.$1;
                  _page = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Collection'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('theme-family-filter'),
              value: _category,
              isExpanded: true,
              items: [
                for (final value in categories)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: (value) => setState(() {
                _category = value ?? 'All families';
                _page = 0;
              }),
            ),
          ),
        ),
        if (active != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Active: ${active.name}'),
              TextButton(
                key: const ValueKey('theme-show-active'),
                onPressed: () => setState(() {
                  _search.clear();
                  _mode = 'all';
                  _category = 'All families';
                  _page =
                      widget.packs.indexWhere((p) => p.id == _activeId) ~/
                      _pageSize;
                }),
                child: const Text('Show active'),
              ),
              if (companion != null)
                TextButton.icon(
                  key: const ValueKey('theme-switch-pair'),
                  onPressed: () => switchPair(companion),
                  icon: Icon(
                    companion.brightness == Brightness.light
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 16,
                  ),
                  label: Text(
                    'Switch to ${companion.brightness == Brightness.light ? 'light' : 'dark'}',
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                '${filtered.length} palettes · Page ${_page + 1} of $pages',
              ),
            ),
            OutlinedButton(
              key: const ValueKey('theme-page-previous'),
              onPressed: _page == 0 ? null : () => setState(() => _page--),
              child: const Text('Previous'),
            ),
            OutlinedButton(
              key: const ValueKey('theme-page-next'),
              onPressed: _page + 1 >= pages
                  ? null
                  : () => setState(() => _page++),
              child: const Text('Next'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No palettes match. Try another name, collection or appearance.',
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final scaled = MediaQuery.textScalerOf(context).scale(14);
            final columns = !widget.grid || scaled > 21
                ? 1
                : (width >= 720
                      ? 3
                      : width >= 440
                      ? 2
                      : 1);
            final cardWidth = (width - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final pack
                    in filtered.skip(_page * _pageSize).take(_pageSize))
                  widget.itemBuilder(
                    pack,
                    cardWidth,
                    pack.id == _activeId,
                    () => apply(pack),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
