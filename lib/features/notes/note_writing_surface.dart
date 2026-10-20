import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/orbit_theme.dart';
import '../../domain/note_writing_appearance.dart';
import '../../domain/writing_photo.dart';
import 'writing_photo_import.dart';
import 'writing_photo_layer.dart';
import 'pixel_font_scope.dart';

String writingDesignName(WritingDesign design) => switch (design) {
  WritingDesign.orbit => 'Orbit',
  WritingDesign.pixelBook => 'Pixel notebook',
  WritingDesign.classicBook => 'Bound book',
  WritingDesign.crt => 'CRT terminal',
  WritingDesign.retro => 'Retro desktop',
  WritingDesign.command => 'Command prompt',
  WritingDesign.blueprint => 'Blueprint',
  WritingDesign.fieldJournal => 'Field journal',
  WritingDesign.typewriter => 'Typewriter',
  WritingDesign.amberTerminal => 'Amber terminal',
};

String writingPaperName(WritingPaper paper) => switch (paper) {
  WritingPaper.plain => 'Plain',
  WritingPaper.ruled => 'Lined paper',
  WritingPaper.grid => 'Math paper',
  WritingPaper.dots => 'Dot grid',
};

WritingPaper writingDefaultPaper(WritingDesign design) => switch (design) {
  WritingDesign.blueprint => WritingPaper.grid,
  WritingDesign.fieldJournal => WritingPaper.ruled,
  _ => WritingPaper.plain,
};

String? writingDesignFont(NoteWritingAppearance appearance) {
  if (!appearance.styledFont) return null;
  return switch (appearance.design) {
    WritingDesign.pixelBook => 'OrbitPixel',
    WritingDesign.classicBook || WritingDesign.fieldJournal => 'OrbitBook',
    WritingDesign.crt ||
    WritingDesign.command ||
    WritingDesign.blueprint ||
    WritingDesign.typewriter ||
    WritingDesign.amberTerminal => 'OrbitTerminal',
    _ => null,
  };
}

Color writingPageColor(WritingDesign design, ThemeData base) =>
    switch (design) {
      WritingDesign.pixelBook => const Color(0xfffbf4dc),
      WritingDesign.classicBook => const Color(0xfff5efdf),
      WritingDesign.crt => const Color(0xff07170f),
      WritingDesign.retro => Colors.white,
      WritingDesign.command => const Color(0xff080a09),
      WritingDesign.blueprint => const Color(0xff123351),
      WritingDesign.fieldJournal => const Color(0xfff1f0e3),
      WritingDesign.typewriter => const Color(0xfffaf7ef),
      WritingDesign.amberTerminal => const Color(0xff191208),
      WritingDesign.orbit => base.colorScheme.surface,
    };

