/// Local presentation preferences. Nothing in this file owns authored content.
class MotionPreferences {
  const MotionPreferences(this.data);
  final Map<String, dynamic> data;
  static const quietDefaults = <String, dynamic>{
    'profile': 'fluid',
    'speed': 1.0,
    'navigation': true,
    'editing': true,
    'drawing': true,
    'reading': true,
    'smart': true,
    'focusTyping': false,
    'readingProgress': false,
    'readingSpotlight': false,
    'pageStyle': 'fade',
    'textStyle': 'word',
  };
  Map<String, dynamic> quiet() => {...data, ...quietDefaults};
  static const profiles = ['fluid', 'paper', 'experimental'];
  static const textStyles = [
    'none',
    'character',
    'typewriter',
    'word',
    'blur',
    'ink',
    'scramble',
    'typography',
  ];
  static const pageStyles = ['fade', 'slide', 'paper', 'curl'];
  String choice(String key, List<String> values, String fallback) =>
      values.contains(data[key]) ? data[key] as String : fallback;
  String get profile => choice('profile', profiles, 'fluid');
  String get textStyle => choice(
    'textStyle',
    textStyles,
    profile == 'paper'
        ? 'ink'
        : profile == 'experimental'
        ? 'scramble'
        : 'word',
  );
  String get pageStyle => choice(
    'pageStyle',
    pageStyles,
    profile == 'paper'
        ? 'paper'
        : profile == 'experimental'
        ? 'slide'
        : 'fade',
  );
  bool enabled(String key, {bool fallback = true}) =>
      data[key] is bool ? data[key] as bool : fallback;
  double get speed {
    final value = data['speed'];
    return value is num && value.isFinite ? value.toDouble().clamp(.5, 2) : 1;
  }

  bool get navigation => enabled('navigation');
  bool get editing => enabled('editing');
  bool get drawing => enabled('drawing');
  bool get reading => enabled('reading');
  bool get smart => enabled('smart');
  bool get focusTyping => enabled('focusTyping', fallback: false);
  bool get readingProgress => enabled('readingProgress', fallback: false);
  bool get readingSpotlight => enabled('readingSpotlight', fallback: false);
  Map<String, dynamic> patch(Map<String, dynamic> values) => {
    ...data,
    ...values,
  };
}

enum MotionFamily { text, drawing, reading, workspace, smart, signature }

/// The supplied guide's effect vocabulary. Entries describe presentation, not
/// a claim that a model, recognizer or remote service is available.
class MotionInspiration {
  const MotionInspiration(this.id, this.title, this.family, this.style);
  final String id, title, style;
  final MotionFamily family;
}

