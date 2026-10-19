# Uploaded document review

Reviewed 18 October 2026. This is an initial extraction-feasibility review, not a validated production importer or a fully annotated dataset.

## Inventory and inspection scope

- 19 course proformas across the supplied Sem 1–7 folders.
- One academic calendar for undergraduate session 2026/2027.
- One additional Timetable.pdf was inventoried but not used in this review or treated as a course proforma.
- The 20 reviewed documents contain 172 PDF pages. All pages produced non-empty text during extraction after handling leading non-PDF bytes where necessary. Non-empty text alone does not prove table accuracy.
- Visual checks covered the calendar's first PDF page, DEP3053's course/assessment pages, and DEQ3093's course/assessment pages. Other documents were checked through text extraction and metadata, not every table visually.
- Six proformas contain 590 or 643 bytes of HTML before the embedded PDF header. Review used an in-memory view beginning at the PDF header; original files were not edited. Future import should detect and report such files rather than assume every .pdf starts with valid PDF bytes.

See `SOURCE_INVENTORY.md` for the course-by-course extraction inventory. Temporary extracted text/images are under `.dart_tool/research_review/`, not the app assets.

## Representative source: DEQ3093

Path: `research/proformas/Sem 7/Konfigurasi/profoma.pdf`.

- PDF page 1: DEQ3093, Pengurusan Konfigurasi Perisian / Software Configuration Management; 3 credits; header Semester 1 Sesi 2026/2027; footer A261 Version 1.
- PDF page 1 also has a recommended course-offering semester/year. This is not the same field as the document's academic session or the student's actual current semester. The Sem 7 folder is an organizational label, not evidence that every internal semester field equals 7.
- PDF page 4 identifies the content table's leading column as Week; following pages contain the week/topic rows and distinct guided/independent workload columns.
- PDF page 9: continuous assessments are Quiz 15%, Group Assignment 25%, another Group Assignment 15%, Presentation 5%; total 60%. Final Examination is 40%. The course grand-total SLT is 120 hours.

Two separate group-assignment rows must retain separate assessment IDs even though their type labels match. Do not merge them, sum their weight into one task, or infer which row corresponds to a student-entered exercise.

SLT and assessment-preparation allocations are curriculum-level quantities, not a direct measurement of a particular student's remaining work. The 120-hour course total includes different activities; do not schedule it all as additional independent study.

## Representative source: DEP3053

Path: `research/proformas/Sem 2/DEP3053/profoma dep.pdf`.

- PDF page 1: DEP3053, Introduction to Psychology for Computing; document header Semester 2 Sesi 2023/2024, A232 Version 1.
- PDF page 8: two separate individual assignments of 30% each, Presentation 4%, Project 36%; total 100%. The assessment table separates conventional F2F/NF2F, online, and SLT values.

These historical sources are useful for extraction development, but do not establish this semester's lecturer-announced deadlines or unchanged assessment arrangements.

## Academic calendar reference

Path: `research/Kalendar-Akademik-Sesi-2026_2027-Program-Sarjana-Muda.pdf`.

PDF page 1 (printed page 4), Semester 1 A261:

| Calendar item | Stated dates |
| --- | --- |
| Teaching week 1 | 28 September–4 October 2026 |
| Teaching week 7 | 9–15 November 2026 |
| Mid-semester break | 16–22 November 2026 |
| Teaching week 8 | 23–29 November 2026 |
| Teaching week 14 | 4–10 January 2027 |
| Revision week | 11–17 January 2027 |
| Examination period | 18 January–7 February 2027 |

Therefore week numbers must be mapped using explicit teaching-week ranges, not simply semester start plus seven days per week. A teaching-week interval is not an exact task deadline. Holidays or a teaching break do not automatically establish personal study availability or imply the FYP submission date.

## Initial fields worth extracting

| Field | Expected source | Confirmation needed |
| --- | --- | --- |
| Course code and bilingual name | Course Info | Resolve parsing errors; retain both language values |
| Document session, version, draft status | Header/footer | Keep separate from student's semester and current assessment arrangements |
| Credit value | Course Info | Useful metadata; not a student's remaining task effort |
| Week and topic | Content/SLT table | Check row boundaries, repeated headers, multi-page rows and academic calendar |
| Assessment type, row identity and weight | Assessment tables | Distinguish repeated types and component versus aggregate weights |
| Independent-learning allocations | Specific SLT columns | Preserve units and activity category; avoid double-counting |
| Exact deadline | Only explicit assessment/date evidence or student confirmation | Missing remains missing; do not derive from generic week/topic text |

## Document reference-sheet specification

Use one row per checked field, assessment row, or topic row. Include:

`document_id`, `relative_source_path`, `document_session`, `document_version`, `course_code`, `source_pdf_page`, `section_or_table`, `source_row_id`, `field_name`, `raw_text`, `verified_value`, `unit`, `verification_method`, `verified_by_code`, `verified_at`, `notes`.

Verification method should distinguish visual/manual checking from unverified machine extraction. An ID or table label is bookkeeping, not a predictive feature. Unknown values stay blank with an explicit status, not fabricated zeroes.

Example reference records verified against rendered DEQ3093 pages:

| Source page | Source row ID | Field | Verified value | Unit |
| --- | --- | --- | --- | --- |
| 1 | course | course_code | DEQ3093 | code |
| 1 | course | credit_value | 3 | credits |
| 9 | continuous-1 | assessment_weight | 15 | percent |
| 9 | continuous-2 | assessment_weight | 25 | percent |
| 9 | continuous-3 | assessment_weight | 15 | percent |
| 9 | continuous-4 | assessment_weight | 5 | percent |
| 9 | final-1 | assessment_weight | 40 | percent |

## Limits and next checks

The uploaded course set has not been established as representative of all three target programmes. Obtain examples from Information Technology and Creative Multimedia if their templates or assessment structures differ; verify programme ownership rather than infer it from a course code.

The collection pack is an English draft. Validate language and labels with the supervisor and a small participant pilot. No exact participant count has been declared sufficient for model training or final evaluation.
