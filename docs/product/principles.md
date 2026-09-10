# Product principles

1. **Local first.** Core reading, writing, navigation, and organization work without
   an account or network. Sync is optional infrastructure.
2. **User-owned knowledge.** Markdown for text, ordinary attachments, documented
   versioned open structures for richer content. Export complete workspaces;
   avoid irreplaceable content hidden only in an index or provider service.
3. **One identity, many views.** Views query/reference universal objects. A canvas
   placement owns geometry, not a duplicated note body.
4. **Organization is plural.** Folders, notebook/section hierarchy, tags, relations,
   manual collections, smart collections, and spatial placement coexist.
5. **Simple by default.** A small working product precedes a platform. Reveal
   advanced options progressively; keep ordinary capture fast.
6. **Safe customization.** Offer extensive control with validation, undo/reset,
   safe defaults, and accessible recovery even when every panel is hidden.
7. **Reversible assistance.** AI explains and proposes; users review mutations.
   Commands preserve before-state and reject stale assumptions.
8. **Shared engines.** Boards, freeform pages, PDF/image annotations reuse spatial
   and ink primitives. Add specialized adapters rather than parallel implementations.
9. **Performance by evidence.** Query visible content, render selectively, batch
   input, keep I/O off the rendering path, and profile representative workloads.
10. **Extensible boundaries.** Plugins and local APIs use versioned capability
    interfaces, scoped permissions, and the same validated application commands.
11. **Portable, accessible experience.** Windows is the first delivery target;
    platform adapters preserve Android/iOS/web viability. Keyboard, touch, stylus,
    screen readers, text scaling, and recovery are part of feature acceptance.
12. **No silent loss.** Preserve conflicts and unknown data, back up migrations,
    and distinguish saved content from queued/exporting state.

Tradeoffs should favor reliable ownership and understandable behavior over a
larger feature count. No feature is required merely because it appears in the
[catalog](feature-catalog.md).

## Compatibility and contextual knowledge

Create once, view anywhere. Any object may provide context for another through
references and typed relations; context never grants permission implicitly.
Backward compatibility is a product feature: new releases should expand existing
workspaces, preserve old notes and unknown data, and migrate safely with recovery.
Use progressive disclosure to keep ordinary work calm while advanced workflows
remain available. See the [compatibility contract](../architecture/compatibility-and-migrations.md).
