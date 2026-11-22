"""Compares the GA with the rule-based baseline over repeated runs (project root):

    & ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set development --seeds 10
    & ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set test --seeds 30 --save

Tune GA settings on the development set only; run the test set once with the
chosen settings. Each GA run uses its own seed (0, 1, ...), so results are
repeatable. --save writes report.json to a new UTC-stamped folder under
research/experiments/scheduling/ (Git-ignored).
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from concurrent.futures import ProcessPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from planova_scheduling.baseline import plan_week  # noqa: E402
from planova_scheduling.ga import GAConfig, run_ga  # noqa: E402
from planova_scheduling.metrics import score, violations  # noqa: E402
from planova_scheduling.objective import Weights, evaluate  # noqa: E402
from planova_scheduling.scenario import load_all  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SHOWN = ["due_placed_pct", "missed_minutes", "last_minute_pct", "day_std_minutes",
         "max_day_minutes", "sessions"]


def _one(job):
    scenario, seed, config, weights = job
    result = run_ga(scenario, seed, config, weights)
    return {
        "seed": seed,
        "fitness": result.fitness,
        "violations": violations(scenario, result.plan),
        "runtime_ms": result.runtime_ms,
        "evaluations": result.evaluations,
        **score(scenario, result.plan),
    }


def quartiles(values):
    if len(values) < 2:
        return values[0], values[0], values[0]
    q = statistics.quantiles(values, n=4, method="inclusive")
    return q[0], statistics.median(values), q[2]


def compare(set_name, seeds, config, weights, workers):
    scenarios = load_all(set_name=set_name)
    jobs = [(s, seed, config, weights) for s in scenarios for seed in range(seeds)]
    with ProcessPoolExecutor(max_workers=workers) as pool:
        runs = list(pool.map(_one, jobs))
    rows = []
    for k, scenario in enumerate(scenarios):
        mine = runs[k * seeds:(k + 1) * seeds]
        base_plan = plan_week(scenario)
        base_fitness, _ = evaluate(scenario, base_plan, weights)
        fit = [r["fitness"] for r in mine]
        rows.append({
            "scenario": scenario.id,
            "baseline": {"fitness": round(base_fitness, 1), **score(scenario, base_plan)},
            "ga_fitness_q1_median_q3": [round(v, 1) for v in quartiles(fit)],
            "ga_median": {m: statistics.median(r[m] for r in mine) for m in SHOWN},
            "ga_not_worse_pct": round(100 * sum(f <= base_fitness + 1e-9 for f in fit) / len(fit), 1),
            "ga_violating_runs": sum(1 for r in mine if r["violations"]),
            "ga_median_runtime_ms": statistics.median(r["runtime_ms"] for r in mine),
            "runs": mine,
        })
    return rows


def wilcoxon(rows):
    try:
        from scipy.stats import wilcoxon as test
    except ImportError:  # pragma: no cover
        return None
    base = [r["baseline"]["fitness"] for r in rows]
    ga = [r["ga_fitness_q1_median_q3"][1] for r in rows]
    diffs = [b - g for b, g in zip(base, ga) if abs(b - g) > 1e-9]
    if len(diffs) < 2:
        return {"n_nonzero": len(diffs), "p_value": None}
    stat = test(diffs, alternative="greater")
    return {"n_nonzero": len(diffs), "statistic": float(stat.statistic),
            "p_value": round(float(stat.pvalue), 4)}


def print_table(rows):
    print(f"{'scenario':<26}{'base fit':>11}{'GA median':>11}{'GA IQR':>21}{'not worse':>11}"
          f"{'day std b/GA':>15}{'24h% b/GA':>12}{'missed b/GA':>13}{'ms':>7}")
    def pair(b, g, key):
        return f"{round(b[key])}/{round(g[key])}"

    for r in rows:
        q1, med, q3 = r["ga_fitness_q1_median_q3"]
        b, g = r["baseline"], r["ga_median"]
        iqr = f"{q1:.0f}-{q3:.0f}"
        print(f"{r['scenario']:<26}{b['fitness']:>11.1f}{med:>11.1f}{iqr:>21}"
              f"{r['ga_not_worse_pct']:>10.0f}%"
              f"{pair(b, g, 'day_std_minutes'):>15}{pair(b, g, 'last_minute_pct'):>12}"
              f"{pair(b, g, 'missed_minutes'):>13}{r['ga_median_runtime_ms']:>7.0f}")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--set", choices=["development", "test"], required=True)
    parser.add_argument("--seeds", type=int, default=10)
    parser.add_argument("--population", type=int)
    parser.add_argument("--generations", type=int)
    parser.add_argument("--seed-priority-order", action="store_true")
    parser.add_argument("--workers", type=int, default=None)
    parser.add_argument("--save", action="store_true")
    args = parser.parse_args(argv)

    config = GAConfig()
    if args.population:
        config = replace(config, population=args.population)
    if args.generations:
        config = replace(config, generations=args.generations)
    if args.seed_priority_order:
        config = replace(config, seed_with_priority_order=True)
    weights = Weights()

    rows = compare(args.set, args.seeds, config, weights, args.workers)
    print_table(rows)
    test = wilcoxon(rows)
    bad = sum(r["ga_violating_runs"] for r in rows)
    print(f"\n{args.set} set, {args.seeds} GA runs per week. Runs breaking a hard rule: {bad}.")
    print(f"Wilcoxon signed-rank (baseline fitness > GA median, one-sided): {test}")
    print("All weeks are synthetic. Lower fitness is better.")
    if args.save:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        out = ROOT / "research" / "experiments" / "scheduling" / f"ga-{args.set}-{stamp}"
        out.mkdir(parents=True, exist_ok=False)
        (out / "report.json").write_text(json.dumps({
            "set": args.set, "seeds": args.seeds, "ga_config": config.to_json(),
            "weights": weights.to_json(), "wilcoxon": test, "rows": rows,
            "note": "Synthetic test weeks; the baseline is the app's planner.",
        }, indent=2) + "\n", encoding="utf-8")
        print(f"Saved {out / 'report.json'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
