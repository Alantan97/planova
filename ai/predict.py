"""Rank an explicit candidate set using a saved experimental model."""

import argparse
import hashlib
import json
from pathlib import Path

import lightgbm as lgb

from planova_ranking.dataset import FEATURES, feature_matrix


def predict(run_dir: Path, tasks: list[dict]) -> list[dict]:
    report = json.loads((run_dir / "report.json").read_text(encoding="utf-8"))
    model_path = run_dir / "model.txt"
    if report["features"] != FEATURES or hashlib.sha256(model_path.read_bytes()).hexdigest() != report["model_sha256"]:
        raise ValueError("Model or feature schema differs from this run's manifest")
    ids = [task["task_id"] for task in tasks]
    if len(ids) != len(set(ids)) or any(not isinstance(task_id, str) or not task_id for task_id in ids):
        raise ValueError("Task IDs must be unique, non-empty strings")
    model = lgb.Booster(model_file=str(model_path))
    if model.feature_name() != FEATURES:
        raise ValueError("Saved model feature order is incompatible")
    scores = model.predict(feature_matrix(tasks))
    ordered = sorted(zip(ids, scores), key=lambda item: (-item[1], item[0]))
    # Equal model scores retain an equal dense rank; task ID only stabilizes display.
    output, rank, previous = [], 0, None
    for task_id, score in ordered:
        if previous is None or score != previous:
            rank += 1
        output.append({"task_id": task_id, "rank": rank, "score": float(score),
                       "status": "experimental_provisional_rule_imitation"})
        previous = score
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--tasks", required=True, type=Path)
    args = parser.parse_args()
    candidates = json.loads(args.tasks.read_text(encoding="utf-8"))
    print(json.dumps(predict(args.run_dir, candidates), indent=2, allow_nan=False))
