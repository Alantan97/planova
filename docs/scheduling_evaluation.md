# Scheduling evaluation

Started 22 November 2026. Increment 1: shared test weeks, plan scoring and
the rule-based baseline. Increment 2: a Genetic Algorithm (GA) scored by
exactly the same code, and its first comparison with the baseline (below).
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

`ai/build_scenarios.py` writes 16 weeks to `ai/scenarios/`. All are
**synthetic**: realistic shapes for a UPSI undergraduate (weekday classes,
evening and weekend study, tasks worth 5–40% of a course), but no real
student, course or proforma is copied. They use the app's default study
preferences unless a week says otherwise.

| Set | Weeks | Purpose |
| --- | --- | --- |
| development | d01–d08 | Building and tuning planners |
| test | t01–t08 | Final results only; never used for tuning |

Cases covered: light and normal weeks, clashing deadlines, heavy
commitments, days off, an impossible workload, re-planning after missed
sessions, tasks that need input (no due date, overdue, completed), strict
preferences, long tasks due after the week, and no free time at all.

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

- **Chromosome**: each task's remaining work is cut into even chunks
  (between the minimum and maximum session length). A chromosome is the
  order of the chunks plus a preferred day for each chunk.
- **Decoder**: places chunks in that order on the preferred day (or the
  nearest usable day, earlier first) at the earliest time that keeps every
  hard rule; a final pass places leftovers in priority order. Every decoded
  plan is therefore valid.
- **Operators**: tournament selection (3), order crossover on the chunk
  order with uniform crossover on days (rate 0.9), swap mutation (0.3), day
  mutation (1 / chunks, mostly ±1 day), 2 elites. Seeded, so repeatable.
- **Budget, chosen on development weeks only**: population 60, 200
  generations. Tried 40×120, 50×150 and 60×200 (10–20 runs per week); 60×200
  was the smallest never worse than the baseline on any development week.
  Starting from a priority-order individual made no difference, so it is off.

Run:

```powershell
& ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set development --seeds 10
& ai/.venv/Scripts/python.exe ai/run_scheduling_ga.py --set test --seeds 30 --save
```

## Results: GA vs baseline (22 November 2026)

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

**Conclusion so far**: on weeks with slack, the GA gives much more even
plans with the same deadlines met; on tight weeks this version can be worse
than the simple rules. It is not ready to replace the baseline. The next step
is a decoder that chooses session lengths while placing (so the baseline's
plan is always reachable), checked on development weeks and then on **new**
held-out weeks, because these test weeks have now been seen.
