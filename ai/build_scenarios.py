"""Writes the synthetic test weeks in ai/scenarios/ (run from the project root).

    & ai/.venv/Scripts/python.exe ai/build_scenarios.py

Every week is made up. The shapes are realistic for a UPSI undergraduate
(weekday classes, evening and weekend study, assignments, quizzes, projects
and test revision worth 10-40% of a course), but no student, course or
proforma is copied. Weeks are split into a development set (for building and
tuning planners) and a test set (only for final results). Re-running the
script rewrites the files identically.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent / "scenarios"

WEEKDAYS = [1, 2, 3, 4, 5]
WEEKEND = [6, 7]
ALL = WEEKDAYS + WEEKEND

DEFAULTS = {
    "horizonDays": 7,
    "minSessionMinutes": 30,
    "maxSessionMinutes": 60,
    "breakMinutes": 15,
    "dailyLimitMinutes": 240,
    "perTaskDailyMinutes": 120,
    "daysOff": [],
}


def rng(days, start, end, title=None):
    r = {"weekdays": days, "start": start, "end": end}
    if title:
        r = {"title": title, **r}
    return r


def task(tid, title, due, minutes, weight=None, done_minutes=0, completed=False):
    return {
        "id": tid,
        "title": title,
        "due": due,
        "estimatedMinutes": minutes,
        "completedMinutes": done_minutes,
        "weightPercent": weight,
        "completed": completed,
    }


# A typical study pattern: weekday evenings, weekend morning and afternoon.
USUAL_WINDOWS = [
    rng(WEEKDAYS, "20:00", "23:00"),
    rng(WEEKEND, "09:00", "12:00"),
    rng(WEEKEND, "14:00", "18:00"),
]
# Weekday afternoons are also open, but classes take most of them.
AFTERNOONS = [rng(WEEKDAYS, "14:00", "18:00")]
CLASSES = [
    rng([1, 3], "14:00", "16:00", "Lecture"),
    rng([2, 4], "15:00", "17:00", "Lab"),
    rng([5], "14:30", "16:30", "Tutorial"),
]


def scenario(sid, set_name, description, now, tasks, windows=None,
             commitments=None, **settings):
    return {
        "id": sid,
        "set": set_name,
        "synthetic": True,
        "description": description,
        "now": now,
        "settings": {**DEFAULTS, **settings},
        "windows": USUAL_WINDOWS if windows is None else windows,
        "commitments": [] if commitments is None else commitments,
        "tasks": tasks,
    }


# Wednesday 14 October 2026, 13:00 is the app's preview clock.
NOW = "2026-10-14T13:00"

SCENARIOS = [
    # ---------------- development set ----------------
    scenario(
        "d01-light-week", "development",
        "Two small tasks and plenty of free time.",
        NOW,
        [
            task("t1", "Reading reflection", "2026-10-16T23:59", 90, 10),
            task("t2", "Quiz 1 revision", "2026-10-19T10:00", 120, 10),
        ],
    ),
    scenario(
        "d02-normal-week", "development",
        "Five tasks with spread-out deadlines and weekday classes.",
        NOW,
        [
            task("t1", "Lab report 2", "2026-10-15T23:59", 120, 15),
            task("t2", "Assignment 1: wireframes", "2026-10-17T23:59", 240, 20),
            task("t3", "Quiz 2 revision", "2026-10-19T09:00", 90, 10),
            task("t4", "Group project proposal", "2026-10-20T17:00", 300, 30),
            task("t5", "Weekly reading", "2026-10-21T12:00", 60, 5),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "d03-clashing-deadlines", "development",
        "Four tasks from different courses all due on Friday night.",
        NOW,
        [
            task("t1", "Programming assignment", "2026-10-16T23:59", 240, 25),
            task("t2", "Essay draft", "2026-10-16T23:59", 180, 20),
            task("t3", "Database ERD", "2026-10-16T23:59", 150, 15),
            task("t4", "Statistics worksheet", "2026-10-16T23:59", 90, 10),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "d04-heavy-commitments", "development",
        "Part-time work most evenings and a club on Saturday leave little time.",
        NOW,
        [
            task("t1", "Assignment 2", "2026-10-18T23:59", 240, 20),
            task("t2", "Quiz revision", "2026-10-20T09:00", 120, 10),
            task("t3", "Project milestone", "2026-10-21T17:00", 300, 30),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS,
        commitments=CLASSES + [
            rng([1, 2, 3, 4], "19:00", "22:30", "Part-time work"),
            rng([6], "09:00", "13:00", "Club"),
        ],
    ),
    scenario(
        "d05-weekend-off", "development",
        "The student keeps Saturday and Sunday free; tasks are due Monday.",
        NOW,
        [
            task("t1", "Portfolio update", "2026-10-19T09:00", 240, 25),
            task("t2", "Lab exercise", "2026-10-19T14:00", 120, 10),
            task("t3", "Reading summary", "2026-10-20T23:59", 60, 5),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
        daysOff=[6, 7],
    ),
    scenario(
        "d06-impossible-workload", "development",
        "Far more work due this week than the free time allows.",
        NOW,
        [
            task("t1", "Final project build", "2026-10-17T23:59", 900, 40),
            task("t2", "Report", "2026-10-18T23:59", 600, 30),
            task("t3", "Presentation slides", "2026-10-19T09:00", 300, 15),
            task("t4", "Quiz revision", "2026-10-16T08:00", 120, 10),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "d07-replan-after-missed", "development",
        "Friday afternoon re-plan after missing most of this week's sessions: "
        "little of the work was recorded.",
        "2026-10-16T14:00",
        [
            task("t1", "Assignment 1", "2026-10-18T23:59", 300, 20, done_minutes=60),
            task("t2", "Quiz 2 revision", "2026-10-19T09:00", 120, 10, done_minutes=30),
            task("t3", "Group project proposal", "2026-10-20T17:00", 300, 30, done_minutes=0),
            task("t4", "Lab report", "2026-10-15T23:59", 120, 15, done_minutes=45),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "d08-needs-input", "development",
        "Normal work plus tasks that cannot be planned: no due date, overdue, "
        "completed, or no work left.",
        NOW,
        [
            task("t1", "Assignment 2", "2026-10-17T23:59", 180, 20),
            task("t2", "Project idea (date not set)", None, 120),
            task("t3", "Lab report (late)", "2026-10-13T23:59", 90, 10),
            task("t4", "Quiz 1 revision (done)", "2026-10-15T09:00", 60, 10, completed=True),
            task("t5", "Reading (all recorded)", "2026-10-16T23:59", 60, 5, done_minutes=60),
            task("t6", "Mid-term revision", "2026-10-21T09:00", 240, 25),
        ],
    ),
    # ---------------- test set ----------------
    scenario(
        "t01-normal-week-b", "test",
        "A different normal week: morning classes, afternoon and evening study.",
        "2026-10-19T08:00",
        [
            task("t1", "Tutorial exercise", "2026-10-20T23:59", 60, 5),
            task("t2", "Assignment 3", "2026-10-23T23:59", 300, 20),
            task("t3", "Quiz 3 revision", "2026-10-22T10:00", 120, 10),
            task("t4", "Case study", "2026-10-25T23:59", 240, 15),
        ],
        windows=[rng(WEEKDAYS, "14:00", "18:00"), rng(WEEKDAYS, "21:00", "23:00"),
                 rng(WEEKEND, "10:00", "16:00")],
        commitments=[rng(WEEKDAYS, "08:00", "12:00", "Lectures"),
                     rng([3], "14:00", "16:00", "Lab")],
    ),
    scenario(
        "t02-exam-week", "test",
        "Two big test revisions on the same day next week plus small quizzes.",
        "2026-10-21T09:00",
        [
            task("t1", "Mid-term A revision", "2026-10-27T09:00", 600, 30),
            task("t2", "Mid-term B revision", "2026-10-27T14:00", 600, 30),
            task("t3", "Quiz 4 revision", "2026-10-23T10:00", 90, 10),
            task("t4", "Short exercise", "2026-10-22T23:59", 60, 5),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "t03-clashing-midweek", "test",
        "Three tasks due Thursday with a big one due Friday too.",
        "2026-10-19T12:00",
        [
            task("t1", "Programming lab", "2026-10-22T23:59", 180, 15),
            task("t2", "Design critique", "2026-10-22T23:59", 120, 10),
            task("t3", "Quiz 3 revision", "2026-10-22T09:00", 120, 10),
            task("t4", "Assignment 2", "2026-10-23T23:59", 360, 25),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "t04-work-and-club", "test",
        "Weekend part-time work, club on Wednesday night and weekday classes.",
        "2026-10-19T09:00",
        [
            task("t1", "Assignment 3", "2026-10-22T23:59", 240, 20),
            task("t2", "Video edit", "2026-10-24T23:59", 300, 25),
            task("t3", "Quiz revision", "2026-10-26T09:00", 90, 10),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS,
        commitments=CLASSES + [
            rng(WEEKEND, "10:00", "18:00", "Part-time work"),
            rng([3], "20:00", "22:30", "Club"),
        ],
    ),
    scenario(
        "t05-strict-preferences", "test",
        "Short sessions, long breaks, 2 hours a day and 1 hour per task a day.",
        NOW,
        [
            task("t1", "Assignment 1", "2026-10-17T23:59", 240, 20),
            task("t2", "Quiz revision", "2026-10-19T09:00", 120, 10),
            task("t3", "Reading", "2026-10-20T23:59", 90, 5),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
        minSessionMinutes=15, maxSessionMinutes=45, breakMinutes=30,
        dailyLimitMinutes=120, perTaskDailyMinutes=60,
    ),
    scenario(
        "t06-long-tasks-later", "test",
        "Mostly long work due after this week, so much of it continues later.",
        NOW,
        [
            task("t1", "Final project", "2026-11-06T23:59", 1200, 40),
            task("t2", "Research paper", "2026-10-30T23:59", 720, 30),
            task("t3", "Quiz 2 revision", "2026-10-19T09:00", 90, 10),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "t07-replan-sunday-night", "test",
        "Sunday-night re-plan: the weekend's sessions were missed.",
        "2026-10-18T20:00",
        [
            task("t1", "Assignment 2", "2026-10-20T23:59", 300, 20, done_minutes=30),
            task("t2", "Quiz 3 revision", "2026-10-21T10:00", 120, 10),
            task("t3", "Group report section", "2026-10-23T17:00", 240, 25, done_minutes=60),
        ],
        windows=USUAL_WINDOWS + AFTERNOONS, commitments=CLASSES,
    ),
    scenario(
        "t08-no-free-time", "test",
        "Every study window is covered by commitments, so nothing can be placed.",
        NOW,
        [
            task("t1", "Assignment", "2026-10-17T23:59", 120, 20),
            task("t2", "Project", "2026-10-27T23:59", 300, 30),
        ],
        windows=[rng(WEEKDAYS, "20:00", "22:00"), rng(WEEKEND, "10:00", "12:00")],
        commitments=[rng(WEEKDAYS, "19:00", "23:00", "Part-time work"),
                     rng(WEEKEND, "09:00", "13:00", "Family")],
    ),
]


def main() -> int:
    OUT.mkdir(exist_ok=True)
    ids = [s["id"] for s in SCENARIOS]
    assert len(ids) == len(set(ids)), "duplicate scenario IDs"
    for s in SCENARIOS:
        path = OUT / f"{s['id']}.json"
        path.write_text(json.dumps(s, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {len(SCENARIOS)} scenarios to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
