import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/orbit_theme.dart';
import '../../domain/universal_object.dart';
import '../../infrastructure/storage/workspace_store.dart';

typedef AttachmentRecoveryProgress =
    void Function(int bytesRead, int totalBytes, String phase);
typedef AttachmentRecoveryCancellation = bool Function();

Color _recoveryReadableColor(
  Color background,
  Color preferred, {
  double minimumContrast = 4.5,
}) {
  if (OrbitContrast.ratio(preferred, background) >= minimumContrast) {
    return preferred;
  }
  final candidates = [Colors.white, Colors.black];
  candidates.sort(
    (a, b) => OrbitContrast.ratio(
      b,
      background,
    ).compareTo(OrbitContrast.ratio(a, background)),
  );
  return candidates.first;
}

ThemeData _recoveryReadableTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  final dialogSurface = colors.surfaceContainerHigh;
  final onSurface = _recoveryReadableColor(dialogSurface, colors.onSurface);
  final onSurfaceVariant = _recoveryReadableColor(
    dialogSurface,
    colors.onSurfaceVariant,
  );
  final outline = _recoveryReadableColor(
    dialogSurface,
    colors.outline,
    minimumContrast: 3.0,
  );
  final primary = _recoveryReadableColor(
    dialogSurface,
    colors.primary,
    minimumContrast: 3.0,
  );
  final onPrimary = _recoveryReadableColor(primary, colors.onPrimary);
  return theme.copyWith(
    colorScheme: colors.copyWith(
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      primary: primary,
      onPrimary: onPrimary,
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ),
  );
}

/// Reviews source recovery choices before invoking workspace commands.
class AttachmentRecoveryDialog extends StatefulWidget {
  const AttachmentRecoveryDialog({
    super.key,
    required this.object,
    required this.reference,
    required this.onRestoreOriginal,
    required this.onRelink,
    required this.onRestoreVersion,
    required this.onOpen,
    required this.onForgetVersion,
    this.staged = const [],
    this.onResume,
    this.onDiscard,
  });

  final UniversalObject object;
  final String reference;
  final Future<bool> Function(
    AttachmentRecoveryProgress report,
    AttachmentRecoveryCancellation isCancelled,
  ) onRestoreOriginal,
      onRelink;
  final Future<bool> Function(
    String,
    AttachmentRecoveryProgress,
    AttachmentRecoveryCancellation,
  )
  onRestoreVersion;
  final ValueChanged<String> onOpen;
  final Future<bool> Function(
    String,
    AttachmentRecoveryProgress,
    AttachmentRecoveryCancellation,
  )
  onForgetVersion;
  final List<WorkspaceAttachmentStageInfo> staged;
  final Future<bool> Function(
    WorkspaceAttachmentStageInfo stage,
    AttachmentRecoveryProgress report,
    AttachmentRecoveryCancellation isCancelled,
  )?
  onResume;
  final Future<bool> Function(WorkspaceAttachmentStageInfo stage)? onDiscard;

  @override
  State<AttachmentRecoveryDialog> createState() =>
      _AttachmentRecoveryDialogState();
}

class _AttachmentRecoveryDialogState extends State<AttachmentRecoveryDialog> {
  final FocusNode _dialogFocusNode = FocusNode(
    debugLabel: 'attachment-recovery-dialog',
  );
  bool busy = false;
  String? status;
  double? progress;
  String? progressLabel;
  bool cancelRequested = false;
  int historyPage = 0;

  @override
  void dispose() {
    _dialogFocusNode.dispose();
    super.dispose();
  }

  void _requestCancel() {
    if (!busy || cancelRequested) return;
    setState(() {
      cancelRequested = true;
      status = 'Cancellation requested. Preserving your sources…';
      progressLabel = 'Cancelling safely…';
    });
  }