const motionInspirations = <MotionInspiration>[
  MotionInspiration(
    'typewriter',
    'Natural typewriter',
    MotionFamily.text,
    'typewriter',
  ),
  MotionInspiration(
    'character',
    'Soft character entrance',
    MotionFamily.text,
    'character',
  ),
  MotionInspiration('caret', 'Elastic caret', MotionFamily.text, 'caret'),
  MotionInspiration('reflow', 'Smooth text reflow', MotionFamily.text, 'morph'),
  MotionInspiration('blur', 'Blur-to-sharp reveal', MotionFamily.text, 'blur'),
  MotionInspiration('words', 'Word-by-word reveal', MotionFamily.text, 'word'),
  MotionInspiration('ink-text', 'Ink reveal', MotionFamily.text, 'ink'),
  MotionInspiration(
    'typography',
    'Morphing typography',
    MotionFamily.text,
    'typography',
  ),
  MotionInspiration('selection', 'Selection wave', MotionFamily.text, 'wave'),
  MotionInspiration(
    'formatting',
    'Animated formatting',
    MotionFamily.text,
    'underline',
  ),
  MotionInspiration(
    'replacement',
    'Text replacement morph',
    MotionFamily.text,
    'morph',
  ),
  MotionInspiration('ghost', 'Ghost text', MotionFamily.text, 'ghost'),
  MotionInspiration('scramble', 'Text scramble', MotionFamily.text, 'scramble'),
  MotionInspiration(
    'focus-typing',
    'Focus typing',
    MotionFamily.text,
    'spotlight',
  ),
  MotionInspiration(
    'live-stroke',
    'Live stroke rendering',
    MotionFamily.drawing,
    'path',
  ),
  MotionInspiration(
    'stroke-replay',
    'Stroke replay',
    MotionFamily.drawing,
    'path',
  ),
  MotionInspiration(
    'pressure',
    'Pressure-responsive ink',
    MotionFamily.drawing,
    'pressure',
  ),
  MotionInspiration(
    'ink-settling',
    'Liquid ink settling',
    MotionFamily.drawing,
    'settle',
  ),
  MotionInspiration(
    'smoothing',
    'Stroke smoothing',
    MotionFamily.drawing,
    'settle',
  ),
  MotionInspiration(
    'shape-morph',
    'Shape morphing',
    MotionFamily.drawing,
    'morph',
  ),
  MotionInspiration(
    'diagram-replay',
    'Self-drawing diagrams',
    MotionFamily.drawing,
    'diagram',
  ),
  MotionInspiration(
    'highlighter',
    'Animated highlighter',
    MotionFamily.drawing,
    'highlight',
  ),
  MotionInspiration(
    'laser',
    'Laser pointer trails',
    MotionFamily.drawing,
    'laser',
  ),
  MotionInspiration(
    'connectors',
    'Magnetic connectors',
    MotionFamily.drawing,
    'diagram',
  ),
  MotionInspiration('eraser', 'Dynamic eraser', MotionFamily.drawing, 'erase'),
  MotionInspiration(
    'brush',
    'Brush transformation',
    MotionFamily.drawing,
    'morph',
  ),
  MotionInspiration(
    'sketch-text',
    'Sketch-to-text morph',
    MotionFamily.drawing,
    'morph',
  ),
  MotionInspiration(
    'lasso',
    'Lasso selection lift',
    MotionFamily.drawing,
    'lift',
  ),
  MotionInspiration('page-curl', '3D page curl', MotionFamily.reading, 'curl'),
  MotionInspiration(
    'page-transition',
    'Fluid page transition',
    MotionFamily.reading,
    'slide',
  ),
  MotionInspiration(
    'page-zoom',
    'Page zoom morph',
    MotionFamily.reading,
    'zoom',
  ),
  MotionInspiration(
    'search-glide',
    'Search-result navigation',
    MotionFamily.reading,
    'spotlight',
  ),
  MotionInspiration(
    'reading-progress',
    'Reading progress reveal',
    MotionFamily.reading,
    'progress',
  ),
  MotionInspiration(
    'annotation',
    'Annotation spotlight',
    MotionFamily.reading,
    'spotlight',
  ),
  MotionInspiration('lens', 'Magnifying lens', MotionFamily.reading, 'lens'),
  MotionInspiration(
    'excerpt',
    'Text excerpt extraction',
    MotionFamily.reading,
    'lift',
  ),
  MotionInspiration(
    'pdf-split',
    'Split-view morph',
    MotionFamily.reading,
    'morph',
  ),
  MotionInspiration(
    'annotation-navigation',
    'Annotation navigation',
    MotionFamily.reading,
    'slide',
  ),
  MotionInspiration(
    'thumbnails',
    'Thumbnail cascade',
    MotionFamily.reading,
    'cascade',
  ),
  MotionInspiration(
    'paper-stack',
    'Paper stack animation',
    MotionFamily.reading,
    'paper',
  ),
  MotionInspiration(
    'note-cards',
    'Morphing note cards',
    MotionFamily.workspace,
    'zoom',
  ),
  MotionInspiration(
    'block-drag',
    'Spring-based block dragging',
    MotionFamily.workspace,
    'lift',
  ),
  MotionInspiration(
    'format-toolbar',
    'Magnetic formatting toolbar',
    MotionFamily.workspace,
    'settle',
  ),
  MotionInspiration(
    'slash-menu',
    'Expandable slash menu',
    MotionFamily.workspace,
    'cascade',
  ),
  MotionInspiration(
    'tool-icons',
    'Toolbar icon morphing',
    MotionFamily.workspace,
    'morph',
  ),
  MotionInspiration(
    'sidebar',
    'Sidebar fluid collapse',
    MotionFamily.workspace,
    'slide',
  ),
  MotionInspiration('tabs', 'Animated tabs', MotionFamily.workspace, 'slide'),
  MotionInspiration(
    'focus-mode',
    'Focus-mode transition',
    MotionFamily.workspace,
    'spotlight',
  ),
  MotionInspiration(
    'folders',
    'Folder expansion',
    MotionFamily.workspace,
    'cascade',
  ),
  MotionInspiration(
    'organize',
    'Drag-to-organize',
    MotionFamily.workspace,
    'lift',
  ),
  MotionInspiration('undo', 'Animated undo', MotionFamily.workspace, 'settle'),
  MotionInspiration(
    'minimize',
    'Document minimization',
    MotionFamily.workspace,
    'zoom',
  ),
  MotionInspiration(
    'panels',
    'Smooth panel resizing',
    MotionFamily.workspace,
    'morph',
  ),
  MotionInspiration(
    'menus',
    'Context-menu expansion',
    MotionFamily.workspace,
    'cascade',
  ),
  MotionInspiration(
    'streaming',
    'AI streaming text',
    MotionFamily.smart,
    'word',
  ),
  MotionInspiration(
    'rewrite',
    'AI rewrite comparison',
    MotionFamily.smart,
    'morph',
  ),
  MotionInspiration(
    'grammar',
    'Grammar-correction morph',
    MotionFamily.smart,
    'morph',
  ),
  MotionInspiration(
    'processing',
    'AI processing shimmer',
    MotionFamily.smart,
    'shimmer',
  ),
  MotionInspiration(
    'ai-diagram',
    'AI diagram construction',
    MotionFamily.smart,
    'diagram',
  ),
  MotionInspiration(
    'recognition',
    'Handwriting recognition arrival',
    MotionFamily.smart,
    'ink',
  ),
  MotionInspiration(
    'selection-expand',
    'Smart selection expansion',
    MotionFamily.smart,
    'wave',
  ),
  MotionInspiration(
    'citations',
    'AI citation linking',
    MotionFamily.smart,
    'path',
  ),
  MotionInspiration(
    'explanations',
    'Inline explanation reveal',
    MotionFamily.smart,
    'cascade',
  ),
  MotionInspiration(
    'mind-map',
    'Mind-map generation',
    MotionFamily.smart,
    'diagram',
  ),
  MotionInspiration(
    'constellation',
    'Spatial note constellation',
    MotionFamily.signature,
    'constellation',
  ),
  MotionInspiration(
    'note-to-canvas',
    'Document-to-canvas transformation',
    MotionFamily.signature,
    'diagram',
  ),
  MotionInspiration(
    'liquid-highlighter',
    'Liquid highlighter',
    MotionFamily.signature,
    'highlight',
  ),
  MotionInspiration(
    'reading-spotlight',
    'Reading spotlight',
    MotionFamily.signature,
    'spotlight',
  ),
  MotionInspiration(
    'knowledge-graph',
    'Living knowledge graph',
    MotionFamily.signature,
    'constellation',
  ),
  MotionInspiration(
    'time-travel',
    'Time-travel editing',
    MotionFamily.signature,
    'morph',
  ),
];
