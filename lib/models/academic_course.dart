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
  });
  final String id;
  final String semesterId;
  final String code;
  final String name;
  final ProformaSource? source;
  String get label => '$code · $name';
}
