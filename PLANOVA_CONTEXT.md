# Planova – Project Context

## 1. Project Overview

**Project Name:** Planova

**Project Title:** AI-Powered Adaptive Study Planner

**Project Type:** Final Year Project (FYP), mobile application

**Target Users:** University students

Initial local target: Universiti Pendidikan Sultan Idris (UPSI) undergraduates in Software Engineering, Information Technology, and Creative Multimedia, using the student's supplied programme names. Official programme labels and coverage should be confirmed before research distribution.
Faculty: Faculty of Computing & Meta-Technology, as supplied by the student.

**Primary Platform:** Android, with potential future iOS support

**Framework:** Flutter (Dart)

Planova is an AI-powered mobile study planner designed to help university students manage academic responsibilities more effectively.

Unlike basic task management applications, Planova aims to automatically prioritize academic tasks, generate personalized study schedules, and adjust those schedules when students miss planned activities.

## 2. Problem Statement

University students often face three challenges:

1. Poor time management when handling multiple academic commitments.
2. Difficulty deciding which assignments, quizzes, or revision activities to prioritize.
3. Traditional planning applications often require users to manually reorganize their schedules when plans change.

Planova aims to address these challenges through intelligent task prioritization and adaptive scheduling.

## 3. Project Objectives

1. Identify suitable approaches for academic task prioritization and adaptive time management.
2. Develop an AI-powered study planner that prioritizes tasks and adjusts study schedules based on student progress.
3. Test and evaluate the functionality of the developed application.

## 4. Core Features

### Task Management
- Create, view, update, and delete academic tasks.
- Enter task title, description, deadline, difficulty, importance, and estimated duration.
- Track task status and completion progress.

### AI Task Prioritization
- Rank tasks based on their characteristics.
- Help students understand which tasks should receive attention first.
- Intended algorithm: LambdaMART (Learning-to-Rank).

### Adaptive Study Scheduling
- Generate study sessions based on task rankings, available study hours, deadlines, and estimated durations.
- Adjust future study sessions when planned sessions are missed or progress changes.
- Intended algorithm: Genetic Algorithm (GA).

### Calendar and Study Planner
- Display scheduled study sessions.
- Provide daily and weekly calendar views.
- Allow students to inspect upcoming activities.

### Dashboard
- Show academic workload, upcoming deadlines, completed tasks, and study progress.
- Provide an overview of planned activities.

### Notifications
- Remind students about upcoming study sessions and deadlines.

### Analytics
- Visualize task completion and study productivity.

## 5. Intended AI Architecture

**LambdaMART:** Ranks tasks according to their relative priority. The ranking model will require suitable task-level training data and relevance labels.

**Genetic Algorithm:** Searches for effective study schedules based on task priorities, deadlines, available study time, and scheduling constraints.

The intended workflow:

Student enters tasks → LambdaMART ranks tasks → GA generates a study schedule → Flutter displays the result → Student records progress → Schedule is recalculated when necessary.

The algorithms are intended to run on a Python backend, with Flutter communicating through an API.

Proposed technologies:
- Flutter and Dart for the mobile application.
- Firebase Authentication and Cloud Firestore for user accounts and data.
- Python for AI implementation.
- LightGBM for the initial offline LambdaMART experiment; ranking quality remains to be independently validated.
- Genetic Algorithm implementation using suitable Python libraries.
- REST API using FastAPI or Flask, subject to final selection.

## 6. Development Methodology

Staged Incremental Model.

Planned development stages:

1. Task Prioritization Engine
2. Adaptive Scheduling Engine
3. Study Planning Module
4. Dashboard, Analytics, and Refinement

The innovation showcase has been cancelled. Interface work already completed remains a foundation for full FYP development. The next priority is product definition, scheduling rules, data feasibility, and a functional baseline before AI integration. See `docs/development_plan.md` for the proposed roadmap.

## 7. Behavioral Foundation

Self-Regulated Learning (SRL).

Planova supports:
- Planning academic activities.
- Monitoring task progress.
- Reflecting on completed and missed activities.
- Adjusting future study plans.

