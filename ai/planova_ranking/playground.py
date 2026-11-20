"""Read-only adapters for the local ranking playground; no training or writes."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

from .dataset import FEATURES, feature_matrix, priority_label, teacher_score


def starter_tasks() -> list[dict]:
    """Illustrative inputs, not extracted deadlines or real student reports."""
    return [
        {"task_name": "Quiz preparation", "days_until_due": 0, "remaining_minutes": 60,
         "assessment_weight_percent": 15.0},
        {"task_name": "Assignment", "days_until_due": 3, "remaining_minutes": 120,
         "assessment_weight_percent": 25.0},
        {"task_name": "Exam preparation", "days_until_due": 21, "remaining_minutes": 240,
         "assessment_weight_percent": 40.0},
    ]


def available_runs(project_root: Path) -> list[Path]:
    directory = project_root / "research/experiments/lambdamart"
    return sorted(
        [path for path in directory.glob("*") if path.is_dir()
         and all((path / name).is_file() for name in ["report.json", "config.json", "model.txt"])],
        key=lambda path: (path / "report.json").stat().st_mtime_ns, reverse=True,
    )


def load_run(run_dir: Path) -> tuple[dict, dict]:
    report = json.loads((run_dir / "report.json").read_text(encoding="utf-8"))
    config = json.loads((run_dir / "config.json").read_text(encoding="utf-8"))
    if report["features"] != FEATURES:
        raise ValueError("This run uses a different input schema. Choose another completed run.")
    if report["label_source"] != config["label_policy"]["version"]:
        raise ValueError("The saved rule version differs from the model report.")
    return report, config


def saved_example(run_dir: Path) -> list[dict]:
    tasks = json.loads((run_dir / "example_tasks.json").read_text(encoding="utf-8"))
    names = {}
    with (run_dir / "test_predictions.csv").open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source):
            names[row["task_id"]] = f"{row['assessment_name']} · {row['course_code']}"
    return [{"task_name": names.get(task["task_id"], f"Example task {i + 1}"),
             **{feature: task[feature] for feature in FEATURES}} for i, task in enumerate(tasks)]


def missing(value) -> bool:
    return value is None or (isinstance(value, float) and math.isnan(value)) or value == ""


def prepare_tasks(rows: list[dict]) -> list[dict]:
    tasks = []
    for index, row in enumerate(rows, 1):
        if all(missing(row.get(name)) for name in ["task_name", *FEATURES]):
            continue
        name = row.get("task_name")
        if not isinstance(name, str) or not name.strip() or len(name.strip()) > 100:
            raise ValueError(f"Row {index}: enter a task name of 1–100 characters.")
        task = {"task_id": f"task-{index}", "task_name": name.strip(),
                **{feature: row.get(feature) for feature in FEATURES}}
        try:
            feature_matrix([task])
        except ValueError as error:
            raise ValueError(f"Row {index}: {error}") from error
        for field in ["days_until_due", "remaining_minutes"]:
            if float(task[field]) != int(task[field]):
                raise ValueError(f"Row {index}: days and minutes must be whole numbers.")
        tasks.append(task)
    if len(tasks) < 2:
        raise ValueError("Enter at least two complete tasks to compare.")
    return tasks


def input_fingerprint(rows: list[dict], run_dir: Path) -> str:
    # Edits and model switches invalidate the visible results, including name edits.
    serialized = json.dumps([str(run_dir.resolve()), rows], sort_keys=True, default=str)
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def compare_tasks(run_dir: Path, tasks: list[dict]) -> dict:
    # Imported here to keep normalization helpers independent of CLI setup.
    from predict import predict

    report, config = load_run(run_dir)
    feature_matrix(tasks)
    predictions = {row["task_id"]: row for row in predict(run_dir, tasks)}
    policy = config["label_policy"]
    rows = []
    for task in tasks:
        score = teacher_score(task, policy)
        rows.append({**task, "model_rank": predictions[task["task_id"]]["rank"],
                     "model_score": predictions[task["task_id"]]["score"],
                     "rule_label": priority_label(score, policy), "rule_score": score})
    labels = sorted({row["rule_label"] for row in rows}, reverse=True)
    for row in rows:
        row["rule_rank"] = labels.index(row["rule_label"]) + 1
    return {"rows": rows, "model_run": run_dir.name, "label_source": report["label_source"]}
