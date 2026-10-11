/// Appearance/editor defaults only. Object IDs, tabs and view state belong to
/// SessionState; its legacy flat serializer remains the compatibility boundary.
class AppPreferences {
  AppPreferences({
    this.fontSize = 16,
    this.uiZoom = 1.0,
    this.contentWidth = 1080,
    this.fontFamily = 'Segoe UI',
    this.documentFontFamily = 'Segoe UI',
    this.monoFontFamily = 'Consolas',
    this.themePreset = 'orbit',
    this.cornerStyle = 'rounded',
    this.compact = false,
    this.motion = 'normal',
    this.spellCheckEnabled = true,
    this.userDictionary = const [],
    this.accentColor = 'violet',
    this.colorOverrides = const {},
    this.defaultNoteMode = 'rich',
    this.defaultDocumentFormat = 'markdown',
    this.bionicReadingDefault = false,
    this.defaultCanvasGrid = 'dots',
    this.canvasSnapToGrid = false,
    this.defaultAudioSpeed = 1.0,
    this.editorLineHeight = 1.6,
    this.showLineNumbers = true,
    this.customThemes = const [],
    this.folderColors = const {},
  });
  double fontSize;
  double uiZoom;
  double contentWidth;
  String fontFamily;
  String documentFontFamily;
  String monoFontFamily;
  String themePreset;
  String cornerStyle;
  bool compact;
  String motion;
  bool spellCheckEnabled;
  List<String> userDictionary;
  String accentColor;
  Map<String, int> colorOverrides;
  String defaultNoteMode;
  String defaultDocumentFormat;
  bool bionicReadingDefault;
  String defaultCanvasGrid;
  bool canvasSnapToGrid;
  double defaultAudioSpeed;
  double editorLineHeight;
  bool showLineNumbers;
  List<Map<String, dynamic>> customThemes;
  Map<String, int> folderColors;
}