## 8. Current Development Direction

The 31 October 2026 event has been cancelled. Development is no longer driven by a showcase deadline.

Implemented foundation:
- Flutter navigation and consistent orange, white, and black styling.
- Academic task creation, editing, deletion, completion, and reopening.
- Sample calendar, study sessions, and progress displays.
- Persistent local task records; edits survive restart. Normal local startup now starts empty and does not seed sample tasks or expose demo study history. Explicit demo/test dependencies retain the sample fixtures. Existing saved records are preserved until the user clears them.
- Persistent semesters (name and dates) and courses (code, name, semester ID), managed under Tasks. Tasks may link to a course or retain a manual subject. Existing records upgrade without guessed course links; referenced records cannot be deleted.
- Sample study data remains separate from saved tasks. Storage startup failures offer retry without resetting records.
- Local proforma import: text extraction for the inspected bilingual UPSI Course Info / assessment template, editable course/task/weekly-learning review, effort pre-filled from each assessment's printed SLT hours (editable suggestion), optional due dates ("Decide later": tasks may have no due date and are then not ranked), source references, atomic save, and duplicate-row protection on repeat import. Weekly topics, week ranges and NF2F/Online/SLT hours are editable and saved with the course, keeping printed evidence separate from confirmed values. Courses & semesters reopens saved weekly data. Schema 4 upgrades earlier data in place, reimports preserve saved corrections, and different PDF versions do not automatically replace saved weekly entries. No OCR, backend, or trained AI is used for extraction.

- Local proforma extraction evaluation: `tool/prepare_proforma_evaluation.py` builds private reference JSON from the reviewed CSVs and source review evidence. Optional Flutter tests compare the actual PDF reader/parser with those references and save reports under `research/evaluation/proforma_import/`. The initial text-only baseline matched all course metadata, 44/70 assessments and 9 complete documents. The position-based reader matches 70/70 assessments and 17/17 complete local documents; weekly extraction matches 235/235 printed source rows, including full normalized topics, page references, week ranges and seven hour fields. Course review supports correcting and saving weekly entries, preserving the printed values separately. Unknown NF2F values, Online blank-to-zero interpretation, whole-range hour explanations and source evidence remain explicit. Source-specific research corrections are not silently applied to new uploads; repeated week labels are flagged. Scheduling remains unimplemented. Report generation is not an accuracy gate unless the corresponding strict flags are enabled. See `docs/proforma_import.md`.

- An offline LambdaMART training prototype under `ai/`: source assessment weights from machine-extracted proformas, explicit simulated deadlines/effort, provisional rule-generated labels, course-disjoint training/validation/test groups, baseline comparisons, saved model and reload/prediction checks. This is rule-imitation evidence, not independently validated priorities. Run artifacts remain under Git-ignored `research/experiments/lambdamart/`.

- Experimental Flutter ranking under Tasks: the bundled numerical forest exported from `proforma-v1-003` runs locally behind a `TaskRankingService` contract. It uses confirmed task assessment percentage, calendar days until deadline and estimated minus recorded minutes. Percentages can be corrected during proforma review or entered/cleared in task forms while original PDF evidence stays intact. Old records retain unknown percentages. Completed tasks are excluded; overdue, unknown-weight and zero-work tasks remain visible without invented ranks. Ranking refreshes after repository changes and uses the existing, explicitly labelled preview clock. No Python API or Firebase is needed. See `docs/task_ranking.md`.

- A separate local Python ranking playground (`ai/playground.py`): editable task inputs, saved-model predictions, teaching-rule comparison, and optional result downloads. It reads existing experiment artifacts without retraining or changing Flutter data. It is a developer testing tool, not the student proforma-upload integration or independent validation of priorities.

