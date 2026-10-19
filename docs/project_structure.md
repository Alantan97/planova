# Project folder guide

Paths and commands in the development documents are relative to the project root.

## Source ownership

```text
assets/branding/           Runtime logos and app branding
lib/
  app/                    App composition, startup, and navigation
  core/
    errors/               Shared user-facing error messages
    theme/                Design tokens and Flutter theme
    time/                 AppClock, DemoClock, and pure date/time helpers
    widgets/              UI shared across features
  data/
    repositories/         Persistence contracts and academic-record rules
    local/                Sembast storage, migrations, and codecs
    mock/                 Explicit sample tasks/sessions
  features/
    courses/              Course/semester forms and reviewed proforma import
    tasks/                Task list, form, and details
    today/                Overview and its view model
    planner/              Sample calendar and its view model
    progress/             Task totals and sample study progress
  models/                 Immutable domain records
  services/proforma/      Local PDF extraction and template parsing
```

Feature widgets belong under their feature's `widgets/` folder. Move a widget to
`core/widgets/` only when multiple features actually share it. Shared utility code
must not import a screen. `main.dart` is the entry point; app tests import
`app/planova_app.dart` directly.

`AppClock` defines the time boundary, `DemoClock` supplies the fixed preview date,
and `date_time_helpers.dart` contains formatting/calendar helpers independent of
that clock. Changing folders does not change the preview date or scheduling behavior.

## Tests

```text
test/app/                 Startup, navigation, and accessibility
test/data/                Mock data and persistence/migration tests
test/features/courses/    Course management and proforma review
test/features/tasks/      Task management and forms
test/services/proforma/   Parser and optional real-PDF extraction tests
test/support/             Synthetic fixtures and reusable widget actions
```

Test suites must not import another `_test.dart` file. Keep shared setup/actions
in `test/support/`, and keep synthetic fixtures separate from private research PDFs.
The real-PDF test deliberately uses a project-root-relative `research/` path.

## Documents and local files

- Root: `README.md`, `AGENTS.md`, and `PLANOVA_CONTEXT.md` are entry points.
- `docs/`: supporting development plans and implementation notes.
- `design/previews/`: historical visual references, not bundled assets.
- `research/`: private source documents, survey drafts, and responses; Git-ignored.
- `build/`, `.dart_tool/`, and platform ephemeral directories: generated output.

Do not move private research into `assets/`, delete local data as cleanup, or edit
generated plugin registration files by hand. Keep Flutter platform folders in
place so native builds and future platform work continue to use standard tooling.

## Future integration

Screens receive repository contracts through `AppDependencies`. Keep Firebase SDK
and Python API details behind those boundaries when integration is implemented.
No backend or trained AI is introduced by this organization pass.
