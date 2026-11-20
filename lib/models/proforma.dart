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
  const AssessmentDraft({
    required this.title,
    required this.source,
    this.sltHours,
  });
  final String title;
  final ProformaSource source;

  /// Total student learning time printed for this assessment (SLT column),
  /// used only to suggest effort. Null when not printed or not readable.
  final double? sltHours;
}

class ProformaDraft {
  const ProformaDraft({
    required this.courseCode,
    required this.courseName,
    required this.documentSession,
    required this.courseSource,
    required this.assessments,
    required this.warnings,
    this.weeklyLearning = const [],
  });
  final String? courseCode;
  final String? courseName;
  final String? documentSession;
  final ProformaSource courseSource;
  final List<AssessmentDraft> assessments;
  final List<String> warnings;
  final List<WeeklyLearningDraft> weeklyLearning;
}

/// Printed workload reference, not a task or a student's remaining effort.
class WeeklyLearningDraft {
  const WeeklyLearningDraft({
    required this.weekStart,
    required this.weekEnd,
    required this.topic,
    required this.guidedNf2fHours,
    required this.independentNf2fHours,
    required this.onlineHours,
    required this.totalSltHours,
    required this.source,
  }) : assert(onlineHours.length == 4);
  final int weekStart;
  final int weekEnd;
  final String topic;
  final double? guidedNf2fHours;
  final double? independentNf2fHours;

  /// Material guided/non-guided, then activity guided/non-guided. Null = printed blank.
  final List<double?> onlineHours;
  final double? totalSltHours;
  final ProformaSource source;
  double get interpretedOnlineHours =>
      onlineHours.fold(0, (sum, value) => sum + (value ?? 0));
  String get weekLabel =>
      weekStart == weekEnd ? 'Week $weekStart' : 'Weeks $weekStart–$weekEnd';

  WeeklyLearningDraft withOnlineZeros() => WeeklyLearningDraft(
    weekStart: weekStart,
    weekEnd: weekEnd,
    topic: topic,
    guidedNf2fHours: guidedNf2fHours,
    independentNf2fHours: independentNf2fHours,
    onlineHours: List.unmodifiable(onlineHours.map((value) => value ?? 0.0)),
    totalSltHours: totalSltHours,
    source: source,
  );
}

/// Original printed evidence and student-reviewed workload are kept separately.
class ReviewedWeeklyLearning {
  const ReviewedWeeklyLearning({
    required this.printed,
    required this.confirmed,
  });
  final WeeklyLearningDraft printed;
  final WeeklyLearningDraft confirmed;
  String get identity =>
      '${printed.source.fingerprint}/${printed.source.rowId}';
  void validate() {
    for (final row in [printed, confirmed]) {
      if (row.weekStart < 1 ||
          row.weekEnd < row.weekStart ||
          row.weekEnd > 30 ||
          row.topic.trim().isEmpty ||
          row.onlineHours.length != 4 ||
          [
            row.guidedNf2fHours,
            row.independentNf2fHours,
            ...row.onlineHours,
            row.totalSltHours,
          ].any((v) => v != null && (!v.isFinite || v < 0))) {
        throw const FormatException('Invalid weekly learning values.');
      }
      final source = row.source;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(source.fingerprint) ||
          !source.rowId.startsWith('weekly-') ||
          source.page < 1 ||
          source.fileName.trim().isEmpty ||
          source.excerpt.trim().isEmpty) {
        throw const FormatException('Invalid weekly learning source.');
      }
    }
    final a = printed.source;
    final b = confirmed.source;
    if (a.fingerprint != b.fingerprint ||
        a.rowId != b.rowId ||
        a.page != b.page ||
        a.fileName != b.fileName ||
        a.excerpt != b.excerpt ||
        a.assessmentWeight != b.assessmentWeight) {
      throw const FormatException('Weekly source evidence cannot be changed.');
    }
  }
}

class ProformaImportResult {
  const ProformaImportResult({
    required this.courseId,
    required this.addedTasks,
    required this.skippedTasks,
    this.addedWeeklyEntries = 0,
    this.skippedWeeklyEntries = 0,
  });
  final String courseId;
  final int addedTasks;
  final int skippedTasks;
  final int addedWeeklyEntries;
  final int skippedWeeklyEntries;
}

/// A word and its bounds in PDF coordinates (origin at the bottom left).
class ProformaTextWord {
  const ProformaTextWord({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
  double get centerY => (top + bottom) / 2;
}