- Courses tab (slice 3 of the UX overhaul): the bottom navigation was Today, Courses, Plan, Progress (since replaced; see the structure update below). The Courses tab groups tasks by course (current semester first, then unlinked tasks by subject), with progress per course; undated tasks show "Needs a due date". Course and semester management remains one tap away.
- Guided setup and follow-up (slice 2 of the UX overhaul): Today's Get started checklist opens a three-step setup (semester, course proformas, weekly availability with one-tap presets saved as normal study windows). Each step saves immediately, so "Finish later" loses nothing. Today lists active tasks without a due date under "Needs your input"; a bottom sheet adds the date and confirms the time estimate, or "Decide later" leaves them unchanged.
- Student availability (Profile tab → My week; originally on the Plan tab): recurring study windows and recurring commitments (class, club/society, part-time work, personal, other), each with weekdays and a same-day start/end time. Saved locally in the same Sembast database as a separate record; add, edit and confirmed delete survive restart. A rule-based helper (`freeStudySlots`) computes free study time per weekday as study windows minus commitments (commitments always win) and the screen shows the weekly total and per-day free slots. No study sessions are generated from it yet. Overnight times, one-off exceptions, protected time (sleep, meals, travel), and preferences (session length, breaks, daily limit) are not yet modelled.

- Rule-based weekly planner (baseline, slice 4): Plan tab → Create my plan proposes the next 7 days of study sessions inside `freeStudySlots`, earliest due date first (grade weight breaks ties), with 30–60 min sessions, 15 min breaks, a 4 h daily limit and 2 h per task per day; sessions never end after a task's due date. The proposal lists work that does not fit and unplanned (undated/overdue) tasks. Nothing is saved until Accept; accepted sessions are stored locally and shown on Plan and Today with commitments. Deterministic, no AI. See `docs/rule_based_planner.md`.

- Session outcomes and adjustment (slice 5): study sessions can be recorded as done, partly done (minutes) or missed, and corrected later; the task's recorded minutes change by the difference (the estimate grows if exceeded). Today lists unrecorded past sessions and, after a missed or partial session, offers a reviewed re-plan that keeps recorded history. Progress shows studied vs planned minutes this week.

- Guided first-run journey (slice 6): a new student sees one screen at a time — welcome & account, how Planova works (3 cards), optional name, semester, courses, weekly availability, missing due dates, first plan (review and accept), and a short tour — with Back, Continue and "Finish later". Progress is saved after every step and resumes later; students with existing data skip it, and Today offers "Use the step-by-step guide". The same setup step widgets serve the journey and Today's short setup. "Continue with Google" is an honest placeholder: an `AuthService` boundary with a guest-only implementation that explains Google sign-in is not connected yet and continues without an account. Real Google sign-in (Firebase Auth + google_sign_in) can replace it in one place; it must follow Google's sign-in branding guidelines.

