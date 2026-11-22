import unittest

from planova_scheduling.baseline import plan_week
from planova_scheduling.ga import GAConfig, chunk_sizes, run_ga
from planova_scheduling.metrics import violations
from planova_scheduling.objective import Context, Weights, evaluate, evaluate_sessions
from planova_scheduling.scenario import SCENARIO_DIR, load, load_all

# Small budget: these tests check behaviour, not search quality.
QUICK = GAConfig(population=12, generations=15)


class Chunks(unittest.TestCase):
    def test_even_chunks_within_limits(self):
        self.assertEqual(chunk_sizes(270, 30, 60), [54, 54, 54, 54, 54])
        self.assertEqual(chunk_sizes(120, 30, 60), [60, 60])
        self.assertEqual(chunk_sizes(45, 30, 60), [45])

    def test_too_small_or_uneven_work_leaves_a_remainder(self):
        self.assertEqual(chunk_sizes(20, 30, 60), [])
        # 70 cannot be split into pieces of 45-60, so one 60 and 10 left over.
        self.assertEqual(chunk_sizes(70, 45, 60), [60])


class GARuns(unittest.TestCase):
    def test_every_ga_plan_keeps_the_hard_rules(self):
        for scenario in load_all():
            with self.subTest(scenario.id):
                result = run_ga(scenario, seed=1, config=QUICK)
                self.assertEqual(violations(scenario, result.plan), [])

    def test_same_seed_same_plan(self):
        scenario = load(SCENARIO_DIR / "d02-normal-week.json")
        a = run_ga(scenario, seed=7, config=QUICK)
        b = run_ga(scenario, seed=7, config=QUICK)
        self.assertEqual(a.plan.to_json(), b.plan.to_json())
        self.assertEqual(a.fitness, b.fitness)

    def test_best_fitness_never_gets_worse(self):
        scenario = load(SCENARIO_DIR / "d04-heavy-commitments.json")
        history = run_ga(scenario, seed=3, config=QUICK).history
        self.assertEqual(history, sorted(history, reverse=True))

    def test_reported_fitness_matches_the_plan(self):
        scenario = load(SCENARIO_DIR / "d05-weekend-off.json")
        result = run_ga(scenario, seed=2, config=QUICK)
        self.assertAlmostEqual(evaluate(scenario, result.plan)[0], result.fitness, places=6)

    def test_needs_input_tasks_are_reported_not_planned(self):
        scenario = load(SCENARIO_DIR / "d08-needs-input.json")
        plan = run_ga(scenario, seed=0, config=QUICK).plan
        self.assertFalse({"t2", "t3", "t4", "t5"} & {s.task_id for s in plan.sessions})
        reasons = {u.task_id: u.reason.value for u in plan.unplaced}
        self.assertEqual(reasons["t2"], "needsDueDate")
        self.assertEqual(reasons["t3"], "overdue")


class Objective(unittest.TestCase):
    def test_missed_deadline_work_outweighs_everything_else(self):
        scenario = load(SCENARIO_DIR / "d01-light-week.json")
        ctx = Context(scenario)
        weights = Weights()
        full, _ = evaluate(scenario, plan_week(scenario), weights, ctx)
        nothing, parts = evaluate_sessions(ctx, [], weights)
        self.assertGreater(nothing, full)
        self.assertEqual(parts["missed_minutes"], 210)

    def test_buffer_counts_minutes_ending_within_a_day_of_the_deadline(self):
        scenario = load(SCENARIO_DIR / "d01-light-week.json")
        ctx = Context(scenario)
        due = ctx.due["t1"]
        _, parts = evaluate_sessions(ctx, [("t1", due - 120, 60)], Weights())
        self.assertEqual(parts["buffer_minutes"], 60)
        _, parts = evaluate_sessions(ctx, [("t1", due - 26 * 60, 60)], Weights())
        self.assertEqual(parts["buffer_minutes"], 0)


if __name__ == "__main__":
    unittest.main()
