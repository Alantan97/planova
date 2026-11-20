import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import lightgbm as lgb
import numpy as np

from planova_ranking.dataset import (
    FEATURES, feature_matrix, generate_scenarios, ndcg, priority_label,
    split_courses, teacher_score,
)
from planova_ranking.extract import parse_pages
from planova_ranking.train import run, training_arrays
from predict import predict


def configuration():
    config = json.loads((Path(__file__).parents[1] / "configs/provisional_v1.json").read_text(encoding="utf-8"))
    config["scenarios"] = {"train": 4, "validation": 3, "test": 3}
    return config


def fixtures():
    return [
        {"source_document_id": f"document-{course}", "course_code": f"COURSE{course}",
         "assessment_name": f"Example {index}", "assessment_weight_percent": weight,
         "verification_status": "synthetic_unit_test_fixture"}
        for course in range(10) for index, weight in enumerate([15, 25, 20, 40])
    ]


class ExtractionTests(unittest.TestCase):
    def test_explicit_fields_and_repeated_assessment_types_keep_identity(self):
        rows = parse_pages([
            "Maklumat Kursus\nCourse Code: DEQ3093\n",
            "Continuous Assessment Percentage\n1 Quiz 15 0 4 4 8\n"
            "2 Assignment 25 0 2 3 5\n3 Assignment 20 2 8 0 10\nTOTAL 60\n"
            "Final Assessment Percentage\n1 Exam 40 2 10 0 12\nTOTAL 40",
        ], "document", "synthetic.pdf")
        self.assertEqual(len(rows), 4)
        self.assertEqual(rows[1]["assessment_name"], rows[2]["assessment_name"])
        self.assertNotEqual(rows[1]["source_row_id"], rows[2]["source_row_id"])
        self.assertTrue(all(row["source_page"] == 2 for row in rows))
        self.assertTrue(all(row["deadline_status"] == "not_extracted" for row in rows))
        self.assertTrue(all("remaining_minutes" not in row for row in rows))

    def test_incomplete_or_ambiguous_tables_are_rejected(self):
        prefix = "Maklumat Kursus\nCourse Code: DEQ3093\nContinuous Assessment\n"
        for text in [prefix + "1 Quiz 15 0 4 4 8", prefix + "1 Quiz 50 0 4 4 8\n1 Exam 50 0 4 4 8"]:
            with self.assertRaises(ValueError):
                parse_pages([text], "doc", "synthetic.pdf")

    def test_whitespace_changes_do_not_erase_explicit_fields(self):
        rows = parse_pages(["Maklumat    Kursus\nCourse   Code:   DEQ3093\n"
                            "Final Assessment\n1   Exam   100   2 10 0 12\nTOTAL 100"],
                           "doc", "synthetic.pdf")
        self.assertEqual(rows[0]["course_code"], "DEQ3093")
        self.assertEqual(rows[0]["assessment_weight_percent"], 100)


class DatasetTests(unittest.TestCase):
    def test_partition_before_generation_prevents_course_and_source_leakage(self):
        records, config = fixtures(), configuration()
        splits = split_courses(records, config["seed"])
        rows, _ = generate_scenarios(records, splits, config)
        for left, right in [("train", "test"), ("train", "validation"), ("validation", "test")]:
            self.assertFalse(set(splits[left]) & set(splits[right]))
            source_ids = lambda split: {r["source_document_id"] for r in rows if r["split"] == split}
            self.assertFalse(source_ids(left) & source_ids(right))
        self.assertEqual((rows, _), generate_scenarios(records, splits, config))
        self.assertTrue(all(row["context_source"] == "simulated_not_student_observed" for row in rows))

    def test_multiple_document_versions_stay_in_same_course_partition(self):
        records = fixtures()
        records.append({**records[0], "source_document_id": "revised-version"})
        splits = split_courses(records, 123)
        memberships = [name for name, codes in splits.items() if "COURSE0" in codes]
        self.assertEqual(len(memberships), 1)
        rows, _ = generate_scenarios(records, splits, configuration())
        for scenario in {r["scenario_id"] for r in rows}:
            for code in splits[memberships[0]]:
                versions = {r["source_document_id"] for r in rows
                            if r["scenario_id"] == scenario and r["course_code"] == code}
                self.assertLessEqual(len(versions), 1)

    def test_noninformative_policy_cannot_silently_generate_training_groups(self):
        config, records = configuration(), fixtures()
        config["label_policy"]["label_thresholds"] = [2, 3, 4]
        with self.assertRaisesRegex(ValueError, "informative groups"):
            generate_scenarios(records, split_courses(records, 1), config)

    def test_label_and_identifiers_cannot_enter_feature_matrix(self):
        candidate = {"days_until_due": 2, "remaining_minutes": 60, "assessment_weight_percent": 25}
        polluted = {**candidate, "priority_label": 999, "teacher_score": 999, "course_code": "LEAK"}
        np.testing.assert_array_equal(feature_matrix([candidate]), feature_matrix([polluted]))
        for bad in [float("nan"), float("inf"), True, "30", None, -1]:
            with self.assertRaises(ValueError):
                feature_matrix([{**candidate, "days_until_due": bad}])

    def test_urgency_increases_under_fixed_provisional_policy(self):
        policy = configuration()["label_policy"]
        task = {"days_until_due": 0, "remaining_minutes": 120, "assessment_weight_percent": 25}
        later = {**task, "days_until_due": 14}
        self.assertGreater(teacher_score(task, policy), teacher_score(later, policy))
        self.assertGreater(priority_label(teacher_score(task, policy), policy),
                           priority_label(teacher_score(later, policy), policy))

    def test_group_arrays_reorder_complete_groups_together(self):
        def row(group, label):
            return {"scenario_id": group, "priority_label": label, "days_until_due": label,
                    "remaining_minutes": 30, "assessment_weight_percent": 15}
        x, y, sizes = training_arrays([row("a", 2), row("b", 0), row("a", 1)])
        self.assertEqual(sizes, [2, 1])
        self.assertEqual(y.tolist(), [2, 1, 0])
        self.assertEqual(x[:, 0].tolist(), [2, 1, 0])

    def test_ndcg_handles_perfect_reversed_and_tied_predictions(self):
        self.assertAlmostEqual(ndcg([3, 2, 0], [3, 2, 0]), 1)
        self.assertLess(ndcg([3, 2, 0], [0, 2, 3]), 1)
        self.assertAlmostEqual(ndcg([3, 2, 0], [1, 1, 1]), ndcg([0, 3, 2], [1, 1, 1]))
        with self.assertRaises(ValueError):
            ndcg([1], [float("nan")])


