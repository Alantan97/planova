# Scheduling evaluation

Started 22 November 2026. This is increment 1 of 3: shared test weeks, plan
scoring and the rule-based baseline. **There is no Genetic Algorithm yet.**
Increment 2 adds the GA, scored by exactly the same code; increment 3 writes
up results and decides integration with the supervisor.

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
- The baseline is deterministic, so it has one result per week; the GA will
  need repeated runs with different seeds.
