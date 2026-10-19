import '../../models/academic_course.dart';
import '../repositories/academic_records.dart';
import 'task_codec.dart';
import 'proforma_source_codec.dart';

class AcademicRecordsCodec {
  static Map<String, Object?> encode(AcademicRecords records) {
    records.validate();
    return {
      'schemaVersion': 3,
      'taskData': TaskCodec.encode(records.tasks),
      'semesters': records.semesters
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'startDate': s.startDate.toIso8601String(),
              'endDate': s.endDate.toIso8601String(),
            },
          )
          .toList(),
      'courses': records.courses
          .map(
            (c) => {
              'id': c.id,
              'semesterId': c.semesterId,
              'code': c.code,
              'name': c.name,
              if (c.source != null)
                'source': ProformaSourceCodec.encode(c.source),
            },
          )
          .toList(),
    };
  }

  static AcademicRecords decode(Map<String, Object?> document) {
    // Old tasks retain their IDs, subject text and effort, without guessed courses.
    if (document['schemaVersion'] == 1) {
      return AcademicRecords(tasks: TaskCodec.decode(document));
    }
    if ((document['schemaVersion'] != 2 && document['schemaVersion'] != 3) ||
        document['taskData'] is! Map ||
        document['semesters'] is! List ||
        document['courses'] is! List) {
      throw const FormatException('Unsupported academic storage format.');
    }
    String text(Map value, String key) {
      final result = value[key];
      if (result is! String || result.trim().isEmpty) {
        throw FormatException('Invalid $key.');
      }
      return result;
    }

    DateTime date(Map value, String key) {
      final saved = text(value, key);
      final result = DateTime.tryParse(saved);
      if (result == null || result.toIso8601String() != saved) {
        throw FormatException('Invalid $key.');
      }
      return result;
    }

    Map record(Object? value) {
      if (value is! Map) {
        throw const FormatException('Invalid academic record.');
      }
      return value;
    }

    final records = AcademicRecords(
      tasks: TaskCodec.decode(
        Map<String, Object?>.from(document['taskData'] as Map),
      ),
      semesters: (document['semesters'] as List).map((v) {
        final s = record(v);
        return AcademicSemester(
          id: text(s, 'id'),
          name: text(s, 'name'),
          startDate: date(s, 'startDate'),
          endDate: date(s, 'endDate'),
        );
      }).toList(),
      courses: (document['courses'] as List).map((v) {
        final c = record(v);
        return AcademicCourse(
          id: text(c, 'id'),
          semesterId: text(c, 'semesterId'),
          code: text(c, 'code'),
          name: text(c, 'name'),
          source: ProformaSourceCodec.decode(c['source']),
        );
      }).toList(),
    );
    records.validate();
    return records;
  }
}
