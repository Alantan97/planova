# Rule-based weekly planner (baseline)

Implemented 21 November 2026. Code: `lib/services/planning/rule_based_planner.dart`
(`planWeek`), tests: `test/services/planning/rule_based_planner_test.dart`.

This is a deterministic, explainable planner. It uses fixed rules, no trained
model and no randomness. It is the baseline that any later optimisation (for
example a Genetic Algorithm) should be compared against on the same inputs.

## Student flow

1. Plan tab → **Create my plan** (or **Re-plan the next 7 days**).
2. A proposal screen shows the sessions by day, work that could not fit, and
   tasks that were not planned. Nothing is saved yet. Since 23 November 2026
   it opens on the **Balanced** plan (the Genetic Algorithm in
   `ga_planner.dart`, see `docs/scheduling_evaluation.md`); this rule-based
   plan is the **Earliest first** option on the same screen.
3. **Accept plan** saves it; **Cancel** leaves any accepted plan unchanged.
4. Plan and Today show the accepted sessions, with recurring commitments shown
   as fixed blocks. Re-planning replaces only planned sessions inside the new
   plan period.

## Inputs

- Tasks: title, due date, estimated and recorded minutes, grade weight.
- Free study time: study windows minus recurring commitments
  (`freeStudySlots`, see the availability feature).
- The current time (the device clock; the fixed preview clock in the demo build and tests).

## Rules

1. **Eligible tasks:** active, with a due date in the future and work remaining.
   Tasks without a due date are listed as "Needs a due date"; overdue tasks as
   "Due date has passed". Neither is guessed or placed.
2. **Priority order:** earliest due date; then higher grade weight (unknown
   weight last); then more remaining work; then task ID.
3. **Plan period:** from now (rounded up to 5 minutes) to the end of the 7th day.
4. **Placement:** each free slot is filled in time order. For every session the
   first task in priority order that may still be studied is chosen, where:
   - the session ends **no later than the task's due date**;
   - total study that day stays within the **daily limit (4 h)**;
   - study of that task that day stays within the **per-task limit (2 h)**;
   - the session lasts **at most 60 min** and **at least 30 min** (or the whole
     remainder if less than 30 min is left).
   A **15 min break** follows each session within the same slot. Gaps too short
   for any session are left free.
5. **Reporting:** remaining work is reported as "Not enough time" when the task
   is due inside the plan period, or "Continues after this week" otherwise.

All limits live in `PlannerSettings` so the report and comparisons use the
same values. The numbers above are the defaults (the baseline). Since slice 2
of the restructure, students can change them on Profile → Study preferences
(`StudyPreferences`, saved with the profile): shortest and longest session,
break, daily limit, time per task per day, and **days off** (weekdays on which
nothing is planned). `PlannerSettings.fromPreferences` turns them into planner
settings; every plan and re-plan uses the saved preferences. Choices are limited
to listed options so invalid combinations cannot be saved. For evaluation, run
the baseline with `const PlannerSettings()`.

## Measures for evaluation

`PlanProposal` exposes: scheduled minutes, minutes not placed before their due
date, minutes per day, number of sessions and tasks. Deadline violations are 0
by construction (rule 4).

## Recording sessions and adjusting the plan

Implemented 21 November 2026 (slice 5). Code: `StudyPlanRepository.recordOutcome`,
`lib/features/planner/widgets/record_session_sheet.dart`.

- Tapping a study session on Today or Plan opens **How did it go?**: **Done**
  (the planned minutes), **Partly done** (the minutes studied, less than the
  session) or **Missed**. Reopening a recorded session allows a correction.
- The task's recorded minutes change by the difference between the new and the
  previous outcome, so corrections never double-count. If more is studied than
  estimated, the estimate grows to match. When no work is left, a message
  offers **Mark complete**.
- Past sessions that were never recorded are listed on Today under
  **Did you do this?**.
- A missed or partly done session sets a "plan needs updating" flag. Today then
  shows **Re-plan the rest of the week**, which opens the same proposal screen;
  accepting clears the flag. Recorded sessions (done, partly done, missed) are
  never replaced by re-planning and remain as history.
- Progress shows minutes studied this week against minutes planned.

Storage format version 2 adds recorded minutes, the "partial" status and the
re-plan flag; plans saved in version 1 still load.

## Not included yet

Automatic re-planning without review and notifications. (The GA comparison is in `docs/scheduling_evaluation.md`.)