  void _handleEscape() {
    if (busy) {
      _requestCancel();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> run(
    Future<bool> Function(
      AttachmentRecoveryProgress report,
      AttachmentRecoveryCancellation isCancelled,
    )
    command,
  ) async {
    setState(() {
      busy = true;
      status = null;
      progress = null;
      progressLabel = 'Preparing recovery…';
      cancelRequested = false;
    });
    void report(int bytesRead, int totalBytes, String phase) {
      if (!mounted) return;
      setState(() {
        progress = totalBytes <= 0
            ? null
            : (bytesRead / totalBytes).clamp(0.0, 1.0).toDouble();
        progressLabel = phase;
      });
    }

    try {
      final ok = await command(report, () => cancelRequested);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context);
      } else {
        setState(
          () => status = cancelRequested
              ? 'Recovery cancelled. Your references and retained sources are preserved.'
              : 'Recovery was not applied. Your references and retained sources are preserved.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              status = 'Recovery failed. Your existing sources are preserved.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          progress = null;
          progressLabel = null;
        });
      }
    }
  }

  Future<void> forget(String reference) async {
    final readableTheme = _recoveryReadableTheme(Theme.of(context));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: readableTheme,
        child: AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.all(16),
          actionsOverflowButtonSpacing: 8,
          title: const Text('Forget retained source?'),
          content: const Text(
            'This removes the source from history and deletes its bytes when no other file object uses them. The active source is not affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Forget source'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await run(
        (report, isCancelled) =>
            widget.onForgetVersion(reference, report, isCancelled),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final highContrast = media.highContrast;
    final reducedMotion = media.disableAnimations;
    final readableTheme = _recoveryReadableTheme(theme);
    final colors = readableTheme.colorScheme;
    final safeOnSurface = colors.onSurface;
    final safeOutline = colors.outline;
    final safePrimary = colors.primary;
    final safeTheme = readableTheme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: highContrast
            ? ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(120, 48)),
                side: WidgetStatePropertyAll(
                  BorderSide(color: safeOutline, width: 1.5),
                ),
              )
            : readableTheme.textButtonTheme.style,
      ),
    );
    final raw = widget.object.properties['attachmentSourceHistory'];
    final history = raw is List
        ? raw.whereType<Map>().toList().reversed.toList()
        : <Map>[];
    const pageSize = 8;
    final pageCount = (history.length / pageSize).ceil();
    final page = pageCount == 0
        ? 0
        : historyPage.clamp(0, pageCount - 1).toInt();
    final visibleHistory = history.skip(page * pageSize).take(pageSize);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        const SingleActivator(LogicalKeyboardKey.pageUp, control: true): () {
          if (!busy && page > 0) setState(() => historyPage = page - 1);
        },
        const SingleActivator(LogicalKeyboardKey.pageDown, control: true): () {
          if (!busy && page < pageCount - 1) {
            setState(() => historyPage = page + 1);
          }
        },
      },
      child: Focus(
        focusNode: _dialogFocusNode,
        autofocus: true,
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: PopScope(
            canPop: !busy,
            child: Semantics(
              namesRoute: true,
              label: 'Attachment recovery and source history',
              child: Theme(
                data: safeTheme,
                child: AlertDialog(
                  scrollable: true,
                  insetPadding: const EdgeInsets.all(16),
                  surfaceTintColor: highContrast ? colors.surface : null,
                  shape: highContrast
                      ? RoundedRectangleBorder(
                          side: BorderSide(color: safeOutline, width: 2),
                          borderRadius: BorderRadius.circular(16),
                        )
                      : null,
                  title: const Text('Attachment recovery & sources'),
                  content: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.object.title,
                          style: safeTheme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(widget.reference),
                        const SizedBox(height: 16),
                        const Text('Restore missing original'),
                        const Text(
                          'Choose a copy with the recorded checksum. This restores missing bytes at the original path without replacing an existing file.',
                        ),
                        TextButton.icon(
                          onPressed: busy
                              ? null
                              : () => run(widget.onRestoreOriginal),
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Locate original file'),
                        ),
                        if (widget.staged.isNotEmpty) ...[
                          const Divider(),
                          Semantics(
                            header: true,
                            child: Text('Interrupted transfers'),
                          ),
                          const Text(
                            'A previous transfer was safely retained. Choose the same source file to continue from its saved byte offset, or discard it.',
                          ),
                          for (final stage in widget.staged) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: highContrast
                                  ? const EdgeInsets.all(8)
                                  : EdgeInsets.zero,
                              decoration: highContrast
                                  ? BoxDecoration(
                                      border: Border.all(
                                        color: safeOutline,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                              child: Semantics(
                                container: true,
                                label:
                                    '${stage.operation == 'restore' ? 'Restore original' : 'New source'}, ${stage.length} bytes, target ${stage.target}',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${stage.operation == 'restore' ? 'Restore original' : 'New source'} · ${stage.length} bytes',
                                      style: safeTheme.textTheme.titleSmall,
                                    ),
                                    SelectableText(stage.target),
                                    if (stage.sourceName != null)
                                      Text('Source: ${stage.sourceName}'),
                                    Text('Checksum: ${stage.expectedHash}'),
                                  ],
                                ),
                              ),
                            ),
                            Wrap(
                              children: [
                                TextButton.icon(
                                  onPressed: busy || widget.onResume == null
                                      ? null
                                      : () => run(
                                          (report, isCancelled) =>
                                              widget.onResume!(
                                                stage,
                                                report,
                                                isCancelled,
                                              ),
                                        ),
                                  icon: const Icon(Icons.play_arrow_outlined),
                                  label: const Text('Resume'),
                                ),
                                TextButton.icon(
                                  onPressed: busy || widget.onDiscard == null
                                      ? null
                                      : () => run(
                                          (_, _) => widget.onDiscard!(stage),
                                        ),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Discard'),
                                ),
                              ],
                            ),
                          ],
                        ],
                        const Divider(),
                        Semantics(
                          header: true,
                          child: Text('Relink file object'),
                        ),
                        const Text(
                          'Choose a new source for links to this file object. Its ID stays the same and the previous source is retained. Markdown paths continue to open their original files.',
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : () => run(widget.onRelink),
                          icon: const Icon(Icons.link_outlined),
                          label: const Text('Choose new source'),
                        ),
                        const Divider(),
                        Semantics(
                          header: true,
                          child: Text(
                            'Source history · ${history.length} retained',
                          ),
                        ),
                        if (history.isEmpty)
                          const Text('No previous sources have been recorded.'),
                        if (pageCount > 1)
                          Row(
                            children: [
                              Semantics(
                                label: 'Previous source history page',
                                hint: 'Control plus Page Up',
                                button: true,
                                child: IconButton(
                                  tooltip: 'Previous source history page',
                                  onPressed: busy || page == 0
                                      ? null
                                      : () => setState(
                                          () => historyPage = page - 1,
                                        ),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  liveRegion: true,
                                  label:
                                      'Source history page ${page + 1} of $pageCount',
                                  child: Text(
                                    'Page ${page + 1} of $pageCount',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              Semantics(
                                label: 'Next source history page',
                                hint: 'Control plus Page Down',
                                button: true,
                                child: IconButton(
                                  tooltip: 'Next source history page',
                                  onPressed: busy || page == pageCount - 1
                                      ? null
                                      : () => setState(
                                          () => historyPage = page + 1,
                                        ),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ),
                            ],
                          ),
                        for (final source in visibleHistory) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: highContrast
                                ? const EdgeInsets.all(8)
                                : EdgeInsets.zero,
                            decoration: highContrast
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: safeOutline,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Semantics(
                              container: true,
                              label:
                                  'Retained source ${source['originalName'] is String ? source['originalName'] : 'without a name'}, ${source['byteLength'] ?? 'unknown'} bytes',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source['originalName'] is String
                                        ? source['originalName'] as String
                                        : 'Retained source',
                                  ),
                                  SelectableText(
                                    '${source['contentRef'] ?? 'Unknown path'}',
                                  ),
                                  Text(
                                    'Recorded: ${source['recordedAt'] ?? 'Unknown'}',
                                  ),
                                  Text(
                                    'Size: ${source['byteLength'] ?? 'Unknown'} bytes',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed:
                                    busy || source['contentRef'] is! String
                                    ? null
                                    : () => widget.onOpen(
                                        source['contentRef'] as String,
                                      ),
                                child: const Text('Open retained source'),
                              ),
                              TextButton(
                                onPressed:
                                    busy || source['contentRef'] is! String
                                    ? null
                                    : () => run(
                                        (report, isCancelled) =>
                                            widget.onRestoreVersion(
                                              source['contentRef'] as String,
                                              report,
                                              isCancelled,
                                            ),
                                      ),
                                child: const Text('Use this source'),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: busy || source['contentRef'] is! String
                                ? null
                                : () => forget(source['contentRef'] as String),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Forget retained source'),
                          ),
                        ],
                        if (busy) ...[
                          Semantics(
                            label: progress == null
                                ? 'Recovery in progress'
                                : 'Recovery ${(progress! * 100).round()} percent complete',
                            value: progressLabel,
                            liveRegion: true,
                            child: TickerMode(
                              enabled: !reducedMotion,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: highContrast ? 6 : 4,
                                color: highContrast ? safePrimary : null,
                                backgroundColor: highContrast
                                    ? safeOnSurface.withValues(alpha: 0.18)
                                    : null,
                              ),
                            ),
                          ),
                          if (progressLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(progressLabel!),
                            ),
                        ],
                        if (status != null)
                          Semantics(liveRegion: true, child: Text(status!)),
                      ],
                    ),
                  ),
                  actions: [
                    Semantics(
                      button: true,
                      label: busy
                          ? cancelRequested
                                ? 'Cancellation requested'
                                : 'Cancel recovery verification'
                          : 'Close recovery dialog',
                      child: TextButton(
                        onPressed: busy
                            ? cancelRequested
                                  ? null
                                  : _requestCancel
                            : _handleEscape,
                        child: Text(
                          busy
                              ? cancelRequested
                                    ? 'Cancelling…'
                                    : 'Cancel verification'
                              : 'Close',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
