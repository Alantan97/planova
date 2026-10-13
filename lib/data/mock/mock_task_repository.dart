import '../../models/academic_task.dart';
import '../repositories/task_repository.dart';

class MockTaskRepository implements TaskRepository {
  @override
  final List<AcademicTask> tasks = List.unmodifiable([
    AcademicTask(
      id: 'database',
      title: 'Database assignment',
      subject: 'Database Systems',
      description: 'Design the schema and complete the SQL query exercises.',
      deadline: DateTime(2026, 10, 16, 23, 59),
      estimatedMinutes: 240,
      completedMinutes: 60,
      difficulty: TaskDifficulty.challenging,
      importance: TaskImportance.high,
    ),
    AcademicTask(
      id: 'graphs',
      title: 'Graph revision',
      subject: 'Data Structures',
      description:
          'Revise traversal algorithms and work through practice problems.',
      deadline: DateTime(2026, 10, 19, 9),
      estimatedMinutes: 180,
      completedMinutes: 45,
      difficulty: TaskDifficulty.challenging,
      importance: TaskImportance.high,
    ),
    AcademicTask(
      id: 'math',
      title: 'Integration practice',
      subject: 'Mathematics',
      description: 'Complete the tutorial exercises before the next class.',
      deadline: DateTime(2026, 10, 20, 17),
      estimatedMinutes: 180,
      completedMinutes: 45,
    ),
    AcademicTask(
      id: 'report',
      title: 'Project report outline',
      subject: 'Software Engineering',
      description:
          'Outline the introduction, requirements, and proposed solution.',
      deadline: DateTime(2026, 10, 22, 17),
      estimatedMinutes: 240,
      importance: TaskImportance.high,
    ),
    AcademicTask(
      id: 'networks',
      title: 'Network fundamentals',
      subject: 'Computer Networks',
      description: 'Review the layers and summarize the key concepts.',
      deadline: DateTime(2026, 10, 23, 17),
      estimatedMinutes: 60,
      completedMinutes: 60,
      difficulty: TaskDifficulty.easy,
    ),
  ]);
}
