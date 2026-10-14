# Planova

Flutter Android prototype for the 31 October 2026 innovation showcase.
Read `PLANOVA_CONTEXT.md` for the product direction and `AGENTS.md` for development guidance.

## Current prototype

- Today: upcoming session, daily agenda, next deadline, and sample weekly progress.
- Tasks: add, edit, delete, complete, and reopen academic tasks with validated forms.
- Plan: browse days and weeks; inspect study sessions and fixed commitments.
- Progress: sample study time and task completion totals.

All data is local and synthetic. The demo clock is fixed at 14 October 2026,
13:00, so rehearsals are reproducible. There is no Firebase, Python API,
LambdaMART, GA implementation, or generated schedule in this phase.
Task changes last for the current app session; restarting restores the demo fixtures.
Prioritization and simulated scheduling remain later phases.
Completing a task changes its status without inventing recorded study time.
Completed or deleted tasks no longer show planned sample sessions; recorded study history remains.

## Structure

- `lib/app/`: application setup, dependency composition, and four-tab shell.
- `lib/core/`: shared theme, date helpers, and reusable widgets.
- `lib/models/`: framework-independent task and session models.
- `lib/data/`: repository contracts and mock implementations.
- `lib/features/`: screens and view models grouped by feature.

Repositories are shared across screens. Planner navigation uses a `ChangeNotifier`
view model; immutable read-only screens do not require their own notifier.
Future Firebase implementations can replace the mock repositories at the
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
use a **hot restart**, rather than hot reload, to recreate the in-memory demo state.
In VS Code, run `Flutter: Hot Restart` from the Command Palette. In a terminal
running `flutter run`, press uppercase `R`. If the debugger remains paused on an
old exception, stop debugging and start the app again.

Android currently retains the template application ID and debug signing for release builds.
Showcase packaging and physical-device validation will be handled in the final preparation phase.

## Getting Started

Flutter learning resources:

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
