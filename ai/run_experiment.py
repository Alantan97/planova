"""Run from the project root: ai/.venv/Scripts/python.exe ai/run_experiment.py."""

import argparse
from pathlib import Path

from planova_ranking.train import run

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Experimental, provisional-rule LambdaMART training")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--config", type=Path, default=Path(__file__).parent / "configs/provisional_v1.json")
    parser.add_argument("--run-dir", type=Path, help="New directory under research/experiments/lambdamart")
    args = parser.parse_args()
    run(args.project_root, args.config, args.run_dir)
