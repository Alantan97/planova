import 'dart:typed_data';

import 'package:planova/services/proforma/proforma_import_service.dart';

const coursePage = '''PRO FORMA KURSUS
COURSE PRO FORMA Semester 1 Sesi 2026/2027
1. Maklumat Kursus / Course Info
Nama Kursus:
Course Name: Kursus Contoh / Example Course
Kod Kursus:
Course Code: DEQ3093 Nilai Kredit:
Credit Value: 3
2. Sinopsis / Synopsis
Course description
5. Prasyarat / Prerequisite DES3043
''';
const assessmentPage = '''Continuous Assessment Percentage (%)
Conventional
Online SLT
F2F NF2F
1 Kuiz (Quiz) 15 0 4 4 8
2 Tugasan (Berkumpulan) (Assignment (Group)) 25 0 2 3 5
3 Tugasan (Berkumpulan) (Assignment (Group)) 15 2 8 0 10
4 Persembahan (Presentation) 5 3 2 0 5
TOTAL 60 5 16 7 28
Final Assessment Percentage (%)
Conventional Online SLT
F2F NF2F
1 Peperiksaan Akhir (Final Examination) 40 2 10 0 12
TOTAL 40 2 10 0 12
GRAND TOTAL 120
''';

class FakeTextReader implements ProformaTextReader {
  FakeTextReader(this.pages);
  final List<String> pages;
  Uint8List? received;
  @override
  Future<List<String>> read(Uint8List bytes) async {
    received = bytes;
    return pages;
  }
}
