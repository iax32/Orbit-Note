import 'writing_photo.dart';

/// Device-local presentation. Never part of a note's Markdown or undo history.
enum WritingDesign {
  orbit,
  pixelBook,
  classicBook,
  crt,
  retro,
  command,
  blueprint,
  fieldJournal,
  typewriter,
  amberTerminal,
}

enum WritingPaper { plain, ruled, grid, dots }

class NoteWritingAppearance {
  const NoteWritingAppearance({
    this.design = WritingDesign.orbit,
    this.paper = WritingPaper.plain,
    this.spacing = 32,
    this.details = true,
    this.styledFont = true,
    this.quiet = false,
    this.pixelSnap = true,
    this.photo,
    this.photoCleared = false,
  });
  final WritingDesign design;
  final WritingPaper paper;
  final double spacing;
  final bool details, styledFont, quiet;
  final bool pixelSnap;
  final WritingPhoto? photo;
  final bool photoCleared;

  @override
  bool operator ==(Object other) =>
      other is NoteWritingAppearance &&
      other.design == design &&
      other.paper == paper &&
      other.spacing == spacing &&
      other.details == details &&
      other.styledFont == styledFont &&
      other.quiet == quiet &&
      other.pixelSnap == pixelSnap &&
      other.photo == photo &&
      other.photoCleared == photoCleared;
  @override
  int get hashCode => Object.hash(
    design,
    paper,
    spacing,
    details,
    styledFont,
    quiet,
    pixelSnap,
    photo,
    photoCleared,
  );

  factory NoteWritingAppearance.fromData(Object? value) {
    if (value is! Map || value['version'] != 1) {
      return const NoteWritingAppearance();
    }
    final spacing = value['spacing'];
    return NoteWritingAppearance(
      design: WritingDesign.values.firstWhere(
        (d) => d.name == value['design'],
        orElse: () => WritingDesign.orbit,
      ),
      paper: WritingPaper.values.firstWhere(
        (p) => p.name == value['paper'],
        orElse: () => WritingPaper.plain,
      ),
      spacing:
          spacing is num && spacing.isFinite && spacing >= 20 && spacing <= 64
          ? spacing.toDouble()
          : 32,
      details: value['details'] != false,
      styledFont: value['styledFont'] != false,
      quiet: value['quiet'] == true,
      pixelSnap: value['pixelSnap'] != false,
      photo: WritingPhoto.fromData(value['photo']),
    );
  }

  NoteWritingAppearance copyWith({
    WritingDesign? design,
    WritingPaper? paper,
    double? spacing,
    bool? details,
    bool? styledFont,
    bool? quiet,
    bool? pixelSnap,
    WritingPhoto? photo,
    bool removePhoto = false,
  }) => NoteWritingAppearance(
    design: design ?? this.design,
    paper: paper ?? this.paper,
    spacing: spacing ?? this.spacing,
    details: details ?? this.details,
    styledFont: styledFont ?? this.styledFont,
    quiet: quiet ?? this.quiet,
    pixelSnap: pixelSnap ?? this.pixelSnap,
    photo: removePhoto ? null : photo ?? this.photo,
    photoCleared: removePhoto || (photo == null && photoCleared),
  );

  /// Keep unfamiliar preference fields when the user deliberately applies a look.
  Map<String, dynamic> toData({Object? original}) {
    final data = <String, dynamic>{
      if (original is Map)
        for (final entry in original.entries)
          if (entry.key is String) entry.key as String: entry.value,
      'version': 1,
      'design': design.name,
      'paper': paper.name,
      'spacing': spacing,
      'details': details,
      'styledFont': styledFont,
      'quiet': quiet,
      'pixelSnap': pixelSnap,
      if (photo != null)
        'photo': photo!.toData(
          original: original is Map ? original['photo'] : null,
        ),
    };
    if (photoCleared) data.remove('photo');
    return data;
  }
}
