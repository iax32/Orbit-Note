# Canvas input performance

User reports severe pen/pan lag on desktop and tablet, including live sessions.
Preserve all samples, pen styles, visuals, gestures and live sync features.

Found: each pen move rebuilds the full editor and repaints/queries the saved
scene. Saved ink LRU can cycle with more visible strokes than its 256-entry
capacity, regenerating display lists on every pan. Isolate active vector ink in
its own repaint boundary and admit a stable bounded visible-ink working set.
Do not reduce pressure samples or change the renderer. Validate pixel equality,
stylus gesture persistence/undo, live behavior and dense-board performance.

Implemented: a separately clipped active-ink repaint boundary uses the identical
vector renderer and retains all source pressure/time samples. Pointer moves only
notify that layer, avoiding editor builds, saved-scene queries, image working-set
work and minimap updates per pen frame. Saved ink admits a stable visible working
set (1024 display-list entries, existing 200k-sample ceiling) rather than cyclic
LRU eviction. Offscreen entries remain reclaimable; uncached ink still renders.

Validation: 22 focused tests pass, including pixel-identical active strokes for
all seven nib/highlighter styles at zoom and prior raster/detail/scene/minimap
checks. Stylus release/palm-cancel/undo test and first-stylus/inverted-eraser test
pass separately. The 1002-sample test also proves no saved-scene painter rebuild
during the input burst. 1500 strokes/20 paints: baseline 30000 recordings / 1.271 s;
stable 1024 recordings / .675 s (informational local CPU benchmark, not tablet FPS).
Final saturation bookkeeping avoids repeatedly scanning a full visible cache:
baseline 1.247 s versus .402 s for the same 1500-stroke/20-paint workload, about
3.1x faster CPU painting. Recording counts and pixel output remain unchanged.
No samples, pen styles, sync functions or exported visuals removed.

Analyzer clean (7.0 s); format 862 files unchanged. Android 1.0.6+7 and Windows
builds are being finalized with the last cache improvement. Physical tablet
acceptance remains separate. No physical-device frame-rate claim is made.
