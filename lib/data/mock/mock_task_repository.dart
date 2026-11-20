import '../../models/academic_task.dart';
import '../../models/academic_course.dart';
import '../repositories/academic_records.dart';
import '../../models/proforma.dart';
import '../repositories/task_repository.dart';

class MockTaskRepository extends TaskRepository {
  @override
  List<AcademicTask> get tasks => List.unmodifiable(_tasks);
  final List<AcademicTask> _tasks = [
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
      status: TaskStatus.completed,
    ),
  ];

  List<AcademicSemester> _semesters = [];
  List<AcademicCourse> _courses = [];
  @override
  List<AcademicSemester> get semesters => List.unmodifiable(_semesters);
  @override
  List<AcademicCourse> get courses => List.unmodifiable(_courses);
  Future<T> _catalogChange<T>(T Function(AcademicRecords) change) async {
    final records = AcademicRecords(
      tasks: _tasks,
      semesters: _semesters,
      courses: _courses,
    );
    final result = change(records);
    records.validate();
    _tasks
      ..clear()
      ..addAll(records.tasks);
    _semesters = records.semesters;
    _courses = records.courses;
    notifyListeners();
    return result;
  }

  @override
  Future<void> saveSemester(AcademicSemester semester, {required bool isNew}) =>
      _catalogChange((r) => r.saveSemester(semester, isNew: isNew));
  @override
  Future<ProformaImportResult> importProforma(
    AcademicCourse course,
    List<AcademicTask> tasks,
  ) => _catalogChange((r) => r.importProforma(course, tasks));
  @override
  Future<void> saveCourse(AcademicCourse course, {required bool isNew}) =>
      _catalogChange((r) => r.saveCourse(course, isNew: isNew));
  @override
  Future<void> saveWeeklyLearning(
    String courseId,
    List<ReviewedWeeklyLearning> rows,
  ) => _catalogChange((r) => r.saveWeeklyLearning(courseId, rows));
  @override
  Future<void> deleteSemester(String id) =>
      _catalogChange((r) => r.deleteSemester(id));
  @override
  Future<void> deleteCourse(String id) =>
      _catalogChange((r) => r.deleteCourse(id));

  void _validate(AcademicTask task) {
    final weight = task.assessmentWeightPercent;
    if (weight != null && (!weight.isFinite || weight < 0 || weight > 100)) {
      throw const FormatException(
        'Enter an assessment percentage from 0 to 100.',
      );
    }
    if (task.courseId != null && courseById(task.courseId) == null) {
      throw const FormatException('The selected course no longer exists.');
    }
    if (task.title.trim().isEmpty ||
        task.subject.trim().isEmpty ||
        task.estimatedMinutes <= 0 ||
        task.estimatedMinutes < task.completedMinutes) {
      throw ArgumentError(
        'Enter a title, subject, and valid estimated duration.',
      );
    }
  }

  @override
  Future<void> add(AcademicTask task) async {
    _validate(task);
    final course = courseById(task.courseId);
    if (course != null) task = task.copyWith(subject: course.label);
    if (taskById(task.id) != null) {
      throw StateError('This task already exists.');
    }
    _tasks.add(task);
    notifyListeners();
  }

  @override
  Future<void> update(AcademicTask task) async {
    _validate(task);
    final course = courseById(task.courseId);
    if (course != null) task = task.copyWith(subject: course.label);
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) throw StateError('This task no longer exists.');
    _tasks[index] = task;
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  @override
  Future<void> setCompleted(String id, bool completed) async {
    final task = taskById(id);
    if (task == null) throw StateError('This task no longer exists.');
    await update(
      task.copyWith(
        status: completed ? TaskStatus.completed : TaskStatus.active,
      ),
    );
  }
}
