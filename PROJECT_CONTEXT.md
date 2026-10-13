# Planova project context

## Purpose and scope

Planova is an Android-first Flutter/Firebase AI-powered adaptive study planner for university students, developed as a Final Year Project (FYP). It helps students prioritize academic tasks and build study schedules that adapt when tasks, availability, or progress change.

Android is the current delivery target. Other generated Flutter platform folders do not expand the agreed scope. Future iOS support is a possible extension, not a current milestone.

## Initial repository baseline

Inspected on 14 October 2026 at `C:\flutter_project\planova`:

- `pubspec.yaml` identifies the package as `planova`, version `1.0.0+1`, with Dart constraint `^3.13.5`.
- `lib/main.dart` contains the generated Flutter counter application.
- `test/widget_test.dart` contains the counter widget smoke test.
- `analysis_options.yaml` includes `flutter_lints`.
- Dependencies currently include Flutter and `cupertino_icons`; no Firebase package is declared.
- The README is the generated Flutter introduction. Android and other platform scaffolds exist.
- No AI backend, training pipeline, dataset, or model artifact was found in the inspected project files. No `.git` directory was found at the project root.

This is an observed starting point, not evidence that the proposed features have been implemented or validated. Re-inspect the repository before future changes.

## Interface increment — 14 October 2026

- The user approved interface-first implementation, with Strava and Luma as inspiration, an orange/white theme, and the supplied `planova icon.png`.
- The counter screen has been replaced by Today and Plan screens. At the user's request, the header uses the supplied `planova full title black.png` instead of the separate icon/text. Both supplied images are preserved and bundled as Flutter assets; native launcher icons remain the generated defaults.
- The user supplied a Strava-style visual reference and requested the exact icon orange (`#FF6600`), black, and white, without deeper orange variants. The next-session card now has a white content area, black badge/action bar, and orange button. Selected days and navigation indicators use the same orange with white foregrounds. Supporting surfaces use white or neutral grey instead of peach; no dark text is placed on solid orange backgrounds.
- Today presents a next-session card, an agenda, an upcoming deadline, and a sample weekly progress summary. Plan supports day selection, previous/next weeks, session details, and an empty-day state.
- The preview uses fixed synthetic data for 12–18 October 2026. Commitments are excluded from displayed study-duration totals. Other weeks have no sample sessions. This is not a LambdaMART ranking or GA-generated schedule.
- Only Today and Plan are implemented in this increment. Task entry, availability editing, session timing, completion tracking, dedicated Progress, authentication, persistence, and AI integration are not implemented.
- UI code is in `lib/main.dart`, `lib/study_home.dart`, and `lib/theme.dart`. No packages or SDK constraints were changed. The supplied image was preserved.
- Changed Dart files were formatted. `flutter analyze` reports no issues; all three widget tests pass, covering session details, day/week navigation, study-duration totals, and a 320-pixel-wide phone with 130% text scaling. Flutter-rendered screenshots were visually inspected.
- The final Android debug APK built successfully using `android/gradlew.bat assembleDebug` with the existing JDK 18 selected through a command-local `JAVA_HOME`. The APK is at `build/app/outputs/apk/debug/app-debug.apk`. Global Flutter settings were not changed. `flutter build apk --debug` still selects a missing `C:\Program Files\Android\Android Studio\jbr`; that toolchain setting remains unresolved. No Android device or emulator is currently reported by Flutter, so a live Android run has not been verified. The existing Gradle scaffold emits deprecation warnings.
- Visually inspected Flutter-rendered previews are saved at `design/previews/today.png` and `design/previews/plan.png`; these are widget renders, not screenshots from an Android device.

## Agreed algorithm roles

**LambdaMART ranks tasks.** It produces a relative priority ordering for candidate tasks in a defined student/planning context. It does not assign tasks to time slots.

**A Genetic Algorithm (GA) generates and re-optimizes schedules.** It uses ranked tasks and planning constraints to search for suitable allocations of study sessions. Re-optimization should respond to changes such as missed sessions, completion, new tasks, or changed availability. A GA does not guarantee a globally optimal schedule.

