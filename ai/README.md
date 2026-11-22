# Experimental proforma-derived LambdaMART

Training remains a separate offline Python experiment. Flutter now evaluates an
explicitly exported numerical forest on-device for experimental task ranking.
No Firebase, API, GA scheduling, or survey-based model training is introduced.

The separate scheduling evaluation (test weeks, plan scoring and the
rule-based baseline in `ai/planova_scheduling/`) is described in
`docs/scheduling_evaluation.md`.

## What is real and what is simulated?

| Item | Origin |
| --- | --- |
| Course code, assessment name, assessment weight | Machine-extracted from local proformas; **not manually verified** |
| Source PDF fingerprint, path, page, row excerpt | Recorded provenance; excluded from model features |
| Days until due and remaining minutes | **Simulated**; not document facts or student observations |
| Priority labels 0–3 | **Provisional rule-generated**, not lecturer/student judgments |
| Model scores | Actual predictions of a trained LightGBM LambdaMART model |

The experiment tests whether the pipeline can learn a provisional policy. It does
not establish useful student priorities, personalization, improved grades, or
better real schedules. Generated groups are not additional independent students.
Survey preferences belong to later planner settings, not these training targets.

## Setup and run (PowerShell, project root)

Tested with Python 3.10.4. Use a project-local virtual environment:

```powershell
python -m venv ai/.venv
& ai/.venv/Scripts/python.exe -m pip install -r ai/requirements.txt
& ai/.venv/Scripts/python.exe -m unittest discover -s ai/tests -t ai -v
& ai/.venv/Scripts/python.exe ai/run_experiment.py
```

Default sources: `research/proformas/**/*.pdf`. Timetable.pdf is excluded. Outputs
go to a new UTC-stamped directory under `research/experiments/lambdamart/`, which
is Git-ignored. For a chosen name, append
`--run-dir research/experiments/lambdamart/my-run-02`. Existing directories are
refused rather than overwritten. Inspect `extraction_audit.json` if a run fails;
only a run with `report.json` has completed training and model-reload checks.
Every run reads the original PDFs without modifying or uploading them.

The parser only accepts the bilingual course-info section and complete assessment
rows matching the narrow numeric-column convention. Recognized weights must sum
to 100%. This is an integrity check, **not proof of correct extraction**. Unsupported,
incomplete and ambiguous documents are recorded for review; they are never replaced
by synthetic assessments. Plain pypdf extraction is used; text order/table handling
can still be wrong and no OCR is used.
At least six usable distinct courses are needed for the three multi-course splits.

## Local ranking playground

To try the saved model in a browser, install the optional UI dependencies and start
the local page from the project root:

```powershell
& ai/.venv/Scripts/python.exe -m pip install -r ai/requirements-ui.txt
& ./ai/run_playground.ps1
```

Open http://127.0.0.1:8501. Keep the terminal running; press Ctrl+C there to stop.
If that port is busy, use `& ./ai/run_playground.ps1 -Port 8502` and open port 8502.
The launcher binds to this computer only and disables Streamlit usage statistics.
The optional UI dependency pins are separate from the training requirements.

1. Choose a completed model run. The most recently completed run is selected initially.
2. Double-click task cells to change names, days until due, remaining minutes, or
   assessment weight. Use at least two tasks. Zero days means today.
3. Click **Rank tasks** to compare actual saved-model predictions with the provisional
   teaching rule. Equal ranks represent ties; raw scores are not confidence percentages.
4. Change an input and rank again. Previous results are hidden until recalculated.
   **Load saved test example** loads held-out inputs; **Reset illustrative tasks**
   restores the invented starter list. Optional downloads export the current comparison.

This page does not retrain the model, upload PDFs, update Flutter records, or generate
a schedule. Edits are temporary session data. Proforma upload remains a separate
Flutter workflow; connecting reviewed tasks to a Python service is future work.
The current experiment learned provisional rule labels using simulated deadlines
and effort, so a convincing demonstration is not independent validation.

Run the test command above after installing UI dependencies to include the Streamlit
interaction tests. Those tests skip when the optional dependency or a local model
is unavailable; the core experiment does not require Streamlit.

## Provisional teaching rule v1

All numbers below are engineering choices for this experiment, not university
rules, validated research findings, or supervisor-approved priorities:

