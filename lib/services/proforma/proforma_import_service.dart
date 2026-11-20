import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/proforma.dart';
import 'upsi_proforma_parser.dart';

abstract interface class ProformaTextReader {
  Future<List<String>> read(Uint8List bytes);
}

class ProformaDocumentText {
  const ProformaDocumentText({required this.pages, required this.words});
  final List<String> pages;
  final List<List<ProformaTextWord>> words;
}

abstract interface class ProformaLayoutReader implements ProformaTextReader {
  Future<ProformaDocumentText> readLayout(Uint8List bytes);
}

class PdfrxProformaTextReader implements ProformaLayoutReader {
  PdfrxProformaTextReader({Future<void> Function()? initialize})
    : _initialize = initialize ?? pdfrxFlutterInitialize;
  final Future<void> Function() _initialize;
  @override
  Future<List<String>> read(Uint8List bytes) async {
    return (await readLayout(bytes)).pages;
  }

  @override
  Future<ProformaDocumentText> readLayout(Uint8List bytes) async {
    await _initialize();
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'planova-local-proforma',
    );
    try {
      if (document.pages.length > 40) {
        throw const FormatException('Choose a proforma with at most 40 pages.');
      }
      final pages = <String>[];
      final words = <List<ProformaTextWord>>[];
      for (final page in document.pages) {
        final text = await page.loadText();
        pages.add(text?.fullText ?? '');
        final pageWords = <ProformaTextWord>[];
        if (text != null) {
          for (final match in RegExp(r'\S+').allMatches(text.fullText)) {
            final rects = text.charRects
                .sublist(match.start, match.end)
                .where((r) => r.isNotEmpty);
            if (rects.isEmpty) continue;
            final box = rects.reduce((a, b) => a.merge(b));
            pageWords.add(
              ProformaTextWord(
                text: match.group(0)!,
                left: box.left,
                right: box.right,
                top: box.top,
                bottom: box.bottom,
              ),
            );
          }
        }
        words.add(pageWords);
      }
      return ProformaDocumentText(pages: pages, words: words);
    } finally {
      await document.dispose();
    }
  }
}

class ProformaImportService {
  ProformaImportService({ProformaTextReader? reader})
    : _reader = reader ?? PdfrxProformaTextReader();
  final ProformaTextReader _reader;
  static const maximumBytes = 10 * 1024 * 1024;

  Future<ProformaDraft?> pickAndExtract() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Choose a UPSI course proforma',
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > maximumBytes) {
      throw const FormatException('Choose a PDF smaller than 10 MB.');
    }
    return extract(await file.readAsBytes(), fileName: file.name);
  }

  Future<ProformaDraft> extract(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw const FormatException('Choose a non-empty PDF smaller than 10 MB.');
    }
    final header = String.fromCharCodes(bytes.take(4096)).indexOf('%PDF-');
    if (header < 0) {
      throw const FormatException(
        'This file does not contain a readable PDF header. Choose another PDF.',
      );
    }
    final pdf = Uint8List.sublistView(bytes, header);
    List<String> pages;
    List<List<ProformaTextWord>>? words;
    try {
      final reader = _reader;
      if (reader is ProformaLayoutReader) {
        final document = await reader.readLayout(pdf);
        pages = document.pages;
        words = document.words;
      } else {
        pages = await reader.read(pdf);
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Could not read this PDF. It may be damaged or password-protected. Try another file or add the course manually.',
      );
    }
    return UpsiProformaParser().parse(
      pages: pages,
      fileName: fileName,
      fingerprint: sha256.convert(pdf).toString(),
      removedPrefix: header > 0,
      pageWords: words,
    );
  }
}
