part of 'workspace_controller.dart';

extension CreativeProjects on WorkspaceController {
  Future<UniversalObject> captureCreativeReference(
    String canvasId,
    String name,
    Uint8List bytes,
  ) async {
    final board = find(canvasId);
    if (board == null ||
        board.isDeleted ||
        board.isReadOnly ||
        repository.readOnly ||
        board.typeId != 'orbit.canvas' ||
        CanvasScene.fromJson(board.data).readOnly) {
      throw StateError('Choose an editable reference board.');
    }
    final workspace = repository.workspaceId, generation = workspaceGeneration;
    final source = await repository.importAttachment(name: name, bytes: bytes);
    if (repository.workspaceId != workspace ||
        workspaceGeneration != generation) {
      throw StateError('The workspace changed during capture.');
    }
    try {
      final latest = find(canvasId);
      final hasOwner = [
        'project',
        'course',
        'context',
      ].any(source.properties.containsKey);
      final object = await repository.save(
        source.copyWith(
          properties: {
            ...source.properties,
            if (latest != null && !latest.isDeleted) ...{
              if (!source.properties.containsKey('folder') &&
                  latest.properties['folder'] is String)
                'folder': latest.properties['folder'],
              if (!hasOwner && latest.properties['project'] is String)
                'project': latest.properties['project'],
              if (!hasOwner && latest.properties['projectName'] is String)
                'projectName': latest.properties['projectName'],
            },
            if (!source.properties.containsKey('referenceBoardId'))
              'referenceBoardId': canvasId,
          },
        ),
      );
      if (repository.workspaceId != workspace ||
          workspaceGeneration != generation) {
        throw StateError('The workspace changed during capture.');
      }
      return object;
    } finally {
      // An imported source remains discoverable even if metadata enrichment fails.
      if (repository.workspaceId == workspace &&
          workspaceGeneration == generation) {
        mergeRepositoryObjects();
        notify();
      }
    }
  }

