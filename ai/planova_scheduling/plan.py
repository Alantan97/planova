"""A plan (the planner's output) in the same shape for every planner."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import Enum

from .scenario import format_time


@dataclass(frozen=True)
class FreeSlot:
    weekday: int
    start_minute: int
    end_minute: int


class UnplacedReason(Enum):
    # Same names and order as UnplacedReason in the app.
    NOT_ENOUGH_TIME_BEFORE_DUE = "notEnoughTimeBeforeDue"
    CONTINUES_LATER = "continuesLater"
    NEEDS_DUE_DATE = "needsDueDate"
    OVERDUE = "overdue"

    @property
    def index(self) -> int:
        return list(UnplacedReason).index(self)


@dataclass(frozen=True)
class Session:
    task_id: str
    start: datetime
    minutes: int


@dataclass(frozen=True)
class Unplaced:
    task_id: str
    minutes: int
    reason: UnplacedReason


@dataclass(frozen=True)
class Plan:
    """Plan period is [start, end)."""

    start: datetime
    end: datetime
    sessions: tuple[Session, ...]
    unplaced: tuple[Unplaced, ...]
    has_availability: bool

    def to_json(self) -> dict:
        """The golden-file format, shared with the Dart export test."""
        return {
            "from": format_time(self.start),
            "to": format_time(self.end),
            "sessions": [
                {"taskId": s.task_id, "start": format_time(s.start), "minutes": s.minutes}
                for s in self.sessions
            ],
            "unplaced": [
                {"taskId": u.task_id, "minutes": u.minutes, "reason": u.reason.value}
                for u in self.unplaced
            ],
        }
