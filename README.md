# Planova

Flutter Android application for the Planova Final Year Project. The innovation showcase has been cancelled; development now follows the proposed roadmap in `docs/development_plan.md`.
Read `PLANOVA_CONTEXT.md` for the product direction and `AGENTS.md` for development guidance.

## Current prototype

- First run: a guided journey (welcome, how it works, semester, courses, week, missing due dates, first plan, tour). "Continue with Google" is a placeholder that explains Google sign-in is not connected yet and continues without an account; data stays on the device.

- Today: a Get started checklist that opens the guided setup (semester → course proformas → weekly availability, resumable, "Finish later" keeps what was saved), a "Needs your input" list of tasks without a due date (a small sheet adds the date and time estimate), the next deadline, and sample sessions in the demo build only.
- Tasks (on the Courses tab): add, edit, delete, complete, and reopen academic tasks with validated forms.
- Courses tab (replaces the former Tasks tab): every task grouped under its course, or under its typed subject when not linked, with per-course progress, compact rows (due date, "Needs a due date", time left), and "Add task to this course". Import proforma and Prioritize sit at the top.
- Prioritize (on the Courses tab): experimental on-device LambdaMART ranking using confirmed assessment percentages, calendar days until due, and work remaining. Ineligible tasks remain visible for review.
- Courses & semesters (link at the bottom of the Courses tab): add/edit semesters and courses, select a course for a task, and explicitly change or unlink that relationship.
- Proforma import (Tasks → Import proforma): choose a supported text-based UPSI PDF and check the assessments. Time estimates are pre-filled from the proforma's printed study hours; due dates are optional and can be added later. Tasks without a due date show "No due date yet" and are not ranked.
- Plan: browse days and weeks; **Create my plan** proposes the next 7 days of study sessions with a rule-based planner (no AI), which you review and accept before it is saved. Accepted sessions and fixed commitments appear on Plan and Today. Tap a session to record it as done, partly done or missed; Today lists unrecorded sessions and offers a reviewed re-plan after a missed one. See `docs/rule_based_planner.md`.
- Weekly availability (under Plan): add, edit and delete recurring study windows and commitments such as classes, clubs, work or personal time. Shows free study time per week and per day (study windows minus commitments). Saved locally; no sessions are generated from it yet.
- Progress: sample study time and task completion totals.

The first UI refinement pass uses compact Today/Tasks headers, a clearer course-import
entry, title-first task cards with explicit due/completion labels and remaining time,
and a separate sample-session card. Bright orange remains an accent; text-bearing
buttons use deeper orange with white text. Bottom navigation retains filled selected
icons with transparent hover/press backgrounds. Task storage and planning behavior
are unchanged by this styling pass.

Tasks are saved locally. A normal new installation starts empty; sample tasks and
study history are available only through the explicit demo/test dependencies. Creating,
editing, completing, reopening, and deleting tasks survives an app restart.
Deleting every task leaves an empty list; samples are not restored automatically.
Semester dates and course records are also saved locally. Existing saved tasks
upgrade automatically and retain their manual subjects until explicitly linked.
Course renaming updates linked task labels without changing task IDs or progress.
Course codes must be unique within a semester. A course with linked tasks, or a
semester with courses, cannot be deleted until those relationships are removed.
The normal app has no study sessions or recorded study hours yet. Demo/test sessions
and study-time totals remain synthetic. The preview clock is fixed at 14 October 2026,
13:00, so rehearsals are reproducible. There is no Firebase, Python API,
GA implementation, or generated schedule in the Flutter runtime. The separate
offline LambdaMART experiment under `ai/` exports a small forest used by Flutter's
experimental ranking screen. This does not generate a study schedule.
Task storage uses a Sembast file in application support storage on Android and
IndexedDB in the browser. Web storage belongs to the browser origin, including
the port: use the same browser and port when checking persistence. Clearing app
or browser data removes local records. There is no cloud synchronization.
Independently validated priorities and schedule generation remain later phases.
Completing a task changes its status without inventing recorded study time.
Completed or deleted tasks no longer show planned sample sessions; recorded study history remains.

