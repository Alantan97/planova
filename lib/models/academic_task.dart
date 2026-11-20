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
    this.deadline,
    required this.estimatedMinutes,
    this.completedMinutes = 0,
    this.difficulty = TaskDifficulty.moderate,
    this.importance = TaskImportance.medium,
    this.status = TaskStatus.active,
    this.courseId,
    this.source,
    this.assessmentWeightPercent,
  }) : assert(estimatedMinutes > 0),
       assert(completedMinutes >= 0);

  final String id;
  final String title;
  final String subject;
  final String description;

  /// Null means the student has not confirmed a due date yet ("decide
  /// later"). Such tasks stay visible but are not ranked or planned.
  final DateTime? deadline;
  final int estimatedMinutes;
  final int completedMinutes;
  final TaskDifficulty difficulty;
  final TaskImportance importance;
  final TaskStatus status;
  final String? courseId;
  final ProformaSource? source;

  /// User-confirmed task value. Original extracted evidence stays in [source].
  /// Null means unknown; never substitute zero or infer it from importance.
  final double? assessmentWeightPercent;

  double get progress =>
      isCompleted ? 1 : (completedMinutes / estimatedMinutes).clamp(0, 1);
  bool get isCompleted => status == TaskStatus.completed;
  bool get hasDeadline => deadline != null;
  bool isOverdueAt(DateTime now) =>
      !isCompleted && deadline != null && deadline!.isBefore(now);

  /// Earliest due date first; tasks without a due date go last.
  static int byDeadline(AcademicTask a, AcademicTask b) {
    if (a.deadline == null || b.deadline == null) {
      return a.deadline == null ? (b.deadline == null ? 0 : 1) : -1;
    }
    return a.deadline!.compareTo(b.deadline!);
  }

  AcademicTask copyWith({
    String? title,
    String? subject,
    String? description,
    DateTime? deadline,
    bool clearDeadline = false,
    int? estimatedMinutes,
    TaskDifficulty? difficulty,
    TaskImportance? importance,
    TaskStatus? status,
    String? courseId,
    bool clearCourse = false,
    double? assessmentWeightPercent,
    bool clearAssessmentWeight = false,
  }) => AcademicTask(
    id: id,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    description: description ?? this.description,
    deadline: clearDeadline ? null : deadline ?? this.deadline,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    completedMinutes: completedMinutes,
    difficulty: difficulty ?? this.difficulty,
    importance: importance ?? this.importance,
    status: status ?? this.status,
    courseId: clearCourse ? null : courseId ?? this.courseId,
    source: source,
    assessmentWeightPercent: clearAssessmentWeight
        ? null
        : assessmentWeightPercent ?? this.assessmentWeightPercent,
  );
}
