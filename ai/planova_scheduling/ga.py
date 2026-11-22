"""A Genetic Algorithm (GA) that searches for a better weekly study plan.

Not trained AI: a GA is a search method. It keeps a population of candidate
plans, scores each with the objective (objective.py), and breeds better ones
by recombining and slightly changing the best. Given the same seed it always
returns the same plan.

Version 2 (22 November 2026). Version 1 cut each task into fixed, even
chunks before placing them; on tight weeks those chunks packed free time
less tightly than the rule-based planner and lost to it. Version 2 chooses
each session's length while placing it, like the rule-based planner.

Chromosome. Each plannable task gets "turns": enough for its remaining work
at the minimum session length. A chromosome is
  - order: a permutation of all turns (who picks free time first),
  - day:   a preferred plan day (offset from the first day) for every turn.

Decoder. Turns are taken in chromosome order. On its turn a task gets one
session on its preferred day if possible, otherwise on the nearest usable
day (earlier days first), at the earliest time that keeps every hard rule of
the app, and as long as fits there, up to the maximum session length and the
work left (the same length rule as the rule-based planner). A final pass
places anything left over in priority order. Every decoded plan is valid.

Because lengths are chosen while placing, the rule-based planner's own plan
can be written as a chromosome (`encode`), and decoding it gives that exact
plan back. With `start_from_baseline` the first population contains it, and
elitism then guarantees the GA's result is never worse than the baseline on
the objective.
"""

from __future__ import annotations

import time
from dataclasses import asdict, dataclass

from .baseline import eligibility, priority_key
from .objective import Context, Weights, evaluate_sessions
from .plan import Plan, Session, Unplaced, UnplacedReason
from .rng import Rng


@dataclass(frozen=True)
class GAConfig:
    # Chosen on the development weeks only (22 November 2026): starting from
    # the baseline's plan with 40x120 was never worse than the baseline in 20
    # runs per week and is the cheapest setting tried (40x120, 60x200, with
    # and without the baseline start). See docs/scheduling_evaluation.md.
    population: int = 40
    generations: int = 120
    tournament: int = 3
    crossover_rate: float = 0.9
    swap_rate: float = 0.3
    day_mutation_rate: float | None = None  # None: 2 / number of turns
    elite: int = 2
    start_from_baseline: bool = True

    def to_json(self) -> dict:
        return asdict(self)


