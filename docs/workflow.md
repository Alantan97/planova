# Planova workflow

Proposed workflow for discussion — 18 October 2026.
Target: university students; FYP submission in early January 2027.
This describes intended behavior, not functionality already implemented.

## 1. Purpose

Help a student turn course requirements into a realistic personal study plan, follow it, and adjust future study sessions when circumstances change.

Planova schedules personal study around the university's class timetable. It does not move official classes, change assessment deadlines, or automatically override personal commitments.

## 2. Main journey

Set up semester → Import proforma → Review course information → Confirm tasks → Set availability and preferences → Review proposed study plan → Accept → Record progress → Review adjustments.

Manual course/task entry remains available when import fails or information is missing.

## 3. First-time setup

Student selects their current semester and confirms its start date and teaching breaks. Use an editable academic calendar so assessment weeks can be interpreted correctly. The exact academic-calendar source is still to be determined.

Account creation may be added with persistent account storage; it is not necessary to test the core planning journey.

Result: a semester with an agreed calendar, not a generated study plan yet.

## 4. Import and review a course proforma

1. Student selects a PDF and the semester/course it belongs to.
2. Planova checks whether the file is supported and readable.
3. Extraction creates a draft of course details, weekly topics, assessments, assessment weights, assessment weeks/dates, and independent-study workload where available.
4. A review screen presents each field with its source page and highlights missing or uncertain information. Do not invent confidence percentages.
5. Student corrects the draft and confirms what to import.
6. The course and confirmed assessment records are saved.

An old proforma is not evidence that an assessment has the same date this semester. A week number remains a provisional window until the calendar and deadline are confirmed. An assessment without a confirmed deadline can be saved as a draft, but is excluded from deadline-based scheduling until completed.

If the PDF cannot be read, offer retry or manual entry. If it has been imported already, offer a comparison/update; do not silently duplicate tasks or overwrite student corrections.

Result: reviewed course information, not an automatically accepted timetable.

## 5. Turn academic information into tasks

Assessments can become task drafts. Topic revision should be suggested for review, not create hundreds of activities without consent.

Before a task can be scheduled, confirm:

- Task title and subject.
- Exact deadline where required by the scheduling rules.
- Estimated remaining effort.
- Difficulty and importance, with editable defaults.

Assessment weighting can inform importance but is not the same as the student's final task priority. Contact teaching hours must not be counted again as independent study time.

Tasks can also be created manually, including assignments announced after the proforma was issued.

Result: a list of confirmed, active academic tasks with usable planning inputs.

## 6. Set personal availability

Student specifies:

- Fixed commitments: classes, labs, work shifts, club meetings, appointments.
- Protected time: sleep, meals, travel, personal responsibilities.
- Allowed study windows: recurring periods plus one-off exceptions.
- Preferences: preferred study periods, session length, break length, and daily study limit.

Activities may be fixed or flexible, chosen by the student. Do not assume non-academic commitments may be sacrificed. For the first version, treat activities as unavailable time unless the student explicitly moves them.

Fixed commitments and protected time override an overlapping study window. A preferred period does not create availability outside the allowed study windows.

Result: feasible study slots and preferences. No medical sleep assessment or inferred sleep recommendations are needed.

## 7. Generate and review a study plan

1. Validate task inputs and identify blocked tasks.
2. Prioritize eligible tasks. Start with transparent rules; later compare the proposed LambdaMART ranker.
3. Allocate remaining work into available slots. Start with a deterministic scheduler; later compare GA optimization.
4. Show a proposed plan, workload summaries, unscheduled work, and useful explanations.
5. Student accepts, changes inputs and regenerates, or cancels.

Initial proposed planning horizon: the next seven days, clearly identified as a weekly plan rather than a promise to finish every future task within that week. Work outside the horizon and work that cannot fit before its deadline should have different explanations.

Hard rules:

- Sessions cannot overlap other sessions, fixed commitments, or protected time.
- Sessions stay within allowed study windows and the stated daily limit.
- Sessions have positive duration and respect agreed break/session rules.
- Completing a task must not fabricate logged study time.
- Work that cannot fit remains visible; never silently schedule it after the deadline.
- Preserve completed history and locked future sessions when making adjustments.

Prefer suitable study times, balanced workload, higher-priority preparation, and minimal movement of existing accepted sessions among otherwise valid plans.

If inputs change while a plan is being prepared, invalidate that proposal and regenerate before accepting it. Regenerating must not duplicate study sessions.

Only acceptance replaces the relevant future plan. Cancelling a proposal leaves the accepted calendar unchanged.

## 8. Daily use and progress

Today shows the next study session, daily agenda, upcoming deadlines, and tasks needing attention.

After a session, student can:

- Mark it completed and confirm actual study time and remaining work.
- Record partial progress and revise remaining effort.
- Mark it missed, adding no completed time.

Elapsed study time and reduction in remaining effort are related but not identical. Initial UI may suggest a remaining-effort value, but students must be able to correct it. Studying for 60 minutes does not prove an assignment is 60 minutes closer to completion.