```text
urgency = 1 / (simulated_days_until_due + 1)
pressure = min(1, simulated_remaining_minutes / ((simulated_days_until_due + 1) * 240))
score = 0.60 * urgency + 0.25 * assessment_weight_percent / 100 + 0.15 * pressure
label = number of thresholds reached: [0.15, 0.35, 0.65]  # 0, 1, 2 or 3
```

The 240-minute pressure scale is a synthetic normalization, **not a student's daily
study limit**. Label ties remain ties. Scenarios with no label variation are rejected
and counted. No exact deadlines, difficulty, personal importance, sleep times, or
remaining effort are inferred from a proforma's SLT columns.

Model features are explicitly allow-listed in `dataset.FEATURES`. The model sees
days-until-due, remaining minutes and assessment weight. It never sees the teaching
score, priority label, IDs, course code, PDF path, or participant information as inputs.
The policy and model settings live in `configs/provisional_v1.json`.

## Evaluation and limits

1. Split **courses before generating scenarios**. All documents/versions of one course
   stay in one partition; normalized-byte-identical PDFs are deduplicated.
2. Build independent cross-course candidate groups within each partition. Preserve
   whole groups for fitting; never randomly split task rows from a group.
3. Use validation groups for early stopping. Test groups are evaluated after training.
4. Report mean NDCG@3 (gain `2**label - 1`) against the **provisional labels**.
   Prediction ties use expected gain across tied positions, avoiding display-order bias.
5. Compare with earliest-deadline and assessment-weight baselines. Include the teaching
   rule as a reference: its agreement is expected to be perfect because it creates labels.
6. Save/reload the model and require equivalent predictions before completing the run.

These are rule-imitation checks, not independent evidence of ranking quality.
Related templates and synthetic contexts further limit generalization claims.
Do not tune on the final test results. Later work needs manually checked source
fields, an agreed labelling procedure, independently reviewed evaluation cases,
and realistic deadlines/effort before app integration.

## Outputs and prediction

- `config.json`, `course_splits.json`: settings and disjoint course membership.
- `extraction_audit.json`, `extracted_assessments.csv`: source records and exclusions.
- `scenario_tasks.csv`: all simulated contexts, provenance and provisional labels.
- `model.txt`: trained LightGBM text model (no pickle).
- `report.json`, `SUMMARY.md`: counts, metrics, versions, hashes and limitations.
- `code_snapshot/`: the implementation and pinned dependencies used for that run.
- `test_predictions.csv`, `example_tasks.json`: held-out scores and label-free inference example.

```powershell
& ai/.venv/Scripts/python.exe ai/predict.py `
  --run-dir research/experiments/lambdamart/proforma-v1-003 `
  --tasks research/experiments/lambdamart/proforma-v1-003/example_tasks.json
```

Custom input is a JSON array of tasks with unique `task_id` strings and the three
numeric feature fields. Days must be non-negative, remaining minutes in (0, 10080],
and assessment weight in [0, 100]. Scores are relative ranking values, not percentages
or probabilities; equal scores keep equal ranks. This first feature schema does not
handle overdue negative offsets or unknown inputs: it rejects them explicitly.

## Flutter export

`export_flutter_model.py` checks the saved model hash and feature schema, rejects
unsupported tree/model configurations, and exports only the numerical forest and
model metadata. It does not bundle PDF paths, assessment names, or research rows.

```powershell
& ai/.venv/Scripts/python.exe ai/export_flutter_model.py `
  --run-dir research/experiments/lambdamart/proforma-v1-003 `
  --output assets/ranking/provisional_v1.json `
  --cases-output test/support/ranking_prediction_cases.json
```

The committed outputs already exist; this command refuses to overwrite them. For
a later model, use new paths, review the export, update the app's asset selection,
and rerun parity tests. Never overwrite the saved experiment to publish a new model.

The exporter compares its evaluation with LightGBM on invented grid and split-boundary
inputs. Dart then checks the exported forest against those Python reference scores
with absolute tolerance `1e-12`. The current export has three trees and 733 reference
inputs. These checks establish inference parity, not useful academic recommendations.
See [the Flutter contract and usage](../docs/task_ranking.md).

## References

- [LightGBM ranker and grouped fitting](https://lightgbm.readthedocs.io/en/stable/pythonapi/lightgbm.LGBMRanker.html)
- [pypdf layout extraction and limitations](https://pypdf.readthedocs.io/en/stable/user/extract-text.html)
