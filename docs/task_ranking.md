# Experimental Flutter task ranking

Implemented 19 November 2026. A saved, trained LambdaMART forest now runs directly
in Flutter. Its labels are provisional rule-generated priorities, so this is an
experimental integration and not independently validated student guidance.

## Try it

Use a full hot restart after these model/dependency changes. If an old app build
cannot find the new asset, stop and run Flutter again. Restarting preserves local data.

1. Open the Courses tab, then **Prioritize · experimental**.
2. For a task listed under Needs attention, open it, choose Edit task, and enter its
   confirmed assessment percentage under Task settings. Do not guess an unknown
   percentage or use the task's importance setting instead.
3. Save and return. Ranking recalculates when saved tasks change. Completing a task
   removes it from the ranking; reopening makes it eligible again if its inputs fit.
4. For imported tasks, use the existing Courses & semesters -> semester -> Import
   proforma flow. The review now includes an editable assessment percentage. Check
   the PDF, enter deadlines/remaining work, confirm, save, then open Prioritize tasks.
5. Refresh priorities to recalculate using the app clock. About this ranking explains
   the model and its limitations.

The app still uses its fixed DemoClock: 14 October 2026 at 13:00. The ranking screen
displays the reference date and labels that preview clock. It does not silently use
the computer's current date while other screens show the preview date.

## Input contract

| Model input | Flutter mapping |
| --- | --- |
| `days_until_due` | Difference between local calendar dates of deadline and app-clock reference, as whole days. A future time today maps to 0. |
| `remaining_minutes` | `estimatedMinutes - completedMinutes`, greater than 0 and no more than 10080. |
| `assessment_weight_percent` | Separately confirmed `AcademicTask.assessmentWeightPercent`, from 0 to 100. Zero is valid; null means unknown. |

Completed tasks are omitted. Active tasks with a deadline already reached, no work
remaining, unsupported effort, or an unknown/invalid percentage remain visible under
Needs attention with a specific reason. Overdue tasks are not silently clamped to
zero days or presented as low priority. Review them separately.

Tasks outside the observed training feature ranges receive a visible caution. This
is a range check, not a statistical estimate of confidence. Difficulty, importance,
study habits, availability and sleep preferences are not inputs to this model.

The model produces relative scores. Sorting is descending; equal scores share a
dense rank, with task ID used only to stabilize display order. A single eligible
task can be displayed, with guidance to add another for comparison. Scores are not
percentages or probabilities and are not displayed as academic importance.

## Storage and evidence

The nullable assessment percentage is an additive field in the existing task codec.
Old task records load without reset and keep their percentage unknown, even when
they have old extracted source metadata. Saving the field confirms a task value;
clearing it restores unknown. No storage-version bump is required for this optional
field. Course relabelling, completion and other `copyWith` edits preserve it.

During new imports the extracted value prefills an editable field. The review/save
confirmation accepts the reviewed value; it does not establish expert validation.
The original `ProformaSource.assessmentWeight`, excerpt, row identity and fingerprint
are preserved when a task value is corrected. Repeat imports still skip existing
source rows and do not overwrite corrections or progress.

Rankings are transient. They do not reorder stored records, create sessions, write
scores into tasks, retrain the model, or synchronize anything to a server.

## Implementation and verification

- `lib/services/ranking/lambda_mart_model.dart`: limited evaluator for the versioned
  numeric forest export. Rejects incompatible metadata, trees and invalid inputs.
- `lib/services/ranking/task_ranking_service.dart`: input mapping, eligibility,
  prediction, ties and training-range checks. The service contract permits a future
  API implementation without backend SDK types in widgets.
- `lib/features/ranking/`: screen and view model. Task changes immediately discard
  old rankings. Request generations prevent late async responses from restoring
  stale results; model-loading failures have explicit retry and preserve tasks.
- `assets/ranking/provisional_v1.json`: three-tree export of `proforma-v1-003`, with
  source model SHA-256 and no source PDFs, assessment names or training rows.
- `ai/export_flutter_model.py`: hash/schema checks, constrained export and numerical
  parity with LightGBM. Leaves already include the learning rate, so the evaluator
  sums leaf values without applying a second shrinkage multiplier.

The 733 invented grid/boundary inputs in `test/support/ranking_prediction_cases.json`
carry Python reference scores. Dart checks those predictions within `1e-12`.
Tests also cover storage reopen/clearing, corrected import values with original
evidence intact, eligibility, ties, stale requests, retry, navigation, task edits,
completion and small screens with enlarged text. No real user data is changed by tests.

The extraction and ranking datasets still need checking, and independent priority
evaluation remains outstanding. On-device inference parity does not establish model
quality, personalization, improved grades or an optimal schedule. GA scheduling,
Python API, Firebase and physical-device/release evaluation remain later work.

Model format reference: [LightGBM Booster dump and leaf values](https://lightgbm.readthedocs.io/en/stable/pythonapi/lightgbm.Booster.html).
