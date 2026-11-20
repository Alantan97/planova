import copy
import hashlib
import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

from planova_ranking.playground import (
    available_runs, compare_tasks, input_fingerprint, prepare_tasks, starter_tasks,
)

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "research/experiments/lambdamart/proforma-v1-003"
HAS_STREAMLIT = importlib.util.find_spec("streamlit") is not None


class PlaygroundInputTests(unittest.TestCase):
    def test_names_are_display_only_and_repeated_assessment_names_are_allowed(self):
        rows = starter_tasks()
        rows[1]["task_name"] = rows[0]["task_name"]
        tasks = prepare_tasks(rows)
        self.assertEqual(len({task["task_id"] for task in tasks}), 3)
        self.assertEqual(tasks[0]["task_name"], tasks[1]["task_name"])

    def test_partial_rows_invalid_values_and_single_task_are_rejected(self):
        for key, value in [("task_name", ""), ("days_until_due", -1), ("remaining_minutes", 0),
                           ("assessment_weight_percent", 101), ("days_until_due", 0.5),
                           ("remaining_minutes", None), ("days_until_due", float("nan"))]:
            rows = starter_tasks()
            rows[0][key] = value
            with self.assertRaises(ValueError):
                prepare_tasks(rows)
        with self.assertRaisesRegex(ValueError, "at least two"):
            prepare_tasks(starter_tasks()[:1])
        self.assertEqual(len(prepare_tasks([*starter_tasks(), {}])), 3)

    def test_every_input_edit_and_model_switch_invalidates_results(self):
        rows = starter_tasks()
        baseline = input_fingerprint(rows, RUN)
        for field, value in [("task_name", "Changed name"), ("days_until_due", 8),
                             ("remaining_minutes", 90), ("assessment_weight_percent", 20)]:
            changed = copy.deepcopy(rows)
            changed[0][field] = value
            self.assertNotEqual(input_fingerprint(changed, RUN), baseline)
        self.assertNotEqual(input_fingerprint(rows, RUN.parent / "another-run"), baseline)

    @unittest.skipUnless((RUN / "report.json").exists(), "Local trained artifact unavailable")
    def test_real_model_comparison_preserves_saved_training_artifacts(self):
        before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in RUN.iterdir() if path.is_file()}
        result = compare_tasks(RUN, prepare_tasks(starter_tasks()))
        self.assertEqual(len(result["rows"]), 3)
        self.assertEqual([row["rule_label"] for row in result["rows"]], [3, 1, 0])
        after = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in RUN.iterdir() if path.is_file()}
        self.assertEqual(before, after)


@unittest.skipUnless(HAS_STREAMLIT and (RUN / "report.json").exists(), "Install UI dependencies and train a local model")
class PlaygroundUITests(unittest.TestCase):
    def app(self):
        from streamlit.testing.v1 import AppTest
        app = AppTest.from_file(str(ROOT / "ai/playground.py"), default_timeout=20).run()
        self.assertEqual(len(app.exception), 0)
        return app

    def test_rank_change_rerank_and_reset(self):
        app = self.app()
        app.button(key="rank_tasks").click().run()
        self.assertEqual(len(app.exception), 0)
        self.assertEqual(len(app.dataframe), 4)  # editor, two rankings, advanced scores
        app.session_state["tasks_editor_1"] = {"edited_rows": {0: {"days_until_due": 14}},
                                                "added_rows": [], "deleted_rows": []}
        app.run()
        self.assertTrue(any("Click Rank tasks" in info.value for info in app.info))
        self.assertEqual(len(app.dataframe), 1)  # no stale comparison displayed
        # AppTest does not emulate the browser's persistent data-editor delta.
        # Resend the edit on submission, as the actual browser does.
        app.button(key="rank_tasks").click()
        app.session_state["tasks_editor_1"] = {"edited_rows": {0: {"days_until_due": 14}},
                                                "added_rows": [], "deleted_rows": []}
        app.run()
        self.assertEqual(app.session_state["ranking_result"]["rows"][0]["days_until_due"], 14)
        app.button(key="reset_tasks").click().run()
        self.assertEqual(len(app.exception), 0)
        self.assertEqual(len(app.dataframe), 1)
        self.assertEqual(app.session_state["input_rows"][0]["days_until_due"], 0)

    def test_saved_example_and_validation(self):
        app = self.app()
        app.button(key="load_example").click().run()
        self.assertEqual(len(app.exception), 0)
        self.assertEqual(len(app.session_state["input_rows"]), 6)
        version = app.session_state["editor_version"]
        app.session_state[f"tasks_editor_{version}"] = {
            "edited_rows": {}, "added_rows": [], "deleted_rows": [0, 1, 2, 3, 4],
        }
        app.run()
        self.assertTrue(app.button(key="rank_tasks").disabled)
        self.assertTrue(any("at least two" in error.value for error in app.error))

    def test_model_switch_hides_old_results(self):
        app = self.app()
        runs = available_runs(ROOT)
        if len(runs) < 2:
            self.skipTest("Only one completed model exists")
        app.button(key="rank_tasks").click().run()
        app.selectbox(key="model_run").select(runs[1]).run()
        self.assertEqual(len(app.exception), 0)
        self.assertTrue(any("model changed" in info.value for info in app.info))
        self.assertEqual(len(app.dataframe), 1)

    def test_missing_models_show_guidance_without_traceback(self):
        from streamlit.testing.v1 import AppTest
        with patch("planova_ranking.playground.available_runs", return_value=[]):
            app = AppTest.from_file(str(ROOT / "ai/playground.py"), default_timeout=20).run()
        self.assertEqual(len(app.exception), 0)
        self.assertTrue(any("No completed model" in error.value for error in app.error))


if __name__ == "__main__":
    unittest.main()
