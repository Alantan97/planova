# Proforma import

Implemented 20 October 2026. This is local text extraction and template parsing, not trained AI or a general document-understanding system.

## Student flow

1. Tasks -> Courses & semesters -> create a semester if needed.
2. In the target semester, choose Import proforma -> Choose PDF.
3. Review the course code/name and document session. The selected app semester is an explicit choice; document offering-year fields and folder names do not set it.
   With **Profile → Experimental features** on, choose **View weekly learning**, expand an entry and choose **Edit entry** to correct its week, topic or planned hours. **Use changes** updates the review; **Use reviewed entries** returns to the import. Nothing is persisted until the final import save.
4. Compare assessment drafts and source excerpts with the PDF. Repeated assessment types retain separate section/row IDs.
5. Every new assessment starts selected; untick any to skip. Each selected task needs only a time estimate. Where the proforma prints the assessment's total SLT hours, that value is pre-filled as a labelled suggestion (hours × 60 minutes) that the student can change. A due date is optional ("Decide later"): proformas do not print assessment dates, so none is inferred, and a task without a due date is saved, shown as "No due date yet", and excluded from ranking until one is added. Title and grade weight are pre-filled and can be corrected under "Edit title or grade weight"; the confirmed percentage is saved separately from original source metadata. Difficulty and importance are no longer asked during import (they keep their defaults and remain editable under More details in the task form).
6. Confirm review and save. A course-only import is allowed. Nothing is written on file selection, extraction, or cancellation.
7. Return to Tasks and open Prioritize tasks for experimental on-device ranking. A confirmed percentage, future deadline and positive work remaining are required. See `docs/task_ranking.md`. Ranking does not replace PDF review or generate a timetable.

## Supported scope

- A text-based bilingual UPSI Course Pro Forma with a first-page Course Info section and recognized Continuous Assessment / Final Assessment table rows.
- The initial reference is `research/proformas/Sem 7/Konfigurasi/profoma.pdf` (DEQ3093): inspected visually on PDF pages 1 and 9 and exercised with the same PDFium text engine used by the app. Five assessment rows and their weights/page references are checked by a local real-file test.
- Maximum file size 10 MB and maximum page count 40. Extra bytes before a PDF header within the first 4096 bytes are stripped in memory and reported; the source file stays unchanged.
- PDF reading uses pdfrx/PDFium, file selection uses file_picker, and SHA-256 identifies normalized PDF bytes. The reader contract is independent of the parser and review UI.

## Storage and repeat imports

Course/task source metadata includes file name, normalized PDF fingerprint, PDF page, section/row ID, a short text excerpt, and assessment weight where recognized. Original PDFs and full extracted documents are not persisted or uploaded. No Firebase or Python service is called.

Storage schema 4 reads and upgrades schemas 1, 2 and 3 atomically. Existing task IDs, fields, relationships, source evidence and progress are retained. Older courses start with no weekly entries; none are invented during migration.

A reviewed import is one transaction. A course with the same code in the selected semester is reused without replacing its name or tasks. Reimport recognizes existing rows by course + PDF fingerprint + source row ID, skips them, and preserves manual task edits/completion. Additional unselected rows can be imported later. The same PDF cannot silently create another course code in that semester when an existing course/task still references it. There is no automatic merge of different PDF versions; inspect those drafts carefully.

## Limits and evaluation still needed

- No OCR, encrypted-PDF password workflow, deadline inference, or timetable generation. Printed assessment SLT hours are used only as an editable effort suggestion.
- The production reader retains PDF word positions. Assessment extraction locates the explicit Percentage header and reads a single numeric value in that column, so blank hour cells do not shift the assessment weight. The total SLT hours are read the same way: only a single number inside the SLT header's column counts, otherwise the suggestion stays empty. Checked against all 19 local proformas: 79 of 79 assessments matched their printed SLT value. Other hour columns are not imported. Text-only injected readers retain the original complete-row fallback; a failed layout match never falls back to guessing numeric columns. Wrapped or rearranged tables may still produce incomplete/no drafts. Review remains necessary.
- No claim is made that the supplied documents represent all three target programmes. Broader template coverage requires manually checked examples and held-out documents.
- Browser/Android runtime testing of the native file chooser remains separate from injected-loader widget tests and real-file PDF extraction tests. Stop and rerun Flutter after adding the plugins.
- Android packaging/device validation remains pending the existing Java configuration issue.

