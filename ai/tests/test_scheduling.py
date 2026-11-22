import dataclasses
import json
import unittest
from datetime import timedelta

import build_scenarios
from planova_scheduling.baseline import plan_week
from planova_scheduling.metrics import score, violations
from planova_scheduling.plan import Session
from planova_scheduling.scenario import EXPECTED_DIR, SCENARIO_DIR, load, load_all


def by_id(scenario_id):
    return load(SCENARIO_DIR / f"{scenario_id}.json")


class ScenarioFiles(unittest.TestCase):
    def test_files_match_the_builder(self):
        built = {s["id"]: s for s in build_scenarios.SCENARIOS}
        saved = sorted(SCENARIO_DIR.glob("*.json"))
        self.assertEqual(sorted(built), [p.stem for p in saved])
        for path in saved:
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), built[path.stem])

    def test_both_sets_are_present_and_synthetic(self):
        scenarios = load_all()
        self.assertGreaterEqual(len(load_all(set_name="development")), 6)
        self.assertGreaterEqual(len(load_all(set_name="test")), 6)
        self.assertTrue(all(s.synthetic for s in scenarios))


class BaselineMatchesApp(unittest.TestCase):
    """The Python baseline must equal the Dart planner's saved plans."""

    def test_every_week_matches_the_dart_planner(self):
        scenarios = load_all()
        self.assertTrue(scenarios)
        for scenario in scenarios:
            with self.subTest(scenario.id):
                expected = json.loads(
                    (EXPECTED_DIR / f"{scenario.id}.json").read_text(encoding="utf-8"))
                self.assertEqual(plan_week(scenario).to_json(), expected)

    def test_every_baseline_plan_keeps_the_hard_rules(self):
        for scenario in load_all():
            with self.subTest(scenario.id):
                self.assertEqual(violations(scenario, plan_week(scenario)), [])


class RuleChecks(unittest.TestCase):
    def setUp(self):
        self.scenario = by_id("d02-normal-week")
        self.plan = plan_week(self.scenario)

    def broken(self, **changes):
        first = dataclasses.replace(self.plan.sessions[0], **changes)
        plan = dataclasses.replace(self.plan, sessions=(first,) + self.plan.sessions[1:])
        return violations(self.scenario, plan)

    def assertFlags(self, problems, text):
        self.assertTrue(any(text in p for p in problems), problems)

    def test_too_long(self):
        self.assertFlags(self.broken(minutes=90), "length")

    def test_outside_free_time(self):
        start = self.plan.sessions[0].start.replace(hour=3, minute=0)
        self.assertFlags(self.broken(start=start), "not inside free study time")

    def test_after_deadline(self):
        late = dataclasses.replace(
            self.plan, sessions=self.plan.sessions + (
                Session("t1", self.plan.start + timedelta(days=5, hours=8), 30),))
        self.assertFlags(violations(self.scenario, late), "after the deadline")

    def test_overlap(self):
        first = self.plan.sessions[0]
        twin = Session("t2", first.start, first.minutes)
        plan = dataclasses.replace(self.plan, sessions=self.plan.sessions + (twin,))
        self.assertFlags(violations(self.scenario, plan), "overlaps")

    def test_unknown_task(self):
        self.assertFlags(self.broken(task_id="nope"), "not plannable")


class Scores(unittest.TestCase):
    def test_impossible_week_reports_missed_work(self):
        scenario = by_id("d06-impossible-workload")
        result = score(scenario, plan_week(scenario))
        self.assertGreater(result["missed_minutes"], 0)
        self.assertLess(result["due_placed_pct"], 100)
        self.assertEqual(result["missed_minutes"],
                         result["due_minutes"] * (100 - result["due_placed_pct"]) / 100)

    def test_no_free_time_places_nothing(self):
        scenario = by_id("t08-no-free-time")
        result = score(scenario, plan_week(scenario))
        self.assertEqual(result["placed_minutes"], 0)
        self.assertEqual(result["usable_days"], 0)

    def test_needs_input_tasks_are_counted_not_planned(self):
        scenario = by_id("d08-needs-input")
        plan = plan_week(scenario)
        self.assertEqual(score(scenario, plan)["needs_input_tasks"], 2)
        self.assertFalse({"t2", "t3", "t4", "t5"} & {s.task_id for s in plan.sessions})

    def test_days_off_are_not_usable(self):
        scenario = by_id("d05-weekend-off")
        plan = plan_week(scenario)
        self.assertFalse(any(s.start.isoweekday() in (6, 7) for s in plan.sessions))
        self.assertEqual(score(scenario, plan)["usable_days"], 5)


if __name__ == "__main__":
    unittest.main()
