import '../../domain/motion_preferences.dart';
import '../../domain/json_values.dart';
import 'motion_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../app/session_state.dart';
import '../../app/workspace_controller.dart';
import '../../domain/object_sort.dart';
import '../notes/note_typography.dart';
import 'focus_timer.dart';
import 'productivity_hub.dart';
import 'google_drive_settings.dart';
import 'system_appearance_setting.dart';
import 'theme_color_settings.dart';
import 'theme_interchange_dialog.dart';

enum _Category {
  appearance('Appearance', 'Color, type and display', Icons.palette_outlined),
  editor(
    'Writing & reading',
    'Comfortable, focused documents',
    Icons.edit_note,
  ),
  code('Code editor', 'Readable source and editor defaults', Icons.code),
  canvas('Canvas', 'Paper and spatial alignment', Icons.dashboard_outlined),
  layout(
    'Workspace',
    'Panels, explorer and split views',
    Icons.space_dashboard_outlined,
  ),
  focus(
    'Focus & audio',
    'Work sessions, breaks and playback',
    Icons.headphones_outlined,
  ),
  data(
    'Files & recovery',
    'Autosave, backups and local data',
    Icons.folder_outlined,
  ),
  sync('Sync & sharing', 'Google Drive and your own server', Icons.sync),
  tools('Tools', 'Research tools and workspace shortcuts', Icons.tune);

