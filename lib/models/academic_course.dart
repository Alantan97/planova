import 'proforma.dart';

class AcademicSemester {
  const AcademicSemester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
}

class AcademicCourse {
  const AcademicCourse({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    this.source,
    this.weeklyLearning = const [],
  });
  final String id;
  final String semesterId;
  final String code;
  final String name;
  final ProformaSource? source;
  final List<ReviewedWeeklyLearning> weeklyLearning;
  AcademicCourse withWeeklyLearning(List<ReviewedWeeklyLearning> rows) =>
      AcademicCourse(
        id: id,
        semesterId: semesterId,
        code: code,
        name: name,
        source: source,
        weeklyLearning: List.unmodifiable(rows),
      );
  String get label => '$code · $name';
}