Proposed flow:

`Tasks + student context -> LambdaMART ranking -> GA scheduling -> study plan -> progress/availability changes -> re-optimization`

Flutter supplies the mobile interface. Firebase is the intended application data/authentication platform; its services and security rules still need to be selected and configured. A Python backend/API for the AI engines is a proposed implementation direction, not an existing or finalized stack. Confirm deployment and API boundaries before adding dependencies.

## Development order

On 14 October 2026, the user changed the immediate priority to planning and developing the interface first, inspired by Strava and Luma, then approved the first Today/Plan increment and an orange/white theme. This overrides the earlier AI-first work order for the current phase. The algorithm roles and unresolved research decisions remain unchanged.

The following was the original development order and remains the engine/integration roadmap after the interface phase:

Work in small, explainable, verifiable increments:

1. **AI engines first.** Define task and availability contracts, investigate data and labels, establish an explicitly labeled heuristic baseline, then develop and evaluate LambdaMART and GA modules. Small synthetic fixtures may validate interfaces and scheduling constraints while research decisions remain open.
2. **Study planning next.** Integrate task management, availability, ranked tasks, schedule generation, progress tracking, and re-optimization. Add the minimum Firebase and API integration needed for each working slice.
3. **Dashboard last.** Present real planning and progress data after the underlying workflow works. Do not let dashboard polish displace AI engine development.

A deterministic priority rule is a baseline, not a trained LambdaMART model. Synthetic demonstrations are not evidence of real-world ranking accuracy or personalization.

## Unresolved research decisions

### Dataset suitability — unresolved

The exact Kaggle student habits dataset, version, license, schema, provenance, and suitability have not been verified. Do not claim it provides task ranking labels. Student-level habit or performance observations must not be treated as labeled task-level ranking examples without a justified transformation and validation design.

Before selecting training data, inspect the actual dataset and document its unit of observation, usable features, missing data, permitted use, and relationship to Planova's ranking objective. It may support exploratory analysis or feature hypotheses, but that does not establish suitability for LambdaMART training.

### Training-label design — unresolved

LambdaMART needs candidate tasks grouped by a meaningful ranking context and relevance/preference labels within those groups. The following still need a defensible design:

- The ranking objective and meaning of relevance (for example, expert priority, student preference, or a defined outcome).
- The query/group definition, label scale, collection method, and annotation consistency.
- Task-level feature availability at prediction time and safeguards against target leakage.
- Whether labels are collected, expert-annotated, synthetic, or derived from a heuristic; document provenance and limitations. Heuristic labels mainly teach the heuristic and must not be presented as independent ground truth.
- Student/time-aware train, validation, and test splits; baselines and metrics such as NDCG at a chosen cutoff once valid labels exist.

Do not silently substitute academic grades for task relevance or report a trained/validated model before valid grouped labels and an evaluation protocol exist.

### Scheduling design — unresolved

Confirm the planning horizon, time-slot granularity, duration estimates, allowed task splitting, fixed commitments, breaks, daily study limits, and treatment of impossible deadlines. Define hard constraints separately from soft preferences and document the GA fitness function, weights, termination conditions, and random seed policy.

Re-optimization should account for completed work and ongoing commitments. Return unscheduled work and reasons when available time is insufficient; do not conceal infeasibility with an invalid schedule.

## Verification and evidence

For future Flutter code changes, format changed Dart files and run `flutter analyze` and `flutter test`; use an Android run/build when the change affects platform integration. Record actual results and toolchain limitations.

For AI work, test input validation, ranking contracts, reproducibility, schedule overlap, availability limits, duration accounting, impossible workloads, and re-optimization behavior. Compare against simple baselines. Separate fixture-level correctness from research evaluation on appropriate held-out data.

Update this document as implementation decisions become established. Keep unresolved items explicit until evidence resolves them.
