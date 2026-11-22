import json
import unittest
from dataclasses import replace

import export_ga_golden
from planova_scheduling.rng import Rng

from planova_scheduling.baseline import plan_week
from planova_scheduling.ga import Decoder, GAConfig, run_ga
from planova_scheduling.metrics import violations
from planova_scheduling.objective import Context, Weights, evaluate, evaluate_sessions
from planova_scheduling.scenario import SCENARIO_DIR, load, load_all

# Small budget: these tests check behaviour, not search quality.
QUICK = GAConfig(population=12, generations=15)
QUICK_RANDOM = replace(QUICK, start_from_baseline=False)


def week(name):
    return load(SCENARIO_DIR / f"{name}.json")


class Decoding(unittest.TestCase):
    def test_baseline_plan_is_reachable_on_every_week(self):
        for scenario in load_all():
            with self.subTest(scenario.id):
                baseline = plan_week(scenario)
                decoder = Decoder(Context(scenario))
                order, days = decoder.encode(baseline)
                self.assertEqual(sorted(order), list(range(len(decoder.turns))))
                decoded = decoder.to_plan(decoder.decode(order, days))
                self.assertEqual(decoded.to_json(), baseline.to_json())

    def test_enough_turns_for_all_work(self):
        decoder = Decoder(Context(week("t06-long-tasks-later")))
        # 1200, 720 and 90 minutes at a 30-minute minimum.
        self.assertEqual(len(decoder.turns), 40 + 24 + 3)


class GARuns(unittest.TestCase):
    def test_every_ga_plan_keeps_the_hard_rules(self):
        for scenario in load_all():
            for config in (QUICK, QUICK_RANDOM):
                with self.subTest(scenario.id, baseline_start=config.start_from_baseline):
                    result = run_ga(scenario, seed=1, config=config)
                    self.assertEqual(violations(scenario, result.plan), [])

    def test_baseline_start_is_never_worse_than_the_baseline(self):
        for scenario in load_all():
            with self.subTest(scenario.id):
                base, _ = evaluate(scenario, plan_week(scenario))
                self.assertLessEqual(run_ga(scenario, seed=4, config=QUICK).fitness, base + 1e-9)

    def test_same_seed_same_plan(self):
        scenario = week("d02-normal-week")
        a = run_ga(scenario, seed=7, config=QUICK_RANDOM)
        b = run_ga(scenario, seed=7, config=QUICK_RANDOM)
        self.assertEqual(a.plan.to_json(), b.plan.to_json())
        self.assertEqual(a.fitness, b.fitness)

    def test_best_fitness_never_gets_worse(self):
        history = run_ga(week("d04-heavy-commitments"), seed=3, config=QUICK_RANDOM).history
        self.assertEqual(history, sorted(history, reverse=True))

    def test_reported_fitness_matches_the_plan(self):
        scenario = week("d05-weekend-off")
        result = run_ga(scenario, seed=2, config=QUICK_RANDOM)
        self.assertAlmostEqual(evaluate(scenario, result.plan)[0], result.fitness, places=6)

    def test_needs_input_tasks_are_reported_not_planned(self):
        plan = run_ga(week("d08-needs-input"), seed=0, config=QUICK).plan
        self.assertFalse({"t2", "t3", "t4", "t5"} & {s.task_id for s in plan.sessions})
        reasons = {u.task_id: u.reason.value for u in plan.unplaced}
        self.assertEqual(reasons["t2"], "needsDueDate")
        self.assertEqual(reasons["t3"], "overdue")


class SharedWithDart(unittest.TestCase):
    def test_random_numbers_match_the_dart_generator(self):
        # Same values are checked in test/services/planning/ga_planner_test.dart.
        a, b = Rng(0), Rng(42)
        self.assertEqual([a.next_u32() for _ in range(3)], [2831543865, 3042595768, 445164014])
        self.assertEqual([b.next_u32() for _ in range(3)], [289363370, 2328323471, 2829082676])

    def test_saved_ga_plans_are_up_to_date(self):
        # The app's Dart GA must reproduce these files exactly.
        results = export_ga_golden.compute_all()
        self.assertEqual(sorted(results), sorted(p.stem for p in SCENARIO_DIR.glob("*.json")))
        for scenario_id, plan in results.items():
            with self.subTest(scenario_id):
                saved = json.loads((export_ga_golden.OUT / f"{scenario_id}.json")
                                   .read_text(encoding="utf-8"))
                self.assertEqual(saved, plan)


class Objective(unittest.TestCase):
    def test_missed_deadline_work_outweighs_everything_else(self):
        scenario = week("d01-light-week")
        ctx = Context(scenario)
        full, _ = evaluate(scenario, plan_week(scenario), Weights(), ctx)
        nothing, parts = evaluate_sessions(ctx, [], Weights())
        self.assertGreater(nothing, full)
        self.assertEqual(parts["missed_minutes"], 210)

    def test_buffer_counts_minutes_ending_within_a_day_of_the_deadline(self):
        ctx = Context(week("d01-light-week"))
        due = ctx.due["t1"]
        _, parts = evaluate_sessions(ctx, [("t1", due - 120, 60)], Weights())
        self.assertEqual(parts["buffer_minutes"], 60)
        _, parts = evaluate_sessions(ctx, [("t1", due - 26 * 60, 60)], Weights())
        self.assertEqual(parts["buffer_minutes"], 0)


if __name__ == "__main__":
    unittest.main()
