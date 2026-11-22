"""The schedule goal: one number (lower is better) for any plan.

Agreed order of importance ("deadline-safe even spread", 22 November 2026):

1. Never miss a deadline: due work left unplaced costs the most.
2. Finish each task at least `buffer_hours` before it is due: minutes in
   sessions ending inside that buffer are penalised.
3. Spread study evenly: the standard deviation of minutes per usable day.
4. Prefer fewer, longer sessions: a small cost per session.

Work on tasks due after the plan period that is left unplaced has a small
cost, so free time is still used for it. The weights make each level matter
far more than the next, but they are a design choice, not a fact; they are
saved with every result.

The same `evaluate` is used for the baseline and the GA, so their numbers
are directly comparable.
"""

from __future__ import annotations

import math
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta

from .baseline import eligibility, free_study_slots, plan_period
from .plan import Plan
from .scenario import Scenario


@dataclass(frozen=True)
class Weights:
    missed_per_minute: float = 1000.0
    buffer_per_minute: float = 20.0
    spread_per_minute_std: float = 5.0
    per_session: float = 10.0
    later_unplaced_per_minute: float = 2.0
    buffer_hours: int = 24

    def to_json(self) -> dict:
        return asdict(self)


class Context:
    """Precomputed facts about one scenario, in whole minutes from midnight
    of the plan's first day (fast for the GA's many evaluations)."""

    def __init__(self, scenario: Scenario):
        self.scenario = scenario
        s = scenario.settings
        now = scenario.now
        self.first_day = datetime(now.year, now.month, now.day)
        start, end = plan_period(scenario)
        self.start = self.minutes(start)
        self.end = self.minutes(end)
        self.eligible, _ = eligibility(scenario)
        self.due = {t.id: self.minutes(t.due) for t in self.eligible}
        self.remaining = {t.id: t.remaining for t in self.eligible}
        self.due_in_period = [t.id for t in self.eligible if self.due[t.id] < self.end]
        self.later = [t.id for t in self.eligible if self.due[t.id] >= self.end]

        by_weekday: dict[int, list] = {}
        for slot in free_study_slots(scenario):
            by_weekday.setdefault(slot.weekday, []).append(slot)
        # days[i] = (day index, [(slot start, slot end), ...]) for usable days.
        self.days: list[tuple[int, list[tuple[int, int]]]] = []
        for d in range(s.horizon_days):
            weekday = (self.first_day + timedelta(days=d)).isoweekday()
            if weekday in s.days_off:
                continue
            slots = []
            for slot in by_weekday.get(weekday, []):
                a = max(d * 1440 + slot.start_minute, self.start)
                b = d * 1440 + slot.end_minute
                if a < b:
                    slots.append((a, b))
            if slots:
                self.days.append((d, slots))

    def minutes(self, t: datetime) -> int:
        return int((t - self.first_day).total_seconds() // 60)

    def time(self, minutes: int) -> datetime:
        return self.first_day + timedelta(minutes=minutes)


def plain_std(values: list[int]) -> float:
    """Population standard deviation, computed step by step exactly like the
    Dart copy (statistics.pstdev uses exact fractions, which Dart lacks)."""
    if not values:
        return 0.0
    mean = sum(values) / len(values)
    total = 0.0
    for v in values:
        d = v - mean
        total += d * d
    return math.sqrt(total / len(values))


def evaluate_sessions(ctx: Context, sessions, weights: Weights) -> tuple[float, dict]:
    """sessions: iterable of (task_id, start_minute, minutes)."""
    placed = {}
    per_day = {}
    buffer = weights.buffer_hours * 60
    in_buffer = 0
    count = 0
    for task_id, start, minutes in sessions:
        count += 1
        placed[task_id] = placed.get(task_id, 0) + minutes
        day = start // 1440
        per_day[day] = per_day.get(day, 0) + minutes
        if ctx.due[task_id] - (start + minutes) < buffer:
            in_buffer += minutes
    missed = sum(ctx.remaining[t] - min(placed.get(t, 0), ctx.remaining[t])
                 for t in ctx.due_in_period)
    later = sum(ctx.remaining[t] - placed.get(t, 0) for t in ctx.later)
    loads = [per_day.get(d, 0) for d, _ in ctx.days]
    spread = plain_std(loads)
    parts = {
        "missed_minutes": missed,
        "buffer_minutes": in_buffer,
        "day_std_minutes": round(spread, 3),
        "sessions": count,
        "later_unplaced_minutes": later,
    }
    total = (weights.missed_per_minute * missed
             + weights.buffer_per_minute * in_buffer
             + weights.spread_per_minute_std * spread
             + weights.per_session * count
             + weights.later_unplaced_per_minute * later)
    return total, parts


def evaluate(scenario: Scenario, plan: Plan, weights: Weights = Weights(),
             ctx: Context | None = None) -> tuple[float, dict]:
    ctx = ctx or Context(scenario)
    return evaluate_sessions(
        ctx, ((s.task_id, ctx.minutes(s.start), s.minutes) for s in plan.sessions), weights)
