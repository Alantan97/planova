"""The app's rule-based planner, copied rule for rule into Python.

Source: lib/services/planning/rule_based_planner.dart (planWeek) and
lib/services/planning/free_study_slots.dart (freeStudySlots). Any change to
those files must be made here too; the golden-plan test fails otherwise.

Rules (no AI, no randomness):
1. Eligible: active tasks with a future due date and work remaining.
2. Order: earliest due date, then higher grade weight, then more work
   remaining, then task ID.
3. Free time: study windows minus commitments, for the next horizon days.
4. Fill each free slot in time order with the first task in priority order
   that may still be studied (ends by its due date, within the daily and
   per-task-per-day limits, at least the minimum length unless less is left).
   Sessions are at most the maximum length, with a break between sessions in
   one slot.
5. Work that does not fit is reported with a reason, never placed late.
"""

from __future__ import annotations

import functools
from datetime import datetime, timedelta

from .plan import FreeSlot, Plan, Session, Unplaced, UnplacedReason
from .scenario import Scenario, Task, TimeRange


# ---------------------------------------------------------------- free time
def _intervals_on(weekday: int, ranges: tuple[TimeRange, ...]) -> list[tuple[int, int]]:
    return [(r.start_minute, r.end_minute) for r in ranges if weekday in r.weekdays]


def _merge(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    merged: list[tuple[int, int]] = []
    # Dart's List.sort is not guaranteed stable, but only start order matters
    # here: equal starts merge into the same interval either way.
    for start, end in sorted(intervals, key=lambda i: i[0]):
        if merged and start <= merged[-1][1]:
            last = merged.pop()
            merged.append((last[0], max(end, last[1])))
        else:
            merged.append((start, end))
    return merged


def _subtract(free: list[tuple[int, int]], busy: list[tuple[int, int]]) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    for w_start, w_end in free:
        start = w_start
        for b_start, b_end in busy:
            if b_end <= start or b_start >= w_end:
                continue
            if b_start > start:
                result.append((start, b_start))
            start = b_end
            if start >= w_end:
                break
        if start < w_end:
            result.append((start, w_end))
    return result


def free_study_slots(scenario: Scenario) -> list[FreeSlot]:
    """Study windows minus commitments, per weekday, in time order."""
    slots: list[FreeSlot] = []
    for weekday in range(1, 8):
        free = _merge(_intervals_on(weekday, scenario.windows))
        busy = _merge(_intervals_on(weekday, scenario.commitments))
        slots.extend(FreeSlot(weekday, s, e) for s, e in _subtract(free, busy))
    return slots


# ---------------------------------------------------------------- ordering
def _by_deadline(a: Task, b: Task) -> int:
    if a.due is None or b.due is None:
        return (0 if b.due is None else 1) if a.due is None else -1
    return (a.due > b.due) - (a.due < b.due)


def _compare(x, y) -> int:
    return (x > y) - (x < y)


def priority(a: Task, b: Task) -> int:
    due = _by_deadline(a, b)
    if due:
        return due
    weight = _compare(
        b.weight_percent if b.weight_percent is not None else -1,
        a.weight_percent if a.weight_percent is not None else -1,
    )
    if weight:
        return weight
    work = _compare(b.remaining, a.remaining)
    return work if work else _compare(a.id, b.id)


priority_key = functools.cmp_to_key(priority)


def round_up_to_five(t: datetime) -> datetime:
    """Sessions start on 5-minute marks, never in the past."""
    base = t.replace(second=0, microsecond=0)
    rounded = base + timedelta(minutes=(5 - base.minute % 5) % 5)
    return rounded + timedelta(minutes=5) if rounded < t else rounded


def minutes_between(later: datetime, earlier: datetime) -> int:
    """Dart's Duration.inMinutes: whole minutes, truncated toward zero."""
    seconds = (later - earlier).total_seconds()
    return int(seconds / 60)


def eligibility(scenario: Scenario) -> tuple[list[Task], list[Unplaced]]:
    """Rule 1: plannable tasks (in priority order) and those needing input."""
    unplaced: list[Unplaced] = []
    eligible: list[Task] = []
    for task in scenario.tasks:
        if task.completed or task.remaining <= 0:
            continue
        if task.due is None:
            unplaced.append(Unplaced(task.id, task.remaining, UnplacedReason.NEEDS_DUE_DATE))
        elif not task.due > scenario.now:
            unplaced.append(Unplaced(task.id, task.remaining, UnplacedReason.OVERDUE))
        else:
            eligible.append(task)
    eligible.sort(key=priority_key)
    return eligible, unplaced


def plan_period(scenario: Scenario) -> tuple[datetime, datetime]:
    now = scenario.now
    first_day = datetime(now.year, now.month, now.day)
    return round_up_to_five(now), first_day + timedelta(days=scenario.settings.horizon_days)


# ---------------------------------------------------------------- planner
def plan_week(scenario: Scenario) -> Plan:
    settings = scenario.settings
    now = scenario.now
    start, end = plan_period(scenario)
    first_day = datetime(now.year, now.month, now.day)

    eligible, unplaced = eligibility(scenario)
    remaining = {t.id: t.remaining for t in eligible}

    slots_by_weekday: dict[int, list[FreeSlot]] = {}
    for slot in free_study_slots(scenario):
        slots_by_weekday.setdefault(slot.weekday, []).append(slot)

    sessions: list[Session] = []
    for d in range(settings.horizon_days):
        day = first_day + timedelta(days=d)
        if day.isoweekday() in settings.days_off:
            continue
        day_used = 0
        task_today: dict[str, int] = {}
        for slot in slots_by_weekday.get(day.isoweekday(), []):
            cursor = day + timedelta(minutes=slot.start_minute)
            slot_end = day + timedelta(minutes=slot.end_minute)
            if cursor < start:
                cursor = start
            while cursor < slot_end:
                room = minutes_between(slot_end, cursor)
                day_room = settings.daily_limit_minutes - day_used
                chosen: Task | None = None
                length = 0
                for task in eligible:
                    left = remaining[task.id]
                    if left <= 0:
                        continue
                    until_due = minutes_between(task.due, cursor)
                    candidate = min(
                        settings.max_session_minutes,
                        left,
                        room,
                        day_room,
                        settings.per_task_daily_minutes - task_today.get(task.id, 0),
                        until_due,
                    )
                    needed = left if left < settings.min_session_minutes else settings.min_session_minutes
                    if candidate >= needed and candidate > 0:
                        chosen = task
                        length = candidate
                        break
                if chosen is None:
                    break
                sessions.append(Session(chosen.id, cursor, length))
                remaining[chosen.id] -= length
                task_today[chosen.id] = task_today.get(chosen.id, 0) + length
                day_used += length
                cursor = cursor + timedelta(minutes=length + settings.break_minutes)

    for task in eligible:
        left = remaining[task.id]
        if left <= 0:
            continue
        reason = (UnplacedReason.NOT_ENOUGH_TIME_BEFORE_DUE if task.due < end
                  else UnplacedReason.CONTINUES_LATER)
        unplaced.append(Unplaced(task.id, left, reason))

    tasks = {t.id: t for t in scenario.tasks}
    unplaced.sort(key=lambda u: (u.reason.index, priority_key(tasks[u.task_id])))

    return Plan(start=start, end=end, sessions=tuple(sessions), unplaced=tuple(unplaced),
                has_availability=bool(scenario.windows))
