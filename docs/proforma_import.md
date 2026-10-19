# First proforma import increment

Implemented 20 October 2026. This is local text extraction and template parsing, not trained AI or a general document-understanding system.

## Student flow

1. Tasks -> Courses & semesters -> create a semester if needed.
2. In the target semester, choose Import proforma -> Choose PDF.
3. Review the course code/name and document session. The selected app semester is an explicit choice; document offering-year fields and folder names do not set it.
4. Compare assessment drafts and source excerpts with the PDF. Repeated assessment types retain separate section/row IDs.
5. Select only assessments to turn into tasks. Supply each selected task's exact deadline/time, estimated work remaining in minutes, difficulty, and importance. These are student inputs. Assessment percentage is retained separately as source metadata.
6. Confirm review and save. A course-only import is allowed. Nothing is written on file selection, extraction, or cancellation.

## Supported scope

- A text-based bilingual UPSI Course Pro Forma with a first-page Course Info section and recognized Continuous Assessment / Final Assessment table rows.
- The initial reference is `research/proformas/Sem 7/Konfigurasi/profoma.pdf` (DEQ3093): inspected visually on PDF pages 1 and 9 and exercised with the same PDFium text engine used by the app. Five assessment rows and their weights/page references are checked by a local real-file test.
- Maximum file size 10 MB and maximum page count 40. Extra bytes before a PDF header within the first 4096 bytes are stripped in memory and reported; the source file stays unchanged.
- PDF reading uses pdfrx/PDFium, file selection uses file_picker, and SHA-256 identifies normalized PDF bytes. The reader contract is independent of the parser and review UI.

## Storage and repeat imports

Course/task source metadata includes file name, normalized PDF fingerprint, PDF page, section/row ID, a short text excerpt, and assessment weight where recognized. Original PDFs and full extracted documents are not persisted or uploaded. No Firebase or Python service is called.

Storage schema 3 reads and upgrades task-only schema 1 and academic-record schema 2 atomically. Existing task IDs, fields, relationships, and progress are retained.

A reviewed import is one transaction. A course with the same code in the selected semester is reused without replacing its name or tasks. Reimport recognizes existing rows by course + PDF fingerprint + source row ID, skips them, and preserves manual task edits/completion. Additional unselected rows can be imported later. The same PDF cannot silently create another course code in that semester when an existing course/task still references it. There is no automatic merge of different PDF versions; inspect those drafts carefully.

## Limits and evaluation still needed

- No OCR, encrypted-PDF password workflow, weekly-topic extraction, SLT-to-task-effort conversion, deadline inference, or timetable generation.
- The parser deliberately recognizes complete single-line assessment rows with the inspected numeric columns. Wrapped or rearranged tables may produce incomplete/no drafts. Review remains necessary, even if several rows were recognized.
- No claim is made that the supplied documents represent all three target programmes. Broader template coverage requires manually checked examples and held-out documents.
- Browser/Android runtime testing of the native file chooser remains separate from injected-loader widget tests and real-file PDF extraction tests. Stop and rerun Flutter after adding the plugins.
- Android packaging/device validation remains pending the existing Java configuration issue.

## Verification

Parser tests use small synthetic text fixtures. Repository tests cover atomic rollback, persisted source metadata, repeated import, and preservation of existing task edits/progress. Widget tests cover review validation, deadline entry, cancellation, extraction retry, and reimport. A real PDF test runs only when the local research document is present; that document is not committed or bundled. This is functional evidence, not an extraction accuracy benchmark across the university.

Package references: [pdfrx](https://pub.dev/packages/pdfrx), [file_picker](https://pub.dev/packages/file_picker), [crypto](https://pub.dev/packages/crypto).