ThemeData writingSurfaceTheme(NoteWritingAppearance look, ThemeData base) {
  if (look.design == WritingDesign.orbit) return base;
  final terminal = look.design == WritingDesign.crt;
  final amber = look.design == WritingDesign.amberTerminal;
  final blueprint = look.design == WritingDesign.blueprint;
  final dark =
      terminal || amber || blueprint || look.design == WritingDesign.command;
  final ink = amber
      ? const Color(0xffffdb8d)
      : blueprint
      ? const Color(0xffeff7ff)
      : terminal
      ? const Color(0xffa2efb5)
      : dark
      ? const Color(0xffe6e8e3)
      : const Color(0xff30291f);
  final secondaryInk = amber
      ? const Color(0xffd0ae70)
      : blueprint
      ? const Color(0xffa8c5df)
      : terminal
      ? const Color(0xff7fbc8d)
      : dark
      ? const Color(0xffadb6ae)
      : const Color(0xff655d50);
  final accent = amber
      ? const Color(0xffffc765)
      : blueprint
      ? const Color(0xffbde5ff)
      : look.design == WritingDesign.fieldJournal
      ? const Color(0xff395942)
      : look.design == WritingDesign.typewriter
      ? const Color(0xff853b32)
      : terminal
      ? const Color(0xffa2efb5)
      : dark
      ? const Color(0xffa4c8ff)
      : look.design == WritingDesign.pixelBook
      ? const Color(0xff993d28)
      : look.design == WritingDesign.classicBook
      ? const Color(0xff6c4931)
      : const Color(0xff000080);
  final page = writingPageColor(look.design, base);
  final panel = amber
      ? const Color(0xff2b2110)
      : blueprint
      ? const Color(0xff1c4565)
      : look.design == WritingDesign.fieldJournal
      ? const Color(0xffe2e6d5)
      : look.design == WritingDesign.typewriter
      ? const Color(0xffece7da)
      : dark
      ? terminal
            ? const Color(0xff13251a)
            : const Color(0xff1c1e20)
      : look.design == WritingDesign.retro
      ? const Color(0xffe7e7e7)
      : const Color(0xffeae0ca);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xff07170f) : Colors.white,
        surface: page,
        onSurface: ink,
        onSurfaceVariant: secondaryInk,
        surfaceContainerLowest: page,
        surfaceContainerLow: panel,
        surfaceContainer: panel,
        surfaceContainerHigh: panel,
        surfaceContainerHighest: dark
            ? amber
                  ? const Color(0xff3a2c17)
                  : blueprint
                  ? const Color(0xff285575)
                  : terminal
                  ? const Color(0xff1c3625)
                  : const Color(0xff2b2e31)
            : const Color(0xffded5c4),
        outline: secondaryInk,
        outlineVariant: secondaryInk.withValues(alpha: .28),
        primaryContainer: dark
            ? amber
                  ? const Color(0xff493416)
                  : blueprint
                  ? const Color(0xff285575)
                  : terminal
                  ? const Color(0xff21462c)
                  : const Color(0xff26323f)
            : const Color(0xffe1d8c4),
        onPrimaryContainer: ink,
      );
  return base.copyWith(
    extensions: [
      ...base.extensions.values.where(
        (value) => value is! OrbitColors && value is! OrbitCorners,
      ),
      OrbitColors(
        background: page,
        workspace: page,
        panel: panel,
        panelSecondary: panel,
        raised: panel,
        floating: panel,
        input: panel,
        hover: Color.alphaBlend(accent.withValues(alpha: .1), page),
        pressed: Color.alphaBlend(accent.withValues(alpha: .16), page),
        selected: Color.alphaBlend(accent.withValues(alpha: .14), page),
        selectedMuted: panel,
        border: scheme.outlineVariant,
        divider: scheme.outlineVariant,
        focus: accent,
        accent: accent,
        secondary: accent,
        accentHover: accent,
        text: ink,
        subtle: secondaryInk,
        muted: secondaryInk,
        textDisabled: secondaryInk.withValues(alpha: .6),
        success: dark ? const Color(0xffa2efb5) : const Color(0xff286338),
        warning: dark ? const Color(0xffefd59f) : const Color(0xff846015),
        danger: dark ? const Color(0xffffa1a1) : const Color(0xffa72f2f),
        link: accent,
        linkVisited: accent,
      ),
      if (look.design == WritingDesign.retro ||
          look.design == WritingDesign.command ||
          look.design == WritingDesign.pixelBook)
        const OrbitCorners(
          style: 'writing-crisp',
          control: 2,
          card: 2,
          panel: 2,
          menu: 2,
          dialog: 8,
          small: 1,
        )
      else
        base.extension<OrbitCorners>() ?? OrbitCorners.rounded,
    ],
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    canvasColor: page,
    dividerColor: scheme.outlineVariant,
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    iconTheme: base.iconTheme.copyWith(color: secondaryInk),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: panel,
      hintStyle: TextStyle(color: secondaryInk),
      labelStyle: TextStyle(color: secondaryInk),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .24),
      selectionHandleColor: accent,
    ),
  );
}

/// Original vector frames around real editable content. No texture covers text,
/// no screenshot is scaled, and decorative layers never receive pointer input.
class NoteWritingSurface extends StatefulWidget {
  const NoteWritingSurface({
    super.key,
    required this.appearance,
    required this.child,
    this.title = 'Writing desk',
    this.photoBytes,
    this.photoLoader,
    this.photoOwner,
    this.readingWidth = 1136,
  });
  final NoteWritingAppearance appearance;
  final Widget child;
  final String title;
  final Uint8List? photoBytes;
  final WritingPhotoLoader? photoLoader;
  final Object? photoOwner;
  final double readingWidth;