## Verification

Parser tests use small synthetic text fixtures. Repository tests cover atomic rollback, persisted source metadata, repeated import, and preservation of existing task edits/progress. Widget tests cover review validation, deadline entry, cancellation, extraction retry, and reimport. A real PDF test runs only when the local research document is present; that document is not committed or bundled. This is functional evidence, not an extraction accuracy benchmark across the university.

### Local comparison against the reviewed dataset

Added 20 November 2026. The optional dataset evaluation exercises the production
`PdfrxProformaTextReader` and `ProformaImportService` on the active local PDFs.
References come from the verified course and assessment CSVs, not the parser's own
predictions. Nothing is saved to the student's app database.

From the project root, run these commands separately:

```powershell
python tool/prepare_proforma_evaluation.py
flutter test test/services/proforma/proforma_dataset_evaluation_test.dart
```

The preparer requires verified records, valid document links, distinct assessment
row identities, weights totalling 100%, and source PDFs under
`research/proformas/`. It writes `research/evaluation/proforma_import/reference.json`.
The test checks source and dataset fingerprints before evaluation and records the
parser/service fingerprints. Regenerate references after reviewing dataset or PDF
changes; do not replace expected values with parser output to improve a score.

Results are local and Git-ignored:

- `research/evaluation/proforma_import/RESULTS.md`: readable per-course results.
- `research/evaluation/proforma_import/results.json`: field differences, missed
  rows, extra row identities, source pages, warnings and fingerprints.

An exact assessment has the correct source row ID, name, percentage and PDF page.
An exact document also has matching course code/name/session, every expected
assessment, and no extra assessment identities. Comparison normalizes whitespace
only; mismatched names or weights are not accepted just because counts match.

The initial text-only baseline against 17 reviewed PDFs recognized all 17 course
metadata records and 44 of 70 assessments exactly, with nine complete documents.
It missed rows in DEP3053, DTS3013, KPP3014, UBM3262, DEP3023, BPK3112, DES3073 and
DES3113 because it required all four numeric hour columns on one line.

The position-based improvement now matches **17/17 complete documents and 70/70
assessments** against the same reviewed references. The parser reads the printed
percentage independently of blank hour columns, carries a recognized section
across a page break, resets at TOTAL, and preserves section/row IDs and PDF page
references. Regression tests reject missing, ambiguous and out-of-range
percentages even when another hour value is present. This result covers these
known local documents only, not arbitrary unseen proformas.

By default, this test generates a baseline report even when extraction is
incomplete. A passing test means report generation and integrity checks succeeded;
it does not mean 100% extraction accuracy. To require every document to match:

```powershell
flutter test --dart-define=PLANOVA_REQUIRE_EXACT_PROFORMA=true test/services/proforma/proforma_dataset_evaluation_test.dart
```

That strict gate failed on the initial baseline and passes with the position-based
reader. The dataset test is skipped when
the local reference file is absent, so private PDFs and research CSVs need not be
committed. This is an evaluation of known supplied course/assessment templates,
not held-out accuracy, weekly NF2F/Online extraction, trained AI, or native file
chooser/device validation. Weekly topic and NF2F/Online workload extraction is a
separate evaluation described below; this change does not create study sessions or retrain ranking.

## Weekly learning review and storage

Requires **Profile → Experimental features** (off by default) since 22 November 2026. With the switch off, weekly rows are still read and saved with the import but not shown; nothing in planning uses them yet.

