part of 'orbit_theme.dart';

/// Authored surface and accent choices, rather than a hue-wheel recoloring of
/// one background. Light and dark variants share an identity, not RGB inversion.
class _OrbitPaletteRecipe {
  const _OrbitPaletteRecipe(
    this.id,
    this.name,
    this.category,
    this.description,
    this.paper,
    this.night,
    this.accent,
  );
  final String id, name, category, description;
  final int paper, night, accent;
}

const _orbitPaletteRecipes = <_OrbitPaletteRecipe>[
  _OrbitPaletteRecipe(
    'porcelain',
    'Porcelain',
    'Studio',
    'Clean mineral neutrals with a considered blue accent.',
    0xfff5f6f8,
    0xff161b23,
    0xff567caa,
  ),
  _OrbitPaletteRecipe(
    'graphite',
    'Graphite Atelier',
    'Studio',
    'Warm graphite and soft stone with restrained violet.',
    0xfff4f2ef,
    0xff211f24,
    0xff8676ad,
  ),
  _OrbitPaletteRecipe(
    'silverline',
    'Silverline',
    'Studio',
    'Silver-grey surfaces and precise steel-blue details.',
    0xfff0f3f5,
    0xff1a2229,
    0xff608799,
  ),
  _OrbitPaletteRecipe(
    'obsidian',
    'Obsidian Ink',
    'Studio',
    'Neutral ink and ivory with quiet indigo focus.',
    0xfff8f7f3,
    0xff141518,
    0xff777da7,
  ),
  _OrbitPaletteRecipe(
    'monochrome',
    'Monochrome',
    'Studio',
    'A neutral editorial palette for undistracted writing.',
    0xfff3f3f1,
    0xff202120,
    0xff737b78,
  ),
  _OrbitPaletteRecipe(
    'atlantic',
    'Atlantic',
    'Ocean',
    'Deep Atlantic blue with a clear horizon accent.',
    0xfff0f5f8,
    0xff142337,
    0xff548ec0,
  ),
  _OrbitPaletteRecipe(
    'lagoon',
    'Lagoon',
    'Ocean',
    'Watery turquoise over warm, pale coastal surfaces.',
    0xfff0f7f4,
    0xff152d30,
    0xff459b9c,
  ),
  _OrbitPaletteRecipe(
    'tidepool',
    'Tidepool',
    'Ocean',
    'Sea-glass greens and blue-grey stone.',
    0xffedf5f3,
    0xff192c2c,
    0xff5e9d8c,
  ),
  _OrbitPaletteRecipe(
    'fjord',
    'Fjord',
    'Ocean',
    'Cool fjord slate with gentle northern blue.',
    0xfff1f4f6,
    0xff202d3a,
    0xff6e94b0,
  ),
  _OrbitPaletteRecipe(
    'harbor',
    'Harbor',
    'Ocean',
    'Weathered harbour neutrals and muted marina teal.',
    0xfff4f5ef,
    0xff202c31,
    0xff608f91,
  ),
  _OrbitPaletteRecipe(
    'cerulean',
    'Cerulean',
    'Ocean',
    'Open-water blue balanced by barely tinted paper.',
    0xfff0f6fb,
    0xff172536,
    0xff418bb3,
  ),
  _OrbitPaletteRecipe(
    'sage',
    'Sage Garden',
    'Forest',
    'Soft sage paper and eucalyptus-grey shadows.',
    0xfff1f5ed,
    0xff222b24,
    0xff7d9872,
  ),
  _OrbitPaletteRecipe(
    'moss',
    'Moss',
    'Forest',
    'Woodland moss and natural chalk neutrals.',
    0xfff3f4e9,
    0xff292d20,
    0xff89904e,
  ),
  _OrbitPaletteRecipe(
    'fern',
    'Fern',
    'Forest',
    'Fresh fern green with warm, readable surfaces.',
    0xffedf5ef,
    0xff192c22,
    0xff56956d,
  ),
  _OrbitPaletteRecipe(
    'pine',
    'Pine',
    'Forest',
    'Evergreen ink with a soft forest-green accent.',
    0xffeff4f0,
    0xff172824,
    0xff4e8d79,
  ),
  _OrbitPaletteRecipe(
    'eucalyptus',
    'Eucalyptus',
    'Forest',
    'Airy grey-green with cool leaf highlights.',
    0xffedf5f2,
    0xff202f2d,
    0xff77a394,
  ),
  _OrbitPaletteRecipe(
    'olive',
    'Olive Grove',
    'Forest',
    'Dry olive leaves and warm limestone.',
    0xfff6f4e9,
    0xff2d2d22,
    0xff919260,
  ),
  _OrbitPaletteRecipe(
    'linen',
    'Linen',
    'Earth',
    'Natural linen, warm charcoal and a quiet bronze accent.',
    0xfff6f1e8,
    0xff2b2621,
    0xffab8b66,
  ),
  _OrbitPaletteRecipe(
    'sandstone',
    'Sandstone',
    'Earth',
    'Pale sandstone and desert shadows with terracotta detail.',
    0xfff8f0e5,
    0xff302720,
    0xffb88c63,
  ),
  _OrbitPaletteRecipe(
    'terracotta',
    'Terracotta',
    'Earth',
    'Baked clay accents on balanced mineral surfaces.',
    0xfff8eee8,
    0xff32241f,
    0xffb86f55,
  ),
  _OrbitPaletteRecipe(
    'copper',
    'Copper',
    'Earth',
    'Soft copper and walnut tones for a tactile workspace.',
    0xfff5eee7,
    0xff2c2422,
    0xffb47d5c,
  ),
  _OrbitPaletteRecipe(
    'clay',
    'Clay Studio',
    'Earth',
    'Warm grey pottery tones with dusty red focus.',
    0xfff3eeeb,
    0xff2c2627,
    0xffa47d76,
  ),
  _OrbitPaletteRecipe(
    'sepia',
    'Sepia Archive',
    'Earth',
    'Archival paper and sepia ink for long reading sessions.',
    0xfff7f1e2,
    0xff2b251c,
    0xff9e8656,
  ),
  _OrbitPaletteRecipe(
    'walnut',
    'Walnut',
    'Earth',
    'Creamy paper and deep walnut with caramel highlights.',
    0xfff3eee5,
    0xff29231e,
    0xff9f8063,
  ),
  _OrbitPaletteRecipe(
    'lavender',
    'Lavender',
    'Botanical',
    'Airy lavender and cool, quiet violet-grey.',
    0xfff4f1fa,
    0xff242134,
    0xff9780be,
  ),
  _OrbitPaletteRecipe(
    'iris',
    'Iris',
    'Botanical',
    'Soft iris blue across gently tinted neutral surfaces.',
    0xfff1f1f9,
    0xff21233a,
    0xff7f83c0,
  ),
  _OrbitPaletteRecipe(
    'orchid',
    'Orchid',
    'Botanical',
    'Muted orchid colour with a warm plum foundation.',
    0xfff7f0f7,
    0xff302330,
    0xffac7aaf,
  ),
  _OrbitPaletteRecipe(
    'rosewater',
    'Rosewater',
    'Botanical',
    'Pale rose paper, warm ink and subdued pink focus.',
    0xfffbf0f0,
    0xff302326,
    0xffba858c,
  ),
  _OrbitPaletteRecipe(
    'wisteria',
    'Wisteria',
    'Botanical',
    'Cool floral violet with misty grey surfaces.',
    0xfff2eff8,
    0xff272337,
    0xff9b8abd,
  ),
  _OrbitPaletteRecipe(
    'plum',
    'Plum Library',
    'Botanical',
    'A literary mix of plum, warm grey and pale vellum.',
    0xfff6eff4,
    0xff2b1f2c,
    0xffa1719c,
  ),
  _OrbitPaletteRecipe(
    'glacier',
    'Glacier',
    'Sky',
    'Ice-blue surfaces and crisp glacial teal.',
    0xffedf6f9,
    0xff1a2b35,
    0xff76a8b6,
  ),
  _OrbitPaletteRecipe(
    'arctic',
    'Arctic',
    'Sky',
    'Snow neutrals and a restrained arctic-blue accent.',
    0xfff5f8fb,
    0xff1b2734,
    0xff839fbb,
  ),
  _OrbitPaletteRecipe(
    'cloud',
    'Cloud',
    'Sky',
    'Soft cloud whites and gentle blue-grey ink.',
    0xfff7f8fa,
    0xff252b33,
    0xff909eb2,
  ),
  _OrbitPaletteRecipe(
    'mist',
    'Morning Mist',
    'Sky',
    'Pearl-grey mist with quiet periwinkle details.',
    0xfff2f4f8,
    0xff242a36,
    0xff8b94b4,
  ),
  _OrbitPaletteRecipe(
    'rain',
    'Rain',
    'Sky',
    'Rain-washed slate and a subtle blue accent.',
    0xffeef2f6,
    0xff202936,
    0xff708ba7,
  ),
  _OrbitPaletteRecipe(
    'cobalt',
    'Cobalt',
    'Sky',
    'Focused cobalt blue over calm, neutral layers.',
    0xffeff3fb,
    0xff19243c,
    0xff577fc4,
  ),
  _OrbitPaletteRecipe(
    'honey',
    'Honey',
    'Warmth',
    'Honey gold and warm off-white, without glare.',
    0xfffbf6e9,
    0xff302a20,
    0xffb3944e,
  ),
  _OrbitPaletteRecipe(
    'amber',
    'Amber Desk',
    'Warmth',
    'Amber details, parchment paper and brown-grey shadows.',
    0xfffaf2e3,
    0xff30261c,
    0xffba8b43,
  ),
  _OrbitPaletteRecipe(
    'apricot',
    'Apricot',
    'Warmth',
    'Soft apricot with a warm mineral foundation.',
    0xfffbf0e8,
    0xff32271f,
    0xffc29371,
  ),
  _OrbitPaletteRecipe(
    'peach',
    'Peach',
    'Warmth',
    'Pale peach surfaces with gentle terracotta focus.',
    0xfffcf1ed,
    0xff312421,
    0xffc68f80,
  ),
  _OrbitPaletteRecipe(
    'coral',
    'Coral',
    'Warmth',
    'Muted coral accents balanced by creamy neutral layers.',
    0xfffcf0ed,
    0xff322323,
    0xffc17b70,
  ),
  _OrbitPaletteRecipe(
    'rosewood',
    'Rosewood',
    'Warmth',
    'Rosewood, dusty red and soft ivory for evening writing.',
    0xfff8eeed,
    0xff2e2023,
    0xffab777c,
  ),
  _OrbitPaletteRecipe(
    'indigo',
    'Indigo Studio',
    'Creative',
    'Inky indigo and clean paper for focused creative work.',
    0xfff2f2fb,
    0xff20223b,
    0xff7b7fbd,
  ),
  _OrbitPaletteRecipe(
    'amethyst',
    'Amethyst',
    'Creative',
    'Amethyst violet restrained by mineral grey surfaces.',
    0xfff6f1fb,
    0xff282136,
    0xffa080c3,
  ),
  _OrbitPaletteRecipe(
    'mulberry',
    'Mulberry',
    'Creative',
    'Deep berry ink with softly tinted rose-white.',
    0xfff8f0f5,
    0xff302131,
    0xffac769f,
  ),
  _OrbitPaletteRecipe(
    'cerise',
    'Cerise',
    'Creative',
    'A considered cherry accent over quiet, warm neutrals.',
    0xfffbf0f4,
    0xff34222b,
    0xffb8698d,
  ),
  _OrbitPaletteRecipe(
    'teal',
    'Teal Workshop',
    'Creative',
    'Balanced blue-green with a practical slate foundation.',
    0xffeef6f6,
    0xff182e31,
    0xff57999f,
  ),
  _OrbitPaletteRecipe(
    'cinnabar',
    'Cinnabar',
    'Creative',
    'Earthy vermilion used sparingly against soft stone.',
    0xfff9eeeb,
    0xff30221f,
    0xffb57362,
  ),
  _OrbitPaletteRecipe(
    'petrol',
    'Petrol',
    'Creative',
    'Petrol-blue ink and cool neutral paper.',
    0xffedf4f6,
    0xff172c35,
    0xff568e9f,
  ),
  _OrbitPaletteRecipe(
    'jade',
    'Jade',
    'Creative',
    'Calm jade focus, pale mineral paper and green-grey ink.',
    0xffedf7f2,
    0xff192d27,
    0xff579e82,
  ),
];

