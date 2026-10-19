import 'proforma.dart';

enum TaskDifficulty { easy, moderate, challenging }

enum TaskImportance { low, medium, high }

enum TaskStatus { active, completed }

class AcademicTask {
  const AcademicTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.deadline,
    required this.estimatedMinutes,
    this.completedMinutes = 0,
    this.difficulty = TaskDifficulty.moderate,
    this.importance = TaskImportance.medium,
    this.status = TaskStatus.active,
    this.courseId,
    this.source,
  }) : assert(estimatedMinutes > 0),
       assert(completedMinutes >= 0);

  final String id;
  final String title;
  final String subject;
  final String description;
  final DateTime deadline;
  final int estimatedMinutes;
  final int completedMinutes;
  final TaskDifficulty difficulty;
  final TaskImportance importance;
  final TaskStatus status;
  final String? courseId;
  final ProformaSource? source;

  double get progress =>
      isCompleted ? 1 : (completedMinutes / estimatedMinutes).clamp(0, 1);
  bool get isCompleted => status == TaskStatus.completed;

  AcademicTask copyWith({
    String? title,
    String? subject,
    String? description,
    DateTime? deadline,
    int? estimatedMinutes,
    TaskDifficulty? difficulty,
    TaskImportance? importance,
    TaskStatus? status,
    String? courseId,
    bool clearCourse = false,
  }) => AcademicTask(
    id: id,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    description: description ?? this.description,
    deadline: deadline ?? this.deadline,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    completedMinutes: completedMinutes,
    difficulty: difficulty ?? this.difficulty,
    importance: importance ?? this.importance,
    status: status ?? this.status,
    courseId: clearCourse ? null : courseId ?? this.courseId,
    source: source,
  );
}