class ModelRoundtripTests(unittest.TestCase):
    def test_full_pipeline_validates_stops_saves_reports_and_predicts(self):
        config = configuration()
        config["scenarios"] = {"train": 30, "validation": 3, "test": 3}
        config["model"]["n_estimators"] = 20
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            package = Path(__file__).parents[1]
            for source in [*package.glob("*.py"), package / "requirements.txt",
                           *(package / "planova_ranking").glob("*.py")]:
                target = root / "ai" / source.relative_to(package)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            config_path = root / "config.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            output = root / "research/experiments/lambdamart/test-run"
            audit = [{"status": "included_unverified"} for _ in range(10)]
            with patch("planova_ranking.train.extract_directory", return_value=(fixtures(), audit)):
                run(root, config_path, output)
            report = json.loads((output / "report.json").read_text(encoding="utf-8"))
            self.assertTrue((output / "SUMMARY.md").is_file())
            self.assertEqual(report["features"], FEATURES)
            self.assertEqual(report["splits"]["test"]["groups"], 3)
            self.assertAlmostEqual(report["metrics"]["test"]["teacher_rule_ndcg_at_3"], 1)
            tasks = json.loads((output / "example_tasks.json").read_text(encoding="utf-8"))
            self.assertEqual(len(predict(output, tasks)), len(tasks))
            for filename, digest in report["code_sha256"].items():
                snapshot = output / "code_snapshot" / Path(filename).relative_to("ai")
                self.assertEqual(hashlib.sha256(snapshot.read_bytes()).hexdigest(), digest)
            with self.assertRaises(FileExistsError):
                run(root, config_path, output)

    def test_saved_model_predicts_without_labels_and_detects_tampering(self):
        config, records = configuration(), fixtures()
        config["scenarios"] = {"train": 30, "validation": 3, "test": 3}
        rows, _ = generate_scenarios(records, split_courses(records, 1), config)
        x, y, groups = training_arrays([r for r in rows if r["split"] == "train"])
        model = lgb.LGBMRanker(objective="lambdarank", n_estimators=10,
                              min_child_samples=2, n_jobs=1, verbosity=-1)
        model.fit(x, y, group=groups, feature_name=FEATURES)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            model.booster_.save_model(str(path / "model.txt"))
            report = {"features": FEATURES, "model_sha256": hashlib.sha256((path / "model.txt").read_bytes()).hexdigest()}
            (path / "report.json").write_text(json.dumps(report), encoding="utf-8")
            tasks = [{"task_id": str(i), **{name: row[name] for name in FEATURES}} for i, row in enumerate(rows[:6])]
            ranked = predict(path, tasks)
            self.assertEqual({r["task_id"] for r in ranked}, {r["task_id"] for r in tasks})
            self.assertEqual([r["score"] for r in ranked], sorted([r["score"] for r in ranked], reverse=True))
            self.assertEqual(ranked, predict(path, copy.deepcopy(tasks)))
            with self.assertRaisesRegex(ValueError, "unique"):
                predict(path, [tasks[0], tasks[0]])
            report["model_sha256"] = "changed"
            (path / "report.json").write_text(json.dumps(report), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "manifest"):
                predict(path, tasks)


if __name__ == "__main__":
    unittest.main()
