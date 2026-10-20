# Writing fonts

Unmodified Tiny5 (variable) and the regular/bold/italic/bold-italic Space Mono
faces are bundled for offline writing
surfaces. Their full SIL Open Font License and copyright notices are alongside
the fonts. Flutter family aliases do not modify the font files.

- Tiny5: https://github.com/google/fonts/tree/main/ofl/tiny5
- Space Mono: https://github.com/google/fonts/tree/main/ofl/spacemono

Space Mono faces match upstream source commit
`329858c2c4dbd3476f972a4ae00624b018cf4b81` in
https://github.com/googlefonts/spacemono/tree/329858c2c4dbd3476f972a4ae00624b018cf4b81/fonts/ttf.
The existing regular face is byte-identical to that revision. No app dependency
or runtime font download is needed. Pixel headings use Tiny5's original regular
outline weight: its heavier variable outlines move the edges off the cell grid.

The book surface uses the existing Crimson Text fonts in ../publishing with
their existing license. Frames and paper patterns are original Flutter vector
drawings; no game screenshots, proprietary fonts or app artwork are bundled.
