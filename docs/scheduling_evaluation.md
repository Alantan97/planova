# Scheduling evaluation

Started 22 November 2026. Increment 1: shared test weeks, plan scoring and
the rule-based baseline. Increment 2: a Genetic Algorithm (GA) scored by
exactly the same code. GA version 1 lost to the baseline on 2 test weeks;
version 2 fixed the cause and was then checked on new held-out weeks.
Everything here is offline Python; the app still uses the rule-based planner.

## Why a baseline first

A GA can only be called better if it beats the planner the app already uses
on the same inputs and the same rules. So the baseline here *is* the app's
planner: `ai/planova_scheduling/baseline.py` is a rule-for-rule copy of
`planWeek` in `lib/services/planning/rule_based_planner.dart`.

To keep the copy honest, a Flutter test
(`test/services/planning/scenario_golden_test.dart`) runs the real Dart
planner on every test week and compares it with the saved plans in
`ai/scenarios/expected/`. A Python test checks the copy against the same
files. If either planner changes, a test fails. After an intended Dart
planner change, rewrite the saved plans and re-run both test suites:

```powershell
$env:PLANOVA_UPDATE_GOLDEN='1'; flutter test test/services/planning/scenario_golden_test.dart; $env:PLANOVA_UPDATE_GOLDEN=''
```

## Test weeks

`ai/build_scenarios.py` writes 24 weeks to `ai/scenarios/`. All are
**synthetic**: realistic shapes for a UPSI undergraduate (weekday classes,
evening and weekend study, tasks worth 5–40% of a course), but no real
student, course or proforma is copied. They use the app's default study
preferences unless a week says otherwise.

| Set | Weeks | Purpose |
| --- | --- | --- |
| development | d01–d08 | Building and tuning planners |
| test | t01–t08 | Results for GA version 1; seen since, so no longer held out |
| holdout | h01–h08 | Written and frozen before GA version 2 existed; final results only |

Cases covered: light and normal weeks, clashing deadlines, heavy
commitments, days off, an impossible workload, re-planning after missed
sessions, tasks that need input (no due date, overdue, completed), strict
preferences, long tasks due after the week, and no free time at all. The
holdout weeks add tight deadlines, awkward amounts of work, 50-minute gaps,
a Friday-night re-plan, a low daily limit, long-session preferences and an
overloaded mid-term week.

## Scoring

`ai/planova_scheduling/metrics.py` has two parts, used for every planner:

- **Hard-rule check** (`violations`): free study time only, no overlaps,
  breaks within a free period, daily and per-task-per-day limits, days off,
  session length, never past a deadline, never more than the work left.
- **Scores** (`score`): due work placed (%), missed minutes, work continuing
  after the week, heaviest day, spread across usable days (standard
  deviation; lower is more even), share of minutes in the last 24 hours
  before a deadline (lower is less cramming), and session counts. Exact
  definitions are in the module docstring.

## Run it

From the project root, with the existing `ai/.venv`:

```powershell
& ai/.venv/Scripts/python.exe -m unittest discover -s ai/tests -t ai -p "test_scheduling.py" -v
& ai/.venv/Scripts/python.exe ai/run_scheduling_baseline.py
```

`--set test` limits the table to one set; `--save` writes `report.json` to a
new folder under `research/experiments/scheduling/` (Git-ignored).

## Baseline results (22 November 2026)

All 16 plans pass the hard-rule check.

| Set | Due work placed | Missed min | Heaviest day | Day spread (std) | Last 24h |
| --- | --- | --- | --- | --- | --- |
| development (mean of 8) | 95.3% | 90 | 210 min | 87.9 min | 7.4% |
| test (mean of 8) | 86.5% | 20.6 | 195 min | 72.8 min | 7.1% |

Missed work comes only from the impossible week (d06), the Sunday-night
re-plan (t07) and the week with no free time (t08), where no planner could
place everything. What the numbers show: the baseline places work as early
as possible, so it rarely crams before deadlines but fills the first days to
the daily limit and leaves later days light (high day spread). That uneven
load is the main thing a GA could improve, *if* the supervisor agrees an
even spread matters more than finishing early.

## Limitations

- The weeks are synthetic and few; they test behaviour, not real students.
- Scores are not yet weighted into one "quality" number. That weighting is a
  decision for the student and supervisor before increment 2.
- The baseline is deterministic, so it has one result per week; the GA is
  run repeatedly with different seeds.

## The schedule goal (objective)

`ai/planova_scheduling/objective.py` turns any plan into one number, lower is
better. Chosen order of importance, "deadline-safe even spread":

| Level | Penalty | Weight |
| --- | --- | --- |
| 1 | Due work left unplaced (would be late) | 1000 per minute |
| 2 | Minutes in sessions ending under 24 h before the task's deadline | 20 per minute |
| 3 | Uneven days (standard deviation of minutes per usable day) | 5 per minute |
| 4 | Number of sessions (prefer fewer, longer ones) | 10 per session |
| — | Work due after the week left unplaced (so free time is still used) | 2 per minute |

