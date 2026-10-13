# Planova

Flutter Android prototype for the 31 October 2026 innovation showcase.
Read `PLANOVA_CONTEXT.md` for the product direction and `AGENTS.md` for development guidance.

## Current prototype

- Today: upcoming session, daily agenda, next deadline, and sample weekly progress.
- Tasks: read-only academic task list and details.
- Plan: browse days and weeks; inspect study sessions and fixed commitments.
- Progress: sample study time and task completion totals.

All data is local and synthetic. The demo clock is fixed at 14 October 2026,
13:00, so rehearsals are reproducible. There is no Firebase, Python API,
LambdaMART, GA implementation, or generated schedule in this phase.
Task editing and simulated scheduling are later phases.

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
