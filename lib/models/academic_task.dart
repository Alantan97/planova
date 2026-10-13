enum TaskDifficulty { easy, moderate, challenging }

enum TaskImportance { low, medium, high }

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

  double get progress => (completedMinutes / estimatedMinutes).clamp(0, 1);
  bool get isCompleted => completedMinutes >= estimatedMinutes;
}