- UI review fixes (after slice 6): the normal app uses the real device date (`SystemClock`); only the demo build and tests use the fixed preview date, labelled "Preview date". Courses added by hand show "No assessments yet" with "Add assessment" instead of a done tick; empty journey steps (due dates, first plan) explain what is missing and link back to the step that fixes it. On the Plan tab, "Create my plan" sits in the top panel until a plan exists. Follow-up polish: Today shows the next session once (no duplicate deadline card or day row), "Skip" buttons are secondary to "Continue", a new task defaults to the current semester's only course, "Remove due date" replaces the ambiguous "No due date yet" button, quick effort choices show the selected one, and the Plan week strip fits all seven 48 px days on a 375 px phone.
- App structure update (slice 1 of the restructure, 22 November 2026): the bottom bar is Today · Plan · + · Courses · Profile. The Progress tab is folded into Plan as a "This week" section (studied vs planned time and tasks completed). The new Profile tab shows the student's name (editable), account status (guest, saved on this device; Google sign-in not connected), current semester with a link to semesters and courses, the weekly availability summary, the planner's fixed study rules (read from `PlannerSettings`), and an honest note that plans come from fixed rules, not trained AI. The centre + opens the same quick-add sheet from any tab: task or assessment, record a study session (started, unrecorded sessions, newest first; disabled in the demo), class or commitment, and import a proforma. Planning itself stays on the Plan tab. Bottom bar follow-up: the tabs sit in a fixed rounded pill with a subtle grey highlight that slides to the selected tab (no page transition; the slide respects the system reduce-motion setting), and the + is a separate round button on the right with no visible label (announced as "Add"). The logo header is replaced by the current tab's name in bold; the welcome screen keeps the logo. 
- Study preferences (slice 2 of the restructure, 22 November 2026): Profile → Study preferences lets the student choose the shortest and longest session, break length, most study per day, most time on one task per day, and days off, from listed options (clashing choices are disabled; at least one study day stays). They are saved with the profile (older saved profiles get the defaults, which equal the original baseline rules) and every Create my plan, re-plan and the journey's first plan follow them. The plan's "How this plan was made" lists the rules in use. This is rule-based personalisation set by the student, not learned behaviour. 
- Clean-up (slice 3 of the restructure, 22 November 2026): the separate short setup screen is removed; its step widgets now live with the guided journey, the only setup flow. On Today, each "Get started" row opens the screen that does it (semesters, proforma import, weekly availability) and "Start/Continue setup" reopens the journey at the first unfinished step. Profile → About has an "Experimental features" switch, off by default and saved with the profile: only when it is on do the Courses tab show "Prioritize · experimental" (the unvalidated LambdaMART ranking) and the proforma import and Courses & semesters screens show weekly learning. Weekly learning is still read and saved during import either way; nothing in planning uses it yet. All ranking and weekly-learning code and data are kept.
- Scheduling evaluation, increment 1 (22 November 2026): 16 synthetic test weeks (8 development, 8 test) in `ai/scenarios/`, a hard-rule check and plan scores, and a Python copy of the rule-based planner that is kept identical to the app's Dart planner by shared saved plans. This is the baseline a GA must beat. Baseline results and limits are in `docs/scheduling_evaluation.md`.
- Scheduling evaluation, increment 2 (22 November 2026): an offline Python Genetic Algorithm (`ai/planova_scheduling/ga.py`; a search method, not trained AI) with a shared objective, "deadline-safe even spread": no missed deadlines, finish 24 hours early, even days, fewer sessions. Settings were chosen on development weeks only. On the held-out test weeks it was better than the rule-based planner on 5, equal on 1 and worse on 2 (not significant, p = 0.41); on one tight week it left more due work unplaced. Cause: fixed chunk lengths in the chromosome.
- Scheduling evaluation, GA version 2 (22 November 2026): the decoder now chooses each session's length while placing it, so the rule-based plan is always reachable and is included in the first population (a safety net; random starts gave the same results). On 8 new holdout weeks frozen before version 2 was written, it was better than the rule-based planner on all 8 (p = 0.004): equal or fewer missed minutes and much more even days, with every hard rule kept. Synthetic weeks only; not tested with students or on a phone.
- GA in Dart (22 November 2026, step 1 of bringing it into the app): `lib/services/planning/ga_planner.dart` (`planWeekBalanced`) is a line-for-line copy of the evaluated Python GA, with a shared xorshift32 random generator in both languages. Tests require it to reproduce the Python GA's plan and exact score on all 24 test weeks. The Python results were re-run after the generator switch (holdout table unchanged). 
- Balanced plan in the app (23 November 2026, step 2): the plan review screen makes both plans and opens on **Balanced** (the GA, run in a background isolate with a progress message); **Earliest first** (the rule-based planner) is one tap away. A comparison shows busiest day, days with study, last-day work and any missed due work; the explanation says the GA is a search method, not trained AI. If the GA fails, earliest first is shown with a note. App wording no longer says plans are always rule-based. 
- Phone check (24 November 2026, step 3): on an OPPO A6t 5G (Android 16, release build) the GA reproduced the Python GA's plan and score on all 24 test weeks. A typical week takes about 0.3 s including the background isolate; the heaviest test week 1.3 s. No budget reduction needed. Benchmark: `tool/phone_benchmark/`.