Reasons: missed deadlines are the worst outcome; a buffer leaves room to
recover from missed sessions (the app re-plans when they happen); spacing
study over days helps learning and keeps days realistic. The weights are a
design choice, saved with every result, and the baseline is scored with the
same function.

## The Genetic Algorithm

`ai/planova_scheduling/ga.py`. A GA is a **search method, not trained AI**:
it keeps a population of candidate plans, scores them, and breeds better ones.
The current code is version 2; version 1 is in Git history (commit a0fbaad).

**Version 2 (current)**

- **Chromosome**: each task gets "turns", enough for its remaining work at
  the minimum session length. A chromosome is the order of all turns plus a
  preferred day for each turn.
- **Decoder**: on its turn, a task gets one session on its preferred day (or
  the nearest usable day, earlier first), at the earliest time that keeps
  every hard rule, and **as long as fits there** up to the maximum length and
  the work left (the baseline's own length rule). A final pass places
  leftovers in priority order. Every decoded plan is valid.
- **The baseline is reachable**: the baseline's plan can be written as a
  chromosome and decodes back exactly (tested on all 24 weeks). By default
  the first population includes it, so with elitism the GA is never worse
  than the baseline on the objective. This is a safety net, not the source
  of the gains: random starts reached the same results (below).
- **Operators**: tournament selection (3), order crossover on turns with
  uniform crossover on days (rate 0.9), swap mutation (0.3), day mutation
  (2 / turns, mostly ±1 day), 2 elites. Seeded, so repeatable.
- **Budget, chosen on development weeks only**: population 40, 120
  generations, baseline start. Tried 40×120 and 60×200, each with and
  without the baseline start (20 runs per week); this was the cheapest never
  worse than the baseline (random start at 40×120 was worse in 2 of 20 runs
  on d03). About 1–4 seconds per run in Python on a laptop.

**Version 1 (replaced)** cut each task into fixed, even chunks before placing
them. Results and the reason it lost are kept below.

Run:

```powershell
& ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set development --seeds 10
& ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set holdout --seeds 30 --save
```

`--random-start` leaves the baseline's plan out of the first population.

## Results: GA version 2 vs baseline (22 November 2026)

**Holdout weeks** (frozen before version 2 was written; run once with the
fixed settings, 30 runs per week). Every run kept all hard rules.

| Week | Baseline fitness | GA median | GA not worse | Day spread base/GA | Last-24h % base/GA | Missed min base/GA |
| --- | --- | --- | --- | --- | --- | --- |
| h01 tight two deadlines | 79311.9 | 64521.7 | 100% | 116 / 98 | 26 / 27 | **75 / 60** |
| h02 odd lengths | 561.9 | 166.4 | 100% | 92 / 13 | 0 / 0 | 0 / 0 |
| h03 short windows | 414.7 | 223.6 | 100% | 67 / 29 | 0 / 0 | 0 / 0 |
| h04 Friday re-plan | 2087.3 | 1924.9 | 100% | 94 / 61 | 13 / 13 | 0 / 0 |
| h05 light spread | 474.4 | 165.0 | 100% | 83 / 21 | 0 / 0 | 0 / 0 |
| h06 day-limit bound | 260.4 | 228.9 | 100% | 32 / 28 | 0 / 0 | 0 / 0 |
| h07 long sessions | 596.7 | 80.0 | 100% | 107 / 0 | 0 / 0 | 0 / 0 |
| h08 overloaded mid-terms | 517572.9 | 515172.9 | 100% | 107 / 107 | 43 / 28 | 510 / 510 |

Better on **all 8** holdout weeks (Wilcoxon signed-rank, one-sided, p =
0.004). On the tight week h01 the GA places 15 more minutes of due work than
the baseline; on the overloaded week h08 both miss the same work, but the GA
moves more of it out of the last 24 hours. Elsewhere the main gain is a much
more even week (e.g. h02 spread 92 → 13 minutes, h07 107 → 0) with the same
deadlines met. With **random starts** the holdout medians were the same on
7 weeks and better on h08 (missed 510 → 495), so the gains come from the
search itself, not from the baseline start.

Supporting results: development weeks, 20 runs each, better on all 8 (p =
0.004). The old test weeks (seen since version 1, so weaker evidence), 30
runs each: better on 6, equal on 2 (t02 exam week, t08 no free time), never
worse (p = 0.016); on t07, where version 1 lost, version 2 places 15 more
minutes of due work than the baseline (missed 45 → 30).

**Conclusion**: on these synthetic weeks, GA version 2 meets deadlines at
least as well as the app's rule-based planner and spreads study much more
evenly, while keeping every rule the app enforces. It has not been tested
with real students, on a phone, or against goals other than the one chosen
above.

**Random-number note.** These version 2 results were re-run on 22 November
2026 after switching the GA from Python's built-in generator to a small
shared generator (`ai/planova_scheduling/rng.py`, xorshift32) and a plain
standard-deviation formula, so that the app's Dart copy can reproduce runs
exactly. Settings and weeks were unchanged; this was not tuning. The holdout
table above was identical before and after the switch.

## The GA in the app (Dart)

`lib/services/planning/ga_planner.dart` (`planWeekBalanced`) is a
line-for-line copy of the Python GA, objective and generator, using the
default settings above and seed 0. It returns the same `PlanProposal` type as
the rule-based planner.

It is held to the evaluated version by saved plans: `ai/export_ga_golden.py`
writes the Python GA's plan and exact score for all 24 weeks to
`ai/scenarios/expected_ga/`, and `test/services/planning/ga_planner_test.dart`
requires the Dart GA to reproduce every one (sessions, unplaced work and the
score to the last digit). `ai/tests/test_ga.py` fails if those files go out of
date. The generator's first values are checked in both languages. After an
intended GA change:

```powershell
& ai/.venv/Scripts/python.exe ai/export_ga_golden.py
flutter test test/services/planning/ga_planner_test.dart
```

**In the app (23 November 2026).** The plan review screen makes both plans
from the same inputs and opens on **Balanced** (the GA); **Earliest first**
(the rule-based planner) is one tap away, and the student accepts either.
A short comparison shows busiest day, days with study, work in the last day
before it is due and, if any, due work not placed. "How this plan was made"
explains the chosen method in plain words, including that the GA is a search
method and not trained AI. The GA runs in a background isolate
(`balanced_plan_runner.dart`) with a "Finding a balanced plan…" message; if
it fails, the screen falls back to earliest first and says so. The seed is
fixed, so the same inputs always give the same plan. Accepted plans are
saved the same way whichever method made them.

In the Dart test runner on a laptop the GA plans all 24 weeks in about 3
seconds; phone timing is still to be measured. Parity is tested on the Dart VM; the generator uses
only 32-bit operations so web builds should match, but that is not tested.

## Results: GA version 1 vs baseline (kept for the record)

**Development weeks** (used for tuning, 20 runs each): the GA was never worse
than the baseline and better on all 8 weeks (Wilcoxon signed-rank, one-sided,
p = 0.004). Mostly it halved the day-to-day spread (e.g. normal week 99 → 51
min) and used fewer sessions; where deadlines clash, the spread cannot move.

**Test weeks** (run once with the fixed settings, 30 runs each; never used
for tuning). Every GA run kept all hard rules. Runs per week converged to the
same plan (inter-quartile range zero).

| Week | Baseline fitness | GA median | GA not worse | Day spread base/GA | Last-24h % base/GA | Missed min base/GA |
| --- | --- | --- | --- | --- | --- | --- |
| t01 normal week b | 654.9 | 330.0 | 100% | 105 / 42 | 0 / 0 | 0 / 0 |
| t02 exam week | 3693.2 | 4247.7 | **0%** | 85 / 82 | 11 / 13 | 0 / 0 |
| t03 clashing mid-week | 2110.3 | 657.8 | 100% | 92 / 104 | 10 / 0 | 0 / 0 |
| t04 work and club | 606.1 | 333.2 | 100% | 97 / 45 | 0 / 0 | 0 / 0 |
| t05 strict preferences | 1632.7 | 1506.5 | 100% | 56 / 35 | 13 / 13 | 0 / 0 |
| t06 long tasks later | 1420.0 | 1043.9 | 100% | 42 / 7 | 0 / 0 | 0 / 0 |
| t07 Sunday re-plan | 48014.0 | 56773.1 | **0%** | 105 / 103 | 23 / 21 | **45 / 54** |
| t08 no free time | 120600.0 | 120600.0 | 100% (equal) | 0 / 0 | 0 / 0 | 120 / 120 |

Better on 5 weeks, equal on 1, **worse on 2**. Across the 7 weeks that
differ, the improvement is not statistically significant (Wilcoxon, p =
0.41). In t07 the GA leaves 54 minutes of due work unplaced against the
baseline's 45, which is worse on the most important goal.

**Why it loses on t02 and t07** (diagnosed after the test run, not tuned on
it): the chromosome fixes chunk lengths in advance (e.g. 270 minutes become
five 54-minute chunks). Fixed lengths pack free periods less tightly than the
baseline's "as long as fits, up to the maximum" rule, leaving small unusable
gaps; on tight weeks that costs placed minutes. The GA cannot even express
the baseline's plan there, so more generations would not help.

**Conclusion for version 1**: on weeks with slack it gave much more even
plans; on tight weeks it could be worse than the simple rules. Version 2
(above) chooses session lengths while placing, and was checked on new
held-out weeks because these test weeks had been seen.