The importer also recognizes the inspected UPSI weekly table using the Week, CLO,
F2F, NF2F, Online and SLT header positions. It preserves PDF reading order to collect
the full topic/subtopics and associated values across continuation pages. A recognized
TOTAL or assessment heading ends weekly extraction. Unknown header layouts or
ambiguous/invalid numeric cells are skipped rather than guessed.

The Course review step links to a weekly editor with expandable entries, full
topics, two conventional NF2F values, four Online values, SLT and PDF source
evidence. A single black summary panel and ordinary light entry cards follow the
existing design. Each entry can be corrected through its own form. Week ranges
must be 1-30 with end on/after start, topics cannot be empty, and hours must be
finite and non-negative. NF2F/SLT may remain unknown. Online fields start at zero
for source blanks and require explicit hours or zero when edited.

Final import saves reviewed weekly entries in the same transaction as the course
and selected tasks. The confirmation shows the number of new weekly entries.
Each saved record retains both its printed values and confirmed values, including
the original raw blanks, printed week label/topic, page and source row identity.
**Courses & semesters → Weekly learning** reopens the saved data. Edits are staged
until **Save changes**; Back discards unsaved changes. Source evidence cannot be
edited through the form or replaced through the weekly-update repository method.

Repeat import identifies entries by course + PDF fingerprint + weekly source row
ID, keeps existing corrections, and adds only missing rows from the same PDF.
Already saved rows are locked in the import review; edit them from the course.
If a course already has weekly rows from a different PDF version, its saved rows
are kept and incoming weekly rows are skipped, with an explanation before save.
There is no automatic document-version replacement. Course metadata edits preserve
weekly data; deleting a course without tasks also deletes its contained weekly
entries, as stated in the deletion confirmation.

Storage regressions cover restart persistence, schema-3 migration, unknown versus
zero values, separate activities in the same week, repeat imports, different PDF
versions, original evidence preservation and rollback on invalid updates. Widget
tests cover review/edit/final-save/reopen flow and hour validation.

- Blank conventional NF2F values stay unknown. Four blank Online cells retain
  their raw blanks and display zero under the user-confirmed UPSI format policy.
- Combined week ranges retain their original total hours; hours are not multiplied
  by range length. Distinct activities in the same week are not deduplicated.
- Repeated source week labels are flagged. Corrections made to individual research
  PDFs (UBM3262/DEP3023) are not silently applied to arbitrary app uploads.
- Text cleaning joins whitespace, expands common Latin ligatures, normalizes
  fullwidth ASCII/punctuation spacing and joins line-break hyphens. Source words
  are retained. CLO tick marks are excluded from topics.
- Hours are planned course workload. SLT includes F2F and other components and
  must not be added to those components as extra study time.

The optional weekly evaluation matches **235/235 source rows across 17 local PDFs**,
including full normalized topics, printed week ranges, source pages and all seven
collected hour values. The source verification log preserves original blanks and
labels where the cleaned CSV contains an authorized interpretation or correction;
the local reference generator uses that evidence for source-level comparison.
Dataset, source PDF and review fingerprints are checked. Results remain evidence
for these known supplied documents, not unseen-format accuracy or independent
human approval of an uploaded document.

```powershell
python tool/prepare_proforma_evaluation.py
flutter test --dart-define=PLANOVA_REQUIRE_EXACT_WEEKLY=true test/services/proforma/proforma_weekly_evaluation_test.dart
```

Weekly results are saved under `research/evaluation/proforma_import/` as
`WEEKLY_RESULTS.md` and `weekly_results.json`. Regenerate local references before
running the new weekly test if references were created by the earlier preparer.

Package references: [pdfrx](https://pub.dev/packages/pdfrx), [file_picker](https://pub.dev/packages/file_picker), [crypto](https://pub.dev/packages/crypto).