Import uses local PDF text extraction and template rules, not trained AI. It keeps
assessment row identities and source-page references, and saves a reviewed course
and tasks in one transaction. Reimporting the same PDF into the same course skips
existing source rows without overwriting edited tasks or progress. Existing course
names are preserved. Unselected rows can be imported later. The PDF itself is not
uploaded, copied into app assets, or retained in the database.
See `docs/proforma_import.md` for supported input, limitations, and validation.

## Offline ranking experiment

The first experimental Python pipeline lives in [ai/README.md](ai/README.md).
It uses proforma-derived assessment weights, explicitly simulated deadline/effort
contexts, and provisional rule-generated labels. Survey responses are reserved for
planner preferences. Its metrics measure rule imitation, not independently validated
student priorities. Original PDFs and generated datasets/models remain local under
Git-ignored `research/`. Flutter uses a reviewed export format of the saved model
under `assets/ranking/`; its predictions remain experimental. See
[Flutter ranking](docs/task_ranking.md) for the app flow, input mapping, and limits.

A separate local ranking playground lets you edit task inputs, run a saved model,
and compare its output with the provisional teaching rule. See the setup and launch
instructions in [ai/README.md](ai/README.md#local-ranking-playground). It does not
retrain models or connect to Flutter's proforma upload. Flutter runs its bundled
model directly, independently of this page.

## Project structure

- `ai/`: isolated offline ranking experiment, configuration, tests, and pinned Python dependencies.

- `assets/branding/`: original wordmark and icon assets, registered in `pubspec.yaml`.
- `lib/app/`: app startup, dependency composition, and navigation shell.
- `lib/core/`: shared theme/widgets, pure date helpers, clock contract, and error messages.
- `lib/models/`: framework-independent academic and study-session models.
- `lib/data/`: repository contracts, local persistence/codecs, and sample data.
- `lib/features/`: screens, view models, and feature-specific widgets.
- `lib/services/proforma/`: PDF text-reader boundary and UPSI template parser.
- `lib/services/ranking/`: on-device model evaluator and replaceable ranking service.
- `test/`: app, data, feature, and service tests; reusable fixtures/actions in `test/support/`.
- `docs/`: development roadmap, student workflow, proforma scope, and folder guide.
- `design/previews/`: historical UI previews, separate from runtime assets.
- `research/`: private local documents and collection materials; excluded from Git and app assets.

Keep `AGENTS.md` and `PLANOVA_CONTEXT.md` at the root as the project entry points.
Flutter platform folders and generated `.dart_tool/` / `build/` directories keep their
standard locations. Generated artifacts are ignored by Git; they are not source files.
See [the folder guide](docs/project_structure.md) for ownership and conventions.

Repositories are shared across screens. Planner navigation uses a `ChangeNotifier`
view model; immutable read-only screens do not require their own notifier.
Future Firebase implementations can replace repositories at the
composition root. A planning service/API boundary will be introduced when
the scheduling flow is implemented; backend SDK types should stay outside widgets.

## Run and validate

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

When changing model fields, repository inheritance, or application initialization,
use a **hot restart**, rather than hot reload, to recreate application state.
After adding native plugins, stop and run the app again for a full rebuild.
Restarting does not reset saved tasks. Storage startup failures show a retry
screen without silently replacing saved data.
In VS Code, run `Flutter: Hot Restart` from the Command Palette. In a terminal
running `flutter run`, press uppercase `R`. If the debugger remains paused on an
old exception, stop debugging and start the app again.

Android currently retains the template application ID and debug signing for release builds.
Android packaging and physical-device validation will be handled during release preparation.

## Development documents

- [Product context](PLANOVA_CONTEXT.md)
- [Development roadmap](docs/development_plan.md)
- [Student workflow](docs/workflow.md)
- [Proforma import scope](docs/proforma_import.md)
- [Experimental Flutter ranking](docs/task_ranking.md)
- [Folder guide](docs/project_structure.md)

To run a focused group from the project root:

```sh
flutter test test/features/courses/
flutter test test/features/tasks/
flutter test test/services/proforma/
flutter test test/app/ui_accessibility_test.dart
flutter build web --debug
```

The real-PDF test under `test/services/proforma/` skips when its private research
file is unavailable. Synthetic parser fixtures live in `test/support/`.
