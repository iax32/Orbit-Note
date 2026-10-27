import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_state.dart';
import 'workspace_controller.dart';

/// Explicitly retained temporary edits, scoped to one Vault and stable owner.
/// These are not canonical object edits and never auto-apply on recovery.
class RetainedForm {
  RetainedForm._(
    this.controller,
    this.generation,
    this.workspace,
    this.key,
    this.base,
  ) {
    _capturedEntry = jsonEncode(_entries[key]);
  }
  late String _capturedEntry;
  void _checkRecord() {
    final raw = controller.session.extra['retainedForms'];
    if (raw != null &&
        (raw is! Map || raw['version'] != 1 || raw['entries'] is! Map)) {
      throw StateError(
        'Unrecognized form drafts are preserved. Copy your edits before closing.',
      );
    }
    if (jsonEncode(_entries[key]) != _capturedEntry) {
      throw StateError(
        'This retained draft changed in another form. Copy your edits before reopening it.',
      );
    }
  }

  final WorkspaceController controller;
  final int generation;
  final String workspace, key, base;
  static RetainedForm? capture(
    BuildContext context,
    String key,
    Object source,
  ) {
    try {
      final c = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(workspaceProvider.notifier);
      if (!c.hasWorkspace || c.loading || c.repository.readOnly) return null;
      return RetainedForm._(
        c,
        c.workspaceGeneration,
        c.repository.workspaceId,
        key,
        sha256.convert(utf8.encode(jsonEncode(source))).toString(),
      );
    } on StateError {
      return null;
    }
  }

  bool get current =>
      controller.hasWorkspace &&
      !controller.loading &&
      controller.workspaceGeneration == generation &&
      controller.repository.workspaceId == workspace &&
      !controller.repository.readOnly;
  Map<String, dynamic> get _entries {
    final raw = controller.session.extra['retainedForms'];
    if (raw is! Map || raw['version'] != 1 || raw['entries'] is! Map) return {};
    return Map<String, dynamic>.from(raw['entries'] as Map);
  }

  Map<String, dynamic>? get recovered {
    if (!current) return null;
    final entry = _entries[key];
    if (entry is! Map || entry['values'] is! Map) return null;
    return Map<String, dynamic>.from(entry['values'] as Map);
  }

  bool get sourceChanged =>
      _entries[key] is Map && (_entries[key] as Map)['base'] != base;
  Future<void> _store(Map<String, dynamic> entries) async {
    final prior = _entries[key];
    final raw = controller.session.extra['retainedForms'];
    void assign(Map<String, dynamic> next) {
      controller.session = SessionState.fromJson({
        ...controller.session.toJson(),
        'retainedForms': {
          ...?raw is Map ? Map<String, dynamic>.from(raw) : null,
          'version': 1,
          'entries': next,
        },
      });
    }

    assign(entries);
    try {
      await controller.saveSession();
      if (!current ||
          controller.sessionSaveFailed ||
          jsonEncode(_entries[key]) != jsonEncode(entries[key])) {
        throw StateError(
          'Draft persistence could not be confirmed. Keep this form open.',
        );
      }
    } catch (_) {
      // A failed write must remain retryable. Never roll back a newer form.
      if (current && jsonEncode(_entries[key]) == jsonEncode(entries[key])) {
        final latest = _entries;
        if (prior == null) {
          latest.remove(key);
        } else {
          latest[key] = prior;
        }
        assign(latest);
      }
      rethrow;
    }
  }

  Future<bool> discard() async {
    _checkRecord();
    if (!current) {
      throw StateError('The Vault changed; retained drafts were not removed.');
    }
    final entries = _entries;
    entries.remove(key);
    await _store(entries);
    controller.notify();
    _capturedEntry = jsonEncode(null);
    return true;
  }

  /// Call only after the normal editor/save boundary accepted the form.
  Future<void> complete() async {
    if (!current || recovered == null) return;
    try {
      await discard();
    } catch (_) {
      // A failed cleanup keeps the reviewable draft; canonical edits stay saved.
    }
  }

  Future<bool> keep(Map<String, dynamic> values) async {
    _checkRecord();
    if (!current) {
      throw StateError(
        'The Vault changed. Keep this form open and copy your edits.',
      );
    }
    final raw = controller.session.extra['retainedForms'];
    if (raw != null && (raw is! Map || raw['version'] != 1)) {
      throw StateError(
        'Newer form drafts are preserved. Copy your edits before closing.',
      );
    }
    if (utf8.encode(jsonEncode(values)).length > 96 * 1024) {
      throw StateError(
        'This draft exceeds 96 KiB. Keep editing or copy the text before closing.',
      );
    }
    final entries = _entries;
    if (entries.length >= 25 && !entries.containsKey(key)) {
      throw StateError(
        '25 form drafts are already retained. Reopen and finish a previous draft first.',
      );
    }
    final previous = entries[key];
    final merged = <String, dynamic>{
      if (previous is Map && previous['values'] is Map)
        ...Map<String, dynamic>.from(previous['values'] as Map),
      ...values,
    };
    if (utf8.encode(jsonEncode(merged)).length > 96 * 1024) {
      throw StateError(
        'The complete retained draft exceeds 96 KiB. Copy it before closing.',
      );
    }
    entries[key] = {
      ...?entries[key] is Map
          ? Map<String, dynamic>.from(entries[key] as Map)
          : null,
      'base': base,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'values': merged,
    };
    await _store(entries);
    controller.notify();
    _capturedEntry = jsonEncode(entries[key]);
    return true;
  }

  Widget notice() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      sourceChanged
          ? 'Recovered unapplied form. The source changed since it was kept; review every field before applying.'
          : 'Recovered unapplied form. Review it before applying; the original is unchanged.',
    ),
  );
}