class Decoder:
    def __init__(self, ctx: Context):
        self.ctx = ctx
        self.s = ctx.scenario.settings
        self.priority = [t.id for t in ctx.eligible]  # already in priority order
        self.turns: list[str] = []
        for task in ctx.eligible:
            self.turns += [task.id] * -(-task.remaining // self.s.min_session_minutes)
        self.offsets = [d for d, _ in ctx.days]  # usable plan days
        # Usable days (indices into ctx.days) that start before each deadline.
        self.days_for = {
            t: [i for i, (_, slots) in enumerate(ctx.days) if slots[0][0] < ctx.due[t]]
            for t in self.priority
        }

    def _fresh(self):
        return {
            "slots": [[[] for _ in slots] for _, slots in self.ctx.days],
            "day_used": [0] * len(self.ctx.days),
            "task_day": {},
            "placed": {t: 0 for t in self.priority},
            "last_end": {t: 0 for t in self.priority},
            "sessions": [],
        }

    def _try_day(self, state, task, i, want, need, after) -> int:
        """Earliest session on usable day i of between `need` and `want`
        minutes, starting no earlier than `after`. Returns its length or 0."""
        s = self.s
        due = self.ctx.due[task]
        cap = min(want,
                  s.daily_limit_minutes - state["day_used"][i],
                  s.per_task_daily_minutes - state["task_day"].get((task, i), 0))
        if cap < need or cap <= 0:
            return 0
        brk = s.break_minutes
        for k, (a, b) in enumerate(self.ctx.days[i][1]):
            booked = state["slots"][i][k]
            for c in sorted({max(x, after, a) for x in [a] + [end + brk for _, end in booked]}):
                # Sessions in the same free period need a break between them.
                if any(start < c < end + brk or start == c for start, end in booked):
                    continue
                limit = min([b, due] + [start - brk for start, _ in booked if start > c])
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

    def _turn(self, state, task, day_order) -> int:
        left = self.ctx.remaining[task] - state["placed"][task]
        if left <= 0:
            return 0
        s = self.s
        if left < s.min_session_minutes:
            # A piece shorter than the minimum must be the task's last session.
            want, need, after = left, left, state["last_end"][task]
        else:
            want, need, after = min(left, s.max_session_minutes), s.min_session_minutes, 0
        for i in day_order:
            got = self._try_day(state, task, i, want, need, after)
            if got:
                return got
        return 0

    def _nearest(self, task, preferred):
        days = self.days_for[task]
        return sorted(days, key=lambda i: (abs(self.ctx.days[i][0] - preferred),
                                           self.ctx.days[i][0]))

    def decode(self, order, days):
        state = self._fresh()
        for gene in order:
            task = self.turns[gene]
            self._turn(state, task, self._nearest(task, days[gene]))
        # Final pass: leftovers in priority order, earliest day first.
        for task in self.priority:
            while self._turn(state, task, self.days_for[task]):
                pass
        return state["sessions"]

    def encode(self, plan: Plan):
        """The chromosome whose decoding is `plan` (used for the baseline)."""
        free = {t: [g for g, owner in enumerate(self.turns) if owner == t] for t in self.priority}
        order, days = [], [self.offsets[0] if self.offsets else 0] * len(self.turns)
        for session in sorted(plan.sessions, key=lambda x: x.start):
            gene = free[session.task_id].pop(0)
            order.append(gene)
            days[gene] = self.ctx.minutes(session.start) // 1440
        order += [g for t in self.priority for g in free[t]]
        return order, days

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
# Every random choice below goes through Rng and happens in a fixed order, so
# the Dart copy (lib/services/planning/ga_planner.dart) reproduces each run
# exactly. Keep the two in step: the shared saved plans test it.
def _order_crossover(rng: Rng, a: list[int], b: list[int]) -> list[int]:
    n = len(a)
    if n < 2:
        return a[:]
    i, j = sorted(rng.sample_indices(n, 2))
    middle = a[i:j + 1]
    taken = set(middle)
    rest = [g for g in b if g not in taken]
    return rest[:i] + middle + rest[i:]


def _best_index(values: list[float], indices) -> int:
    """The index with the lowest value; the first one on ties."""
    best = None
    for i in indices:
        if best is None or values[i] < values[best]:
            best = i
    return best


@dataclass
class GAResult:
    plan: Plan
    fitness: float
    parts: dict
    history: list[float]
    evaluations: int
    runtime_ms: float


def run_ga(scenario, seed: int, config: GAConfig = GAConfig(),
           weights: Weights = Weights(), baseline: Plan | None = None) -> GAResult:
    began = time.perf_counter()
    ctx = Context(scenario)
    decoder = Decoder(ctx)
    rng = Rng(seed)
    n = len(decoder.turns)
    usable = decoder.offsets
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
        return order, [rng.choice(usable) if usable else 0 for _ in range(n)]

    population = [random_individual() for _ in range(config.population)]
    if config.start_from_baseline and population:
        if baseline is None:
            from .baseline import plan_week
            baseline = plan_week(scenario)
        population[0] = decoder.encode(baseline)

    day_rate = config.day_mutation_rate if config.day_mutation_rate is not None else (2 / n if n else 0)
    history = []
    for _ in range(config.generations):
        values = [fitness(ind)[0] for ind in population]
        # Stable: equal values keep population order (Dart sorts by (value, index)).
        ranked = sorted(range(len(population)), key=lambda i: (values[i], i))
        history.append(values[ranked[0]])
        nxt = [(population[i][0][:], population[i][1][:]) for i in ranked[:config.elite]]

        def pick():
            group = rng.sample_indices(len(population), min(config.tournament, len(population)))
            return population[_best_index(values, group)]

        while len(nxt) < config.population:
            p1, p2 = pick(), pick()
            if rng.random() < config.crossover_rate:
                order = _order_crossover(rng, p1[0], p2[0])
                days = [p1[1][g] if rng.random() < 0.5 else p2[1][g] for g in range(n)]
            else:
                order, days = p1[0][:], p1[1][:]
            if n >= 2 and rng.random() < config.swap_rate:
                i, j = rng.sample_indices(n, 2)
                order[i], order[j] = order[j], order[i]
            for g in range(n):
                if usable and rng.random() < day_rate:
                    if rng.random() < 0.7:
                        days[g] = min(max(days[g] + rng.choice((-1, 1)), usable[0]), usable[-1])
                    else:
                        days[g] = rng.choice(usable)
            nxt.append((order, days))
        population = nxt

    values = [fitness(ind)[0] for ind in population]
    best = population[_best_index(values, range(len(population)))]
    value, parts, sessions = fitness(best)
    history.append(value)
    return GAResult(
        plan=decoder.to_plan(sessions), fitness=value, parts=parts, history=history,
        evaluations=evaluations, runtime_ms=round((time.perf_counter() - began) * 1000, 1),
    )
