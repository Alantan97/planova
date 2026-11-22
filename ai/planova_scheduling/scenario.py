"""Test-week (scenario) files: the same inputs the app's planner receives.

A scenario is one student's situation at one moment: the time "now", their
tasks, weekly study windows, commitments and study preferences. Times are
local wall-clock times (Malaysia has no daylight saving), written to the
minute, e.g. "2026-10-14T13:00". Weekdays are 1 = Monday ... 7 = Sunday.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

SCENARIO_DIR = Path(__file__).resolve().parents[1] / "scenarios"
EXPECTED_DIR = SCENARIO_DIR / "expected"
# "test" was used once for the first GA (and has been seen since);
# "holdout" was frozen before the second GA was written.
SETS = ("development", "test", "holdout")


@dataclass(frozen=True)
class Settings:
    """Mirrors PlannerSettings; the defaults are the app's defaults."""

    horizon_days: int = 7
    max_session_minutes: int = 60
    min_session_minutes: int = 30
    break_minutes: int = 15
    daily_limit_minutes: int = 240
    per_task_daily_minutes: int = 120
    days_off: frozenset[int] = frozenset()


@dataclass(frozen=True)
class TimeRange:
    weekdays: tuple[int, ...]
    start_minute: int
    end_minute: int


@dataclass(frozen=True)
class Task:
    id: str
    title: str
    due: datetime | None
    estimated_minutes: int
    completed_minutes: int = 0
    weight_percent: float | None = None
    completed: bool = False

    @property
    def remaining(self) -> int:
        return self.estimated_minutes - self.completed_minutes


@dataclass(frozen=True)
class Scenario:
    id: str
    set: str
    description: str
    now: datetime
    settings: Settings
    windows: tuple[TimeRange, ...]
    commitments: tuple[TimeRange, ...]
    tasks: tuple[Task, ...]
    synthetic: bool = True


def parse_time(text: str) -> datetime:
    return datetime.strptime(text, "%Y-%m-%dT%H:%M")


def format_time(value: datetime) -> str:
    return value.strftime("%Y-%m-%dT%H:%M")


def _clock(text: str) -> int:
    hours, minutes = (int(part) for part in text.split(":"))
    if not 0 <= minutes < 60:
        raise ValueError(f"Invalid time {text!r}.")
    return hours * 60 + minutes


def _range(raw: dict) -> TimeRange:
    days = tuple(raw["weekdays"])
    start, end = _clock(raw["start"]), _clock(raw["end"])
    # Same rules as WeeklyTimeRange.validate in the app.
    if not days or any(d < 1 or d > 7 for d in days):
        raise ValueError(f"Invalid weekdays {days!r}.")
    if start < 0 or end > 1440 or end <= start:
        raise ValueError(f"Invalid time range {raw['start']}-{raw['end']}.")
    return TimeRange(days, start, end)


def _task(raw: dict) -> Task:
    weight = raw.get("weightPercent")
    task = Task(
        id=raw["id"],
        title=raw["title"],
        due=parse_time(raw["due"]) if raw.get("due") else None,
        estimated_minutes=int(raw["estimatedMinutes"]),
        completed_minutes=int(raw.get("completedMinutes", 0)),
        weight_percent=None if weight is None else float(weight),
        completed=bool(raw.get("completed", False)),
    )
    # Same rules as the AcademicTask constructor.
    if task.estimated_minutes <= 0 or task.completed_minutes < 0:
        raise ValueError(f"Task {task.id}: invalid minutes.")
    return task


def from_json(raw: dict) -> Scenario:
    s = raw["settings"]
    scenario = Scenario(
        id=raw["id"],
        set=raw["set"],
        description=raw["description"],
        now=parse_time(raw["now"]),
        settings=Settings(
            horizon_days=s.get("horizonDays", 7),
            max_session_minutes=s["maxSessionMinutes"],
            min_session_minutes=s["minSessionMinutes"],
            break_minutes=s["breakMinutes"],
            daily_limit_minutes=s["dailyLimitMinutes"],
            per_task_daily_minutes=s["perTaskDailyMinutes"],
            days_off=frozenset(s.get("daysOff", [])),
        ),
        windows=tuple(_range(w) for w in raw["windows"]),
        commitments=tuple(_range(c) for c in raw["commitments"]),
        tasks=tuple(_task(t) for t in raw["tasks"]),
        synthetic=raw.get("synthetic", True),
    )
    if scenario.set not in SETS:
        raise ValueError(f"{scenario.id}: set must be one of {SETS}.")
    ids = [t.id for t in scenario.tasks]
    if len(ids) != len(set(ids)):
        raise ValueError(f"{scenario.id}: duplicate task IDs.")
    return scenario


def load(path: Path) -> Scenario:
    return from_json(json.loads(path.read_text(encoding="utf-8")))


def load_all(directory: Path = SCENARIO_DIR, set_name: str | None = None) -> list[Scenario]:
    scenarios = [load(p) for p in sorted(directory.glob("*.json"))]
    if set_name is not None:
        scenarios = [s for s in scenarios if s.set == set_name]
    return scenarios