Not yet implemented:
- Real Google sign-in and cloud storage (pending the supervisor's scope decision), notifications, automatic (unreviewed) re-planning, and a GA comparison against the rule-based baseline.
- Broader proforma formats, OCR, and explicit document-version replacement.
- Independently validated task ranking, Python API, and Firebase.

A supervisor suggested importing course proformas to reduce manual setup and inform study planning. The student has chosen this as a central workflow for their own university's students. Exact extraction scope needs confirmation with representative documents. A proforma may not contain exact deadlines or class times; extracted drafts must be reviewed before becoming confirmed tasks. University-specific fit is the intended contribution; document upload alone should not be claimed as unique among all existing planners.

The intended scheduling target is the student's personal study sessions around fixed commitments, not changing the university's official timetable. Confirm this scope with the supervisor.

UI refinement history (20 October 2026): the student has paused new functionality to refine UI/UX. Today, Tasks, shared typography/buttons/cards, and sample-data labels have been refined. Add/Edit Task now puts the title first, groups related fields, explains total versus remaining effort, collapses optional notes, and keeps Save above the keyboard. Existing task data, validation, and save behavior are preserved. Proforma review now uses Course, Assessments, and Confirm steps with persistent actions, expandable extraction notes and source evidence, and a final import summary. Existing validation, explicit deadlines/effort, atomic save and duplicate protection are preserved. Courses & semesters now has a compact academic summary, clearer semester/course hierarchy, prominent import/add actions, and overflow menus for edit/delete. Course and semester forms keep Save above the keyboard. Existing record protection and task links are preserved. Task details now separates remaining work and recorded progress from manual completion, groups deadline and settings, collapses notes/source evidence, and keeps primary actions above notifications. Deletion remains confirmed in an overflow menu. The final UI consistency pass improves selected-calendar contrast, 48-pixel date/text/icon-button targets, calendar screen-reader labels, progress wording, larger-text heading/header wrapping, and selectable source evidence. Main-tab accessibility guideline and double-text-size regressions are covered; full assistive-technology/device evaluation remains future work. Project organization: runtime branding is in `assets/branding/`, supporting documents in `docs/`, tests grouped by app/data/feature/service with `test/support/` fixtures, and clock/formatting/error helpers separated in `lib/core/`. See `docs/project_structure.md`. Functional development follows the roadmap when resumed; algorithm selections remain proposed pending data feasibility and supervisor requirements.

Current direction (19 November 2026): following the supervisor's reported guidance, use proforma-derived assessment information for LambdaMART and reserve the survey for planner preferences. The student explicitly authorized an initial offline experiment using provisional rule-generated labels and clearly simulated deadline/effort scenarios, with later revision. This supersedes the earlier plan to require student priority snapshots as the immediate training-label source. Provisional labels are neither student observations nor expert-approved priorities, and do not establish optimal decisions or improved grades. The isolated Python pipeline, configuration, test suite and interpretation limits are documented in `ai/README.md`. Local proformas and an academic calendar have been supplied in `research/`. Draft collection materials and source review are in `research/data_collection/`; they are local research files, excluded from Git, and no live questionnaire has been published.

Clearly distinguish mock behavior, rule-based baselines, trained ranking, and scheduling optimization throughout development.

## 9. Product Direction

Planova should feel like a modern student productivity application.

Design principles:
- Use black selectively for one focal summary/action panel on a screen, with white text, muted light secondary text, and orange accents. Keep routine cards, forms, lists, and page backgrounds light; avoid turning every section black.
- Clean, modern, polished, and intuitive.
- Student-friendly but professional.
- Consistent typography, spacing, navigation, and color system.
- Clear visual hierarchy.
- Responsive layouts suitable for mobile screens.
- Support for light and dark themes where practical.
- Meaningful empty, loading, and success states.

The interface should make task prioritization and adaptive scheduling easy to understand, during everyday use.

## 10. Important Constraints

- Prioritize Android for the FYP.
- Keep the codebase compatible with future iOS development where practical.
- Use Flutter and Dart.
- Separate UI, data models, services, and business logic.
- Do not introduce unnecessary backend dependencies during UI prototyping.
- Avoid claiming AI functionality is complete when it is simulated.
- Keep the implementation maintainable for future FYP development.
