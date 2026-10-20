# Technical articles and CMS handoff

Local EDT-09, REV-02/03/04, CAN-07/13 and PORT-05/06 subset, 2026-10-17.

## Writing

Article publishing now protects unapplied metadata edits on all normal dismissal
paths, and resets that protection after a successful Apply. Copy/export does not
claim to have saved metadata to the note. Stale editor/Vault contexts refuse
Apply and keep the form. The shared HTML exporter preserves code language,
table alignment and title anchors without emitting a second matching title.

New Note from Template includes Game memory research article, Reverse-engineering
case study, Build comparison article and Game systems technical deep dive.
Choose one, then fill title, author, reader, question, target/build, architecture
and tools. These become ordinary editable Markdown. New articles also carry
optional publishing metadata. Insert Template adds authored sections without
inserting a second metadata header into an existing document.

The starters separate observations from hypotheses, request reproducible build/
module/address-space context and controls, and include evidence, limitations,
sources and corrections. They do not contain a live debugger or perform memory
reads/writes, scanning, injection or binary patching.

## Diagrams and recorded address arithmetic

Writing tools → Research diagram creates a Memory layout, Pointer chain, Call flow
or Evidence and validation diagram. Inserting a diagram saves one ordinary Canvas
and embeds explicit placement references in the note. Shapes/labels/connectors
remain editable; Rich and Read use the shared vector renderer with source opening,
zoom and selectable details. Edits remain live. Missing/deleted items retain the
original reference with a useful fallback. Note insertion uses normal undo; the
underlying saved Canvas remains a separate recoverable object.

Canvas → Shapes and diagrams → Memory & research diagram inserts the same preset
as one undoable scene change. Existing diagram-to-Markdown actions now accept
ordinary rectangles, ellipses, diamonds and text, with bound relationships between
referenced items. Object cards/media retain their own reference-block workflow.
The normal Canvas SVG/PNG/JSON export remains available for public figures.

The research dialog also calculates recorded unsigned hexadecimal base+RVA values
at 32/64 bits, rejects overflow and shows little-endian address bytes. Copy or
insert a Markdown calculation table. This arithmetic does not resolve a pointer,
confirm an address is mapped, or associate a bare address with a binary identity.
Record build/module context in the surrounding article. Preset values are examples.

## Article publishing

Writing tools → Article publishing edits search title, description, author/profile,
canonical URL, representative image URL, language, publication/update dates and
the exported HTML's indexing choice. Apply to note uses the editor's normal
recoverable save path and refuses changed documents/Vaults. Unknown fields survive;
future/malformed article versions cannot be replaced by this panel.

Offline content checks identify unfinished prompts, missing image alternative
text, private links and reader-navigation concerns. They exclude code examples,
retain manual evidence/reproducibility prompts, and cache content analysis while
metadata fields are edited. They do not test a live site, predict a Google penalty,
enforce a word count/keyword density, or produce an invented SEO score.

- Copy CMS HTML: body fragment with escaped prose/code, tables and linked endnotes.
  Set the post title in the CMS separately. Public HTTP(S) image URLs remain image
  links; local figures need upload/replacement. Private/live objects and unavailable
  resources retain explicit exporter warnings/fallbacks, not a self-contained
  public diagram or attachment. Preview the result in the CMS.
- Copy CMS handoff: metadata and a deployment/checking checklist. Configure head
  metadata through the CMS/SEO fields. WordPress may sanitize scripts and SVG;
  do not paste an entire HTML document into the article body.
- Copy Article JSON-LD: only authored applicable properties, with safe JSON
  escaping. Check whether the CMS already generates schema to avoid duplication.
- Export standalone HTML / existing Publish document HTML: include description,
  canonical, optional noindex, Open Graph fields, visible byline/dates and Article
  JSON-LD. No publication/update dates are invented. PDF/Word retain the existing
  document-print workflow; web head metadata is not a print format.

No publishing account is connected, article uploaded, remote image fetched or
website/robots configuration changed by these tools.

## Search guidance

Google recommends original, useful, reliable content for a defined readership,
descriptive titles/links, public crawlable pages and an overall good page
experience. Keyword stuffing, hidden ranking-oriented text, link spam and scaled
low-value content can violate its policies. No setting guarantees first place,
indexing or rich results. Being absent from Search is not itself proof of a ban.

After publishing, verify the public URL, HTTP 200, access without login, canonical,
robots/noindex settings and sitemap. Use Search Console URL Inspection and Page
indexing; consult Manual Actions and Security Issues when investigating exclusion
or a traffic drop. Hosting, CMS rendering, mobile layout and performance require
checks on the actual site. Do not treat the offline prompts as those checks.

Official references checked 2026-10-17:

- [Google SEO starter guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)
- [Helpful content](https://developers.google.com/search/docs/fundamentals/creating-helpful-content)
- [Article structured data](https://developers.google.com/search/docs/appearance/structured-data/article)
- [Spam policies](https://developers.google.com/search/docs/essentials/spam-policies)
- [Search traffic diagnostics](https://developers.google.com/search/docs/monitor-debug/debugging-search-traffic-drops)
- [WordPress Custom HTML](https://wordpress.org/documentation/article/custom-html/)