final _additionalOrbitPalettes = List<OrbitThemePack>.unmodifiable([
  for (final recipe in _orbitPaletteRecipes)
    for (final brightness in [Brightness.light, Brightness.dark])
      OrbitThemePack(
        id: 'palette-${recipe.id}-${brightness.name}',
        familyId: recipe.id,
        category: recipe.category,
        name:
            '${recipe.name} ${brightness == Brightness.light ? 'Light' : 'Dark'}',
        description: recipe.description,
        brightness: brightness,
        colors: _curatedPalette(recipe, brightness),
      ),
]);

Color _paletteMix(Color a, Color b, double amount) =>
    Color(Color.lerp(a, b, amount)!.toARGB32());

/// Adjust only as far as necessary to satisfy the worst actual semantic surface.
/// Tests cover all catalog pairs; this is not a claim about arbitrary overrides.
Color _paletteInk(
  Color candidate,
  List<Color> surfaces,
  Color toward, {
  double minimum = 4.5,
}) {
  bool readable(Color color) => surfaces.every(
    (surface) => OrbitContrast.ratio(color, surface) >= minimum,
  );
  if (readable(candidate)) return candidate;
  var low = 0.0, high = 1.0;
  for (var i = 0; i < 24; i++) {
    final amount = (low + high) / 2;
    if (readable(_paletteMix(candidate, toward, amount))) {
      high = amount;
    } else {
      low = amount;
    }
  }
  return _paletteMix(candidate, toward, high);
}

