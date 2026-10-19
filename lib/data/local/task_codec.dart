import '../../models/academic_task.dart';
import 'proforma_source_codec.dart';

/// Versioned storage format, independent of Flutter widgets and backend SDKs.
class TaskCodec {
  static Map<String, Object?> encode(List<AcademicTask> tasks) => {
    'schemaVersion': 1,
    'tasks': tasks
        .map(
          (task) => {
            'id': task.id,
            'title': task.title,
            'subject': task.subject,
            'description': task.description,
            'deadline': task.deadline.toIso8601String(),
            'estimatedMinutes': task.estimatedMinutes,
            'completedMinutes': task.completedMinutes,
            'difficulty': task.difficulty.name,
            'importance': task.importance.name,
            'status': task.status.name,
            if (task.courseId != null) 'courseId': task.courseId,
            if (task.source != null)
              'source': ProformaSourceCodec.encode(task.source),
          },
        )
        .toList(),
  };

  static List<AcademicTask> decode(Map<String, Object?> document) {
    if (document['schemaVersion'] != 1 || document['tasks'] is! List) {
      throw const FormatException('Unsupported task storage format.');
    }
    final ids = <String>{};
    return (document['tasks'] as List).map((value) {
      if (value is! Map) throw const FormatException('Invalid task record.');
      String text(String key, {bool allowEmpty = false}) {
        final result = value[key];
        if (result is! String || (!allowEmpty && result.trim().isEmpty)) {
          throw FormatException('Invalid task $key.');
        }
        return result;
      }

      int number(String key, {required int minimum}) {
        final result = value[key];
        if (result is! int || result < minimum) {
          throw FormatException('Invalid task $key.');
        }
        return result;
      }

      T enumeration<T extends Enum>(String key, List<T> options) {
        final name = text(key);
        final result = options.where((item) => item.name == name).firstOrNull;
        if (result == null) throw FormatException('Invalid task $key.');
        return result;
      }

      final id = text('id');
      if (!ids.add(id)) throw const FormatException('Duplicate task ID.');
      final deadline = DateTime.tryParse(text('deadline'));
      if (deadline == null || deadline.toIso8601String() != text('deadline')) {
        throw const FormatException('Invalid task deadline.');
      }
      final estimated = number('estimatedMinutes', minimum: 1);
      final completed = number('completedMinutes', minimum: 0);
      if (completed > estimated) {
        throw const FormatException('Invalid task effort.');
      }
      return AcademicTask(
        id: id,
        title: text('title'),
        subject: text('subject'),
        description: text('description', allowEmpty: true),
        deadline: deadline,
        estimatedMinutes: estimated,
        completedMinutes: completed,
        difficulty: enumeration('difficulty', TaskDifficulty.values),
        importance: enumeration('importance', TaskImportance.values),
        status: enumeration('status', TaskStatus.values),
        courseId: value['courseId'] == null ? null : text('courseId'),
        source: ProformaSourceCodec.decode(value['source']),
      );
    }).toList();
  }
}
