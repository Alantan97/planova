# Planova development guidance

## Read before working

Read `PROJECT_CONTEXT.md`, inspect the current repository, and follow any applicable nested `AGENTS.md` instructions before editing. The context document distinguishes agreed scope, observed implementation, proposals, and unresolved research decisions.

Planova is an Android-first Flutter/Firebase adaptive study planner for university students. LambdaMART ranks tasks; a Genetic Algorithm generates and re-optimizes schedules.

## Work order and scope

- Prioritize the AI engines, then the study planning workflow, then the dashboard.
- Implement small, working increments with clear validation and a brief explanation of the result.
- Do not rebuild the entire app, introduce a broad architecture, or add packages merely to prepare for hypothetical future features.
- Preserve existing code, user edits, project conventions, and generated platform scaffolds. Inspect before replacing any file. Do not reset, delete, or overwrite existing work to obtain a clean starting point.
- Keep Android as the current target; do not add iOS, desktop, or web delivery milestones without a scope change from the user.
- If synced `sources/` reference files are present, treat them as read-only: do not edit, rename, move, or delete them.

## AI and research honesty

- Keep ranking and scheduling separate: LambdaMART orders candidate tasks; the GA allocates study time under constraints.
- **Dataset suitability and training-label design are unresolved.** Inspect actual data and document the objective, ranking groups, features, labels, provenance, splits, and evaluation protocol before claiming usable training data.
- **Do not claim the Kaggle student habits dataset provides task ranking labels.** Do not convert student grades or habits into task relevance without an explicit, justified design.
- Clearly identify synthetic fixtures, heuristic labels, mocked responses, and deterministic ranking baselines. Never describe these as a trained or validated LambdaMART engine.
- Do not fabricate model performance, user-study results, personalization, or optimality claims. Report measurements with their dataset and evaluation conditions.
- While labels are unresolved, progress on data contracts, explicit baselines, GA constraint handling, and module tests is appropriate. Do not silently choose a scientific labeling objective.
- Define hard scheduling constraints and soft preferences explicitly. Detect infeasible workloads and return unscheduled tasks with reasons. Re-optimization must account for completed work and current commitments.

## Implementation boundaries

- Firebase is intended but not yet configured in the inspected baseline. Inspect dependencies and configuration before integration; add only the services needed for the current slice.
- A Python AI service/API is proposed, not established. Confirm stack decisions against the repository and user direction before scaffolding a backend.
- Keep AI logic testable independently of Flutter screens. Define shared input/output contracts before wiring UI to engines.
- Keep credentials, service-account keys, private student records, and secrets out of source control, logs, and sample fixtures. Scope student data access to the authenticated user when implementing Firebase rules.
- Preserve the installed SDK constraints unless a task requires an upgrade. Avoid unrelated dependency updates.

## Validation and reporting

- Documentation-only changes need content and file-preservation checks; do not modify the app to test documentation.
- For Dart changes, format changed files, run `flutter analyze` and `flutter test`, and use Android integration checks when relevant. Adapt the generated counter test when replacing its screen; do not delete tests simply to hide failures.
- For AI engines, add meaningful checks for ranking contracts, reproducible fixtures, schedule validity, duration accounting, impossible inputs, and adaptation after progress changes. Use the selected backend's test tools once established.
- Report what changed, which checks actually ran, their results, and unresolved decisions. A hanging or unavailable tool is not a passing check.
- Keep `PROJECT_CONTEXT.md` current when verified implementation status or agreed decisions change. Do not turn assumptions into facts.