  @override
  State<NoteWritingSurface> createState() => _NoteWritingSurfaceState();
}

class _NoteWritingSurfaceState extends State<NoteWritingSurface> {
  ThemeData? _base, _scheme;
  NoteWritingAppearance? _appearance;
  bool _photoFailed = false;
  int _photoRetry = 0;
  double _readablePhoto = 0;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final appearance = widget.appearance;
    if (_base != base || _appearance != appearance) {
      _base = base;
      _appearance = appearance;
      _scheme = writingSurfaceTheme(appearance, base);
      _readablePhoto = readablePhotoOpacity(_scheme!);
    }
    final scheme = _scheme!;
    final d = appearance.design;
    final framed = d != WritingDesign.orbit;
    final desktop = d == WritingDesign.retro || d == WritingDesign.command;
    final photo = appearance.photo;
    final readable = _readablePhoto;
    final highContrast = MediaQuery.highContrastOf(context);
    return Theme(
      data: scheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 500;
          final inset = !framed
              ? 0.0
              : narrow
              ? 10.0
              : 20.0;
          final gutter = d == WritingDesign.pixelBook ? 10.0 : 0.0;
          return ColoredBox(
            color: writingPageColor(d, base),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: WritingSurfacePainter(
                        appearance,
                        scheme,
                        inset: inset,
                        highContrast: MediaQuery.highContrastOf(context),
                      ),
                    ),
                  ),
                ),
                if (photo != null && !highContrast)
                  Positioned.fill(
                    left: inset,
                    right: inset,
                    top: inset + (desktop ? 30 : 0),
                    bottom: inset,
                    child: RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          d == WritingDesign.crt ||
                                  d == WritingDesign.amberTerminal
                              ? 18
                              : 0,
                        ),
                        child: WritingPhotoLayer(
                          photo: photo,
                          opacity: photo.readingSheet
                              ? photo.opacity
                              : photo.opacity.clamp(0, readable),
                          bytes: widget.photoBytes,
                          loader: widget.photoLoader,
                          owner: widget.photoOwner,
                          retry: _photoRetry,
                          onFailure: (value) {
                            if (_photoFailed != value && mounted) {
                              setState(() => _photoFailed = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset + gutter,
                    inset + (desktop ? 30 : 0),
                    inset,
                    inset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: photo?.readingSheet == true && !highContrast
                            ? math.min(
                                widget.readingWidth,
                                (constraints.maxWidth - inset * 2 - gutter) *
                                    (constraints.maxWidth >= 800 ? .88 : 1),
                              )
                            : double.infinity,
                      ),
                      child: Material(
                        color: photo?.readingSheet == true && !highContrast
                            ? scheme.colorScheme.surface.withValues(
                                alpha: 1 - readable.clamp(0, .04),
                              )
                            : Colors.transparent,
                        textStyle: scheme.textTheme.bodyMedium,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (photo?.readingSheet == true &&
                                appearance.paper != WritingPaper.plain)
                              RepaintBoundary(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: WritingSurfacePainter(
                                      appearance.copyWith(
                                        design: WritingDesign.orbit,
                                      ),
                                      scheme,
                                      inset: 0,
                                      highContrast: highContrast,
                                    ),
                                  ),
                                ),
                              ),
                            Column(
                              children: [
                                if (photo != null &&
                                    _photoFailed &&
                                    !highContrast)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        const Text(
                                          'Photo unavailable. Choose another in Writing surface.',
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              setState(() => _photoRetry++),
                                          child: const Text('Retry background'),
                                        ),
                                      ],
                                    ),
                                  ),
                                Expanded(child: widget.child),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (desktop)
                  Positioned(
                    left: inset + 8,
                    right: inset + 8,
                    top: inset + 4,
                    child: IgnorePointer(
                      child: Text(
                        'Orbit Note — ${widget.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Segoe UI',
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WritingSurfacePainter extends CustomPainter {
  WritingSurfacePainter(
    this.look,
    this.theme, {
    required this.inset,
    this.highContrast = false,
  });
  final NoteWritingAppearance look;
  final ThemeData theme;
  final double inset;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final d = look.design;
    final page = bounds.deflate(inset);
    final paint = Paint();
    void fill(Rect rect, Color color) {
      canvas.drawRect(
        rect,
        paint
          ..color = color
          ..shader = null,
      );
    }

    void line(Offset a, Offset b, Color color, [double width = 1]) {
      canvas.drawLine(
        a,
        b,
        paint
          ..shader = null
          ..color = color
          ..strokeWidth = width,
      );
    }

    if (d == WritingDesign.pixelBook) {
      fill(bounds, const Color(0xff392419));
      final leather = bounds.deflate(3);
      fill(leather, const Color(0xff75432a));
      fill(leather.deflate(4), const Color(0xffa16340));
      fill(page.inflate(4), const Color(0xffd3b278));
      fill(page, writingPageColor(d, theme));
      if (look.details) {
        // Stepped corner shadows, stacked leaves, and red binding stitches.
        for (var i = 0; i < 4; i++) {
          line(
            Offset(page.right + i, page.top + 5),
            Offset(page.right + i, page.bottom - i),
            i.isEven ? const Color(0xffb09b72) : const Color(0xffede0b5),
          );
          line(
            Offset(page.left + i, page.bottom + i),
            Offset(page.right, page.bottom + i),
            const Color(0xffbba77c),
          );
        }
        for (double y = page.top + 14; y < page.bottom - 10; y += 25) {
          final x = page.left + 5;
          line(Offset(x, y), Offset(x + 4, y - 4), const Color(0xffa33122), 2);
          line(Offset(x, y), Offset(x, y + 10), const Color(0xffa33122), 2);
          line(
            Offset(x, y + 10),
            Offset(x + 4, y + 12),
            const Color(0xffa33122),
            2,
          );
        }
        for (final corner in [page.topRight, page.bottomRight]) {
          fill(
            Rect.fromLTWH(
              corner.dx - 8,
              corner.dy == page.top ? corner.dy : corner.dy - 8,
              8,
              8,
            ),
            const Color(0xffe0d3ab),
          );
        }
      }
    } else if (d == WritingDesign.classicBook) {
      fill(bounds, const Color(0xff534336));
      fill(bounds.deflate(4), const Color(0xff8a6546));
      fill(page.inflate(4), const Color(0xffd4c5a8));
      fill(page, writingPageColor(d, theme));
      if (look.details) {
        for (var i = 0; i < 4; i++) {
          line(
            Offset(page.right + i, page.top),
            Offset(page.right + i, page.bottom),
            const Color(0xffac9d83),
          );
        }
        final spine = Rect.fromLTWH(page.left, page.top, 30, page.height);
        canvas.drawRect(
          spine,
          paint
            ..shader = const LinearGradient(
              colors: [Color(0x30624526), Color(0x00624526)],
            ).createShader(spine),
        );
        paint.shader = null;
      }
    } else if (d == WritingDesign.blueprint) {
      fill(bounds, const Color(0xff0b2035));
      fill(page, writingPageColor(d, theme));
      final white = theme.colorScheme.onSurface.withValues(alpha: .55);
      for (final rect in [bounds.deflate(4), page.deflate(2)]) {
        canvas.drawRect(
          rect,
          paint
            ..shader = null
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      paint.style = PaintingStyle.fill;
      if (look.details) {
        for (double x = page.left + 10; x < page.right; x += 10) {
          final major = ((x - page.left).round() % 50) == 0;
          line(
            Offset(x, page.top - (major ? 8 : 4)),
            Offset(x, page.top - 1),
            white,
          );
        }
        for (double y = page.top + 10; y < page.bottom; y += 10) {
          final major = ((y - page.top).round() % 50) == 0;
          line(
            Offset(page.left - (major ? 8 : 4), y),
            Offset(page.left - 1, y),
            white,
          );
        }
      }
    } else if (d == WritingDesign.fieldJournal) {
      fill(bounds, const Color(0xff304638));
      fill(bounds.deflate(4), const Color(0xff657254));
      fill(page.inflate(3), const Color(0xffbac0a2));
      fill(page, writingPageColor(d, theme));
      if (look.details) {
        for (double y = 12; y < size.height - 8; y += 14) {
          line(Offset(8, y), Offset(8, y + 6), const Color(0xffccd3b6));
          line(
            Offset(size.width - 8, y),
            Offset(size.width - 8, y + 6),
            const Color(0xffccd3b6),
          );
        }
        line(
          Offset(page.left + 12, page.top),
          Offset(page.left + 12, page.bottom),
          const Color(0xff869475).withValues(alpha: .35),
        );
        for (var i = 1; i < 4; i++) {
          line(
            Offset(page.right + i, page.top + i),
            Offset(page.right + i, page.bottom),
            const Color(0xffa6ad91),
          );
        }
      }
    } else if (d == WritingDesign.typewriter) {
      fill(bounds, const Color(0xff34393b));
      fill(page.inflate(3), const Color(0xffc6c0b2));
      fill(page, writingPageColor(d, theme));
      if (look.details) {
        final roller = Rect.fromLTWH(
          page.left - 5,
          3,
          page.width + 10,
          math.max(2, inset - 7),
        );
        fill(roller, const Color(0xff171b1c));
        line(
          Offset(page.left + 32, page.top),
          Offset(page.left + 32, page.bottom),
          const Color(0xffa85d50).withValues(alpha: .15),
        );
        for (final x in [page.left + 8, page.right - 16]) {
          fill(Rect.fromLTWH(x, page.top - 5, 8, 10), const Color(0xff969e9e));
          line(
            Offset(x + 1, page.top - 4),
            Offset(x + 6, page.top - 4),
            const Color(0xffe2e7e6),
          );
        }
      }
    } else if (d == WritingDesign.crt || d == WritingDesign.amberTerminal) {
      final amber = d == WritingDesign.amberTerminal;
      fill(bounds, amber ? const Color(0xff30291d) : const Color(0xff292e29));
      final shell = RRect.fromRectAndRadius(
        bounds.deflate(3),
        const Radius.circular(27),
      );
      canvas.drawRRect(
        shell,
        paint
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: amber
                ? const [
                    Color(0xff695940),
                    Color(0xff211c14),
                    Color(0xff55472f),
                  ]
                : const [
                    Color(0xff49514a),
                    Color(0xff171c18),
                    Color(0xff3e443f),
                  ],
          ).createShader(bounds),
      );
      paint.shader = null;
      final screen = RRect.fromRectAndRadius(page, const Radius.circular(18));
      canvas.drawRRect(screen, paint..color = writingPageColor(d, theme));
      if (amber) {
        canvas.drawRRect(
          shell,
          paint
            ..color = const Color(0xff756044)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        paint.style = PaintingStyle.fill;
      }
      if (look.details && !highContrast) {
        canvas.save();
        canvas.clipRRect(screen);
        canvas.drawRect(
          page,
          paint
            ..shader = const RadialGradient(
              radius: .8,
              colors: [Color(0x00000000), Color(0x50000000)],
            ).createShader(page),
        );
        paint.shader = null;
        for (double y = page.top; y < page.bottom; y += 4) {
          line(
            Offset(page.left, y),
            Offset(page.right, y),
            const Color(0x0c9deaaf),
          );
        }
        canvas.restore();
      }
    } else if (d == WritingDesign.retro || d == WritingDesign.command) {
      fill(bounds, const Color(0xffc0c0c0));
      line(const Offset(1, 1), Offset(size.width - 1, 1), Colors.white, 2);
      line(const Offset(1, 1), Offset(1, size.height - 1), Colors.white, 2);
      line(
        Offset(size.width - 1, 1),
        Offset(size.width - 1, size.height),
        const Color(0xff454545),
        2,
      );
      line(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        const Color(0xff454545),
        2,
      );
      final title = Rect.fromLTWH(page.left, page.top, page.width, 25);
      canvas.drawRect(
        title,
        paint
          ..shader = LinearGradient(
            colors: d == WritingDesign.command
                ? const [Color(0xff145eb7), Color(0xff7cadde)]
                : const [Color(0xff000080), Color(0xff17419e)],
          ).createShader(title),
      );
      paint.shader = null;
      final work = Rect.fromLTRB(
        page.left,
        page.top + 30,
        page.right,
        page.bottom,
      );
      fill(work, writingPageColor(d, theme));
      line(work.topLeft, work.topRight, const Color(0xff555555), 2);
      line(work.topLeft, work.bottomLeft, const Color(0xff555555), 2);
      line(work.bottomLeft, work.bottomRight, Colors.white, 2);
      line(work.topRight, work.bottomRight, Colors.white, 2);
    }

    if (look.paper == WritingPaper.plain) return;
    final area = Rect.fromLTRB(
      page.left + (d == WritingDesign.pixelBook ? 14 : 0),
      page.top +
          ((d == WritingDesign.retro || d == WritingDesign.command) ? 30 : 0),
      page.right,
      page.bottom,
    );
    final ink = theme.colorScheme.onSurface;
    final color = ink.withValues(alpha: highContrast ? .18 : .085);
    final step = look.spacing.clamp(20.0, 64.0);
    canvas.save();
    canvas.clipRect(area);
    if (look.paper == WritingPaper.ruled || look.paper == WritingPaper.grid) {
      for (double y = area.top + step; y < area.bottom; y += step) {
        line(Offset(area.left, y), Offset(area.right, y), color);
      }
      if (look.paper == WritingPaper.grid) {
        for (double x = area.left + step; x < area.right; x += step) {
          line(Offset(x, area.top), Offset(x, area.bottom), color);
        }
        if (d == WritingDesign.blueprint && look.details) {
          final major = ink.withValues(alpha: highContrast ? .28 : .18);
          for (double y = area.top + step * 5; y < area.bottom; y += step * 5) {
            line(Offset(area.left, y), Offset(area.right, y), major);
          }
          for (double x = area.left + step * 5; x < area.right; x += step * 5) {
            line(Offset(x, area.top), Offset(x, area.bottom), major);
          }
        }
      } else {
        line(
          Offset(area.left + 24, area.top),
          Offset(area.left + 24, area.bottom),
          const Color(0xffbc6356).withValues(alpha: .2),
        );
      }
    } else {
      for (double y = area.top + step; y < area.bottom; y += step) {
        for (double x = area.left + step; x < area.right; x += step) {
          canvas.drawCircle(
            Offset(x, y),
            highContrast ? 1.2 : .8,
            paint
              ..shader = null
              ..color = ink.withValues(alpha: .2),
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WritingSurfacePainter oldDelegate) =>
      oldDelegate.look.design != look.design ||
      oldDelegate.look.paper != look.paper ||
      oldDelegate.look.spacing != look.spacing ||
      oldDelegate.look.details != look.details ||
      oldDelegate.inset != inset ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.theme.colorScheme != theme.colorScheme;
}

Future<NoteWritingAppearance?> showWritingAppearance(
  BuildContext context,
  NoteWritingAppearance initial, {
  WritingPhotoLoader? photoLoader,
  Object? photoOwner,
  Future<ImportedWritingPhoto?> Function()? pickPhoto,
  Future<String> Function(Uint8List bytes)? savePhoto,
  bool Function()? canApply,
}) => showDialog<NoteWritingAppearance>(
  context: context,
  builder: (_) => _WritingAppearanceDialog(
    initial: initial,
    photoLoader: photoLoader,
    photoOwner: photoOwner,
    pickPhoto: pickPhoto,
    savePhoto: savePhoto,
    canApply: canApply,
  ),
);

class _WritingAppearanceDialog extends StatefulWidget {
  const _WritingAppearanceDialog({
    required this.initial,
    this.photoLoader,
    this.photoOwner,
    this.pickPhoto,
    this.savePhoto,
    this.canApply,
  });
  final NoteWritingAppearance initial;
  final WritingPhotoLoader? photoLoader;
  final Object? photoOwner;
  final Future<ImportedWritingPhoto?> Function()? pickPhoto;
  final Future<String> Function(Uint8List bytes)? savePhoto;
  final bool Function()? canApply;
  @override
  State<_WritingAppearanceDialog> createState() =>
      _WritingAppearanceDialogState();
}

class _WritingAppearanceDialogState extends State<_WritingAppearanceDialog> {
  late NoteWritingAppearance look = widget.initial;
  Uint8List? _pendingPhoto;
  bool _busy = false;
  String? _error;

  Future<void> _choosePhoto() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (widget.pickPhoto ?? () => pickWritingPhoto())();
      if (!mounted || result == null) return;
      validateWritingPhotoBytes(result.bytes);
      setState(() {
        look = look.copyWith(photo: result.photo);
        _pendingPhoto = result.bytes;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Could not use this photo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.canApply?.call() == false) {
        throw const FormatException(
          'The note or Vault changed. Reopen Writing surface.',
        );
      }
      final bytes = _pendingPhoto;
      if (bytes != null && look.photo != null) {
        final save = widget.savePhoto;
        if (save == null) {
          throw const FormatException('Photo storage is unavailable.');
        }
        final id = await save(bytes);
        if (id != look.photo!.id) {
          throw const FormatException('The photo changed before it was saved.');
        }
      }
      if (!mounted) return;
      if (widget.canApply?.call() == false) {
        throw const FormatException(
          'The note or Vault changed. Reopen Writing surface.',
        );
      }
      Navigator.pop(context, look);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not apply this background: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Writing surface'),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a desk for this note. Text, links and undo stay intact.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final paper in WritingPaper.values)
                  ChoiceChip(
                    key: ValueKey('writing-paper-${paper.name}'),
                    label: Text(writingPaperName(paper)),
                    selected: look.paper == paper,
                    onSelected: (_) =>
                        setState(() => look = look.copyWith(paper: paper)),
                  ),
              ],
            ),
            if (look.paper != WritingPaper.plain) ...[
              const SizedBox(height: 12),
              Text('Paper spacing: ${look.spacing.round()} px'),
              Slider(
                value: look.spacing,
                min: 20,
                max: 64,
                divisions: 11,
                label: '${look.spacing.round()} px',
                onChanged: (value) =>
                    setState(() => look = look.copyWith(spacing: value)),
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth < 360
                    ? 1
                    : constraints.maxWidth < 550
                    ? 2
                    : 3;
                final width = (constraints.maxWidth - (count - 1) * 12) / count;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final design in WritingDesign.values)
                      SizedBox(
                        width: width,
                        child: _DesignTile(
                          design: design,
                          selected: look.design == design,
                          onTap: () => setState(
                            () => look = look.copyWith(
                              design: design,
                              paper: look.paper == WritingPaper.plain
                                  ? writingDefaultPaper(design)
                                  : look.paper,
                              quiet:
                                  look.design == WritingDesign.orbit &&
                                      design != WritingDesign.orbit
                                  ? true
                                  : look.quiet,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              key: const ValueKey('writing-quiet-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet writing'),
              subtitle: const Text(
                'A simple desk with mode and appearance controls. Show editor tools brings back the full toolbar.',
              ),
              value: look.quiet,
              onChanged: (value) =>
                  setState(() => look = look.copyWith(quiet: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Design typography'),
              subtitle: const Text(
                'Use the book, pixel or terminal font. Turn off to keep your chosen font.',
              ),
              value: look.styledFont,
              onChanged: (value) =>
                  setState(() => look = look.copyWith(styledFont: value)),
            ),
            if (look.design == WritingDesign.pixelBook && look.styledFont)
              SwitchListTile(
                key: const ValueKey('writing-pixel-snap'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Crisp pixel sizing'),
                subtitle: const Text(
                  'Keep letter cells on whole display pixels at zoom. Text sizes grow in steps; turn off for continuous sizing.',
                ),
                value: look.pixelSnap,
                onChanged: (value) =>
                    setState(() => look = look.copyWith(pixelSnap: value)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Surface details'),
              subtitle: const Text(
                'Binding, paper edges and static scanlines. No flashing or moving text.',
              ),
              value: look.details,
              onChanged: (value) =>
                  setState(() => look = look.copyWith(details: value)),
            ),
            const SizedBox(height: 12),
            Text(
              'Personal photo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('writing-pick-photo'),
                  onPressed: _busy || widget.savePhoto == null
                      ? null
                      : _choosePhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    look.photo == null ? 'Choose photo' : 'Replace photo',
                  ),
                ),
                if (look.photo != null)
                  TextButton(
                    key: const ValueKey('writing-remove-photo'),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            look = look.copyWith(removePhoto: true);
                            _pendingPhoto = null;
                            _error = null;
                          }),
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
            const Text(
              'Local copy only. PNG, JPEG or WebP; up to 16 MiB. The original is unchanged.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (MediaQuery.highContrastOf(context))
              const Text(
                'High contrast hides photo backgrounds. Your photo choice is retained.',
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (look.photo case final WritingPhoto photo) ...[
              const SizedBox(height: 8),
              Text(photo.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('Photo intensity: ${(photo.opacity * 100).round()}%'),
              Slider(
                key: const ValueKey('writing-photo-intensity'),
                value: photo.opacity,
                min: 0,
                max: 1,
                divisions: 20,
                label: '${(photo.opacity * 100).round()}%',
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => look = look.copyWith(
                          photo: photo.copyWith(opacity: value),
                        ),
                      ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Fill & crop'),
                    selected: !photo.contain,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                            () => look = look.copyWith(
                              photo: photo.copyWith(contain: false),
                            ),
                          ),
                  ),
                  ChoiceChip(
                    label: const Text('Fit whole photo'),
                    selected: photo.contain,
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                            () => look = look.copyWith(
                              photo: photo.copyWith(contain: true),
                            ),
                          ),
                  ),
                ],
              ),
              const Text('Horizontal position'),
              Slider(
                key: const ValueKey('writing-photo-x'),
                value: photo.x,
                min: -1,
                max: 1,
                divisions: 20,
                label: photo.x.toStringAsFixed(1),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => look = look.copyWith(
                          photo: photo.copyWith(x: value),
                        ),
                      ),
              ),
              const Text('Vertical position'),
              Slider(
                key: const ValueKey('writing-photo-y'),
                value: photo.y,
                min: -1,
                max: 1,
                divisions: 20,
                label: photo.y.toStringAsFixed(1),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => look = look.copyWith(
                          photo: photo.copyWith(y: value),
                        ),
                      ),
              ),
              SwitchListTile(
                key: const ValueKey('writing-photo-sheet'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Reading sheet'),
                value: photo.readingSheet,
                subtitle: const Text(
                  'Protect text on a quiet sheet. Without it, photo intensity is automatically limited for contrast.',
                ),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => look = look.copyWith(
                          photo: photo.copyWith(readingSheet: value),
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: NoteWritingSurface(
                appearance: look,
                photoBytes: _pendingPhoto,
                photoLoader: widget.photoLoader,
                photoOwner: widget.photoOwner,
                title: 'Preview',
                child: Builder(
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(18),
                    child: SingleChildScrollView(
                      child: PixelFontScope(
                        enabled:
                            writingDesignFont(look) == 'OrbitPixel' &&
                            look.pixelSnap,
                        child: Text(
                          'A place for your ideas.\n\nSketch a theory. Keep a discovery.\nx² + y² = r²',
                          style: TextStyle(
                            fontFamily: writingDesignFont(look),
                            fontWeight: FontWeight.w400,
                            fontSize: look.design == WritingDesign.pixelBook
                                ? 20
                                : 16,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('writing-reset'),
        onPressed: _busy
            ? null
            : () => setState(() {
                look = const NoteWritingAppearance(photoCleared: true);
                _pendingPhoto = null;
                _error = null;
              }),
        child: const Text('Reset'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('writing-apply'),
        onPressed: _busy ? null : _apply,
        child: const Text('Apply'),
      ),
    ],
  );
}

class _DesignTile extends StatelessWidget {
  const _DesignTile({
    required this.design,
    required this.selected,
    required this.onTap,
  });
  final WritingDesign design;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: OutlinedButton(
      key: ValueKey('writing-design-${design.name}'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(8),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 92,
            width: double.infinity,
            child: NoteWritingSurface(
              appearance: NoteWritingAppearance(
                design: design,
                paper: writingDefaultPaper(design),
              ),
              title: 'Notes',
              child: Builder(
                builder: (context) => Center(
                  child: PixelFontScope(
                    enabled: design == WritingDesign.pixelBook,
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontFamily: writingDesignFont(
                          NoteWritingAppearance(design: design),
                        ),
                        fontWeight: FontWeight.w400,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: design == WritingDesign.pixelBook ? 28 : 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(writingDesignName(design), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
