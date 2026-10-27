import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Makes a local Markdown image an explicit, accessible attachment action in
/// Read mode. Remote/data images keep their normal display behavior.
class ReadAttachmentPreview extends StatelessWidget {
  const ReadAttachmentPreview({
    super.key,
    required this.uri,
    required this.child,
    this.onOpen,
    this.description,
  });

  final Uri uri;
  final Widget child;
  final ValueChanged<String>? onOpen;
  final String? description;

  @override
  Widget build(BuildContext context) {
    if (uri.scheme.isNotEmpty || onOpen == null) return child;
    final label = uri.path.isEmpty ? uri.toString() : uri.path;
    return Semantics(
      button: true,
      label: description?.trim().isNotEmpty == true
          ? '${description!.trim()}. Open attachment $label'
          : 'Open attachment $label',
      child: InkWell(
        onTap: () => onOpen!(uri.toString()),
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

/// Loads a local attachment with an explicit retry path when the vault is
/// temporarily unavailable or the original bytes were removed.
class ReadAttachmentImage extends StatefulWidget {
  const ReadAttachmentImage({
    super.key,
    required this.load,
    required this.builder,
    required this.label,
    this.revision = 0,
    this.aspectRatio,
    this.showReplacementStatus = false,
    this.retryableBuilder,
    this.title,
    this.mimeType,
    this.recordedByteLength,
    this.onOpenOriginal,
    this.onReveal,
    this.onCopyReference,
    this.onRecover,
  });

  final Future<Uint8List?> Function() load;
  final Widget Function(Uint8List bytes) builder;

  /// Optional builder for image decoders that can fail after the bytes load.
  /// It receives the same retry callback as storage failures.
  final Widget Function(Uint8List bytes, VoidCallback onRetry)?
  retryableBuilder;
  final String label;
  final int revision;
  final double? aspectRatio;
  final bool showReplacementStatus;
  final String? title, mimeType;

  /// Imported metadata, kept distinct from the bytes read for this preview.
  final int? recordedByteLength;
  final VoidCallback? onOpenOriginal, onReveal, onCopyReference, onRecover;

  @override
  State<ReadAttachmentImage> createState() => _ReadAttachmentImageState();
}

class _ReadAttachmentImageState extends State<ReadAttachmentImage> {
  late Future<Uint8List?> _future;
  int _attempt = 0;
  int? _replacementRevision;

  @override
  void initState() {
    super.initState();
    _future = Future.sync(widget.load);
  }

  @override
  void didUpdateWidget(covariant ReadAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label ||
        oldWidget.revision != widget.revision) {
      if (oldWidget.revision != widget.revision &&
          widget.showReplacementStatus) {
        _replacementRevision = widget.revision;
      }
      _attempt++;
      _future = Future.sync(widget.load);
    }
  }

  void _retry() {
    setState(() {
      _attempt++;
      _future = Future.sync(widget.load);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    key: ValueKey((widget.label, widget.revision, _attempt)),
    future: _future,
    builder: (context, snapshot) {
      Widget frame(Widget preview) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Reserve the same geometry while fetching, decoding and retrying.
              // Contain keeps the complete image visible without reducing quality.
              if (!constraints.hasBoundedWidth) return preview;
              final ratio = widget.aspectRatio;
              final height =
                  (constraints.maxWidth /
                          (ratio != null && ratio.isFinite && ratio > 0
                              ? ratio
                              : 1.5))
                      .clamp(96.0, 600.0);
              return SizedBox(height: height, child: preview);
            },
          ),
          if (widget.title != null ||
              widget.onOpenOriginal != null ||
              widget.onReveal != null ||
              widget.onCopyReference != null ||
              widget.onRecover != null)
            ReadAttachmentDetails(
              reference: widget.label,
              title: widget.title,
              mimeType: widget.mimeType,
              recordedByteLength: widget.recordedByteLength,
              loadedByteLength: snapshot.connectionState == ConnectionState.done
                  ? snapshot.data?.length
                  : null,
              onOpenOriginal: widget.onOpenOriginal,
              onReveal: widget.onReveal,
              onCopyReference: widget.onCopyReference,
              onRecover: widget.onRecover,
            ),
          if (_replacementRevision != null &&
              snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null)
            ReadAttachmentReplacementStatus(revision: _replacementRevision!),
        ],
      );
      final bytes = snapshot.data;
      if (bytes != null) {
        return frame(
          widget.retryableBuilder?.call(bytes, _retry) ?? widget.builder(bytes),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return frame(
          Semantics(
            liveRegion: true,
            label: 'Loading attachment ${widget.title ?? widget.label}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    if (widget.revision > 0) ...[
                      const SizedBox(height: 6),
                      const Text('Refreshing preview…'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final missing = snapshot.error == null;
      return frame(
        _AttachmentImageFailure(
          label: widget.label,
          message: missing ? 'Attachment missing' : 'Could not read attachment',
          onRetry: _retry,
        ),
      );
    },
  );
}

class _AttachmentImageFailure extends StatelessWidget {
  const _AttachmentImageFailure({
    required this.label,
    required this.message,
    required this.onRetry,
  });

  final String label;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72, minWidth: 180),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Semantics(
      liveRegion: true,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          const Icon(Icons.broken_image_outlined, size: 20),
          Text('$message: $label'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

/// Announces that a watcher-driven replacement has finished loading. This is
/// intentionally separate from the transient loading message so users can
/// tell a refreshed preview from the original bytes after the spinner leaves.
class ReadAttachmentReplacementStatus extends StatelessWidget {
  const ReadAttachmentReplacementStatus({super.key, required this.revision});

  final int revision;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Attachment preview updated',
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sync_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Preview updated · revision $revision',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}

/// A compact footer available even when storage or image decoding fails. Actions
/// remain at the workspace boundary; this widget never launches files itself.
class ReadAttachmentDetails extends StatelessWidget {
  const ReadAttachmentDetails({
    super.key,
    required this.reference,
    this.title,
    this.mimeType,
    this.recordedByteLength,
    this.loadedByteLength,
    this.onOpenOriginal,
    this.onReveal,
    this.onCopyReference,
    this.onRecover,
  });

  final String reference;
  final String? title, mimeType;
  final int? recordedByteLength, loadedByteLength;
  final VoidCallback? onOpenOriginal, onReveal, onCopyReference, onRecover;

  String get _name => title?.trim().isNotEmpty == true
      ? title!.trim()
      : reference.split('/').last;

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attachment details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('Type: ${mimeType ?? 'Unknown'}'),
              if (loadedByteLength != null)
                Text('Preview source: $loadedByteLength bytes'),
              if (recordedByteLength != null && recordedByteLength! >= 0)
                Text('Recorded size: $recordedByteLength bytes'),
              if (loadedByteLength != null &&
                  recordedByteLength != null &&
                  recordedByteLength! >= 0 &&
                  loadedByteLength != recordedByteLength)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'The loaded size differs from the recorded size.',
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Vault reference'),
              SelectableText(reference),
            ],
          ),
        ),
        actions: [
          if (onCopyReference != null)
            TextButton(
              onPressed: onCopyReference,
              child: const Text('Copy reference'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Tooltip(
          message: reference,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              _name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Attachment details for $_name',
          icon: const Icon(Icons.info_outline, size: 18),
          onPressed: () => _showDetails(context),
        ),
        if (onOpenOriginal != null)
          IconButton(
            tooltip: 'Open original $_name',
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: onOpenOriginal,
          ),
        if (onReveal != null)
          IconButton(
            tooltip: 'Show $_name in folder',
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            onPressed: onReveal,
          ),
        if (onCopyReference != null)
          IconButton(
            tooltip: 'Copy attachment reference for $_name',
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: onCopyReference,
          ),
        if (onRecover != null)
          IconButton(
            tooltip: 'Recover attachment or review source history',
            icon: const Icon(Icons.history_rounded, size: 18),
            onPressed: onRecover,
          ),
      ],
    ),
  );
}

/// Used as `Image.memory.errorBuilder` so corrupt or unsupported bytes have
/// the same recovery affordance as a missing attachment.
class ReadAttachmentDecodeFailure extends StatelessWidget {
  const ReadAttachmentDecodeFailure({
    super.key,
    required this.label,
    required this.onRetry,
  });

  final String label;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _AttachmentImageFailure(
    label: label,
    message: 'Preview could not be decoded',
    onRetry: onRetry,
  );
}