OrbitColors _curatedPalette(_OrbitPaletteRecipe recipe, Brightness brightness) {
  final light = brightness == Brightness.light;
  final paper = Color(recipe.paper), night = Color(recipe.night);
  final seed = Color(recipe.accent);
  final base = light ? paper : night;
  Color neutral(double amount) =>
      _paletteMix(base, light ? night : Colors.white, amount);
  final workspace = light
      ? _paletteMix(paper, Colors.white, .38)
      : neutral(.022);
  final panel = neutral(light ? .038 : .045);
  final panelSecondary = neutral(.065);
  final raised = light ? _paletteMix(Colors.white, paper, .15) : neutral(.085);
  final floating = light ? Colors.white : neutral(.105);
  final input = light ? Colors.white : neutral(.055);
  final hover = neutral(light ? .075 : .12);
  final pressed = neutral(light ? .115 : .16);
  final selected = _paletteMix(base, seed, light ? .15 : .20);
  final selectedMuted = _paletteMix(base, seed, light ? .075 : .10);
  final surfaces = [
    base,
    workspace,
    panel,
    panelSecondary,
    raised,
    floating,
    input,
    hover,
    pressed,
    selected,
    selectedMuted,
  ];
  final toward = light ? Colors.black : Colors.white;
  Color ink(Color color, {double minimum = 4.5}) =>
      _paletteInk(color, surfaces, toward, minimum: minimum);
  final accent = ink(seed);
  final secondarySeed = HSLColor.fromColor(seed);
  final secondary = ink(
    secondarySeed.withHue((secondarySeed.hue + 24) % 360).toColor(),
  );
  final text = ink(
    light ? _paletteMix(night, Colors.black, .18) : neutral(.93),
    minimum: 7,
  );
  final subtle = ink(light ? neutral(.68) : neutral(.78));
  final muted = ink(light ? neutral(.54) : neutral(.60));
  final focus = ink(seed, minimum: 3.2);
  final border = neutral(light ? .21 : .25);
  return OrbitColors(
    background: base,
    workspace: workspace,
    panel: panel,
    panelSecondary: panelSecondary,
    raised: raised,
    floating: floating,
    input: input,
    hover: hover,
    pressed: pressed,
    selected: selected,
    selectedMuted: selectedMuted,
    border: border,
    divider: neutral(light ? .105 : .145),
    focus: focus,
    accent: accent,
    secondary: secondary,
    accentHover: ink(_paletteMix(accent, toward, .12)),
    text: text,
    subtle: subtle,
    muted: muted,
    textDisabled: neutral(light ? .32 : .39),
    success: ink(Color(light ? 0xff267550 : 0xff82c79d)),
    warning: ink(Color(light ? 0xff946516 : 0xffddbc7a)),
    danger: ink(Color(light ? 0xffb34b5b : 0xffe895a0)),
    link: accent,
    linkVisited: secondary,
    canvasBackground: base,
    canvasGrid: neutral(light ? .12 : .14),
    graphEdge: neutral(light ? .30 : .34),
  );
}
