# Project folder guide

Paths and commands in the development documents are relative to the project root.

## Source ownership

```text
ai/                         Isolated offline LambdaMART experiment (not an API)
assets/branding/            Runtime logos and app branding
assets/ranking/             Exported ranking model used by the experimental screen
lib/
  main.dart                 Entry point
  app/                      Dependency composition (AppDependencies), startup
                            (journey or app), and the navigation shell; widgets/
                            holds the bottom bar (pill tabs Today, Plan,
                            Courses, Profile and a separate + for quick-add)
  core/
    errors/                 Shared user-facing error messages
    theme/                  Design tokens and Flutter theme
    time/                   AppClock + SystemClock (real), DemoClock (preview),
                            and pure date/time helpers
    widgets/                UI shared across features (effort input, task card,
                            session rows, counters, panels) and
                            ExperimentalFeatures (the Profile switch, provided
                            above every route)
  data/
    repositories/           Storage contracts and their shared rules
                            (tasks/courses, availability, study plan, profile)
    local/                  Sembast storage, migrations, and codecs
    mock/                   Explicit sample tasks/sessions for the demo build
  features/
    onboarding/             Guided first-run journey; widgets/ holds the welcome
                            screen, intro cards, "what is missing" panel and
                            the step widgets (semester, courses, availability,
                            step intro and progress bar)
    today/                  Overview, "Get started" card, "Needs your input"
    courses/                Courses tab, course/semester forms, proforma import
                            and review, weekly learning; start_proforma_import.dart
    tasks/                  Task form and details; widgets/ holds the due-date sheet
    planner/                Plan tab, plan proposal, record-session sheet;
                            open_plan_proposal.dart runs the planner for review
    availability/           Weekly availability and commitment forms
    progress/               "This week" card on the Plan tab (studied vs planned
                            time and task totals)
    profile/                Profile tab and the study preferences screen: name,
                            account, semester, my week,
                            study rules, how plans are made
    quick_add/              The centre + sheet (task, record session,
                            commitment, proforma)
    ranking/                Experimental priority screen and view model
  models/                   Immutable domain records
  services/
    auth/                   Account boundary (guest-only until Google sign-in)
    planning/               Free study slots and the rule-based weekly planner
    proforma/               Local PDF extraction and template parsing
    ranking/                Versioned model evaluator and on-device ranking
```

Feature widgets belong under their feature's `widgets/` folder. A file that starts
a flow used by several features (`start_proforma_import.dart`,
`open_plan_proposal.dart`) sits at the feature root. Move a widget to
`core/widgets/` only when several features actually share it. Shared utility code
must not import a screen. App tests import `app/planova_app.dart` directly.

Queries about saved data belong on the repository contract, not in a screen:
for example `TaskRepository.currentSemester(now)`.

`AppClock` defines the time boundary. The normal app uses `SystemClock` (the
device's real date); the demo build and tests use `DemoClock` (14 October 2026,
13:00) so results are reproducible. `date_time_helpers.dart` contains formatting
helpers independent of the clock.

## Tests

```text
test/app/                   Startup, navigation, and accessibility
test/core/                  Shared widgets (effort input, counters)
test/data/                  Mock data and persistence/migration tests
test/features/<feature>/    One folder per lib/features/<feature>/
test/services/              Planner, proforma parser and ranking tests
test/support/               Fixtures, realModeApp() and widget actions
```

Name test files after what they check (`today_layout_test.dart`), not after the
work session that added them. Test suites must not import another `_test.dart`
file. Keep shared setup in `test/support/` (for example `realModeApp()` in
`test_apps.dart`), and keep synthetic fixtures separate from private research
PDFs. The real-PDF tests use a project-root-relative `research/` path and skip
when it is missing.

## Documents and local files

- Root: `README.md`, `AGENTS.md`, and `PLANOVA_CONTEXT.md` are entry points.
- `docs/`: development plan, workflow, proforma import, task ranking, rule-based
  planner, and this folder guide.
- `design/previews/`: historical visual references, not bundled assets.
- `research/`: private source documents, survey drafts, and responses; Git-ignored.
- `tool/`: helper scripts (proforma evaluation preparation).
- `build/`, `.dart_tool/`, and platform ephemeral directories: generated output.

Do not move private research into `assets/`, delete local data as cleanup, or edit
generated plugin registration files by hand. Keep Flutter platform folders in
place so native builds and future platform work continue to use standard tooling.

## Planning

`lib/models/weekly_availability.dart` defines study windows, recurring commitments
and their shared `WeeklyTimeRange`. `lib/services/planning/free_study_slots.dart`
computes free study time (windows minus commitments) and
`rule_based_planner.dart` fills it with sessions (see `docs/rule_based_planner.md`).
`StudyPlanRepository` stores accepted plans and recorded outcomes.

## Ranking integration

`lib/features/ranking/` owns the experimental priority screen and view model.
`AppDependencies` supplies its ranking-service contract. The local implementation
evaluates the saved model export in `assets/ranking/`, independently of the Python
playground. No source PDFs or training rows are bundled. See `docs/task_ranking.md`.

## Future integration

Screens receive repository contracts and the `AuthService` through
`AppDependencies`. Keep Firebase SDK and Python API details behind those
boundaries when integration is implemented.

## Offline ranking experiment

`ai/planova_ranking/` contains PDF extraction, dataset generation and training.
`ai/configs/` versions provisional policies; `ai/tests/` covers ranking invariants.
`ai/playground.py` is an optional local Streamlit testing page; its read-only model
adapters live in `ai/planova_ranking/playground.py`. Launch it with
`ai/run_playground.ps1` after installing `ai/requirements-ui.txt`.
`ai/.venv/` is local and ignored. Run outputs stay under
`research/experiments/lambdamart/`, including the extraction audit, datasets and
model. Training remains separate from Flutter; only the explicitly exported forest
is used by its experimental ranking screen. Independent ranking validation remains
outstanding. See `ai/README.md` for reproduction.

## Scheduling evaluation

`ai/planova_scheduling/` holds the scheduling evaluation: scenario loading,
a rule-for-rule Python copy of the app's planner (the baseline), hard-rule
checks and plan scores. `ai/build_scenarios.py` writes the synthetic test weeks
to `ai/scenarios/`; `ai/scenarios/expected/` holds the Dart planner's plans for
them, checked by `test/services/planning/scenario_golden_test.dart` and
`ai/tests/test_scheduling.py`. `ai/run_scheduling_baseline.py` prints the
baseline table. See `docs/scheduling_evaluation.md`.
