"""Hard-rule checks and scores that apply to a plan from any planner.

`violations` lists every broken hard rule (a valid plan has none). These are
the app's rules, so a future GA must pass the same checks as the baseline.

`score` gives the comparison measures. Definitions:

- due_minutes: work left on plannable tasks due inside the plan period.
- due_placed_pct: share of due_minutes placed before the deadline.
- missed_minutes: due work not placed (would be late or not done).
- continues_later_minutes: work on tasks due after the period, not placed yet.
- needs_input_tasks: tasks with no due date or already overdue (not planned).
- max_day_minutes: the heaviest study day.
- day_std_minutes: standard deviation of study minutes over usable days
  (days in the period, not days off, with free time after the plan starts).
  Lower means a more even spread.
- last_minute_pct: share of placed minutes in sessions that end within 24
  hours before that task's deadline. Lower means less cramming.
- sessions / short_sessions: short ones are under the minimum length (only
  allowed when they finish a task).
"""

from __future__ import annotations

import statistics
from collections import defaultdict
from datetime import datetime, timedelta

from .baseline import eligibility, free_study_slots, plan_period
from .plan import Plan, UnplacedReason
from .scenario import Scenario


def _day(t: datetime) -> datetime:
    return datetime(t.year, t.month, t.day)


def violations(scenario: Scenario, plan: Plan) -> list[str]:
    s = scenario.settings
    eligible, _ = eligibility(scenario)
    tasks = {t.id: t for t in eligible}
    start, end = plan_period(scenario)
    slots = defaultdict(list)
    for slot in free_study_slots(scenario):
        slots[slot.weekday].append(slot)

    problems: list[str] = []
    ordered = sorted(plan.sessions, key=lambda x: x.start)
    per_day: dict[datetime, int] = defaultdict(int)
    per_task_day: dict[tuple[str, datetime], int] = defaultdict(int)
    per_task: dict[str, int] = defaultdict(int)
    previous = None
    for i, session in enumerate(ordered):
        label = f"session {i} ({session.task_id} {session.start:%a %d %H:%M})"
        task = tasks.get(session.task_id)
        finish = session.start + timedelta(minutes=session.minutes)
        day = _day(session.start)
        if task is None:
            problems.append(f"{label}: task is not plannable")
            continue
        if session.minutes <= 0 or session.minutes > s.max_session_minutes:
            problems.append(f"{label}: length {session.minutes} outside 1..{s.max_session_minutes}")
        if session.start < start or finish > end:
            problems.append(f"{label}: outside the plan period")
        if finish > task.due:
            problems.append(f"{label}: ends after the deadline")
        if day.isoweekday() in s.days_off:
            problems.append(f"{label}: on a day off")
        slot = next((sl for sl in slots[day.isoweekday()]
                     if day + timedelta(minutes=sl.start_minute) <= session.start
                     and finish <= day + timedelta(minutes=sl.end_minute)), None)
        if slot is None:
            problems.append(f"{label}: not inside free study time")
        if previous is not None:
            prev_session, prev_slot = previous
            prev_finish = prev_session.start + timedelta(minutes=prev_session.minutes)
            if session.start < prev_finish:
                problems.append(f"{label}: overlaps the previous session")
            elif (slot is not None and slot == prev_slot and _day(prev_session.start) == day
                  and session.start < prev_finish + timedelta(minutes=s.break_minutes)):
                problems.append(f"{label}: break shorter than {s.break_minutes} min")
        previous = (session, slot)
        per_day[day] += session.minutes
        per_task_day[(task.id, day)] += session.minutes
        per_task[task.id] += session.minutes
        if session.minutes < s.min_session_minutes and per_task[task.id] != task.remaining:
            problems.append(f"{label}: shorter than {s.min_session_minutes} min without finishing the task")

    for day, minutes in per_day.items():
        if minutes > s.daily_limit_minutes:
            problems.append(f"{day:%a %d}: {minutes} min is over the daily limit")
    for (task_id, day), minutes in per_task_day.items():
        if minutes > s.per_task_daily_minutes:
            problems.append(f"{task_id} on {day:%a %d}: {minutes} min is over the per-task limit")
    for task_id, minutes in per_task.items():
        if minutes > tasks[task_id].remaining:
            problems.append(f"{task_id}: {minutes} min planned but only {tasks[task_id].remaining} left")
    return problems


def usable_days(scenario: Scenario) -> list[datetime]:
    start, _ = plan_period(scenario)
    now = scenario.now
    first = datetime(now.year, now.month, now.day)
    slots = free_study_slots(scenario)
    days = []
    for d in range(scenario.settings.horizon_days):
        day = first + timedelta(days=d)
        if day.isoweekday() in scenario.settings.days_off:
            continue
        if any(sl.weekday == day.isoweekday()
               and day + timedelta(minutes=sl.end_minute) > start for sl in slots):
            days.append(day)
    return days


def score(scenario: Scenario, plan: Plan) -> dict:
    s = scenario.settings
    eligible, _ = eligibility(scenario)
    _, end = plan_period(scenario)
    tasks = {t.id: t for t in eligible}
    placed = defaultdict(int)
    per_day = defaultdict(int)
    last_minute = 0
    short = 0
    for session in plan.sessions:
        task = tasks[session.task_id]
        placed[task.id] += session.minutes
        per_day[_day(session.start)] += session.minutes
        finish = session.start + timedelta(minutes=session.minutes)
        if task.due - finish < timedelta(hours=24):
            last_minute += session.minutes
        if session.minutes < s.min_session_minutes:
            short += 1

    due = [t for t in eligible if t.due < end]
    later = [t for t in eligible if t.due >= end]
    due_minutes = sum(t.remaining for t in due)
    due_placed = sum(min(placed[t.id], t.remaining) for t in due)
    total = sum(placed.values())
    days = usable_days(scenario)
    loads = [per_day.get(d, 0) for d in days]
    return {
        "placed_minutes": total,
        "due_minutes": due_minutes,
        "due_placed_pct": round(100 * due_placed / due_minutes, 1) if due_minutes else 100.0,
        "missed_minutes": due_minutes - due_placed,
        "continues_later_minutes": sum(t.remaining - placed[t.id] for t in later),
        "needs_input_tasks": sum(1 for u in plan.unplaced if u.reason in
                                 (UnplacedReason.NEEDS_DUE_DATE, UnplacedReason.OVERDUE)),
        "sessions": len(plan.sessions),
        "short_sessions": short,
        "usable_days": len(days),
        "max_day_minutes": max(per_day.values(), default=0),
        "day_std_minutes": round(statistics.pstdev(loads), 1) if loads else 0.0,
        "last_minute_pct": round(100 * last_minute / total, 1) if total else 0.0,
    }
