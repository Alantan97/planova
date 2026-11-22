"""Saves the GA's plan for every test week as the reference for the app.

    & ai/.venv/Scripts/python.exe ai/export_ga_golden.py          # rewrite
    & ai/.venv/Scripts/python.exe ai/export_ga_golden.py --check  # compare

Writes ai/scenarios/expected_ga/<week>.json using the default GA settings
(the ones the app uses) and seed 0. The Dart GA test
(test/services/planning/ga_planner_test.dart) must reproduce these plans and
fitness values exactly, so the app runs the same GA that was evaluated.
Rewrite only after an intended GA change, then re-run both test suites.
"""

from __future__ import annotations

import argparse
import json
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from planova_scheduling.ga import GAConfig, run_ga  # noqa: E402
from planova_scheduling.scenario import SCENARIO_DIR, load  # noqa: E402

OUT = SCENARIO_DIR / "expected_ga"
SEED = 0


def golden(path: Path) -> tuple[str, dict]:
    scenario = load(path)
    config = GAConfig()
    result = run_ga(scenario, SEED, config)
    return scenario.id, {
        "seed": SEED,
        "population": config.population,
        "generations": config.generations,
        "startFromBaseline": config.start_from_baseline,
        "fitness": result.fitness,
        **result.plan.to_json(),
    }


def compute_all(workers: int | None = None) -> dict[str, dict]:
    paths = sorted(SCENARIO_DIR.glob("*.json"))
    with ProcessPoolExecutor(max_workers=workers) as pool:
        return dict(pool.map(golden, paths))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    results = compute_all()
    if args.check:
        stale = [sid for sid, plan in results.items()
                 if not (OUT / f"{sid}.json").exists()
                 or json.loads((OUT / f"{sid}.json").read_text(encoding="utf-8")) != plan]
        print("All saved GA plans match." if not stale else f"Out of date: {stale}")
        return 1 if stale else 0
    OUT.mkdir(exist_ok=True)
    for sid, plan in results.items():
        (OUT / f"{sid}.json").write_text(json.dumps(plan, indent=2) + "\n",
                                         encoding="utf-8", newline="\n")
    print(f"Wrote {len(results)} GA plans to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
