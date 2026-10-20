import 'universal_object.dart';

/// Course metadata lives on its ordinary overview note. Explicit membership
/// takes priority over legacy labels and folder membership.
bool belongsToCourse(UniversalObject object, UniversalObject course) {
  if (object.isDeleted) return false;
  final id = object.properties['courseId'];
  if (object.properties.containsKey('courseId')) return id == course.id;
  final folder = course.properties['folder'];
  final path = object.properties['folder'];
  if (folder is String &&
      folder.isNotEmpty &&
      path is String &&
      (path == folder || path.startsWith('$folder/'))) {
    return true;
  }
  // Identically named courses in different folders must not mix.
  if (path is String && path.isNotEmpty) return false;
  final label = course.properties['course'];
  return label is String &&
      label.isNotEmpty &&
      object.properties['course'] == label;
}

class CourseProgress {
  CourseProgress(
    UniversalObject course,
    Iterable<UniversalObject> objects, {
    DateTime? now,
  }) {
    final day = now ?? DateTime.now();
    final today = DateTime(day.year, day.month, day.day);
    for (final object in objects) {
      if (!belongsToCourse(object, course) || object.id == course.id) continue;
      members.add(object);
      if (object.typeId == 'orbit.task') {
        tasks++;
        if (object.isCompleted) {
          completedTasks++;
        } else {
          final due = DateTime.tryParse(
            '${object.properties['dueDate'] ?? ''}',
          );
          if (due != null &&
              DateTime(due.year, due.month, due.day).isBefore(today)) {
            overdue++;
          }
        }
      }
      if (object.properties.containsKey('exerciseStatus')) {
        exercises++;
        if (object.properties['exerciseStatus'] == 'solved') solvedExercises++;
      }
      if (object.properties.containsKey('studyUnderstanding')) {
        concepts++;
        if (object.properties['studyUnderstanding'] == 'understood') {
          understoodConcepts++;
        }
      }
    }
  }
  final members = <UniversalObject>[];
  int tasks = 0, completedTasks = 0, overdue = 0;
  int exercises = 0, solvedExercises = 0;
  int concepts = 0, understoodConcepts = 0;
  double get taskRatio => tasks == 0 ? 0 : completedTasks / tasks;
}
