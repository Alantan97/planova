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
- LightGBM for LambdaMART, subject to final implementation decisions.
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
- Persistent local task records, seeded once with sample tasks; edits survive restart.
- Persistent semesters (name and dates) and courses (code, name, semester ID), managed under Tasks. Tasks may link to a course or retain a manual subject. Existing records upgrade without guessed course links; referenced records cannot be deleted.
- Sample study data remains separate from saved tasks. Storage startup failures offer retry without resetting records.
- Narrow local proforma import: text extraction for the inspected bilingual UPSI Course Info / assessment template, editable course/task review, explicit deadlines and effort, source references, atomic save, and duplicate-row protection on repeat import. No OCR, topic extraction, backend, or trained AI is used.

Not yet implemented:
- Real schedule generation and adaptive rescheduling.
- Broader proforma formats, OCR, and weekly topic/workload extraction.
- Trained task ranking, Python API, and Firebase.

A supervisor suggested importing course proformas to reduce manual setup and inform study planning. The student has chosen this as a central workflow for their own university's students. Exact extraction scope needs confirmation with representative documents. A proforma may not contain exact deadlines or class times; extracted drafts must be reviewed before becoming confirmed tasks. University-specific fit is the intended contribution; document upload alone should not be claimed as unique among all existing planners.

The intended scheduling target is the student's personal study sessions around fixed commitments, not changing the university's official timetable. Confirm this scope with the supervisor.

Current priority (20 October 2026): the student has paused new functionality to refine UI/UX. Today, Tasks, shared typography/buttons/cards, and sample-data labels have been refined. Add/Edit Task now puts the title first, groups related fields, explains total versus remaining effort, collapses optional notes, and keeps Save above the keyboard. Existing task data, validation, and save behavior are preserved. Proforma review now uses Course, Assessments, and Confirm steps with persistent actions, expandable extraction notes and source evidence, and a final import summary. Existing validation, explicit deadlines/effort, atomic save and duplicate protection are preserved. Courses & semesters now has a compact academic summary, clearer semester/course hierarchy, prominent import/add actions, and overflow menus for edit/delete. Course and semester forms keep Save above the keyboard. Existing record protection and task links are preserved. Task details now separates remaining work and recorded progress from manual completion, groups deadline and settings, collapses notes/source evidence, and keeps primary actions above notifications. Deletion remains confirmed in an overflow menu. The final UI consistency pass improves selected-calendar contrast, 48-pixel date/text/icon-button targets, calendar screen-reader labels, progress wording, larger-text heading/header wrapping, and selectable source evidence. Main-tab accessibility guideline and double-text-size regressions are covered; full assistive-technology/device evaluation remains future work. Project organization: runtime branding is in `assets/branding/`, supporting documents in `docs/`, tests grouped by app/data/feature/service with `test/support/` fixtures, and clock/formatting/error helpers separated in `lib/core/`. See `docs/project_structure.md`. Functional development follows the roadmap when resumed; algorithm selections remain proposed pending data feasibility and supervisor requirements.

The student has confirmed that the ranking target is students' stated task-priority choices. These labels are not an objective ground truth for optimal academic decisions or improved grades. Local proformas and an academic calendar have been supplied in `research/`. Draft collection materials and source review are in `research/data_collection/`; they are local research files, excluded from Git, and no live questionnaire has been published.

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
