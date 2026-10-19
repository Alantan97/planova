/// Evidence retained with a confirmed record; the original PDF is not stored.
class ProformaSource {
  const ProformaSource({
    required this.fingerprint,
    required this.fileName,
    required this.page,
    required this.rowId,
    required this.excerpt,
    this.assessmentWeight,
  });
  final String fingerprint;
  final String fileName;
  final int page;
  final String rowId;
  final String excerpt;
  final double? assessmentWeight;
}

class AssessmentDraft {
  const AssessmentDraft({required this.title, required this.source});
  final String title;
  final ProformaSource source;
}

class ProformaDraft {
  const ProformaDraft({
    required this.courseCode,
    required this.courseName,
    required this.documentSession,
    required this.courseSource,
    required this.assessments,
    required this.warnings,
  });
  final String? courseCode;
  final String? courseName;
  final String? documentSession;
  final ProformaSource courseSource;
  final List<AssessmentDraft> assessments;
  final List<String> warnings;
}

class ProformaImportResult {
  const ProformaImportResult({
    required this.courseId,
    required this.addedTasks,
    required this.skippedTasks,
  });
  final String courseId;
  final int addedTasks;
  final int skippedTasks;
}
