import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../app/workspace_controller.dart';
import '../../domain/universal_object.dart';
import '../../domain/object_reference.dart';
import '../../domain/reverse_engineering.dart';
import '../../app/orbit_components.dart';
import '../../app/orbit_theme.dart';
import '../../platform/open_attachment.dart';
import '../../domain/object_sort.dart';
import 'orbit_explorer_row.dart';
import 'research_record_dialog.dart';
import 'folder_color_dialog.dart';
import 'object_rename_dialog.dart';
import '../../application/workspace_repository.dart';
import '../../infrastructure/storage/path_safety.dart';
import '../notes/creative_brief_dialog.dart';
import '../notes/note_templates.dart';

/// Real on-disk Notes folders. Objects keep their identity when their owner moves.
IconData viewTypeIcon(String? viewType) => switch (viewType) {
  'board' => Icons.view_kanban_outlined,
  'calendar' => Icons.calendar_month_outlined,
  'timeline' => Icons.timeline_outlined,
  'gantt' => Icons.view_timeline_outlined,
  'research' => Icons.collections_bookmark_outlined,
  'exercises' => Icons.table_chart_outlined,
  'overview' => Icons.dashboard_outlined,
  'game_dashboard' => Icons.sports_esports_outlined,
  'milestones' => Icons.flag_outlined,
  _ => Icons.checklist_outlined,
};

class NoteFolderExplorer extends StatefulWidget {
  const NoteFolderExplorer({
    super.key,
    required this.controller,
    required this.notes,
    this.filtering = false,
  });
  final WorkspaceController controller;
  final List<UniversalObject> notes;
  final bool filtering;

  @override
  State<NoteFolderExplorer> createState() => _NoteFolderExplorerState();
}

/// Metadata collected before scaffolding a project template. Keeping this in
/// the explorer makes templates useful on first launch while leaving the
/// controller as the durable storage boundary.
class _ProjectTemplateDetails {
  const _ProjectTemplateDetails({required this.name, this.values = const {}});

  final String name;
  final Map<String, dynamic> values;
}

Future<_ProjectTemplateDetails?> _showProjectTemplateDialog(
  BuildContext context, {
  required String kind,
  required String title,
  required String initialName,
}) async {
  final name = TextEditingController(text: initialName);
  final courseCode = TextEditingController();
  final semester = TextEditingController(text: 'WS 2026');
  final ects = TextEditingController(text: '5');
  final lecturer = TextEditingController();
  final genre = TextEditingController(text: 'Action RPG');
  final platform = TextEditingController(
    text: kind == 'reverse' ? 'Windows' : 'PC / Steam',
  );
  final engine = TextEditingController(text: 'Godot / Unity / Custom');
  final architecture = TextEditingController(text: 'x86-64');
  final format = TextEditingController(text: 'PE');
  final version = TextEditingController(text: '1.0.0');
  final form = GlobalKey<FormState>();
  final result = await showDialog<_ProjectTemplateDetails>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final isCourse = kind == 'course';
        final isGame = kind == 'game';
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isCourse
                    ? Icons.school_outlined
                    : isGame
                    ? Icons.sports_esports_outlined
                    : Icons.manage_search_outlined,
              ),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isCourse
                          ? 'Set the course identity once. Orbit Note will use it across lectures, exercises, deadlines, and the dashboard.'
                          : isGame
                          ? 'Describe the project so the generated GDD, boards, and tasks start with useful context.'
                          : 'Capture the target fingerprint so notes, functions, hypotheses, and evidence stay connected.',
                      style: TextStyle(
                        fontSize: 12,
                        color: OrbitColors.of(context).subtle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isCourse
                            ? 'Course name'
                            : isGame
                            ? 'Project name'
                            : 'Target name',
                        hintText: isCourse ? 'e.g. Algorithms II' : null,
                      ),
                      validator: (value) =>
                          (value ?? '').trim().isEmpty ? 'Enter a name.' : null,
                    ),
                    if (isCourse) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: courseCode,
                        decoration: const InputDecoration(
                          labelText: 'Course code (optional)',
                          hintText: 'e.g. CS-301',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: semester,
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: ects,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'ECTS',
                              ),
                              validator: (value) =>
                                  int.tryParse((value ?? '').trim()) == null
                                  ? 'Number'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: lecturer,
                        decoration: const InputDecoration(
                          labelText: 'Lecturer (optional)',
                        ),
                      ),
                    ],
                    if (isGame) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: genre,
                        decoration: const InputDecoration(labelText: 'Genre'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: platform,
                        decoration: const InputDecoration(
                          labelText: 'Target platform',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: engine,
                        decoration: const InputDecoration(labelText: 'Engine'),
                      ),
                    ],
                    if (!isCourse && !isGame) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: architecture,
                        decoration: const InputDecoration(
                          labelText: 'Architecture',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: format,
                              decoration: const InputDecoration(
                                labelText: 'File format',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: version,
                              decoration: const InputDecoration(
                                labelText: 'Version',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  _ProjectTemplateDetails(
                    name: name.text.trim(),
                    values: {
                      if (isCourse) ...{
                        'courseCode': courseCode.text.trim(),
                        'semester': semester.text.trim(),
                        'ects': int.tryParse(ects.text.trim()) ?? 5,
                        'lecturer': lecturer.text.trim(),
                      },
                      if (isGame) ...{
                        'genre': genre.text.trim(),
                        'platform': platform.text.trim(),
                        'engine': engine.text.trim(),
                      },
                      if (!isCourse && !isGame) ...{
                        'architecture': architecture.text.trim(),
                        'format': format.text.trim(),
                        'platform': platform.text.trim(),
                        'version': version.text.trim(),
                      },
                    },
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Create workspace'),
            ),
          ],
        );
      },
    ),
  );
  for (final controller in [
    name,
    courseCode,
    semester,
    ects,
    lecturer,
    genre,
    platform,
    engine,
    architecture,
    format,
    version,
  ]) {
    controller.dispose();
  }
  return result;
}

class _NoteFolderExplorerState extends State<NoteFolderExplorer> {
  final Set<String> _selectedNoteIds = {};
  String? _anchorNoteId;
  final FocusNode _focusNode = FocusNode();
  int _focusedIndex = 0;
  bool _showArchived = false;
  bool _batchBusy = false;
  Object? _selectionOwner;

  (WorkspaceController, WorkspaceRepository, int, String) _capture() {
    final c = widget.controller;
    return (c, c.repository, c.workspaceGeneration, c.repository.workspaceId);
  }

