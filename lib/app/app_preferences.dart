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
    this.followSystemAppearance = false,
    this.cornerStyle = 'rounded',
    this.compact = false,
    this.motion = 'normal',
    this.motionOptions = const {},
    this.spellCheckEnabled = true,
    this.userDictionary = const [],
    this.accentColor = 'theme',
    this.colorOverrides = const {},
    this.defaultNoteMode = 'rich',
    this.defaultDocumentFormat = 'markdown',
    this.bionicReadingDefault = false,
    this.defaultCanvasGrid = 'dots',
    this.canvasSnapToGrid = false,
    this.defaultAudioSpeed = 1.0,
    this.editorLineHeight = 1.6,
    this.showLineNumbers = true,
    this.defaultCodeWrap = false,
    this.codeFontSize = 14,
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
  bool followSystemAppearance;
  String cornerStyle;
  bool compact;
  String motion;
  Map<String, dynamic> motionOptions;
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
  bool defaultCodeWrap;
  double codeFontSize;
  List<Map<String, dynamic>> customThemes;
  Map<String, int> folderColors;
}
