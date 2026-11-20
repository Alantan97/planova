import 'package:flutter_test/flutter_test.dart';
import 'package:planova/models/proforma.dart';
import 'package:planova/services/proforma/upsi_weekly_layout.dart';

ProformaTextWord word(String text, double x, {double y = 500}) =>
    ProformaTextWord(
      text: text,
      left: x,
      right: x + text.length * 5,
      top: y + 5,
      bottom: y - 5,
    );

List<ProformaTextWord> header() => [
  // PDF reading order keeps these headings after Week in the real table.
  word('Week', 40),
  word('Course', 100),
  word('Content', 140),
  word('Outline', 180),
  word('Conventional', 300),
  word('Online', 520),
  word('Material', 540),
  word('Activities', 620),
  word('CLO1', 260),
  word('L', 300),
  word('T', 320),
  word('P', 340),
  word('O', 360),
  word('(NF2F)', 400),
  word('(NF2F)', 460),
  for (final x in [520.0, 560.0, 600.0, 640.0]) word('Guided', x),
  word('SLT', 680),
];

List<ProformaTextWord> row(
  String week, {
  bool unknown = false,
  String? invalid,
}) => [
  word(week, 42),
  word('Continuous', 72),
  word('learning', 130),
  word('Topic', 72),
  word('details', 110),
  word('✔', 260),
  word('2', 300),
  word('0', 320),
  word('0', 340),
  word('0', 360),
  if (!unknown) word(invalid ?? '1', 415),
  if (!unknown) word('2', 475),
  word('5', 685),
];

List<WeeklyLearningDraft> read(List<List<ProformaTextWord>> pages) =>
    UpsiWeeklyLayout().read(pages, fingerprint: 'pdf', fileName: 'course.pdf');

void main() {
  test('Preserves full topics, blank NF2F and raw blank Online cells', () {
    final actual = read([
      [...header(), ...row('1', unknown: true)],
    ]).single;
    expect(actual.topic, 'Continuous learning Topic details');
    expect(actual.guidedNf2fHours, isNull);
    expect(actual.independentNf2fHours, isNull);
    expect(actual.onlineHours, [null, null, null, null]);
    expect(actual.interpretedOnlineHours, 0);
    expect(actual.totalSltHours, 5);
  });
  test('Keeps source week ranges and separate activities in the same week', () {
    final actual = read([
      [...header(), ...row('3–4'), ...row('3–4')],
    ]);
    expect(actual.length, 2);
    expect(actual.first.weekStart, 3);
    expect(actual.first.weekEnd, 4);
    expect(actual.first.source.rowId, isNot(actual.last.source.rowId));
  });
  test('Header-only page carries columns to continuation; TOTAL ends rows', () {
    final actual = read([
      header(),
      [...row('1'), word('TOTAL', 250), ...row('2')],
    ]);
    expect(actual.length, 1);
    expect(actual.single.source.page, 2);
  });
  test('Spaced week ranges remain one source entry', () {
    final original = row('3–4');
    final actual = read([
      [
        ...header(),
        word('3', 40),
        word('-', 47),
        word('4', 54),
        ...original.skip(1),
      ],
    ]);
    expect(actual.length, 1);
    expect(actual.single.weekStart, 3);
    expect(actual.single.weekEnd, 4);
    expect(actual.single.topic, 'Continuous learning Topic details');
  });
  test(
    'Rejects unknown headers and invalid numeric cells without inventing zero',
    () {
      expect(
        read([
          [...header().where((w) => w.text != '(NF2F)'), ...row('1')],
        ]),
        isEmpty,
      );
      expect(
        read([
          [...header(), ...row('1', invalid: 'bad')],
        ]),
        isEmpty,
      );
      expect(
        read([
          [...header(), ...row('1', invalid: '-1')],
        ]),
        isEmpty,
      );
    },
  );
}