Finishing one session does not automatically finish the entire assignment. Assignment completion is an explicit action and does not create extra study hours. A passed session is not automatically considered completed; ask for its outcome.

## 9. Adjustment workflow

Triggers include a missed session, changed remaining effort, new task, changed deadline, or changed availability.

1. Save the student's factual update immediately.
2. Mark the affected future plan as needing review.
3. Reconsider priorities and reschedule only the work still outstanding.
4. Present before/after session times, reasons for changes, and any unscheduled work.
5. Student applies the proposal or keeps the current plan.

Rejecting a proposal does not erase a missed-session record or progress update. Keep any resulting conflicts visible. Apply only if the proposal still matches current inputs.

For a completed/deleted task, remove its planned future sessions with clear confirmation where relevant; retain recorded study history. A reopened task can be included in a newly reviewed proposal.

## 10. Worked example

Illustrative inputs, not automatically extracted facts:

- Reviewed proforma identifies a database assignment worth 30%.
- Student confirms Friday at 5 PM as the deadline and two hours of remaining effort.
- Tuesday evening is a fixed work shift; 11 PM–7 AM is protected sleep time.
- Available slots include Monday, Wednesday, and Thursday from 8–9 PM.
- Student prefers 60-minute study sessions.

Initial proposal: Monday 8–9 PM and Wednesday 8–9 PM. Student accepts.

Student misses Monday. Remaining effort stays at two hours. Planova proposes keeping Wednesday's session and adding Thursday 8–9 PM. The Tuesday work shift and protected sleep time remain untouched. Student reviews and applies the change.

If Thursday becomes unavailable and no other permitted slot can fit the work, show the unscheduled hour and ask the student to change availability, revise their estimate, or make another explicit decision. Do not quietly move the deadline or sleep period.

## 11. Screens and navigation

Keep the current Today / Tasks / Plan / Progress bottom navigation.

| Screen or flow | Access | Main action |
| --- | --- | --- |
| Semester and courses | Profile/settings or a course-management action | Set calendar, manage subjects, import PDFs |
| Import review | After PDF selection | Correct and confirm extracted information |
| Tasks and task details | Tasks | Manage academic work and missing inputs |
| Availability and preferences | Plan setup and profile/settings | Define when studying is possible |
| Plan preview | Generate plan | Review, accept, or regenerate |
| Daily agenda and session details | Today / Plan | Record an outcome |
| Adjustment review | Prompt after relevant changes or Plan | Inspect and apply proposed changes |
| Progress | Progress | Review real recorded time, task completion, and missed sessions |

Preserve orange, white, and black styling. White text/icons on orange surfaces. Bottom navigation uses filled orange selected icons/labels without pill indicators or hover/press pills.

## 12. Data collection alongside development

Keep these collections separate:

1. PDF extraction reference: university proformas plus manually checked fields and source pages.
2. Student preferences: a one-time form plus editable changes during use.
3. Ranking examples: active task sets at a recorded planning moment, attributes, and independent priority judgments. Agree whether labels express student preferences or adviser recommendations.
4. Scheduler cases: realistic tasks, calendars, constraints, and expected feasibility; include impossible cases.
5. Evaluation: held-out ranking cases, unseen documents, scheduler comparisons, and student usability feedback.

Use a form and spreadsheet for a small collection pilot before expanding. Decide the final study size and process with the supervisor. Kaggle data is optional and must fit the same task and label definitions before use.

Preferences collected at onboarding are operating inputs, not automatically ranking labels. Proforma fields are document reference data, not evidence of correct task priorities.

## 13. Practical build order

| Increment | Concrete outcome |
| --- | --- |
| A. Inspect representative PDFs and finalize the worked example | Field list, missing-input decisions, reviewed scheduling rules |
| B. Add persistent records, semester/courses, and availability | Inputs survive restart and describe a real student week |
| C. Build a narrow proforma extraction proof of concept | One university template produces editable, source-linked drafts |
| D. Connect confirmed tasks to a baseline planner | A complete import/manual-entry → review → accepted-plan journey |
| E. Add progress recording and adjustment review | A missed or partial session results in an explainable proposal |
| F. Evaluate ranking/GA and integrate a Python API | Real algorithms compared fairly against the baseline |
| G. Student testing and release preparation | Usability findings, Android checks, evaluation results, submission artifacts |

Investigate ranking-data feasibility and pilot the collection instruments during A–D. Do not postpone that work until the interface is finished.

## 14. Definition of a working first version

A student can import and correct supported course information, add missing task details, protect academic/personal commitments, accept a feasible weekly plan, record progress, and review an adjustment. Their records survive restart. Invalid or impossible inputs have clear explanations.

The baseline can meet this definition before trained ranking or GA is integrated. Until then, label its planning method accurately. Notifications, a chatbot, broad OCR support, and extensive analytics are later scope decisions.

## 15. Next action

Inspect two or three representative proformas supplied by the student, then confirm the extraction fields and work through one real student week with the supervisor. The planning horizon and constraint defaults above are proposals to review, not finalized research requirements.
