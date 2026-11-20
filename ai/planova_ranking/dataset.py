"""Explicitly simulated planning contexts and provisional ranking targets."""

from __future__ import annotations

import math
import random

import numpy as np

FEATURES = ["days_until_due", "remaining_minutes", "assessment_weight_percent"]


def feature_matrix(rows: list[dict]) -> np.ndarray:
    if not rows:
        raise ValueError("At least one task is required")
    values = []
    for row in rows:
        numbers = []
        for name in FEATURES:
            value = row.get(name)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError(f"{name} must be a finite number")
            numbers.append(float(value))
        days, minutes, weight = numbers
        if days < 0 or not 0 < minutes <= 10080 or not 0 <= weight <= 100:
            raise ValueError("Expected days >= 0, remaining minutes in (0, 10080], weight in [0, 100]")
        values.append(numbers)
    return np.asarray(values, dtype=float)


def teacher_score(row: dict, policy: dict) -> float:
    days, minutes, weight = feature_matrix([row])[0]
    urgency = 1 / (days + 1)
    pressure = min(1.0, minutes / ((days + 1) * policy["pressure_minutes_per_day"]))
    return (policy["urgency_weight"] * urgency
            + policy["assessment_weight"] * weight / 100
            + policy["pressure_weight"] * pressure)


def priority_label(score: float, policy: dict) -> int:
    return sum(score >= threshold for threshold in policy["label_thresholds"])


def split_courses(records: list[dict], seed: int) -> dict[str, list[str]]:
    codes = sorted({row["course_code"] for row in records})
    if len(codes) < 6:
        raise ValueError("Need at least six usable distinct courses for disjoint multi-course splits")
    random.Random(seed).shuffle(codes)
    held_out = max(2, round(len(codes) * 0.2))
    if len(codes) - 2 * held_out < 2:
        held_out = 2
    return {"train": sorted(codes[2 * held_out:]), "validation": sorted(codes[:held_out]),
            "test": sorted(codes[held_out:2 * held_out])}


def generate_scenarios(records: list[dict], splits: dict, config: dict) -> tuple[list[dict], dict]:
    policy = config["label_policy"]
    thresholds = policy["label_thresholds"]
    if thresholds != sorted(set(thresholds)) or len(thresholds) != 3:
        raise ValueError("Expected three increasing, distinct label thresholds")
    weights = [policy[name] for name in ("urgency_weight", "assessment_weight", "pressure_weight")]
    if any(weight < 0 for weight in weights) or not math.isclose(sum(weights), 1):
        raise ValueError("Provisional policy weights must be non-negative and sum to one")
    if policy["pressure_minutes_per_day"] <= 0:
        raise ValueError("Pressure scale must be positive")
    all_codes = [code for codes in splits.values() for code in codes]
    if len(all_codes) != len(set(all_codes)):
        raise ValueError("Course leakage across splits")
    result, rejected = [], {}
    for split_number, (split, codes) in enumerate(splits.items()):
        rng = random.Random(config["seed"] + split_number + 1)
        by_course = {code: [r for r in records if r["course_code"] == code] for code in codes}
        count = config["scenarios"][split]
        if count < 1 or config["assessments_per_course"] < 1 or config["courses_per_scenario"] < 2:
            raise ValueError("Need positive scenario/task counts and at least two courses per scenario")
        if len(codes) < config["courses_per_scenario"] or any(not rows for rows in by_course.values()):
            raise ValueError(f"Insufficient source courses in {split}")
        accepted = attempts = 0
        while accepted < count and attempts < count * 50:
            attempts += 1
            candidates = []
            for code in rng.sample(codes, config["courses_per_scenario"]):
                # Never mix two versions of the same course inside one scenario.
                documents = sorted({r["source_document_id"] for r in by_course[code]})
                document = rng.choice(documents)
                available = [r for r in by_course[code] if r["source_document_id"] == document]
                for source in rng.sample(available, min(config["assessments_per_course"], len(available))):
                    row = {**source,
                           "days_until_due": rng.choice(config["simulated_days_until_due"]),
                           "remaining_minutes": rng.choice(config["simulated_remaining_minutes"])}
                    score = teacher_score(row, policy)
                    candidates.append({**row, "teacher_score": score,
                                       "priority_label": priority_label(score, policy)})
            if len({row["priority_label"] for row in candidates}) < 2:
                continue
            rng.shuffle(candidates)
            scenario_id = f"{split}-{accepted + 1:04}"
            for index, row in enumerate(candidates):
                result.append({**row, "split": split, "scenario_id": scenario_id,
                               "task_id": f"{scenario_id}-task-{index + 1}",
                               "context_source": "simulated_not_student_observed",
                               "deadline_source": "simulated_days_offset_not_pdf_deadline",
                               "remaining_minutes_source": "simulated_not_proforma_slt",
                               "label_source": policy["version"]})
            accepted += 1
        if accepted != count:
            raise ValueError(f"Could not produce enough informative groups in {split}")
        rejected[split] = attempts - accepted
    return result, rejected


def grouped(rows: list[dict]) -> list[list[dict]]:
    groups = {}
    for row in rows:
        groups.setdefault(row["scenario_id"], []).append(row)
    return list(groups.values())


def ndcg(labels: list[int], scores: list[float], k: int = 3) -> float:
    """Gain=2**label-1, log2 discount; average tied prediction gains per rank."""
    if len(labels) != len(scores) or k < 1:
        raise ValueError("Aligned labels/scores and a positive cutoff are required")
    if not labels or any(not math.isfinite(float(s)) for s in scores):
        raise ValueError("Non-empty finite scores required")
    ideal = sorted((2 ** label - 1 for label in labels), reverse=True)
    denominator = sum(gain / math.log2(i + 2) for i, gain in enumerate(ideal[:k]))
    if denominator == 0:
        return 0.0
    tied = {}
    for label, score in zip(labels, scores):
        tied.setdefault(float(score), []).append(2 ** label - 1)
    expected_gains = []
    for score in sorted(tied, reverse=True):
        gains = tied[score]
        expected_gains.extend([sum(gains) / len(gains)] * len(gains))
    return sum(gain / math.log2(i + 2) for i, gain in enumerate(expected_gains[:k])) / denominator
