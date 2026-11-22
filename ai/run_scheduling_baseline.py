"""Scores the app's rule-based planner on every test week (project root):

    & ai/.venv/Scripts/python.exe ai/run_scheduling_baseline.py
    & ai/.venv/Scripts/python.exe ai/run_scheduling_baseline.py --set test --save

--save writes report.json to a new UTC-stamped folder under
research/experiments/scheduling/ (Git-ignored); existing folders are refused.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from planova_scheduling.baseline import plan_week  # noqa: E402
from planova_scheduling.metrics import score, violations  # noqa: E402
from planova_scheduling.scenario import load_all  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
COLUMNS = [
    ("due_placed_pct", "due placed %"),
    ("missed_minutes", "missed min"),
    ("continues_later_minutes", "later min"),
    ("max_day_minutes", "max day"),
    ("day_std_minutes", "day std"),
    ("last_minute_pct", "last 24h %"),
    ("sessions", "sessions"),
]


def evaluate(set_name: str | None) -> list[dict]:
    rows = []
    for scenario in load_all(set_name=set_name):
        began = time.perf_counter()
        plan = plan_week(scenario)
        elapsed = (time.perf_counter() - began) * 1000
        rows.append({
            "scenario": scenario.id,
            "set": scenario.set,
            "planner": "rule_based_baseline",
            "violations": violations(scenario, plan),
            "runtime_ms": round(elapsed, 2),
            **score(scenario, plan),
        })
    return rows


def table(rows: list[dict]) -> str:
    head = f"{'scenario':<26}" + "".join(f"{label:>14}" for _, label in COLUMNS)
    lines = [head, "-" * len(head)]
    for row in rows:
        lines.append(f"{row['scenario']:<26}" + "".join(f"{row[key]:>14}" for key, _ in COLUMNS))
    for set_name in ("development", "test"):
        group = [r for r in rows if r["set"] == set_name]
        if group:
            lines.append(f"{'mean (' + set_name + ')':<26}" + "".join(
                f"{round(statistics.mean(r[key] for r in group), 1):>14}" for key, _ in COLUMNS))
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--set", choices=["development", "test"], default=None)
    parser.add_argument("--save", action="store_true")
    args = parser.parse_args(argv)

    rows = evaluate(args.set)
    print(table(rows))
    broken = [r for r in rows if r["violations"]]
    print(f"\n{len(rows)} weeks, {len(broken)} with hard-rule violations. "
          "All weeks are synthetic.")
    if args.save:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        out = ROOT / "research" / "experiments" / "scheduling" / f"baseline-{stamp}"
        out.mkdir(parents=True, exist_ok=False)
        (out / "report.json").write_text(json.dumps({
            "planner": "rule_based_baseline",
            "note": "Synthetic test weeks; the baseline is the app's planner.",
            "rows": rows,
        }, indent=2) + "\n", encoding="utf-8")
        print(f"Saved {out / 'report.json'}")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
