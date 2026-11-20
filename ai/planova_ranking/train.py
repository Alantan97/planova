"""One reproducible offline experiment, with auditable private outputs."""

from __future__ import annotations

import csv
import hashlib
import json
import platform
import shutil
from datetime import datetime, timezone
from importlib.metadata import version
from pathlib import Path

import lightgbm as lgb
import numpy as np

from .dataset import FEATURES, feature_matrix, generate_scenarios, grouped, ndcg, split_courses
from .extract import extract_directory


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def training_arrays(rows):
    groups = grouped(rows)
    ordered = [row for group in groups for row in group]
    return feature_matrix(ordered), np.asarray([r["priority_label"] for r in ordered]), [len(g) for g in groups]


def evaluate(model, rows):
    values = {"model_ndcg_at_3": [], "earliest_deadline_ndcg_at_3": [],
              "assessment_weight_ndcg_at_3": [], "teacher_rule_ndcg_at_3": []}
    for group in grouped(rows):
        labels = [r["priority_label"] for r in group]
        predictions = {
            "model_ndcg_at_3": model.predict(feature_matrix(group)),
            "earliest_deadline_ndcg_at_3": [-r["days_until_due"] for r in group],
            "assessment_weight_ndcg_at_3": [r["assessment_weight_percent"] for r in group],
            "teacher_rule_ndcg_at_3": [r["teacher_score"] for r in group],
        }
        for name, scores in predictions.items():
            values[name].append(ndcg(labels, scores))
    return {name: float(np.mean(scores)) for name, scores in values.items()}