  /// Scaffolds real objects through the existing validated, recoverable saves.
  /// On failure, already-saved objects remain available rather than being erased.
  Future<UniversalObject?> createCreativeProject(
    String name, {
    required String briefBody,
    String targetParentFolder = 'Notes',
  }) async {
    if (_creatingCreativeProject) return null;
    _creatingCreativeProject = true;
    final saved = <UniversalObject>[];
    try {
      final clean = name.trim();
      if (clean.isEmpty ||
          clean.length > 120 ||
          clean == '.' ||
          clean == '..' ||
          clean.endsWith('.') ||
          RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(clean)) {
        throw const FormatException(
          'Use a project name without path separators or reserved filename characters.',
        );
      }
      if (!repository.folders.contains(targetParentFolder)) {
        throw const FormatException('Choose an existing parent folder.');
      }
      final folder = '$targetParentFolder/$clean';
      if (repository.folders.any(
            (f) => f.toLowerCase() == folder.toLowerCase(),
          ) ||
          activeObjects.any(
            (o) =>
                o.properties['folder']?.toString().toLowerCase() ==
                folder.toLowerCase(),
          )) {
        throw const FormatException(
          'That project folder already exists. Choose a different name.',
        );
      }
      if (!await flushAll()) return null;
      await repository.createFolder(folder);
      for (final sub in ['References', 'Production']) {
        await repository.createFolder('$folder/$sub');
      }
      Future<UniversalObject> add(
        String type,
        String title, {
        String body = '',
        Map<String, dynamic> properties = const {},
        Map<String, dynamic> data = const {},
      }) async {
        final object = await repository.create(
          typeId: type,
          title: title,
          body: body,
          properties: {
            'folder': folder,
            'creativeProject': true,
            ...properties,
          },
          data: data,
        );
        saved.add(object);
        return object;
      }

      var brief = await add(
        'orbit.note',
        '$clean — Brief',
        body: briefBody,
        properties: {'isCreativeBrief': true, 'projectName': clean},
      );
      final project = brief.id;
      final common = {'project': project, 'projectName': clean};
      final decisions = await add(
        'orbit.note',
        '$clean — Decisions',
        properties: common,
        body:
            '# Decisions\n\n| Date | Question | Decision | Evidence / reference | Next action |\n| --- | --- | --- | --- | --- |\n| | | | | |\n',
      );
      final references = await add(
        'orbit.canvas',
        '$clean — References',
        properties: {...common, 'folder': '$folder/References'},
        data: {
          'schemaVersion': 1,
          'elements': [
            for (var i = 0; i < 3; i++)
              {
                'id': const Uuid().v4(),
                'type': 'column',
                'text': [
                  'Inspiration',
                  'Research & sources',
                  'Chosen direction',
                ][i],
                'x': i * 300.0,
                'y': 0.0,
                'width': 280.0,
                'height': 520.0,
                'color': [0xff8b7cf6, 0xff6f7fea, 0xff65c6a3][i],
              },
          ],
        },
      );
      const stages = ['Explore', 'Decide', 'Produce', 'Review'];
      final tasks = <UniversalObject>[];
      for (var i = 0; i < stages.length; i++) {
        tasks.add(
          await add(
            'orbit.task',
            [
              'Gather and compare references',
              'Choose a direction and record why',
              'Make the smallest useful prototype',
              'Review against the brief',
            ][i],
            properties: {
              ...common,
              'folder': '$folder/Production',
              'completed': false,
              'status': 'todo',
              'priority': 'medium',
              'milestone': stages[i],
              'resources': [brief.id, references.id, decisions.id],
            },
            body: [
              brief,
              references,
              decisions,
            ].map((o) => ObjectReference(o.id).markdown(o.title)).join('\n\n'),
          ),
        );
      }
      final milestones = await add(
        'orbit.view',
        '$clean — Milestones',
        properties: {
          ...common,
          'viewType': 'milestones',
          'scope': project,
          'folderFilter': folder,
          'milestoneStages': stages,
        },
      );
      final taskList = await add(
        'orbit.view',
        '$clean — Tasks',
        properties: {
          ...common,
          'viewType': 'tasks',
          'scope': project,
          'folderFilter': folder,
        },
      );
      final board = await add(
        'orbit.canvas',
        '$clean — Project Board',
        properties: common,
        data: {
          'schemaVersion': 1,
          'elements': [
            for (var i = 0; i < stages.length; i++)
              {
                'id': 'stage-$i',
                'type': 'column',
                'text': stages[i],
                'x': i * 300.0,
                'y': 240.0,
                'width': 280.0,
                'height': 440.0,
                'color': [0xff8b7cf6, 0xff6f7fea, 0xffd8b56a, 0xff65c6a3][i],
              },
            for (var i = 0; i < tasks.length; i++)
              {
                'id': const Uuid().v4(),
                'type': 'card',
                'objectId': tasks[i].id,
                'columnId': 'stage-$i',
                'x': i * 300.0 + 16,
                'y': 300.0,
                'width': 248.0,
                'height': 150.0,
              },
            for (final (i, object) in [
              brief,
              references,
              decisions,
              milestones,
            ].indexed)
              {
                'id': const Uuid().v4(),
                'type': 'card',
                'objectId': object.id,
                'x': i * 300.0,
                'y': 0.0,
                'width': 280.0,
                'height': 190.0,
              },
          ],
        },
      );
      final research = await add(
        'orbit.view',
        '$clean — Research',
        properties: {
          ...common,
          'viewType': 'research',
          'researchVersion': 1,
          'researchLayout': 'Gallery',
          'referenceEntries': <Map<String, dynamic>>[],
          'briefId': brief.id,
        },
      );
      brief = await repository.save(
        brief.copyWith(
          properties: {
            ...brief.properties,
            ...common,
            'projectBoardId': board.id,
            'referenceBoardId': references.id,
            'milestoneViewId': milestones.id,
            'researchViewId': research.id,
          },
          body:
              '$briefBody\n\n## Project workspace\n'
              '${[board, references, research, decisions, milestones, taskList].map((o) => '- ${ObjectReference(o.id).markdown(o.title)}').join('\n')}\n',
        ),
      );
      mergeRepositoryObjects();
      error = null;
      openObject(board.id);
      notify();
      return brief;
    } catch (e) {
      mergeRepositoryObjects();
      error = saved.isEmpty
          ? '$e'
          : 'Project setup stopped: $e. ${saved.length} saved items remain available in the project folder.';
      notify();
      return null;
    } finally {
      _creatingCreativeProject = false;
    }
  }
}
