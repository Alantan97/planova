"""A Genetic Algorithm (GA) that searches for a better weekly study plan.

Not trained AI: a GA is a search method. It keeps a population of candidate
plans, scores each with the objective (objective.py), and breeds better ones
by recombining and slightly changing the best. Given the same seed it always
returns the same plan.

Chromosome. Each plannable task's remaining work is cut into chunks of at
most the maximum session length (and at least the minimum, where possible).
A chromosome is
  - order: a permutation of the chunks (which get first pick of free time),
  - day:   a preferred plan day for every chunk.

Decoder. Chunks are placed one by one, in chromosome order, on their
preferred day if possible, otherwise on the nearest usable day (earlier days
first), at the earliest time that keeps every hard rule of the app:
free study time only, no overlaps, breaks inside a free period, daily and
per-task-per-day limits, days off and never past the deadline. A final pass
places anything left over, in priority order, including pieces shorter than
the minimum (only as a task's last session, as the app allows). So every
decoded plan is valid; the GA only chooses between valid plans.
"""

from __future__ import annotations

import random
import time
from dataclasses import asdict, dataclass

from .baseline import eligibility, priority_key
from .objective import Context, Weights, evaluate_sessions
from .plan import Plan, Session, Unplaced, UnplacedReason


@dataclass(frozen=True)
class GAConfig:
    # Chosen on the development weeks only (22 November 2026): the smallest
    # tried budget (40x120, 50x150, 60x200) never worse than the baseline in
    # 20 runs per week. See docs/scheduling_evaluation.md.
    population: int = 60
    generations: int = 200
    tournament: int = 3
    crossover_rate: float = 0.9
    swap_rate: float = 0.3
    day_mutation_rate: float | None = None  # None: 1 / number of chunks
    elite: int = 2
    seed_with_priority_order: bool = False

    def to_json(self) -> dict:
        return asdict(self)


