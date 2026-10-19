import '../../models/proforma.dart';

/// Conservative parser for the inspected bilingual UPSI Course Info / SLT template.
/// Only explicit assessment table rows become drafts; no dates or effort are inferred.
class UpsiProformaParser {
  ProformaDraft parse({
    required List<String> pages,
    required String fileName,
    required String fingerprint,
    bool removedPrefix = false,
  }) {
    if (pages.isEmpty || pages.every((p) => p.trim().isEmpty)) {
      throw const FormatException(
        'This PDF has no readable text. Scanned PDFs need OCR, which is not supported yet. You can add the course manually.',
      );
    }
    final normalized = pages
        .map(
          (p) => p
              .replaceAll('\r', '\n')
              .split('\n')
              .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
              .where((l) => l.isNotEmpty)
              .join('\n'),
        )
        .toList();
    final first = normalized.first;
    if (!first.contains('COURSE PRO FORMA') ||
        !first.contains('Maklumat Kursus')) {
      throw const FormatException(
        'This PDF does not match the supported UPSI proforma template. Add the course manually or choose a supported text-based proforma.',
      );
    }
    final info =
        RegExp(
          r'Maklumat Kursus[^\n]*\n(.*?)2\.\s*Sinopsis',
          dotAll: true,
        ).firstMatch(first)?.group(1) ??
        '';
    final code = RegExp(r'Course Code:\s*([A-Z]{2,4}\d{4})\b')
        .firstMatch(info)
        ?.group(1);
    final name = RegExp(
      r'Course Name:\s*(.*?)\s*Kod Kursus:',
      dotAll: true,
    ).firstMatch(info)?.group(1)?.replaceAll('\n', ' ').trim();
    final session = RegExp(r'Semester\s+\d+\s+Sesi\s+\d{4}/\d{4}')
        .firstMatch(first)
        ?.group(0);
    final warnings = <String>[
      'Extraction can miss or misread rows. Compare these drafts with the assessment table in your PDF before confirming.',
      'Exact deadlines and your remaining effort are not inferred. Confirm both for every assessment you select.',
      'Document session and SLT hours are reference information, not your current semester dates or remaining task effort.',
      if (removedPrefix) 'This file contained extra data before its PDF header. Only the embedded PDF was read; the original file was not changed.',
      if (code == null || name == null || name.isEmpty) 'Some course fields were not recognized. Enter or correct them before saving.',
    ];
    final assessments = <AssessmentDraft>[];
    final ids = <String>{};
    String? section;
    for (var p = 0; p < normalized.length; p++) {
      for (final line in normalized[p].split('\n')) {
        if (line.startsWith('Continuous Assessment')) {
          section = 'continuous';
          continue;
        }
        if (line.startsWith('Final Assessment')) {
          section = 'final';
          continue;
        }
        if (line.startsWith('TOTAL') || line.startsWith('GRAND TOTAL')) {
          section = null;
          continue;
        }
        if (section == null) continue;
        // The inspected template puts weight followed by F2F/NF2F/online/SLT numbers.
        final row = RegExp(
          r'^(\d+)\s+(.+?)\s+(\d+(?:\.\d+)?)\s+\d+(?:\.\d+)?\s+\d+(?:\.\d+)?\s+\d+(?:\.\d+)?\s+\d+(?:\.\d+)?$',
        ).firstMatch(line);
        if (row == null) continue;
        final weight = double.parse(row.group(3)!);
        if (weight > 100) continue;
        final rowId = '$section-${row.group(1)}';
        if (!ids.add(rowId)) {
          warnings.add(
            'Repeated assessment row $rowId needs manual checking. It was not imported twice.',
          );
          continue;
        }
        assessments.add(
          AssessmentDraft(
            title: row.group(2)!,
            source: ProformaSource(
              fingerprint: fingerprint,
              fileName: fileName,
              page: p + 1,
              rowId: rowId,
              excerpt: line,
              assessmentWeight: weight,
            ),
          ),
        );
      }
    }
    if (assessments.isEmpty) {
      warnings.add(
        'No complete assessment rows were recognized. You can save the reviewed course and add tasks manually.',
      );
    }
    final courseExcerpt = info.isEmpty ? first : info;
    return ProformaDraft(
      courseCode: code,
      courseName: name,
      documentSession: session,
      courseSource: ProformaSource(
        fingerprint: fingerprint,
        fileName: fileName,
        page: 1,
        rowId: 'course',
        excerpt: courseExcerpt.substring(
          0,
          courseExcerpt.length.clamp(0, 1200),
        ),
      ),
      assessments: List.unmodifiable(assessments),
      warnings: List.unmodifiable(warnings),
    );
  }
}