  bool _owns((WorkspaceController, WorkspaceRepository, int, String) owner) =>
      mounted &&
      identical(widget.controller, owner.$1) &&
      identical(widget.controller.repository, owner.$2) &&
      widget.controller.workspaceGeneration == owner.$3 &&
      widget.controller.repository.workspaceId == owner.$4;

  bool _sameSelection(Set<String> selection) =>
      _selectedNoteIds.length == selection.length &&
      _selectedNoteIds.containsAll(selection);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget _drag(String path, String? noteId, Widget child) =>
      Draggable<({String path, String? noteId})>(
        data: (path: path, noteId: noteId),
        maxSimultaneousDrags:
            widget.controller.repository.readOnly || path == 'Notes' ? 0 : 1,
        feedback: Material(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(p.posix.basename(path)),
          ),
        ),
        child: child,
      );

  Widget _drop(String folder, Widget child) =>
      DragTarget<({String path, String? noteId})>(
        onWillAcceptWithDetails: (details) {
          final source = details.data;
          return !widget.controller.repository.readOnly &&
              source.path != folder &&
              p.posix.dirname(source.path) != folder &&
              !folder.startsWith('${source.path}/');
        },
        onAcceptWithDetails: (details) async {
          if (details.data.noteId == null) {
            await widget.controller.moveFolder(
              details.data.path,
              '$folder/${p.posix.basename(details.data.path)}',
            );
          } else {
            await widget.controller.moveObjectToFolder(
              details.data.noteId!,
              folder,
            );
          }
        },
        builder: (context, candidates, rejected) => ColoredBox(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          child: child,
        ),
      );

  Future<String?> _name(
    BuildContext context,
    String title, {
    String initial = '',
    bool? isFolder,
  }) async {
    final owner = _capture();
    final input = TextEditingController(text: initial);
    final form = GlobalKey<FormState>();
    final folderName =
        isFolder ??
        (title.toLowerCase().contains('folder') ||
            title.toLowerCase().contains('project') ||
            title.toLowerCase().contains('course'));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => OrbitDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            controller: input,
            autofocus: true,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isEmpty) return 'Enter a name.';
              if (folderName) {
                try {
                  validateFolderName(value ?? '');
                } catch (error) {
                  return '$error'.replaceAll('WorkspaceFailure: ', '');
                }
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: folderName ? 'Folder name' : title,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  folderName ? input.text : input.text.trim(),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
    return _owns(owner) ? result : null;
  }

  Future<String?> _destination(BuildContext context, {String? exclude}) =>
      showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Move to folder'),
          children: [
            for (final folder in widget.controller.repository.folders)
              if (folder != exclude &&
                  !(exclude != null && folder.startsWith('$exclude/')))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, folder),
                  child: Text(folder),
                ),
          ],
        ),
      );

  Future<void> _folderAction(
    BuildContext context,
    String folder,
    String action,
  ) async {
    final owner = _capture();
    if (action.startsWith('new') || action == 'new') {
      widget.controller.updateSession(
        (s) => s.collapsedFolders = s.collapsedFolders
            .where((f) => f != folder)
            .toList(),
      );
    }
    if (action == 'new_note') {
      await widget.controller.create(
        'orbit.note',
        properties: {'folder': folder},
      );
    } else if (action == 'new_canvas') {
      await widget.controller.create(
        'orbit.canvas',
        properties: {'folder': folder},
      );
    } else if (action == 'new_research') {
      final project = widget.controller.activeObjects
          .where(
            (o) =>
                o.properties['folder'] == folder &&
                o.properties['creativeProject'] == true,
          )
          .firstOrNull;
      await widget.controller.createResearchCollection(
        title: '${p.posix.basename(folder)} Research',
        folder: folder,
        project: project?.properties['project']?.toString(),
      );
    } else if (action == 'new_task_list') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Tasks',
        properties: {'folder': folder, 'viewType': 'tasks'},
      );
    } else if (action == 'new_board') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Board',
        properties: {
          'folder': folder,
          'viewType': 'board',
          'preset': 'university',
        },
      );
    } else if (action == 'new_calendar') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Calendar',
        properties: {'folder': folder, 'viewType': 'calendar'},
      );
    } else if (action == 'new_timeline') {
      final base = p.posix.basename(folder);
      await widget.controller.create(
        'orbit.view',
        title: '$base Timeline',
        properties: {'folder': folder, 'viewType': 'timeline'},
      );
    } else if (action == 'new_gantt') {
      await widget.controller.create(
        'orbit.view',
        title: '${p.posix.basename(folder)} Gantt',
        properties: {
          'folder': folder,
          'viewType': 'gantt',
          'ganttVersion': 1,
          'ganttDays': 28,
        },
      );
    } else if (action == 'new_creative_project') {
      final brief = await showDialog<NoteTemplate>(
        context: context,
        builder: (_) => const CreativeBriefDialog(projectWorkspace: true),
      );
      if (brief != null) {
        await widget.controller.createCreativeProject(
          brief.defaultTitle,
          briefBody: brief.body,
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_game_project') {
      final details = await _showProjectTemplateDialog(
        context,
        kind: 'game',
        title: 'New Game Project',
        initialName: 'MyGame',
      );
      if (details != null) {
        await widget.controller.createGameProject(
          details.name,
          genre: details.values['genre'] as String,
          targetPlatform: details.values['platform'] as String,
          targetEngine: details.values['engine'] as String,
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_gdd') {
      final name = await _name(
        context,
        'New GDD Note',
        initial: 'Game Design Document',
      );
      await widget.controller.createGameDesignDocument(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_feature_spec') {
      final name = await _name(
        context,
        'New Feature Spec',
        initial: 'Feature Spec',
      );
      await widget.controller.createFeatureSpec(folder: folder, title: name);
    } else if (action == 'new_bug_report') {
      final name = await _name(context, 'New Bug Report', initial: 'Bug');
      await widget.controller.createBugReport(folder: folder, title: name);
    } else if (action == 'new_playtest') {
      final name = await _name(
        context,
        'New Playtest Session',
        initial: 'Playtest',
      );
      await widget.controller.createPlaytestSession(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_dev_log') {
      await widget.controller.createDevLog(folder: folder);
    } else if (action == 'new_level_design') {
      final name = await _name(
        context,
        'New Level Design Doc',
        initial: 'Level 1',
      );
      await widget.controller.createLevelDesignDoc(folder: folder, title: name);
    } else if (action == 'new_mechanic_spec') {
      final name = await _name(
        context,
        'New Mechanic Spec',
        initial: 'Dash Mechanic',
      );
      await widget.controller.createMechanicDesignDoc(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_enemy_design') {
      final name = await _name(
        context,
        'New Enemy Design',
        initial: 'Melee Drone',
      );
      await widget.controller.createEnemyDesignDoc(folder: folder, title: name);
    } else if (action == 'new_character_design') {
      final name = await _name(
        context,
        'New Character Profile',
        initial: 'Hero',
      );
      await widget.controller.createCharacterDesignDoc(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_item_design') {
      final name = await _name(
        context,
        'New Item / Weapon',
        initial: 'Relic Blade',
      );
      await widget.controller.createItemDesignDoc(folder: folder, title: name);
    } else if (action == 'new_quest') {
      final name = await _name(
        context,
        'New Quest / Mission',
        initial: 'The Ancient Cipher',
      );
      await widget.controller.createQuestDesignDoc(folder: folder, title: name);
    } else if (action == 'new_audio_plan') {
      final name = await _name(
        context,
        'New Audio Plan',
        initial: 'Audio Asset Plan',
      );
      await widget.controller.createAudioDesignDoc(folder: folder, title: name);
    } else if (action == 'new_release_checklist') {
      final name = await _name(
        context,
        'New Release Checklist',
        initial: 'Release Checklist v1.0',
      );
      await widget.controller.createReleaseChecklist(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_weekly_review') {
      await widget.controller.createWeeklyReview(folder: folder);
    } else if (action == 'new_risk') {
      final name = await _name(
        context,
        'New Risk Assessment',
        initial: 'Physics Latency',
      );
      await widget.controller.createRiskAssessmentDoc(
        folder: folder,
        title: name,
      );
    } else if (action == 'new_decision') {
      final name = await _name(
        context,
        'New Architecture Decision',
        initial: 'Render Pipeline',
      );
      await widget.controller.createDecisionDoc(folder: folder, title: name);
    } else if (action == 'duplicate_project_structure') {
      final base = p.posix.basename(folder);
      final name = await _name(
        context,
        'New Project Name',
        initial: '${base}Copy',
      );
      if (name != null && name.trim().isNotEmpty) {
        await widget.controller.duplicateGameProjectStructure(
          base,
          name.trim(),
        );
      }
    } else if (action == 'new_course') {
      final details = await _showProjectTemplateDialog(
        context,
        kind: 'course',
        title: 'New University Course',
        initialName: 'AKMath',
      );
      if (details != null) {
        await widget.controller.createUniversityCourse(
          details.name,
          semester: details.values['semester'] as String,
          ects: details.values['ects'] as int,
          courseCode: details.values['courseCode'] as String,
          lecturer: details.values['lecturer'] as String,
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_lecture') {
      final name = await _name(context, 'New Lecture Note', initial: 'Lecture');
      await widget.controller.createLectureNote(folder: folder, title: name);
    } else if (action == 'new_exercise') {
      final name = await _name(
        context,
        'New Exercise Canvas',
        initial: 'Exercise',
      );
      await widget.controller.createExerciseCanvas(folder: folder, title: name);
    } else if (action == 'new_re_project') {
      final details = await _showProjectTemplateDialog(
        context,
        kind: 'reverse',
        title: 'New Reverse Engineering Project',
        initialName: 'Target',
      );
      if (details != null) {
        await widget.controller.createReverseEngineeringProject(
          details.name,
          architecture: details.values['architecture'] as String,
          format: details.values['format'] as String,
          targetPlatform: details.values['platform'] as String,
          targetVersion: details.values['version'] as String,
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_game_internals_project') {
      final name = await _name(
        context,
        'New Game Internals Project',
        initial: 'GameTitle',
      );
      if (name != null && name.trim().isNotEmpty) {
        await widget.controller.createGameInternalsProject(
          name.trim(),
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_malware_project') {
      final name = await _name(
        context,
        'New Malware Analysis Project',
        initial: 'Sample_01',
      );
      if (name != null && name.trim().isNotEmpty) {
        await widget.controller.createMalwareAnalysisProject(
          name.trim(),
          targetParentFolder: folder,
        );
      }
    } else if (action == 'new_research_record') {
      if (context.mounted) {
        await showResearchRecordDialog(
          context,
          widget.controller,
          folder: folder,
        );
      }
    } else if (action == 'new_research_map') {
      final ids = widget.controller.activeObjects
          .where((o) {
            final owner = o.properties['folder']?.toString() ?? '';
            return (owner == folder || owner.startsWith('$folder/')) &&
                researchRecordCategories.contains(o.properties['category']);
          })
          .map((o) => o.id)
          .toList();
      if (ids.isEmpty || ids.length > 500) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Choose a folder containing 1–500 research records.',
              ),
            ),
          );
        }
        return;
      }
      final name = await _name(
        context,
        'New Research Map',
        initial: 'Evidence map',
      );
      if (name != null) {
        await widget.controller.createResearchMap(
          folder: folder,
          title: name,
          objectIds: ids,
        );
      }
    } else if (action == 'new_function_doc') {
      final name = await _name(
        context,
        'New Function Symbol',
        initial: 'sub_1400',
      );
      if (name != null) {
        await widget.controller.createFunctionDoc(folder: folder, name: name);
      }
    } else if (action == 'new_structure_doc') {
      final name = await _name(
        context,
        'New Structure Name',
        initial: 'EntityStruct',
      );
      if (name != null) {
        await widget.controller.createStructureDoc(folder: folder, name: name);
      }
    } else if (action == 'new_finding_doc') {
      final name = await _name(
        context,
        'New Finding Title',
        initial: 'Finding',
      );
      if (name != null) {
        await widget.controller.createFindingDoc(folder: folder, title: name);
      }
    } else if (action == 'new_hypothesis_doc') {
      final name = await _name(
        context,
        'New Hypothesis',
        initial: 'Hypothesis',
      );
      if (name != null) {
        await widget.controller.createHypothesisDoc(
          folder: folder,
          title: name,
        );
      }
    } else if (action == 'new_session_doc') {
      final name = await _name(
        context,
        'New Analysis Session',
        initial: 'Session',
      );
      if (name != null) {
        await widget.controller.createAnalysisSessionDoc(
          folder: folder,
          title: name,
        );
      }
    } else if (action == 'new_ioc_doc') {
      final name = await _name(
        context,
        'New Indicator (IOC)',
        initial: '198.51.100.1',
      );
      if (name != null) {
        await widget.controller.createIocDoc(folder: folder, value: name);
      }
    } else if (action == 'archive') {
      widget.controller.archiveFolder(folder);
    } else if (action == 'restore') {
      widget.controller.restoreFolder(folder);
    } else if (action == 'new') {
      final name = await _name(context, 'New folder');
      if (name != null) {
        await widget.controller.organize(
          () => widget.controller.repository.createFolder('$folder/$name'),
        );
      }
    } else if (action == 'rename') {
      Set<String> members() => {
        for (final object in widget.controller.objects)
          if (widget.controller.repository.objectFolder(object.id) == folder ||
              widget.controller.repository
                  .objectFolder(object.id)
                  .startsWith('$folder/'))
            '${object.id}:${widget.controller.repository.objectPath(object.id)}',
      };
      final before = members();
      final folders = widget.controller.allKnownFolders
          .where((f) => f == folder || f.startsWith('$folder/'))
          .toSet();
      final name = await _name(
        context,
        'Rename folder',
        initial: p.posix.basename(folder),
      );
      if (name != null && name != p.posix.basename(folder)) {
        final after = members();
        final currentFolders = widget.controller.allKnownFolders
            .where((f) => f == folder || f.startsWith('$folder/'))
            .toSet();
        if (!_owns(owner) ||
            before.length != after.length ||
            !before.containsAll(after) ||
            folders.length != currentFolders.length ||
            !folders.containsAll(currentFolders)) {
          widget.controller.error =
              'This folder changed while Rename was open. Its contents are retained; reopen Rename to review them.';
          widget.controller.notify();
          return;
        }
        await widget.controller.moveFolder(
          folder,
          '${p.posix.dirname(folder)}/$name',
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: const Text('Delete folder'),
          content: Text(
            'Delete “${p.posix.basename(folder)}”? All contained objects will move to Trash. Restoring them places them at the root.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && _owns(owner)) {
        await widget.controller.deleteFolder(folder);
      }
    } else if (action == 'reveal') {
      await openAttachment(
        widget.controller.repository.location,
        folder,
        reveal: true,
      );
    } else if (action == 'move') {
      final parent = await _destination(context, exclude: folder);
      if (_owns(owner) && parent != null && parent != p.posix.dirname(folder)) {
        await widget.controller.moveFolder(
          folder,
          '$parent/${p.posix.basename(folder)}',
        );
      }
    } else if (action == 'set_folder_color') {
      final currentVal = widget.controller.folderColorValue(folder);
      final explicit = widget.controller.session.folderColors[folder];
      final currentColor = currentVal != null ? Color(currentVal) : null;
      await showFolderColorDialog(
        context,
        folderName: p.posix.basename(folder),
        currentColor: currentColor,
        onCommit: (color) {
          if (!_owns(owner) ||
              !widget.controller.allKnownFolders.contains(folder) ||
              widget.controller.session.folderColors[folder] != explicit) {
            return false;
          }
          widget.controller.setFolderColor(folder, color?.toARGB32());
          return true;
        },
      );
    } else if (action == 'clear_folder_color') {
      widget.controller.setFolderColor(folder, null);
    }
  }

  void _onNoteTap(String noteId, List<String> visibleNoteIds) {
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    setState(() {
      if (isCtrl) {
        if (_selectedNoteIds.contains(noteId)) {
          _selectedNoteIds.remove(noteId);
        } else {
          _selectedNoteIds.add(noteId);
          _anchorNoteId = noteId;
        }
      } else if (isShift &&
          _anchorNoteId != null &&
          visibleNoteIds.contains(_anchorNoteId)) {
        final start = visibleNoteIds.indexOf(_anchorNoteId!);
        final end = visibleNoteIds.indexOf(noteId);
        final minIdx = math.min(start, end);
        final maxIdx = math.max(start, end);
        _selectedNoteIds.clear();
        _selectedNoteIds.addAll(visibleNoteIds.sublist(minIdx, maxIdx + 1));
      } else {
        _selectedNoteIds.clear();
        _selectedNoteIds.add(noteId);
        _anchorNoteId = noteId;
        widget.controller.openObject(noteId);
      }
    });
  }

  Future<void> _batchMoveToFolder() async {
    if (_selectedNoteIds.isEmpty || _batchBusy) return;
    final owner = _capture(), selection = Set.of(_selectedNoteIds);
    _batchBusy = true;
    try {
      final target = await _destination(context);
      if (target == null || !_owns(owner)) return;
      final moved = await owner.$1.moveObjectsToFolder(selection, target);
      if (_owns(owner) && moved && _sameSelection(selection)) {
        setState(() => _selectedNoteIds.clear());
      }
    } finally {
      if (_owns(owner)) _batchBusy = false;
    }
  }

  Future<void> _batchCopyReferences() async {
    if (_selectedNoteIds.isEmpty) return;
    final owner = _capture();
    final selected = _selectedNoteIds
        .map(widget.controller.find)
        .whereType<UniversalObject>()
        .where((o) => !o.isDeleted)
        .toList();
    final refs = selected
        .map((o) => ObjectReference(o.id).markdown(o.title))
        .join('\n');
    await Clipboard.setData(ClipboardData(text: refs));
    if (mounted && _owns(owner)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied ${selected.length} object references')),
      );
    }
  }

  Future<void> _batchMoveToTrash() async {
    if (_selectedNoteIds.isEmpty || _batchBusy) return;
    final owner = _capture(), selection = Set.of(_selectedNoteIds);
    final selected = selection
        .map(owner.$1.find)
        .whereType<UniversalObject>()
        .toList();
    final count = selected.length;
    if (count == 0) return;
    _batchBusy = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => OrbitDialog(
          title: const Text('Move to Trash'),
          content: Text('Move $count items to Trash?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true || !_owns(owner)) return;
      final moved = <String>{};
      for (final object in selected) {
        if (!_owns(owner)) return;
        if (await owner.$1.trash(object.id, expected: object)) {
          moved.add(object.id);
        }
      }
      if (!mounted || !_owns(owner)) return;
      if (_sameSelection(selection)) {
        setState(() => _selectedNoteIds.removeAll(moved));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${moved.length} of $count items to Trash.${moved.length == count ? '' : ' Remaining items are retained; check their save or read-only status.'}',
          ),
        ),
      );
    } finally {
      if (_owns(owner)) _batchBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.controller.repository;
    final owner = _capture();
    if (_selectionOwner != owner) {
      _selectionOwner = owner;
      _selectedNoteIds.clear();
      _anchorNoteId = null;
      _focusedIndex = 0;
      _batchBusy = false;
    }
    final rows = <Widget>[];

    final visibleEntries = <({bool isFolder, String id, String folderPath})>[];
    final visibleNoteIds = <String>[];

    bool isFolderArchived(String f) => widget.controller.isArchivedFolder(f);

    bool objectInFolder(UniversalObject o, String folder) {
      if (o.isDeleted) return false;
      if (o.typeId == 'orbit.file' && !widget.controller.showAttachments) {
        return false;
      }
      return repo.objectFolder(o.id) == folder;
    }

    final allItems = widget.controller.activeObjects
        .where(
          (o) =>
              !o.isDeleted &&
              (o.typeId == 'orbit.note' ||
                  o.typeId == 'orbit.canvas' ||
                  o.typeId == 'orbit.view' ||
                  o.typeId == 'orbit.file'),
        )
        .toList();

    String normalizeFolder(String f) {
      if (f == 'Notes' || f.startsWith('Notes/')) return f;
      return 'Notes/$f';
    }

    final allKnownFolders = <String>{'Notes'};
    for (final raw in repo.folders) {
      if (raw.isEmpty) continue;
      final f = normalizeFolder(raw);
      allKnownFolders.add(f);
      var parent = p.posix.dirname(f);
      while (parent.isNotEmpty && parent != '.' && parent != 'Notes') {
        allKnownFolders.add(parent);
        parent = p.posix.dirname(parent);
      }
    }
    for (final o in allItems) {
      final raw = repo.objectFolder(o.id);
      if (raw.isNotEmpty) {
        final f = normalizeFolder(raw);
        allKnownFolders.add(f);
        var parent = p.posix.dirname(f);
        while (parent.isNotEmpty && parent != '.' && parent != 'Notes') {
          allKnownFolders.add(parent);
          parent = p.posix.dirname(parent);
        }
      }
    }

    final rootFolders = [
      'Notes',
      ...allKnownFolders
          .where((f) => f != 'Notes' && p.posix.dirname(f) == '.')
          .toSet()
          .toList()
        ..sort(),
    ];

    void collect(String folder) {
      if (isFolderArchived(folder)) return;
      visibleEntries.add((isFolder: true, id: folder, folderPath: folder));
      final collapsed =
          !widget.filtering &&
          widget.controller.session.collapsedFolders.contains(folder);
      if (collapsed) return;
      for (final child
          in allKnownFolders
              .where(
                (f) =>
                    f != folder &&
                    p.posix.dirname(f) == folder &&
                    !isFolderArchived(f),
              )
              .toList()
            ..sort()) {
        collect(child);
      }
      final folderObjects = allItems
          .where((o) => objectInFolder(o, folder))
          .toList();
      sortObjects(folderObjects, widget.controller.session.noteSort);
      for (final note in folderObjects) {
        visibleEntries.add((isFolder: false, id: note.id, folderPath: folder));
        visibleNoteIds.add(note.id);
      }
    }

    for (final root in rootFolders) {
      collect(root);
    }

    Color? resolveAccent(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return Color(raw);
      if (raw is Color) return raw;
      if (raw is String) {
        if (OrbitColors.accentPresets.containsKey(raw)) {
          return OrbitColors.accentPresets[raw];
        }
        final hex = raw.replaceAll('#', '');
        if (hex.length == 6) {
          final val = int.tryParse('FF$hex', radix: 16);
          if (val != null) return Color(val);
        } else if (hex.length == 8) {
          final val = int.tryParse(hex, radix: 16);
          if (val != null) return Color(val);
        }
      }
      return null;
    }

    Color? getFolderAccent(String folderPath) {
      String? current = folderPath;
      while (current != null && current.isNotEmpty) {
        final raw =
            widget.controller.session.folderColors[current] ??
            (widget.controller.session.extra['folderColors'] as Map?)?[current];
        final acc = resolveAccent(raw);
        if (acc != null) return acc;
        final parent = p.posix.dirname(current);
        if (parent == current || parent == '.' || parent.isEmpty) break;
        current = parent;
      }
      return null;
    }

    void visit(String folder, int depth) {
      final collapsed =
          !widget.filtering &&
          widget.controller.session.collapsedFolders.contains(folder);
      final folderAccent = getFolderAccent(folder);
      final hasExplicitFolderColor =
          widget.controller.session.folderColors.containsKey(folder) ||
          ((widget.controller.session.extra['folderColors'] as Map?)
                  ?.containsKey(folder) ??
              false);
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 12.0),
          child: _drop(
            folder,
            _drag(
              folder,
              null,
              OrbitExplorerRow(
                key: ValueKey('folder:$folder'),
                accentColor: folderAccent,
                leading: Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16,
                ),
                onExpand: () => widget.controller.updateSession(
                  (s) => s.collapsedFolders = s.collapsedFolders
                      .where((f) => f != folder)
                      .toList(),
                ),
                onCollapse: () => widget.controller.updateSession(
                  (s) => s.collapsedFolders = {
                    ...s.collapsedFolders,
                    folder,
                  }.toList(),
                ),
                title: Text(
                  p.posix.basename(folder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5),
                ),
                onTap: () => widget.controller.updateSession(
                  (s) => s.collapsedFolders = collapsed
                      ? s.collapsedFolders.where((f) => f != folder).toList()
                      : {...s.collapsedFolders, folder}.toList(),
                ),
                menu: PopupMenuButton<String>(
                  tooltip: 'Folder actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) => _owns(owner)
                      ? _folderAction(context, folder, action)
                      : null,
                  itemBuilder: (_) {
                    final isGameFolder =
                        folder.startsWith('Games') ||
                        folder.startsWith('Notes/Games') ||
                        folder.toLowerCase().contains('game');
                    final isCourseFolder =
                        folder.startsWith('Courses') ||
                        folder.startsWith('University') ||
                        folder.startsWith('Notes/Courses') ||
                        folder.startsWith('Notes/University') ||
                        folder.toLowerCase().contains('course');
                    final isReFolder =
                        folder.startsWith('Reverse Engineering') ||
                        folder.startsWith('Malware Analysis') ||
                        folder.startsWith('Game Internals') ||
                        folder.startsWith('Notes/Reverse Engineering') ||
                        folder.startsWith('Notes/Malware Analysis') ||
                        folder.startsWith('Notes/Game Internals') ||
                        folder.toLowerCase().contains('reverse engineering') ||
                        folder.toLowerCase().contains('malware') ||
                        folder.toLowerCase().contains('internals') ||
                        folder.toLowerCase().contains('security');
                    return [
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_note',
                        child: const Text('New Note'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_canvas',
                        child: const Text('New Canvas'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new',
                        child: Text(
                          folder == 'Notes' ? 'New folder' : 'New subfolder',
                        ),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_task_list',
                        child: const Text('New Task List'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_board',
                        child: const Text('New Board'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_calendar',
                        child: const Text('New Calendar'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_timeline',
                        child: const Text('New Timeline'),
                      ),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_gantt',
                        child: const Text('New Gantt Timeline'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        enabled: !repo.readOnly,
                        value: 'new_research',
                        child: const Text('New Research Workspace'),
                      ),
                      if (folder == 'Notes' || isGameFolder) ...[
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_creative_project',
                          child: const Text('New Creative Project…'),
                        ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_game_project',
                          child: const Text('New Game Project…'),
                        ),
                        if (isGameFolder) ...[
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'duplicate_project_structure',
                            child: const Text('Duplicate Project Structure…'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_gdd',
                            child: const Text('New GDD Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_feature_spec',
                            child: const Text('New Feature Spec'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_mechanic_spec',
                            child: const Text('New Mechanic Spec'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_level_design',
                            child: const Text('New Level Design Doc'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_enemy_design',
                            child: const Text('New Enemy Design'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_character_design',
                            child: const Text('New Character Profile'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_item_design',
                            child: const Text('New Item / Weapon'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_quest',
                            child: const Text('New Quest / Mission'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_audio_plan',
                            child: const Text('New Audio Plan'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_bug_report',
                            child: const Text('New Bug Report'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_playtest',
                            child: const Text('New Playtest Session'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_dev_log',
                            child: const Text('New Dev Log'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_release_checklist',
                            child: const Text('New Release Checklist'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_weekly_review',
                            child: const Text('New Weekly Review'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_risk',
                            child: const Text('New Risk Assessment'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_decision',
                            child: const Text('New Architecture Decision'),
                          ),
                        ],
                      ],
                      if (folder == 'Notes' || isCourseFolder) ...[
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_course',
                          child: const Text('New Course (University)…'),
                        ),
                        if (isCourseFolder) ...[
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_lecture',
                            child: const Text('New Lecture Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_exercise',
                            child: const Text('New Exercise Canvas'),
                          ),
                        ],
                      ],
                      if (folder == 'Notes' || isReFolder) ...[
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_re_project',
                          child: const Text('New Reverse Engineering Project…'),
                        ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_game_internals_project',
                          child: const Text('New Game Internals Project…'),
                        ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'new_malware_project',
                          child: const Text('New Malware Analysis Project…'),
                        ),
                        if (isReFolder) ...[
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_research_record',
                            child: const Text('New Research Record…'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_research_map',
                            child: const Text('Map Research Records…'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_function_doc',
                            child: const Text('New Function Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_structure_doc',
                            child: const Text('New Structure Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_finding_doc',
                            child: const Text('New Finding Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_hypothesis_doc',
                            child: const Text('New Hypothesis Note'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_session_doc',
                            child: const Text('New Analysis Session'),
                          ),
                          PopupMenuItem(
                            enabled: !repo.readOnly,
                            value: 'new_ioc_doc',
                            child: const Text('New Indicator (IOC)'),
                          ),
                        ],
                      ],
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'set_folder_color',
                        child: Text(
                          hasExplicitFolderColor
                              ? 'Change folder color…'
                              : 'Set folder color…',
                        ),
                      ),
                      if (hasExplicitFolderColor)
                        const PopupMenuItem(
                          value: 'clear_folder_color',
                          child: Text('Reset folder color'),
                        ),
                      if (folder != 'Notes') ...[
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'rename',
                          child: const Text('Rename folder'),
                        ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'move',
                          child: const Text('Move folder…'),
                        ),
                        if (!kIsWeb)
                          const PopupMenuItem(
                            value: 'reveal',
                            child: Text('Reveal in File Explorer'),
                          ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'archive',
                          child: const Text('Archive folder'),
                        ),
                        PopupMenuItem(
                          enabled: !repo.readOnly,
                          value: 'delete',
                          child: const Text('Delete folder'),
                        ),
                      ] else if (!kIsWeb) ...[
                        const PopupMenuItem(
                          value: 'reveal',
                          child: Text('Reveal in File Explorer'),
                        ),
                      ],
                    ];
                  },
                ),
              ),
            ),
          ),
        ),
      );
      if (collapsed) return;
      for (final child
          in allKnownFolders
              .where(
                (f) =>
                    f != folder &&
                    p.posix.dirname(f) == folder &&
                    !isFolderArchived(f),
              )
              .toList()
            ..sort()) {
        visit(child, depth + 1);
      }
      final folderObjects = allItems
          .where((o) => objectInFolder(o, folder))
          .toList();
      sortObjects(folderObjects, widget.controller.session.noteSort);
      for (final note in folderObjects) {
        final isMulti = _selectedNoteIds.contains(note.id);
        final hasBatch = _selectedNoteIds.length > 1 && isMulti;
        final mime = (note.properties['mimeType'] as String? ?? '')
            .toLowerCase();
        final lowerTitle = note.title.toLowerCase();
        final isPdf =
            note.typeId == 'orbit.file' &&
            (mime == 'application/pdf' || lowerTitle.endsWith('.pdf'));
        final isImage =
            note.typeId == 'orbit.file' &&
            (mime.startsWith('image/') ||
                lowerTitle.endsWith('.png') ||
                lowerTitle.endsWith('.jpg') ||
                lowerTitle.endsWith('.jpeg') ||
                lowerTitle.endsWith('.webp') ||
                lowerTitle.endsWith('.gif') ||
                lowerTitle.endsWith('.svg'));
        final leadingWidget =
            note.properties['icon'] != null &&
                note.properties['icon'].toString().isNotEmpty
            ? Text(
                note.properties['icon'].toString(),
                style: const TextStyle(fontSize: 14),
              )
            : note.typeId == 'orbit.canvas'
            ? const Icon(Icons.dashboard_outlined, size: 16)
            : note.typeId == 'orbit.view'
            ? Icon(
                viewTypeIcon(note.properties['viewType'] as String?),
                size: 16,
              )
            : note.typeId == 'orbit.file'
            ? Icon(
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                size: 16,
                color: isPdf
                    ? Theme.of(context).colorScheme.error
                    : isImage
                    ? Theme.of(context).colorScheme.tertiary
                    : null,
              )
            : const Icon(Icons.description_outlined, size: 16);

        final noteExplicitColor = resolveAccent(
          note.properties['accent'] ?? note.properties['color'],
        );
        final noteAccent = noteExplicitColor ?? folderAccent;

        rows.add(
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 12.0),
            child: _drag(
              repo.objectPath(note.id) ?? note.title,
              note.id,
              OrbitExplorerRow(
                key: ValueKey(
                  note.typeId == 'orbit.note'
                      ? 'folder-note:${note.id}'
                      : 'folder-item:${note.id}',
                ),
                selected: widget.controller.session.activeId == note.id,
                multiSelected: isMulti,
                accentColor: noteAccent,
                leading: leadingWidget,
                title: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _onNoteTap(note.id, visibleNoteIds),
                menu: PopupMenuButton<String>(
                  tooltip: 'Object actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) async {
                    if (!_owns(owner)) return;
                    if (action == 'batch_move') {
                      await _batchMoveToFolder();
                    } else if (action == 'batch_copy') {
                      await _batchCopyReferences();
                    } else if (action == 'batch_trash') {
                      await _batchMoveToTrash();
                    } else if (action == 'rename') {
                      if (!context.mounted) return;
                      await showObjectRenameDialog(
                        context,
                        widget.controller,
                        note,
                      );
                    } else if (action == 'copy') {
                      await Clipboard.setData(
                        ClipboardData(
                          text: ObjectReference(note.id).markdown(note.title),
                        ),
                      );
                    } else if (action == 'split') {
                      widget.controller.openObject(note.id, secondary: true);
                    } else if (action == 'duplicate') {
                      await widget.controller.duplicateObject(note.id);
                    } else if (action == 'reveal') {
                      final relPath = repo.objectPath(note.id);
                      if (relPath != null) {
                        await openAttachment(
                          repo.location,
                          relPath,
                          reveal: true,
                        );
                      }
                    } else if (action == 'trash') {
                      await widget.controller.trash(note.id);
                    } else if (action == 'move') {
                      if (!context.mounted) return;
                      final target = await _destination(context);
                      if (target != null && target != folder) {
                        await widget.controller.moveObjectToFolder(
                          note.id,
                          target,
                        );
                      }
                    } else if (action == 'set_note_color') {
                      await showFolderColorDialog(
                        context,
                        folderName: note.title.isEmpty
                            ? 'Untitled'
                            : note.title,
                        isNote: true,
                        currentColor: noteExplicitColor,
                        onCommit: (color) {
                          if (!_owns(owner)) return false;
                          return widget.controller.editObjectMetadata(
                            note,
                            generation: owner.$3,
                            changes: color == null
                                ? const {}
                                : {'color': color.toARGB32()},
                            remove: color == null
                                ? {'color', 'accent'}
                                : const {},
                            unchanged: {'accent'},
                          );
                        },
                      );
                    } else if (action == 'clear_note_color') {
                      widget.controller.editObjectMetadata(
                        note,
                        generation: owner.$3,
                        remove: {'color', 'accent'},
                      );
                    } else if (action == 'batch_move') {
                      await _batchMoveToFolder();
                    } else if (action == 'batch_copy') {
                      await _batchCopyReferences();
                    } else if (action == 'batch_duplicate') {
                      await widget.controller.duplicateObjects(
                        _selectedNoteIds,
                      );
                    } else if (action == 'batch_trash') {
                      await _batchMoveToTrash();
                    }
                  },
                  itemBuilder: (_) => [
                    if (hasBatch) ...[
                      PopupMenuItem(
                        value: 'batch_move',
                        child: Text(
                          'Move ${_selectedNoteIds.length} items to folder…',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'batch_copy',
                        child: Text(
                          'Copy ${_selectedNoteIds.length} references',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'batch_duplicate',
                        child: Text(
                          'Duplicate ${_selectedNoteIds.length} items',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'batch_trash',
                        child: Text('Move ${_selectedNoteIds.length} to Trash'),
                      ),
                      const PopupMenuDivider(),
                    ],
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'rename',
                      child: Text(
                        note.typeId == 'orbit.note' ? 'Rename note' : 'Rename',
                      ),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'duplicate',
                      child: Text(
                        note.typeId == 'orbit.note'
                            ? 'Duplicate note'
                            : note.typeId == 'orbit.canvas'
                            ? 'Duplicate canvas'
                            : note.typeId == 'orbit.task'
                            ? 'Duplicate task'
                            : note.typeId == 'orbit.view'
                            ? 'Duplicate view'
                            : 'Duplicate',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'split',
                      child: Text('Open beside'),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(
                        note.typeId == 'orbit.note'
                            ? 'Copy note reference'
                            : 'Copy reference',
                      ),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'move',
                      child: const Text('Move to folder…'),
                    ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'set_note_color',
                      child: Text(
                        noteExplicitColor != null
                            ? 'Change accent color…'
                            : 'Set accent color…',
                      ),
                    ),
                    if (noteExplicitColor != null)
                      const PopupMenuItem(
                        value: 'clear_note_color',
                        child: Text('Reset color'),
                      ),
                    if (repo.objectPath(note.id) != null && !kIsWeb)
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in File Explorer'),
                      ),
                    PopupMenuItem(
                      enabled: !repo.readOnly && !note.isReadOnly,
                      value: 'trash',
                      child: const Text('Move to Trash'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    for (final root in rootFolders) {
      visit(root, 0);
    }

    // Archived Folders section
    final archivedFolders = allKnownFolders
        .where((f) => isFolderArchived(f))
        .toList();
    if (archivedFolders.isNotEmpty) {
      rows.add(const SizedBox(height: 8));
      rows.add(
        OrbitExplorerRow(
          key: const ValueKey('archived-header'),
          leading: Icon(
            _showArchived ? Icons.expand_more : Icons.chevron_right,
            size: 16,
          ),
          title: Text(
            'Archived (${archivedFolders.length})',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          onTap: () => setState(() => _showArchived = !_showArchived),
          menu: PopupMenuButton<String>(
            tooltip: 'Archived options',
            icon: const Icon(Icons.more_horiz, size: 16),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(_showArchived ? 'Collapse' : 'Expand'),
              ),
            ],
            onSelected: (_) => setState(() => _showArchived = !_showArchived),
          ),
        ),
      );

      if (_showArchived) {
        for (final archFolder in archivedFolders) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: OrbitExplorerRow(
                key: ValueKey('archived-folder:$archFolder'),
                leading: const Icon(Icons.archive_outlined, size: 16),
                title: Text(
                  p.posix.basename(archFolder),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                onTap: () {},
                menu: PopupMenuButton<String>(
                  tooltip: 'Archived folder actions',
                  icon: const Icon(Icons.more_horiz, size: 16),
                  onSelected: (action) => _owns(owner)
                      ? _folderAction(context, archFolder, action)
                      : null,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore folder'),
                    ),
                    if (!kIsWeb)
                      const PopupMenuItem(
                        value: 'reveal',
                        child: Text('Reveal in File Explorer'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete folder'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (!_owns(owner)) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final isCtrl =
            HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
          setState(() {
            _selectedNoteIds.clear();
            _selectedNoteIds.addAll(visibleNoteIds);
          });
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (visibleEntries.isNotEmpty) {
            setState(() {
              _focusedIndex = math.min(
                visibleEntries.length - 1,
                _focusedIndex + 1,
              );
              final item = visibleEntries[_focusedIndex];
              if (!item.isFolder) {
                if (isShift) {
                  if (_anchorNoteId != null &&
                      visibleNoteIds.contains(_anchorNoteId)) {
                    final start = visibleNoteIds.indexOf(_anchorNoteId!);
                    final end = visibleNoteIds.indexOf(item.id);
                    final minIdx = math.min(start, end);
                    final maxIdx = math.max(start, end);
                    _selectedNoteIds.clear();
                    _selectedNoteIds.addAll(
                      visibleNoteIds.sublist(minIdx, maxIdx + 1),
                    );
                  } else {
                    _selectedNoteIds.add(item.id);
                    _anchorNoteId = item.id;
                  }
                } else {
                  _selectedNoteIds.clear();
                  _selectedNoteIds.add(item.id);
                  _anchorNoteId = item.id;
                }
              }
            });
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (visibleEntries.isNotEmpty) {
            setState(() {
              _focusedIndex = math.max(0, _focusedIndex - 1);
              final item = visibleEntries[_focusedIndex];
              if (!item.isFolder) {
                if (isShift) {
                  if (_anchorNoteId != null &&
                      visibleNoteIds.contains(_anchorNoteId)) {
                    final start = visibleNoteIds.indexOf(_anchorNoteId!);
                    final end = visibleNoteIds.indexOf(item.id);
                    final minIdx = math.min(start, end);
                    final maxIdx = math.max(start, end);
                    _selectedNoteIds.clear();
                    _selectedNoteIds.addAll(
                      visibleNoteIds.sublist(minIdx, maxIdx + 1),
                    );
                  } else {
                    _selectedNoteIds.add(item.id);
                    _anchorNoteId = item.id;
                  }
                } else {
                  _selectedNoteIds.clear();
                  _selectedNoteIds.add(item.id);
                  _anchorNoteId = item.id;
                }
              }
            });
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              if (collapsed) {
                widget.controller.updateSession(
                  (s) => s.collapsedFolders = s.collapsedFolders
                      .where((f) => f != item.id)
                      .toList(),
                );
              } else if (_focusedIndex + 1 < visibleEntries.length) {
                setState(() => _focusedIndex++);
              }
              return KeyEventResult.handled;
            }
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              if (!collapsed && item.id != 'Notes') {
                widget.controller.updateSession(
                  (s) => s.collapsedFolders = {
                    ...s.collapsedFolders,
                    item.id,
                  }.toList(),
                );
              } else {
                final parentFolder = p.posix.dirname(item.id);
                final parentIdx = visibleEntries.indexWhere(
                  (e) => e.isFolder && e.id == parentFolder,
                );
                if (parentIdx >= 0) setState(() => _focusedIndex = parentIdx);
              }
              return KeyEventResult.handled;
            } else {
              final parentFolder = item.folderPath;
              final parentIdx = visibleEntries.indexWhere(
                (e) => e.isFolder && e.id == parentFolder,
              );
              if (parentIdx >= 0) setState(() => _focusedIndex = parentIdx);
              return KeyEventResult.handled;
            }
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (item.isFolder) {
              final collapsed = widget.controller.session.collapsedFolders
                  .contains(item.id);
              widget.controller.updateSession(
                (s) => s.collapsedFolders = collapsed
                    ? s.collapsedFolders.where((f) => f != item.id).toList()
                    : {...s.collapsedFolders, item.id}.toList(),
              );
            } else {
              widget.controller.openObject(item.id);
            }
            return KeyEventResult.handled;
          }
        }

        if (event.logicalKey == LogicalKeyboardKey.space) {
          if (_focusedIndex >= 0 && _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (!item.isFolder) {
              setState(() {
                if (_selectedNoteIds.contains(item.id)) {
                  _selectedNoteIds.remove(item.id);
                } else {
                  _selectedNoteIds.add(item.id);
                }
              });
              return KeyEventResult.handled;
            }
          }
        }

        if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
          if (_selectedNoteIds.isNotEmpty) {
            widget.controller.duplicateObjects(_selectedNoteIds.toList());
            return KeyEventResult.handled;
          } else if (_focusedIndex >= 0 &&
              _focusedIndex < visibleEntries.length) {
            final item = visibleEntries[_focusedIndex];
            if (!item.isFolder) {
              widget.controller.duplicateObject(item.id);
              return KeyEventResult.handled;
            }
          }
        }

        if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyE) {
          if (widget.controller.areAllFoldersCollapsed) {
            widget.controller.expandAllFolders();
          } else {
            widget.controller.collapseAllFolders();
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          if (_selectedNoteIds.length > 1)
            Container(
              key: const ValueKey('explorer-batch-bar'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: OrbitColors.of(context).raised,
                borderRadius: BorderRadius.circular(OrbitRadius.control),
                border: Border.all(color: OrbitColors.of(context).border),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedNoteIds.length} items selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Move to folder…',
                    icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                    onPressed: () {
                      if (_owns(owner)) _batchMoveToFolder();
                    },
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy references',
                    icon: const Icon(Icons.link, size: 16),
                    onPressed: () {
                      if (_owns(owner)) _batchCopyReferences();
                    },
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move to Trash',
                    icon: const Icon(Icons.delete_outline, size: 16),
                    onPressed: () {
                      if (_owns(owner)) _batchMoveToTrash();
                    },
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear selection',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      if (_owns(owner)) {
                        setState(() => _selectedNoteIds.clear());
                      }
                    },
                    splashRadius: 14,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}
