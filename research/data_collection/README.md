# Planova: UPSI data collection pack

Draft v0.1 - 18 October 2026. Prepared for researcher/supervisor review; no form has been published and no participant data has been collected by these templates.

## Confirmed project decisions

- University: Universiti Pendidikan Sultan Idris (UPSI).
- Faculty: Faculty of Computing & Meta-Technology (name supplied by the researcher).
- Intended programmes, using the researcher's supplied names: Software Engineering, Information Technology, Creative Multimedia. Confirm official programme labels before publishing the form.
- Ranking target: students' stated choices of task priority in a recorded planning situation. It is not an objective measure of the academically optimal choice or proof of improved grades.
- Course proforma import is central to the proposed application.
- FYP deadline: early January 2027; exact date pending.

## Start here

1. Read `SOURCE_REVIEW.md` for what the uploaded files can support.
2. Use `GOOGLE_FORM_DRAFT.md` as the copy-ready first-form build specification (question types, required fields, and routing). It adapts `STUDENT_QUESTIONNAIRE.md`. Complete the participant-information placeholders and review wording before distribution.
3. Use `TASK_SNAPSHOT_TEMPLATE.md` for a small supervised collection pilot, then revise unclear questions before scaling.
4. Use `PILOT_PROTOCOL.md` for collection, checking, participant linking, and evaluation separation.

Recommended tools: one Google Form linked to Sheets, or Microsoft Forms with Excel; a spreadsheet for repeated task sets; a PDF reader and reference sheet for document fields. These files are specifications for those tools, not live forms or authored workbooks.

## Three different collections

| Collection | What it contains | What it supports |
| --- | --- | --- |
| Course document reference | PDFs, version information, manually checked fields and source pages | Import development and extraction evaluation |
| Student questionnaire | Study preferences, protected time, activities, planning needs | Requirements and scheduler inputs |
| Task snapshots | Concurrent tasks, features, and student-chosen priorities at a specific time | Ranking research |

Scheduler cases and final usability feedback are separate later collections. A student's preference answers are not automatically task-priority labels. A proforma's assessment weight is not the student's chosen rank.

## Supplied task example

- Task: Exercise 3.
- Subject/course code: DEQ3093.
- Deadline: 21 October 2026, 11:59 PM (Asia/Kuala_Lumpur), using the user's clarified date and earlier supplied time. This is a Wednesday; the initial Friday wording is superseded.
- Time still needed to finish: 30 minutes, explicitly clarified by the user on 18 October 2026. This supersedes the original ambiguous value 1.
- Difficulty: easy.
- Importance: medium.
- Priority relative to other tasks: not supplied.

Use 30 minutes as the current estimate and preserve the original ambiguous value in the correction history. Do not assign a rank. For future participants, ask in plain language: How many more minutes or hours do you think you need to finish this task? Accept Not sure. A single task is useful for wording questions, but is not a useful between-task ranking group on its own.

## Handling research files

Original documents have not been changed. The whole `/research/` directory is excluded from Git so source documents and future responses are not accidentally published. Keep contact/recruitment information separately from participant-coded research records. Do not put this folder into Flutter assets.

No raw participant responses, email addresses, or names belong in source code or the model's predictive features. The proposed repeated collection is participant-coded, not guaranteed fully anonymous, because records can be linked across sessions.