def run(project_root: Path, config_path: Path, run_dir: Path | None = None) -> Path:
    project_root = project_root.resolve()
    config = json.loads(config_path.read_text(encoding="utf-8"))
    private_root = (project_root / "research/experiments/lambdamart").resolve()
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    run_dir = (run_dir or private_root / timestamp).resolve()
    if not run_dir.is_relative_to(private_root):
        raise ValueError("Outputs must stay inside research/experiments/lambdamart (Git-ignored)")
    run_dir.mkdir(parents=True, exist_ok=False)
    write_json(run_dir / "config.json", config)
    code_files = [*(project_root / "ai/planova_ranking").glob("*.py"),
                  project_root / "ai/run_experiment.py", project_root / "ai/predict.py",
                  project_root / "ai/requirements.txt"]
    for source in code_files:
        target = run_dir / "code_snapshot" / source.relative_to(project_root / "ai")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    records, audit = extract_directory(project_root)
    write_json(run_dir / "extraction_audit.json", audit)
    write_csv(run_dir / "extracted_assessments.csv", records)
    splits = split_courses(records, config["seed"])
    write_json(run_dir / "course_splits.json", splits)
    rows, rejected = generate_scenarios(records, splits, config)
    write_csv(run_dir / "scenario_tasks.csv", rows)
    partitions = {name: [r for r in rows if r["split"] == name] for name in splits}
    train_x, train_y, train_groups = training_arrays(partitions["train"])
    val_x, val_y, val_groups = training_arrays(partitions["validation"])
    params = config["model"]
    model = lgb.LGBMRanker(
        objective="lambdarank", metric="ndcg", n_estimators=params["n_estimators"],
        learning_rate=params["learning_rate"], num_leaves=params["num_leaves"],
        min_child_samples=params["min_child_samples"], random_state=config["seed"],
        n_jobs=1, verbosity=-1, deterministic=True, force_col_wise=True,
    )
    model.fit(train_x, train_y, group=train_groups, eval_X=val_x, eval_y=val_y,
              eval_group=[val_groups], eval_at=[3], feature_name=FEATURES,
              callbacks=[lgb.early_stopping(params["early_stopping_rounds"], verbose=False)])
    model_path = run_dir / "model.txt"
    model.booster_.save_model(str(model_path))
    restored = lgb.Booster(model_file=str(model_path))
    test_x = feature_matrix(partitions["test"])
    if not np.allclose(model.booster_.predict(test_x), restored.predict(test_x), rtol=0, atol=1e-12):
        raise RuntimeError("Reloaded model predictions differ")
    scores = restored.predict(test_x)
    write_csv(run_dir / "test_predictions.csv", [
        {**row, "predicted_score": float(score)} for row, score in zip(partitions["test"], scores)
    ])
    example = grouped(partitions["test"])[0]
    write_json(run_dir / "example_tasks.json", [
        {"task_id": r["task_id"], **{name: r[name] for name in FEATURES}} for r in example
    ])
    metrics = {name: evaluate(restored, partitions[name]) for name in ("validation", "test")}
    report = {
        "status": "experimental_rule_imitation_not_validated_student_priority",
        "experiment_version": config["experiment_version"], "created_at_utc": timestamp,
        "features": FEATURES, "label_source": config["label_policy"]["version"],
        "extraction_status": "machine_extracted_unverified",
        "documents_included": sum(a["status"] == "included_unverified" for a in audit),
        "documents_needing_review": sum(a["status"] == "needs_review" for a in audit),
        "distinct_courses": len({r["course_code"] for r in records}),
        "source_assessments": len(records),
        "splits": {name: {"courses": codes, "groups": len(grouped(partitions[name])),
                           "simulated_task_rows": len(partitions[name])} for name, codes in splits.items()},
        "rejected_all_tied_scenarios": rejected, "best_iteration": model.best_iteration_,
        "model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "dataset_sha256": hashlib.sha256((run_dir / "scenario_tasks.csv").read_bytes()).hexdigest(),
        "versions": {name: version(name) for name in ("lightgbm", "numpy", "scikit-learn", "pypdf")},
        "python_version": platform.python_version(), "platform": platform.platform(),
        "code_sha256": {
            path.relative_to(project_root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(code_files)
        },
        "metrics": metrics,
        "limitations": [
            "Metrics measure agreement with provisional labels, not independently judged priorities.",
            "The teacher rule defines the labels; its own agreement is expected to be perfect.",
            "Deadline offsets and remaining effort are simulated, not extracted or student-observed.",
            "Source fields remain machine-unverified; the audit excludes incomplete table totals.",
            "Course-disjoint splits do not establish generalization to new university templates.",
            "No survey training labels, personalization, grade improvement, scheduling or app integration.",
        ],
    }
    write_json(run_dir / "report.json", report)
    (run_dir / "SUMMARY.md").write_text(
        "# Experimental training run\n\n"
        f"Included {report['documents_included']} proformas, {report['distinct_courses']} distinct courses "
        f"and {len(records)} machine-extracted assessment rows. "
        f"{report['documents_needing_review']} proformas need manual review and were excluded.\n\n"
        "## Simulated planning groups\n\n"
        + "\n".join(f"- {name}: {details['groups']} groups, {details['simulated_task_rows']} task rows, "
                    f"{len(details['courses'])} courses" for name, details in report['splits'].items())
        + "\n\n## Held-out agreement with the provisional teaching rule\n\n"
        + "\n".join(f"- {name}: {value:.4f}" for name, value in metrics['test'].items())
        + "\n\nHigher NDCG@3 means closer agreement with the rule-generated labels. "
        "These are not accuracy percentages or independent academic-priority judgments. "
        "The rule's own score of 1 is expected because it creates the labels.\n\n"
        + "\n".join(f"- {limitation}" for limitation in report['limitations'])
        + "\n\nModel save/reload equivalence was checked. See extraction_audit.json for every "
        "source inclusion/exclusion, scenario_tasks.csv for provenance, and code_snapshot/ "
        "for this run's implementation/dependency snapshot.\n", encoding="utf-8")
    print(json.dumps({"run_directory": str(run_dir), "source_assessments": len(records),
                      "distinct_courses": report["distinct_courses"], "test_rule_agreement": metrics["test"],
                      "status": report["status"]}, indent=2))
    return run_dir