  const _Category(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

class _Entry {
  const _Entry(
    this.id,
    this.category,
    this.group,
    this.title,
    this.keywords,
    this.build,
  );
  final String id, group, title, keywords;
  final _Category category;
  final WidgetBuilder build;
  bool matches(String query) {
    final haystack = '$title $group $keywords ${category.label}'.toLowerCase();
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .every(haystack.contains);
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    required this.onExport,
    required this.onImport,
    required this.onOpenWorkspace,
  });
  final WorkspaceController controller;
  final VoidCallback onExport, onImport, onOpenWorkspace;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final scroll = ScrollController();
  final offsets = <_Category, double>{};
  _Category category = _Category.appearance;
  String query = '';
  WorkspaceController get controller => widget.controller;
  VoidCallback get onExport => widget.onExport;
  VoidCallback get onImport => widget.onImport;
  VoidCallback get onOpenWorkspace => widget.onOpenWorkspace;

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void changeSession(void Function(SessionState) change) {
    controller.updateSession(change);
    if (mounted) {
      setState(() {});
    }
  }

  void select(_Category value) {
    if (scroll.hasClients && query.isEmpty) {
      offsets[category] = scroll.offset;
    }
    search.clear();
    setState(() {
      category = value;
      query = '';
    });
    restoreScroll(offsets[value] ?? 0);
  }

  void setQuery(String value) {
    if (query.isEmpty && scroll.hasClients) {
      offsets[category] = scroll.offset;
    }
    setState(() => query = value.trim());
    restoreScroll(query.isEmpty ? offsets[category] ?? 0 : 0);
  }

  void restoreScroll(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(offset.clamp(0.0, scroll.position.maxScrollExtent));
      }
    });
  }

  Widget searchField() => TextField(
    key: const ValueKey('settings-search'),
    controller: search,
    focusNode: searchFocus,
    maxLength: 160,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => searchFocus.unfocus(),
    decoration: InputDecoration(
      hintText: 'Search settings',
      counterText: '',
      prefixIcon: const Icon(Icons.search, size: 19),
      suffixIcon: query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () {
                search.clear();
                setQuery('');
                searchFocus.requestFocus();
              },
            ),
    ),
    onChanged: setQuery,
  );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          searchFocus.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (query.isNotEmpty) {
          search.clear();
          setQuery('');
        }
      },
    },
    child: LayoutBuilder(
      builder: (context, area) {
        final colors = OrbitColors.of(context);
        final wide =
            area.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(14) <= 23;
        final entries = settings();
        final visible = entries
            .where(
              (e) => query.isEmpty ? e.category == category : e.matches(query),
            )
            .toList();
        final groups = <String, List<_Entry>>{};
        for (final e in visible) {
          final key = query.isEmpty
              ? e.group
              : '${e.category.label} / ${e.group}';
          groups.putIfAbsent(key, () => []).add(e);
        }
        final body = ListView(
          key: const ValueKey('settings-content'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          controller: scroll,
          padding: EdgeInsets.all(wide ? 32 : 16),
          children: [
            if (!wide) ...[
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              searchField(),
              const SizedBox(height: 12),
              if (query.isEmpty)
                DropdownButtonFormField<_Category>(
                  key: const ValueKey('settings-category-picker'),
                  initialValue: category,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Browse settings',
                  ),
                  items: [
                    for (final item in _Category.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      select(v);
                    }
                  },
                )
              else
                Text(
                  'Across all categories',
                  style: TextStyle(color: colors.subtle, fontSize: 12),
                ),
              const SizedBox(height: 24),
            ],
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text(
                  query.isEmpty ? category.label : 'Search results',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (query.isEmpty && resets().isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('settings-reset-section'),
                    onPressed: resetSection,
                    icon: const Icon(Icons.restart_alt, size: 17),
                    label: const Text('Reset section'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Semantics(
              liveRegion: query.isNotEmpty,
              child: Text(
                query.isEmpty
                    ? category.description
                    : '${visible.length} ${visible.length == 1 ? 'setting matches' : 'settings match'} “$query”',
                style: TextStyle(color: colors.subtle),
              ),
            ),
            const SizedBox(height: 24),
            if (visible.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.search_off),
                    const SizedBox(height: 12),
                    const Text('No matching settings'),
                    const SizedBox(height: 6),
                    const Text('Try “font”, “backup”, “grid” or “focus”.'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        search.clear();
                        setQuery('');
                      },
                      child: const Text('Clear search'),
                    ),
                  ],
                ),
              ),
            for (final group in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(group.key, style: OrbitTypography.section(context)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < group.value.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: colors.divider),
                      Padding(
                        key: ValueKey('settings-entry-${group.value[i].id}'),
                        padding: const EdgeInsets.all(16),
                        child: Material(
                          type: MaterialType.transparency,
                          child: group.value[i].build(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Changes save automatically on this device. Document-specific choices keep their own settings.',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ],
        );
        if (!wide) {
          return body;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 244,
              decoration: BoxDecoration(
                color: colors.workspace,
                border: Border(right: BorderSide(color: colors.divider)),
              ),
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      top: 8,
                      bottom: 20,
                    ),
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  searchField(),
                  const SizedBox(height: 20),
                  for (final item in _Category.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          key: ValueKey('settings-category-${item.name}'),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: Icon(item.icon, size: 19),
                          title: Text(item.label),
                          selected: query.isEmpty && category == item,
                          onTap: () => select(item),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'Orbit Note\nYour workspace, your way.',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: body,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget choice<T>(
    String id,
    String title,
    String description,
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed,
  ) => _SettingsControlTile(
    title: Text(title),
    subtitle: Text(description),
    trailing: DropdownButton<T>(
      key: ValueKey('settings-$id'),
      isExpanded: true,
      itemHeight: null,
      value: value,
      underline: const SizedBox.shrink(),
      items: [
        for (final e in {
          ...choices,
          if (!choices.containsKey(value)) value: '$value (Current)',
        }.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) {
          changed(v);
        }
      },
    ),
  );
  Widget toggle(
    String id,
    String title,
    String detail,
    bool value,
    ValueChanged<bool> changed,
  ) => SwitchListTile(
    key: ValueKey('settings-$id'),
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(detail),
    value: value,
    onChanged: changed,
  );
  Widget range(
    String id,
    String title,
    String detail,
    double value,
    double min,
    double max,
    ValueChanged<double> changed, {
    String? label,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SettingsControlTile(
        title: Text(title),
        subtitle: Text(detail),
        trailing: Text(label ?? '${value.round()} px'),
      ),
      Slider(
        key: ValueKey('settings-$id'),
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: (max - min).round(),
        label: label ?? '${value.round()}',
        onChanged: changed,
      ),
    ],
  );

  Future<void> resetSection() async {
    final owner = controller,
        session = controller.session,
        generation = controller.workspaceGeneration,
        section = category;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: Text('Reset ${section.label.toLowerCase()}?'),
        content: const SingleChildScrollView(
          child: Text(
            'Restore this section’s preferences to Orbit defaults. Your documents, layouts in other Spaces and account connections stay intact. You can undo this reset.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset preferences'),
          ),
        ],
      ),
    );
    bool owns() =>
        mounted &&
        identical(controller, owner) &&
        identical(controller.session, session) &&
        controller.workspaceGeneration == generation;
    if (!mounted || accepted != true || !owns()) {
      return;
    }
    // Capture at approval time so an external settings change is not overwritten
    // by the values that were visible when the confirmation opened.
    final livePlan = resets(forCategory: section);
    changeSession((s) {
      for (final entry in livePlan) {
        entry.reset(s);
      }
    });
    configureTimer(section);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${section.label} preferences reset'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!owns() ||
                !livePlan.every((e) => e.isReset(controller.session))) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Preferences changed after the reset. Undo was not applied.',
                    ),
                  ),
                );
              }
              return;
            }
            changeSession((s) {
              for (final entry in livePlan) {
                entry.restore(s);
              }
            });
            configureTimer(section);
          },
        ),
      ),
    );
  }

  void configureTimer(_Category section) {
    if (section == _Category.focus) {
      final s = controller.session;
      globalFocusTimer.configureDurations(
        focus: s.focusMinutes,
        shortBreak: s.shortBreakMinutes,
        longBreak: s.longBreakMinutes,
      );
    }
  }

  List<_Reset> resets({_Category? forCategory}) {
    final s = controller.session;
    return switch (forCategory ?? category) {
      _Category.appearance => [
        resetColors(s),
        _resetValue(
          s,
          (s) => s.themePreset,
          (s, v) => s.themePreset = v,
          'orbit',
        ),
        _resetValue(
          s,
          (s) => s.followSystemAppearance,
          (s, v) => s.followSystemAppearance = v,
          false,
        ),
        _resetValue(
          s,
          (s) => s.accentColor,
          (s, v) => s.accentColor = v,
          'theme',
        ),
        _resetValue(
          s,
          (s) => s.fontFamily,
          (s, v) => s.fontFamily = v,
          'Segoe UI',
        ),
        _resetValue(
          s,
          (s) => s.cornerStyle,
          (s, v) => s.cornerStyle = v,
          'rounded',
        ),
        _resetValue(s, (s) => s.uiZoom, (s, v) => s.uiZoom = v, 1.0),
      ],
      _Category.editor => [
        _resetValue(s, (s) => s.fontSize, (s, v) => s.fontSize = v, 16.0),
        _resetValue(
          s,
          (s) => s.contentWidth,
          (s, v) => s.contentWidth = v,
          1080.0,
        ),
        _resetValue(
          s,
          (s) => s.editorLineHeight,
          (s, v) => s.editorLineHeight = v,
          1.6,
        ),
        _resetValue(
          s,
          (s) => s.spellCheckEnabled,
          (s, v) => s.spellCheckEnabled = v,
          true,
        ),
        _resetValue(
          s,
          (s) => s.defaultNoteMode,
          (s, v) => s.defaultNoteMode = v,
          'rich',
        ),
        _resetValue(
          s,
          (s) => s.defaultDocumentFormat,
          (s, v) => s.defaultDocumentFormat = v,
          'markdown',
        ),
        _resetValue(
          s,
          (s) => s.bionicReadingDefault,
          (s, v) => s.bionicReadingDefault = v,
          false,
        ),
      ],
      _Category.code => [
        _resetValue(
          s,
          (s) => s.monoFontFamily,
          (s, v) => s.monoFontFamily = v,
          'Consolas',
        ),
        _resetValue(
          s,
          (s) => s.codeFontSize,
          (s, v) => s.codeFontSize = v,
          14.0,
        ),
        _resetValue(
          s,
          (s) => s.showLineNumbers,
          (s, v) => s.showLineNumbers = v,
          true,
        ),
        _resetValue(
          s,
          (s) => s.defaultCodeWrap,
          (s, v) => s.defaultCodeWrap = v,
          false,
        ),
      ],
      _Category.canvas => [
        _resetValue(
          s,
          (s) => s.defaultCanvasGrid,
          (s, v) => s.defaultCanvasGrid = v,
          'dots',
        ),
        _resetValue(
          s,
          (s) => s.canvasSnapToGrid,
          (s, v) => s.canvasSnapToGrid = v,
          false,
        ),
      ],
      _Category.layout => [
        _resetValue(s, (s) => s.compact, (s, v) => s.compact = v, false),
        _resetValue(
          s,
          (s) => s.sidebarVisible,
          (s, v) => s.sidebarVisible = v,
          true,
        ),
        _resetValue(
          s,
          (s) => s.inspectorVisible,
          (s, v) => s.inspectorVisible = v,
          false,
        ),
        _resetValue(
          s,
          (s) => s.sidebarWidth,
          (s, v) => s.sidebarWidth = v,
          240.0,
        ),
        _resetValue(
          s,
          (s) => s.splitAxis,
          (s, v) => s.splitAxis = v,
          'horizontal',
        ),
        _resetValue(s, (s) => s.splitRatio, (s, v) => s.splitRatio = v, .5),
        _resetValue(
          s,
          (s) => s.noteSort,
          (s, v) => s.noteSort = v,
          'modified-desc',
        ),
        _resetValue(
          s,
          (s) => s.showAttachments,
          (s, v) => s.showAttachments = v,
          false,
        ),
        _resetValue(
          s,
          (s) => s.explorerCalendarCollapsed,
          (s, v) => s.explorerCalendarCollapsed = v,
          true,
        ),
        _resetValue(s, (s) => s.motion, (s, v) => s.motion = v, 'normal'),
        _resetMotionOptions(s),
      ],
      _Category.focus => [
        _resetValue(s, (s) => s.focusMinutes, (s, v) => s.focusMinutes = v, 25),
        _resetValue(
          s,
          (s) => s.shortBreakMinutes,
          (s, v) => s.shortBreakMinutes = v,
          5,
        ),
        _resetValue(
          s,
          (s) => s.longBreakMinutes,
          (s, v) => s.longBreakMinutes = v,
          15,
        ),
        _resetValue(
          s,
          (s) => s.defaultAudioSpeed,
          (s, v) => s.defaultAudioSpeed = v,
          1.0,
        ),
      ],
      _Category.data => [
        _resetValue(
          s,
          (s) => s.autoSaveInterval,
          (s, v) => s.autoSaveInterval = v,
          1000,
        ),
        _resetValue(
          s,
          (s) => s.autoSnapshotOnClose,
          (s, v) => s.autoSnapshotOnClose = v,
          true,
        ),
      ],
      _ => [],
    };
  }

  bool reloading = false;
  Future<void> reloadFiles() async {
    if (reloading) {
      return;
    }
    final generation = controller.workspaceGeneration;
    setState(() => reloading = true);
    try {
      await controller.refresh();
      if (!mounted || controller.workspaceGeneration != generation) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.error ??
                (controller.dirty.isNotEmpty
                    ? 'Unsaved drafts remain. Files were not reloaded.'
                    : 'Workspace files reloaded.'),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reload files. Your drafts are retained.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => reloading = false);
      }
    }
  }

  Future<void> clearDictionary() async {
    final owner = controller.session,
        generation = controller.workspaceGeneration;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => OrbitDialog(
        title: const Text('Clear custom dictionary?'),
        content: const Text(
          'Remove your saved spelling exceptions from this device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear words'),
          ),
        ],
      ),
    );
    if (!mounted ||
        accepted != true ||
        !identical(controller.session, owner) ||
        controller.workspaceGeneration != generation) {
      return;
    }
    final before = List<String>.from(owner.userDictionary);
    changeSession((s) => s.userDictionary = []);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Custom dictionary cleared'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (mounted &&
                identical(controller.session, owner) &&
                controller.workspaceGeneration == generation &&
                owner.userDictionary.isEmpty) {
              changeSession((s) => s.userDictionary = before);
            }
          },
        ),
      ),
    );
  }

  Future<void> manageDictionary() async {
    final owner = controller.session,
        generation = controller.workspaceGeneration;
    final before = List<String>.from(owner.userDictionary);
    final field = TextEditingController(text: before.join('\n'));
    String? error;
    try {
      final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => OrbitDialog(
            title: const Text('Custom dictionary'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'One word per line. These words are ignored by offline spell checking.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('settings-dictionary-words'),
                    controller: field,
                    minLines: 5,
                    maxLines: 10,
                    maxLength: 80000,
                    decoration: InputDecoration(
                      labelText: 'Saved words',
                      errorText: error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final words = <String, String>{};
                  for (final word in field.text.trim().split(
                    RegExp(r'[\s,;]+'),
                  )) {
                    if (word.isNotEmpty) {
                      words.putIfAbsent(word.toLowerCase(), () => word);
                    }
                  }
                  if (words.length > 1000 ||
                      words.values.any((w) => w.length > 80)) {
                    update(
                      () => error =
                          'Use at most 1,000 words, each up to 80 characters.',
                    );
                    return;
                  }
                  if (!mounted ||
                      !identical(controller.session, owner) ||
                      controller.workspaceGeneration != generation ||
                      before.join('\n') != owner.userDictionary.join('\n')) {
                    update(
                      () => error =
                          'The Vault or dictionary changed. Close and reopen this editor.',
                    );
                    return;
                  }
                  changeSession(
                    (s) => s.userDictionary = words.values.toList(),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save words'),
              ),
            ],
          ),
        ),
      );
      await Navigator.of(context).push(route);
      await route.completed;
    } finally {
      field.dispose();
    }
  }

  _Reset resetColors(SessionState source) {
    final before = Map<String, int>.from(source.colorOverrides);
    final fallback = {
      for (final e in before.entries)
        if (!OrbitColors.roleLabels.containsKey(e.key)) e.key: e.value,
    };
    return _Reset(
      (s) => s.colorOverrides = Map.from(fallback),
      (s) => s.colorOverrides = Map.from(before),
      (s) =>
          s.colorOverrides.length == fallback.length &&
          fallback.entries.every((e) => s.colorOverrides[e.key] == e.value),
    );
  }

  Widget advancedAppearance() {
    final recovery = orbitRecoveryThemeForPreferences(
      controller.session.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    return Theme(
      data: recovery,
      child: Material(
        color: recovery.extension<OrbitColors>()!.panel,
        child: ExpansionTile(
          key: ValueKey('advanced-colors-$query'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Advanced theme controls'),
          subtitle: const Text('Custom colors, preview, import and export'),
          initiallyExpanded: query.isNotEmpty,
          children: [ThemeColorSettings(controller: controller)],
        ),
      ),
    );
  }

  List<_Entry> settings() {
    final c = controller, s = c.session;
    return [
      _Entry(
        "system",
        _Category.appearance,
        "Theme & color",
        "Follow system appearance",
        "light dark automatic paired",
        (context) => SystemAppearanceSetting(controller: controller),
      ),
      _Entry(
        "theme",
        _Category.appearance,
        "Theme & color",
        "Workspace theme gallery",
        "palette browse light dark",
        (context) => _WorkspaceThemeSummary(controller: c),
      ),
      _Entry(
        "accent",
        _Category.appearance,
        "Theme & color",
        "Accent palette",
        "color violet cyan emerald amber rose cobalt",
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Accent palette', style: OrbitTypography.metadata(context)),
            const Text(
              'Accent shades adapt to keep text and controls readable.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  (
                    'theme',
                    'Follow theme',
                    OrbitThemePack.forPreferences(
                      s.preferences,
                      MediaQuery.platformBrightnessOf(context),
                    ).colors.accent,
                  ),
                  ('violet', 'Observatory Violet', Color(0xFF8B7CF6)),
                  ('cyan', 'Nebula Cyan', Color(0xFF06B6D4)),
                  ('emerald', 'Emerald Aurora', Color(0xFF10B981)),
                  ('amber', 'Solar Flare Amber', Color(0xFFF59E0B)),
                  ('rose', 'Crimson Nova Rose', Color(0xFFF43F5E)),
                  ('blue', 'Cobalt Deep Blue', Color(0xFF3B82F6)),
                ])
                  Tooltip(
                    message: entry.$2,
                    child: InkWell(
                      key: ValueKey('settings-accent-${entry.$1}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => changeSession((s) {
                        s.accentColor = entry.$1;
                        s.colorOverrides = {...s.colorOverrides}
                          ..remove('accent')
                          ..remove('accentHover');
                      }),
                      child: AnimatedContainer(
                        duration: OrbitMotionScope.duration(
                          context,
                          OrbitMotion.micro,
                        ),
                        curve: OrbitMotion.ease,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: s.accentColor == entry.$1
                              ? entry.$3.withValues(alpha: 0.18)
                              : OrbitColors.of(context).panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: s.accentColor == entry.$1
                                ? entry.$3
                                : OrbitColors.of(context).border,
                            width: s.accentColor == entry.$1 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: entry.$3,
                                shape: BoxShape.circle,
                                boxShadow: s.accentColor == entry.$1
                                    ? [
                                        BoxShadow(
                                          color: entry.$3.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: s.accentColor == entry.$1
                                  ? Icon(
                                      Icons.check,
                                      size: 10,
                                      color: OrbitContrast.inkOn(entry.$3),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                entry.$2.split(' ').first,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: s.accentColor == entry.$1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: s.accentColor == entry.$1
                                      ? OrbitColors.of(context).text
                                      : OrbitColors.of(context).subtle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      _Entry(
        "advanced-colors",
        _Category.appearance,
        "Theme & color",
        "Advanced theme colors",
        "custom contrast overrides import export reset preview",
        (context) => advancedAppearance(),
      ),
      _Entry(
        "font",
        _Category.appearance,
        "Display",
        "Font family",
        "interface reading serif sans Georgia Times New Roman",
        (context) => _SettingsControlTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Font family'),
          subtitle: Text(
            s.fontFamily == 'Times New Roman'
                ? 'Times New Roman (Academic Serif)'
                : (s.fontFamily == 'Georgia'
                      ? 'Georgia (Editorial Serif)'
                      : (s.fontFamily == 'Consolas'
                            ? 'Consolas (Code Monospace)'
                            : 'Segoe UI (Clean Sans)')),
          ),
          trailing: DropdownButton<String>(
            isExpanded: true,
            itemHeight: null,
            key: const ValueKey('settings-font-family-dropdown'),
            value:
                [
                  'Segoe UI',
                  'Times New Roman',
                  'Georgia',
                  'Consolas',
                ].contains(s.fontFamily)
                ? s.fontFamily
                : 'Segoe UI',
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: 'Segoe UI',
                child: Text('Segoe UI (Default Sans)'),
              ),
              DropdownMenuItem(
                value: 'Times New Roman',
                child: Text(
                  'Times New Roman (Serif)',
                  style: TextStyle(fontFamily: 'Times New Roman'),
                ),
              ),
              DropdownMenuItem(
                value: 'Georgia',
                child: Text(
                  'Georgia (Serif)',
                  style: TextStyle(fontFamily: 'Georgia'),
                ),
              ),
              DropdownMenuItem(
                value: 'Consolas',
                child: Text(
                  'Consolas (Code)',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                changeSession((s) => s.fontFamily = v);
              }
            },
          ),
        ),
      ),
      _Entry(
        "zoom",
        _Category.appearance,
        "Display",
        "App zoom",
        "scale accessibility size Ctrl plus minus",
        (context) => _SettingsControlTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('App zoom'),
          subtitle: const Text(
            'Whole interface: Ctrl + / minus; Ctrl 0 to reset',
          ),
          trailing: DropdownButton<double>(
            isExpanded: true,
            itemHeight: null,
            key: const ValueKey('settings-app-zoom'),
            value: s.uiZoom,
            items:
                ([
                      ...{.75, .9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, s.uiZoom},
                    ]..sort())
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text('${(v * 100).round()}%'),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v != null) {
                changeSession((s) => s.uiZoom = v);
              }
            },
          ),
        ),
      ),
      _Entry(
        "corners",
        _Category.appearance,
        "Display",
        "Control corners",
        "rounded crisp subtle radius",
        (context) => choice(
          'corners',
          'Control corners',
          'Choose a softer or crisper interface.',
          s.cornerStyle,
          const {'rounded': 'Rounded', 'subtle': 'Subtle'},
          (v) => changeSession((s) => s.cornerStyle = v),
        ),
      ),
      _Entry(
        "size",
        _Category.editor,
        "Reading comfort",
        "Text size",
        "font prose readability",
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Text size'),
              trailing: Text('${s.fontSize.round()} px'),
            ),
            Slider(
              value: s.fontSize,
              min: 12,
              max: 26,
              divisions: 14,
              label: '${s.fontSize.round()}',
              onChanged: (v) => changeSession((s) => s.fontSize = v),
            ),
          ],
        ),
      ),
      _Entry(
        "width",
        _Category.editor,
        "Reading comfort",
        "Editor and reading width",
        "wide page content column",
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsControlTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Editor and reading width'),
              trailing: Text('${s.contentWidth.round()} px'),
            ),
            Slider(
              value: s.contentWidth,
              min: 520,
              max: 2000,
              divisions: 37,
              onChanged: (v) => changeSession((s) => s.contentWidth = v),
            ),
          ],
        ),
      ),
      _Entry(
        "line-height",
        _Category.editor,
        "Reading comfort",
        "Line spacing",
        "line height paragraph compact relaxed",
        (context) => choice(
          'line-spacing-dropdown',
          'Line spacing',
          'Vertical spacing in writing and reading views.',
          s.editorLineHeight,
          {
            1.2: '1.2 · Tight',
            1.4: '1.4 · Compact',
            1.6: '1.6 · Standard',
            1.8: '1.8 · Relaxed',
            2.0: '2.0 · Double',
            2.2: '2.2 · Spacious',
            2.4: '2.4 · Extra spacious',
          },
          (v) => changeSession((s) => s.editorLineHeight = v),
        ),
      ),
      _Entry(
        "preview",
        _Category.editor,
        "Reading comfort",
        "Reading preview",
        "typography sample serif",
        (context) => Container(
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrbitColors.of(context).background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OrbitColors.of(context).border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reading preview', style: OrbitTypography.metadata(context)),
              const SizedBox(height: 8),
              Text(
                'A quiet place for clear ideas.\nThe quick brown fox jumps over the lazy dog.',
                key: const ValueKey('settings-reading-font-preview'),
                style: NoteTypography(
                  fontFamily: s.fontFamily,
                  fontSize: s.fontSize,
                  lineHeight: s.editorLineHeight,
                ).body(color: OrbitColors.of(context).text),
              ),
              const SizedBox(height: 8),
              Text(
                'For serif reading, try 18â€“20 px with comfortable line spacing.',
                style: OrbitTypography.metadata(context),
              ),
            ],
          ),
        ),
      ),
      _Entry(
        "default-mode",
        _Category.editor,
        "New documents",
        "Default editor view mode",
        "rich source raw markdown split read",
        (context) => _SettingsControlTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default editor view mode'),
          subtitle: const Text(
            'Initial mode when opening a note without saved state',
          ),
          trailing: DropdownButton<String>(
            isExpanded: true,
            itemHeight: null,
            key: const ValueKey('settings-default-mode-dropdown'),
            value: s.defaultNoteMode,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'rich', child: Text('Rich Visual')),
              DropdownMenuItem(value: 'write', child: Text('Raw Markdown')),
              DropdownMenuItem(value: 'split', child: Text('Split View')),
              DropdownMenuItem(value: 'read', child: Text('Reading View')),
            ],
            onChanged: (v) {
              if (v != null) {
                changeSession((s) => s.defaultNoteMode = v);
              }
            },
          ),
        ),
      ),
      _Entry(
        "default-format",
        _Category.editor,
        "New documents",
        "Default document format",
        "markdown GFM latex",
        (context) => _SettingsControlTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default document format'),
          subtitle: const Text(
            'Standard document syntax for newly created notes',
          ),
          trailing: DropdownButton<String>(
            isExpanded: true,
            itemHeight: null,
            key: const ValueKey('settings-default-format-dropdown'),
            value: s.defaultDocumentFormat,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: 'markdown',
                child: Text('Markdown (GFM)'),
              ),
              DropdownMenuItem(value: 'latex', child: Text('LaTeX Document')),
            ],
            onChanged: (v) {
              if (v != null) {
                changeSession((s) => s.defaultDocumentFormat = v);
              }
            },
          ),
        ),
      ),
      _Entry(
        "bionic",
        _Category.editor,
        "Reading tools",
        "Enable Bionic Reading by default",
        "fixation bold reading",
        (context) => SwitchListTile(
          key: const ValueKey('settings-bionic-reading-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Bionic Reading by default'),
          subtitle: const Text('Emphasize the start of words in reading view.'),
          value: s.bionicReadingDefault,
          onChanged: (v) => changeSession((s) => s.bionicReadingDefault = v),
        ),
      ),
      _Entry(
        "spelling",
        _Category.editor,
        "Spelling & grammar",
        "Spell and grammar check",
        "offline dictionary proofreading correction",
        (context) => SwitchListTile(
          key: const ValueKey('settings-spellcheck-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Spell and grammar check'),
          subtitle: const Text(
            'Offline dictionary and grammar analysis with right-click suggestions',
          ),
          value: s.spellCheckEnabled,
          onChanged: (v) => changeSession((s) => s.spellCheckEnabled = v),
        ),
      ),
      _Entry(
        "dictionary",
        _Category.editor,
        "Spelling & grammar",
        "Custom dictionary",
        "words spelling ignore personal glossary",
        (context) => _SettingsControlTile(
          title: const Text('Custom dictionary'),
          subtitle: Text(
            '${s.userDictionary.length} saved words · available offline',
          ),
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('settings-manage-dictionary'),
                onPressed: manageDictionary,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit words'),
              ),
              if (s.userDictionary.isNotEmpty)
                TextButton(
                  key: const ValueKey('settings-clear-dictionary-button'),
                  onPressed: clearDictionary,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
      ),
      _Entry(
        "code-font",
        _Category.code,
        "Typography",
        "Code font family",
        "source monospace Consolas terminal",
        (context) => choice(
          'code-font',
          'Code font family',
          'Used in code blocks and source workspaces.',
          s.monoFontFamily,
          const {
            'Consolas': 'Consolas',
            'OrbitTerminal': 'Orbit Terminal',
            'monospace': 'System monospace',
          },
          (v) => changeSession((s) => s.monoFontFamily = v),
        ),
      ),
      _Entry(
        "code-size",
        _Category.code,
        "Typography",
        "Code text size",
        "source font size",
        (context) => range(
          'code-size',
          'Code text size',
          'Independent of prose text size.',
          s.codeFontSize,
          10,
          26,
          (v) => changeSession((s) => s.codeFontSize = v),
        ),
      ),
      _Entry(
        "code-numbers",
        _Category.code,
        "Editor defaults",
        "Show code line numbers",
        "gutter source IDE",
        (context) => toggle(
          'code-numbers',
          'Show code line numbers',
          'Default for new code workspaces and IDE editors.',
          s.showLineNumbers,
          (v) => changeSession((s) => s.showLineNumbers = v),
        ),
      ),
      _Entry(
        "code-wrap",
        _Category.code,
        "Editor defaults",
        "Wrap long code lines",
        "horizontal scroll source IDE",
        (context) => toggle(
          'code-wrap',
          'Wrap long code lines',
          'Default for newly opened code workspaces. Existing panes keep their local choice.',
          s.defaultCodeWrap,
          (v) => changeSession((s) => s.defaultCodeWrap = v),
        ),
      ),
      _Entry(
        "paper",
        _Category.canvas,
        "New boards",
        "Default paper grid",
        "dots grid graph cross hex blueprint classic architecture cornell music ledger triangular ruled isometric blank",
        (context) => choice(
          'canvas-grid-dropdown',
          'Default paper grid',
          'Applies when a Canvas has no saved paper choice.',
          s.defaultCanvasGrid,
          const {
            'dots': 'Standard dots',
            'grid': 'Standard grid',
            'graph': 'Engineering graph',
            'cross': 'Cross / Reticle (+)',
            'hex': 'Hexagonal honeycomb',
            'blueprint': 'Architectural blueprint',
            'blueprint_classic': 'Classic deep-blue blueprint',
            'lines': 'Ruled notebook lines',
            'ruled': 'Student ruled margin',
            'isometric': 'Isometric 3D grid',
            'cornell': 'Cornell notes',
            'music': 'Music staff',
            'ledger': 'Accounting ledger',
            'triangular': 'Triangular grid',
            'blank': 'Blank paper',
          },
          (v) => changeSession((s) => s.defaultCanvasGrid = v),
        ),
      ),
      _Entry(
        "snap",
        _Category.canvas,
        "New boards",
        "Snap to grid by default",
        "alignment spatial cards shapes",
        (context) => SwitchListTile(
          key: const ValueKey('settings-canvas-snap-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Snap to grid by default'),
          subtitle: const Text(
            'Automatically aligns newly placed spatial cards and shapes to grid nodes',
          ),
          value: s.canvasSnapToGrid,
          onChanged: (v) => changeSession((s) => s.canvasSnapToGrid = v),
        ),
      ),
      _Entry(
        "density",
        _Category.layout,
        "Panels & density",
        "Compact density",
        "comfortable spacing touch",
        (context) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Compact density'),
          value: s.compact,
          onChanged: (v) => changeSession((s) => s.compact = v),
        ),
      ),
      _Entry(
        "explorer",
        _Category.layout,
        "Panels & density",
        "Show explorer",
        "sidebar navigation files",
        (context) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show explorer'),
          value: s.sidebarVisible,
          onChanged: (v) => changeSession((s) => s.sidebarVisible = v),
        ),
      ),
      _Entry(
        "inspector",
        _Category.layout,
        "Panels & density",
        "Show context inspector",
        "backlinks properties sidebar",
        (context) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show context inspector'),
          value: s.inspectorVisible,
          onChanged: (v) => changeSession((s) => s.inspectorVisible = v),
        ),
      ),
      _Entry(
        "sidebar-width",
        _Category.layout,
        "Panels & density",
        "Explorer width",
        "sidebar size navigation",
        (context) => range(
          'sidebar-width',
          'Explorer width',
          'Width of the desktop file explorer.',
          s.sidebarWidth,
          180,
          420,
          (v) => changeSession((s) => s.sidebarWidth = v),
        ),
      ),
      _Entry(
        "split-axis",
        _Category.layout,
        "Split views",
        "Split direction",
        "horizontal vertical panes stacked side by side",
        (context) => choice(
          'split-axis',
          'Split direction',
          'Arrange two open documents side by side or stacked.',
          s.splitAxis,
          const {'horizontal': 'Side by side', 'vertical': 'Stacked'},
          (v) => changeSession((s) => s.splitAxis = v),
        ),
      ),
      _Entry(
        "split-ratio",
        _Category.layout,
        "Split views",
        "Primary pane size",
        "split ratio width height",
        (context) => range(
          'split-ratio',
          'Primary pane size',
          'Share of the split used by the first document.',
          s.splitRatio * 100,
          25,
          75,
          (v) => changeSession((s) => s.splitRatio = v / 100),
          label: '${(s.splitRatio * 100).round()}%',
        ),
      ),
      _Entry(
        "sort",
        _Category.layout,
        "Explorer",
        "Default note order",
        "sort title name modified created ascending descending",
        (context) => choice(
          'note-sort',
          'Default note order',
          'Sorting used by the workspace explorer.',
          s.noteSort,
          objectSortLabels,
          (v) => changeSession((s) => s.noteSort = v),
        ),
      ),
      _Entry(
        "attachments",
        _Category.layout,
        "Explorer",
        "Show attachments in explorer",
        "files images pdf media",
        (context) => toggle(
          'show-attachments',
          'Show attachments in explorer',
          'Include attachment files beside your notes.',
          s.showAttachments,
          (v) => changeSession((s) => s.showAttachments = v),
        ),
      ),
      _Entry(
        "calendar",
        _Category.layout,
        "Explorer",
        "Collapse explorer calendar",
        "sidebar month dates",
        (context) => toggle(
          'calendar-collapsed',
          'Collapse explorer calendar',
          'Keep the sidebar calendar folded until you open it.',
          s.explorerCalendarCollapsed,
          (v) => changeSession((s) => s.explorerCalendarCollapsed = v),
        ),
      ),
      _Entry(
        "motion",
        _Category.layout,
        "Motion",
        "Animation preference",
        "reduced off transitions accessibility animation studio paper ink fluid",
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OrbitModeControl<String>(
                values: const {
                  'normal': 'Normal',
                  'reduced': 'Reduced',
                  'off': 'Off',
                },
                value: s.motion,
                onChanged: (mode) => changeSession((s) => s.motion = mode),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.animation),
              label: const Text('Open motion studio'),
              onPressed: () {
                final owner = controller;
                showMotionStudio(
                  context,
                  options: owner.session.motionOptions,
                  onChanged: (value) {
                    if (!mounted || !identical(owner, controller)) return;
                    changeSession((s) => s.motionOptions = value);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Respects the system’s reduced-motion preference.',
              style: TextStyle(
                color: OrbitColors.of(context).subtle,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      _Entry(
        "focus-time",
        _Category.focus,
        "Work & breaks",
        "Focus session duration",
        "timer pomodoro minutes deep work",
        (context) => choice(
          'focus-duration-dropdown',
          'Focus session duration',
          'Length of a focused work block.',
          s.focusMinutes,
          const {
            15: '15 min',
            20: '20 min',
            25: '25 min · Standard',
            30: '30 min',
            45: '45 min',
            60: '60 min',
            90: '90 min',
            120: '120 min',
          },
          (v) {
            changeSession((s) => s.focusMinutes = v);
            globalFocusTimer.configureDurations(focus: v);
          },
        ),
      ),
      _Entry(
        "short-break",
        _Category.focus,
        "Work & breaks",
        "Short break duration",
        "rest timer minutes",
        (context) => choice(
          'short-break-dropdown',
          'Short break duration',
          'Rest between focus sessions.',
          s.shortBreakMinutes,
          const {
            1: '1 min',
            3: '3 min',
            5: '5 min · Standard',
            10: '10 min',
            15: '15 min',
          },
          (v) {
            changeSession((s) => s.shortBreakMinutes = v);
            globalFocusTimer.configureDurations(shortBreak: v);
          },
        ),
      ),
      _Entry(
        "long-break",
        _Category.focus,
        "Work & breaks",
        "Long break duration",
        "rest timer cycle minutes",
        (context) => choice(
          'long-break-dropdown',
          'Long break duration',
          'Rest after a four-session cycle.',
          s.longBreakMinutes,
          const {
            10: '10 min',
            15: '15 min · Standard',
            20: '20 min',
            30: '30 min',
            45: '45 min',
            60: '60 min',
          },
          (v) {
            changeSession((s) => s.longBreakMinutes = v);
            globalFocusTimer.configureDurations(longBreak: v);
          },
        ),
      ),
      _Entry(
        "audio",
        _Category.focus,
        "Listening",
        "Default playback speed",
        "audio voice memos rate",
        (context) => _SettingsControlTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Default playback speed'),
          subtitle: const Text(
            'Standard playback rate when listening to voice memos and audio notes',
          ),
          trailing: DropdownButton<double>(
            isExpanded: true,
            itemHeight: null,
            key: const ValueKey('settings-audio-speed-dropdown'),
            value: [1.0, 1.25, 1.5, 2.0].contains(s.defaultAudioSpeed)
                ? s.defaultAudioSpeed
                : 1.0,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 1.0, child: Text('1.0Ã— (Normal)')),
              DropdownMenuItem(value: 1.25, child: Text('1.25Ã— (Brisk)')),
              DropdownMenuItem(value: 1.5, child: Text('1.5Ã— (Accelerated)')),
              DropdownMenuItem(value: 2.0, child: Text('2.0Ã— (Double)')),
            ],
            onChanged: (v) {
              if (v != null) {
                changeSession((s) => s.defaultAudioSpeed = v);
              }
            },
          ),
        ),
      ),
      _Entry(
        "autosave",
        _Category.data,
        "Save & recover",
        "Auto-save debounce interval",
        "storage save delay typing disk",
        (context) => choice(
          'autosave-interval-dropdown',
          'Auto-save delay',
          'How long Orbit waits after typing before saving drafts.',
          s.autoSaveInterval,
          const {
            500: '0.5 sec · Fast',
            1000: '1 sec · Balanced',
            1500: '1.5 sec',
            2500: '2.5 sec',
            5000: '5 sec',
          },
          (v) => changeSession((s) => s.autoSaveInterval = v),
        ),
      ),
      _Entry(
        "snapshots",
        _Category.data,
        "Save & recover",
        "Auto-snapshot on document close",
        "history recovery checkpoint",
        (context) => SwitchListTile(
          key: const ValueKey('settings-auto-snapshot-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-snapshot on document close'),
          subtitle: const Text(
            'Automatically records a historical recovery checkpoint when closing a note',
          ),
          value: s.autoSnapshotOnClose,
          onChanged: (v) => changeSession((s) => s.autoSnapshotOnClose = v),
        ),
      ),
      _Entry(
        "files",
        _Category.data,
        "Vault & backups",
        "Workspace data",
        "backup import export manage vault location reload files",
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              c.hasWorkspace ? c.repository.location : 'Personal Vault',
              style: TextStyle(
                fontSize: 12,
                color: OrbitColors.of(context).subtle,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export workspace'),
                ),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Import backup'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenWorkspace,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Manage Vaults'),
                ),
                TextButton.icon(
                  onPressed: reloading ? null : reloadFiles,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reload from files'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Notes use Markdown; tasks and canvases use documented JSON.\nNo account, cloud connection or AI provider is required.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: OrbitColors.of(context).subtle,
              ),
            ),
          ],
        ),
      ),
      _Entry(
        "statistics",
        _Category.data,
        "Vault & backups",
        "Vault overview",
        "analytics statistics notes tasks canvases attachments local",
        (context) => Container(
          key: const ValueKey('settings-vault-analytics-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Vault overview',
                    style: OrbitTypography.section(context),
                  ),
                  const OrbitPulseBadge(
                    key: ValueKey('settings-vault-live-badge'),
                    label: 'LOCAL ONLY',
                    active: false,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Local object counts. Nothing is sent to a server.',
                style: TextStyle(color: OrbitColors.of(context).subtle),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final kind in [
                    ('orbit.note', 'Notes', Icons.description_outlined),
                    ('orbit.canvas', 'Canvases', Icons.dashboard_outlined),
                    ('orbit.task', 'Tasks', Icons.check_circle_outline),
                    ('orbit.file', 'Attachments', Icons.attach_file),
                  ])
                    _buildMetricCol(
                      context,
                      kind.$2,
                      c.activeObjects
                          .where((o) => !o.isDeleted && o.typeId == kind.$1)
                          .length,
                      kind.$3,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      _Entry(
        "drive",
        _Category.sync,
        "Connections",
        "Google Drive and multiplayer",
        "sign in server host sync backup transfer automatic collaboration devices",
        (context) => GoogleDriveSettings(workspace: controller),
      ),
      _Entry(
        "research",
        _Category.tools,
        "Optional tools",
        "Reverse-engineering research tools",
        "experimental record templates",
        (context) => SwitchListTile(
          key: const ValueKey('settings-reverse-engineering-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Reverse-engineering research tools'),
          subtitle: const Text(
            'Show experimental research project and record templates. Existing notes and maps stay accessible when disabled.',
          ),
          value: s.reverseEngineeringEnabled,
          onChanged: (v) =>
              changeSession((s) => s.reverseEngineeringEnabled = v),
        ),
      ),
      _Entry(
        "shortcuts",
        _Category.tools,
        "Workspace shortcuts",
        "Planning and workspaces",
        "study calendar spaces layouts templates",
        (context) => ProductivityToolbar(controller: controller),
      ),
    ];
  }

  Widget _buildMetricCol(
    BuildContext context,
    String label,
    int count,
    IconData icon,
  ) {
    final colors = OrbitColors.of(context);
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colors.subtle),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.subtle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          OrbitAnimatedCounter(
            value: count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colors.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

_Reset _resetMotionOptions(SessionState source) {
  final before = Map<String, dynamic>.of(source.motionOptions);
  final after = MotionPreferences(before).quiet();
  return _Reset(
    (s) => s.motionOptions = after,
    (s) => s.motionOptions = before,
    (s) => jsonValuesEqual(s.motionOptions, after),
  );
}

class _Reset {
  const _Reset(this.reset, this.restore, this.isReset);
  final void Function(SessionState) reset, restore;
  final bool Function(SessionState) isReset;
}

_Reset _resetValue<T>(
  SessionState source,
  T Function(SessionState) read,
  void Function(SessionState, T) write,
  T fallback,
) {
  final before = read(source);
  return _Reset(
    (s) => write(s, fallback),
    (s) => write(s, before),
    (s) => read(s) == fallback,
  );
}

class _WorkspaceThemeSummary extends StatelessWidget {
  const _WorkspaceThemeSummary({required this.controller});
  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final pack = OrbitThemePack.forPreferences(
      controller.session.preferences,
      MediaQuery.platformBrightnessOf(context),
    );
    final colors = OrbitColors.of(context);
    return OrbitCard(
      padding: const EdgeInsets.all(16),
      onTap: () => showOrbitThemeGalleryDialog(context, controller),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pack.colors.background,
              borderRadius: BorderRadius.circular(OrbitRadius.control),
              border: Border.all(color: colors.border),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 14,
                      decoration: BoxDecoration(
                        color: pack.colors.panel,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(OrbitRadius.control),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 8,
                  top: 16,
                  child: Container(height: 4, color: pack.colors.accent),
                ),
                Positioned(
                  left: 22,
                  right: 16,
                  top: 28,
                  child: Container(height: 3, color: pack.colors.subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace theme',
                  style: TextStyle(
                    color: colors.subtle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pack.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Typography, surfaces, accents, and corners move together.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.open_in_new, size: 17, color: colors.muted),
        ],
      ),
    );
  }
}

/// A setting's control gets its own row before either label or value is squeezed.
class _SettingsControlTile extends StatelessWidget {
  const _SettingsControlTile({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.contentPadding = EdgeInsets.zero,
  });
  final Widget title, trailing;
  final Widget? subtitle;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: contentPadding.add(const EdgeInsets.symmetric(vertical: 8)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labels = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w600),
              child: title,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: OrbitColors.of(context).subtle,
                ),
                child: subtitle!,
              ),
            ],
          ],
        );
        if (constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labels, const SizedBox(height: 8), trailing],
          );
        }
        return Row(
          children: [
            Expanded(child: labels),
            const SizedBox(width: 20),
            SizedBox(width: 260, child: trailing),
          ],
        );
      },
    ),
  );
}