# ------------------------------------------------------------------ chunks
def chunk_sizes(remaining: int, min_len: int, max_len: int) -> list[int]:
    """Even chunks within [min_len, max_len]; any remainder is left for the
    final pass (it may then become a short last session)."""
    if remaining < min_len:
        return []
    low = -(-remaining // max_len)          # fewest chunks
    high = remaining // min_len             # most chunks
    if low <= high:
        n = low
        base, extra = divmod(remaining, n)
        return [base + 1] * extra + [base] * (n - extra)
    n = high                                # cannot cover it all evenly
    return [max_len] * n


class Decoder:
    def __init__(self, ctx: Context):
        self.ctx = ctx
        s = ctx.scenario.settings
        self.s = s
        self.priority = [t.id for t in ctx.eligible]  # already in priority order
        self.chunks: list[tuple[str, int]] = []
        for task in ctx.eligible:
            for size in chunk_sizes(task.remaining, s.min_session_minutes, s.max_session_minutes):
                self.chunks.append((task.id, size))
        self.day_index = [d for d, _ in ctx.days]
        # Usable plan days on or before each task's due date.
        self.days_for = {
            t: [i for i, (d, slots) in enumerate(ctx.days) if slots[0][0] < ctx.due[t]]
            for t in self.priority
        }

    # One plan under construction.
    def _fresh(self):
        return {
            "slots": [[[] for _ in slots] for _, slots in self.ctx.days],
            "day_used": [0] * len(self.ctx.days),
            "task_day": {},
            "placed": {t: 0 for t in self.priority},
            "last_end": {t: -1 for t in self.priority},
            "sessions": [],
        }

    def _try_day(self, state, task, i, want, need, after):
        """Earliest placement on usable day i of between `need` and `want`
        minutes; returns the length placed (0 if none)."""
        s = self.s
        due = self.ctx.due[task]
        day_room = s.daily_limit_minutes - state["day_used"][i]
        task_room = s.per_task_daily_minutes - state["task_day"].get((task, i), 0)
        cap = min(want, day_room, task_room)
        if cap < need or cap <= 0:
            return 0
        brk = s.break_minutes
        for k, (a, b) in enumerate(self.ctx.days[i][1]):
            booked = state["slots"][i][k]
            candidates = sorted({max(x, after, a) for x in [a] + [end + brk for _, end in booked]})
            for c in candidates:
                # Sessions in the same free period need a break between them:
                # earlier ones must end `brk` before c, later ones cap the length.
                if any(start < c and c < end + brk for start, end in booked):
                    continue
                limit = min([b, due] + [start - brk for start, _ in booked if start >= c])
                length = min(cap, limit - c)
                if length >= need and length > 0:
                    booked.append((c, c + length))
                    booked.sort()
                    state["day_used"][i] += length
                    state["task_day"][(task, i)] = state["task_day"].get((task, i), 0) + length
                    state["placed"][task] += length
                    state["last_end"][task] = max(state["last_end"][task], c + length)
                    state["sessions"].append((task, c, length))
                    return length
        return 0

    def _place(self, state, task, length, preferred, full_only):
        days = self.days_for[task]
        if not days:
            return 0
        # Nearest usable day to the preferred one, earlier days first.
        pos = min(range(len(days)), key=lambda j: (abs(days[j] - preferred), days[j]))
        order = [days[pos]]
        lo, hi = pos - 1, pos + 1
        while lo >= 0 or hi < len(days):
            if lo >= 0:
                order.append(days[lo])
                lo -= 1
            if hi < len(days):
                order.append(days[hi])
                hi += 1
        need = length if full_only else min(length, self.s.min_session_minutes)
        for i in order:
            placed = self._try_day(state, task, i, length, need, -1)
            if placed:
                return placed
        return 0

    def decode(self, order, days):
        state = self._fresh()
        s = self.s
        for gene in order:
            task, size = self.chunks[gene]
            left = min(size, self.ctx.remaining[task] - state["placed"][task])
            if left <= 0:
                continue
            got = self._place(state, task, left, days[gene], full_only=True)
            if not got:
                got = self._place(state, task, left, days[gene], full_only=False)
            # Anything not placed here is retried in the final pass.
        # Final pass: leftovers in priority order, earliest day first.
        for task in self.priority:
            while True:
                left = self.ctx.remaining[task] - state["placed"][task]
                if left <= 0:
                    break
                if left < s.min_session_minutes:
                    # A short piece must be the task's last session.
                    after = max(state["last_end"][task], 0)
                    for i in self.days_for[task]:
                        if self._try_day(state, task, i, left, left, after):
                            break
                    break
                got = 0
                for i in self.days_for[task]:
                    got = self._try_day(state, task, i, min(left, s.max_session_minutes),
                                        s.min_session_minutes, -1)
                    if got:
                        break
                if not got:
                    break
        return state["sessions"]

    def to_plan(self, sessions) -> Plan:
        ctx = self.ctx
        ordered = sorted(sessions, key=lambda x: (x[1], x[0]))
        placed = {t: 0 for t in self.priority}
        for task, _, minutes in ordered:
            placed[task] += minutes
        _, unplaced = eligibility(ctx.scenario)
        unplaced = list(unplaced)
        for task in ctx.eligible:
            left = task.remaining - placed[task.id]
            if left > 0:
                reason = (UnplacedReason.NOT_ENOUGH_TIME_BEFORE_DUE
                          if ctx.due[task.id] < ctx.end else UnplacedReason.CONTINUES_LATER)
                unplaced.append(Unplaced(task.id, left, reason))
        tasks = {t.id: t for t in ctx.scenario.tasks}
        unplaced.sort(key=lambda u: (u.reason.index, priority_key(tasks[u.task_id])))
        return Plan(
            start=ctx.time(ctx.start), end=ctx.time(ctx.end),
            sessions=tuple(Session(t, ctx.time(a), m) for t, a, m in ordered),
            unplaced=tuple(unplaced), has_availability=bool(ctx.scenario.windows),
        )


# ------------------------------------------------------------------ GA
def _order_crossover(rng: random.Random, a: list[int], b: list[int]) -> list[int]:
    n = len(a)
    if n < 2:
        return a[:]
    i, j = sorted(rng.sample(range(n), 2))
    middle = a[i:j + 1]
    taken = set(middle)
    rest = [g for g in b if g not in taken]
    return rest[:i] + middle + rest[i:]


@dataclass
class GAResult:
    plan: Plan
    fitness: float
    parts: dict
    history: list[float]
    evaluations: int
    runtime_ms: float


def run_ga(scenario, seed: int, config: GAConfig = GAConfig(),
           weights: Weights = Weights()) -> GAResult:
    began = time.perf_counter()
    ctx = Context(scenario)
    decoder = Decoder(ctx)
    rng = random.Random(seed)
    n = len(decoder.chunks)
    usable = decoder.day_index
    cache: dict[tuple, tuple[float, dict, list]] = {}
    evaluations = 0

    def fitness(ind):
        nonlocal evaluations
        key = (tuple(ind[0]), tuple(ind[1]))
        hit = cache.get(key)
        if hit is None:
            evaluations += 1
            sessions = decoder.decode(ind[0], ind[1])
            value, parts = evaluate_sessions(ctx, sessions, weights)
            hit = (value, parts, sessions)
            cache[key] = hit
        return hit

    def random_individual():
        order = list(range(n))
        rng.shuffle(order)
        days = [rng.choice(usable) if usable else 0 for _ in range(n)]
        return order, days

    population = [random_individual() for _ in range(config.population)]
    if config.seed_with_priority_order and population:
        # Chunks in priority order, all preferring the earliest day: close to
        # the rule-based planner's choices (not identical; see the docs).
        population[0] = (list(range(n)), [usable[0] if usable else 0] * n)

    day_rate = config.day_mutation_rate if config.day_mutation_rate is not None else (1 / n if n else 0)
    history = []
    for _ in range(config.generations):
        scored = sorted(population, key=lambda ind: fitness(ind)[0])
        history.append(fitness(scored[0])[0])
        nxt = [(o[:], d[:]) for o, d in scored[:config.elite]]
        while len(nxt) < config.population:
            def pick():
                group = rng.sample(population, min(config.tournament, len(population)))
                return min(group, key=lambda ind: fitness(ind)[0])
            p1, p2 = pick(), pick()
            if rng.random() < config.crossover_rate:
                order = _order_crossover(rng, p1[0], p2[0])
                days = [p1[1][g] if rng.random() < 0.5 else p2[1][g] for g in range(n)]
            else:
                order, days = p1[0][:], p1[1][:]
            if n >= 2 and rng.random() < config.swap_rate:
                i, j = rng.sample(range(n), 2)
                order[i], order[j] = order[j], order[i]
            for g in range(n):
                if usable and rng.random() < day_rate:
                    days[g] = (days[g] + rng.choice((-1, 1))) if rng.random() < 0.7 else rng.choice(usable)
                    days[g] = min(max(days[g], usable[0]), usable[-1])
            nxt.append((order, days))
        population = nxt

    best = min(population, key=lambda ind: fitness(ind)[0])
    value, parts, sessions = fitness(best)
    history.append(value)
    return GAResult(
        plan=decoder.to_plan(sessions), fitness=value, parts=parts, history=history,
        evaluations=evaluations, runtime_ms=round((time.perf_counter() - began) * 1000, 1),
    )
