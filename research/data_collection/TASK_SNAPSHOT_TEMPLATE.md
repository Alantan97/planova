# Planova task snapshot and availability templates

Draft v0.1 - 18 October 2026. Copy the tables into Sheets/Excel. These are collection specifications, not completed participant responses.

## Participant instructions

A snapshot is your set of active academic tasks at one planning moment. It is not a screenshot. Record your current situation before viewing any ranking suggested by Planova.

1. Use your assigned participant code. Record the date and time in Malaysia time.
2. List your active tasks you could currently work on, across your subjects. For a pilot, aim to include several competing tasks, for example 3–8 where available. Do not invent work to reach a count. If you have more, record it or note the number omitted; the set being ranked must be clear.
3. Give an exact deadline where known. Ask: **How much more time do you think you need to finish this task?** For example, another half hour = 30 minutes. This is an approximate guess, not the time until the deadline. Choose Not sure if you cannot estimate; unknown is not zero.
4. Choose difficulty and importance using the definitions below.
5. Ask yourself: **If I could begin my next study session now, which of these tasks would I choose to work on first, then next? I may work on part of a task rather than finish it.** Rank all tasks in this set. Equal priorities are allowed.
6. Briefly explain your choice if you wish. There is no adviser-provided correct ordering in this collection.
7. Repeat at the next agreed collection time with a new snapshot ID. Keep stable task IDs for work that appears again. Never copy the old ranks without reconsidering the current situation.

Do not list completed tasks or work that cannot currently be started as if it were an available choice. Note blocked work separately so missing prerequisites are not confused with low priority.

## A. Snapshot header: one row per planning moment

| Field | Required? | Format / meaning |
| --- | --- | --- |
| participant_id | Yes | Researcher-issued code, e.g. P001 |
| snapshot_id | Yes | Unique, e.g. P001-S01 |
| snapshot_at | Yes | Exact date and time, e.g. YYYY-MM-DD HH:MM; Asia/Kuala_Lumpur |
| programme | Yes | Software Engineering / Information Technology / Creative Multimedia |
| semester_of_study | Yes | Positive whole number |
| questionnaire_version | Yes | Version of the collection wording |
| minutes_available_for_next_session | Ask, allow unknown | Positive minutes; blank/unknown is not zero |
| listed_task_count | Yes | Number of tasks in the snapshot |
| all_actionable_tasks_listed | Yes | Yes / No / Unsure |
| omitted_task_count | If known | Number omitted; use unknown when unknown |
| conditions_note | Optional | Generic circumstances affecting choice; no identifying/medical detail |

## B. Tasks: one row per task per snapshot

| Field | Required? | Format / meaning |
| --- | --- | --- |
| snapshot_id | Yes | Links to exactly one snapshot header |
| task_id | Yes | Stable within a participant, e.g. P001-T01; never a predictive feature |
| input_order | Yes | Original display/list position to inspect ordering effects |
| task_title | Yes | Generic academic title; no other people's names |
| course_code | Yes | Student-supplied code; do not guess course name |
| task_type | Yes | Exercise / Assignment / Revision / Quiz preparation / Exam preparation / Project / Other |
| deadline_at | If known | YYYY-MM-DD HH:MM, Malaysia time; blank if unknown |
| deadline_status | Yes | Confirmed exact / Week only / Unknown |
| deadline_week_raw | If week only | Keep the stated week and academic session, without inventing a date |
| remaining_minutes | Ask, allow unknown | Positive whole minutes; work still needed, not original total duration |
| difficulty | Yes | Easy / Moderate / Challenging |
| importance | Yes | Low / Medium / High |
| assessment_weight_percent | Optional | 0–100 if known; blank means unknown, not 0 |
| chosen_rank | For an interpretable rank group | 1 = first choice; ties allowed; blank if student cannot judge |
| rank_status | Yes | Provided / Unable to judge |
| choice_reason | Optional | Student's reason, not an AI-generated explanation |
| label_source | Yes | student_stated_preference |
| record_source | Yes | participant_report; synthetic or researcher examples must be separate |

### Definitions to show participants

- **Remaining effort:** your estimate of minutes still needed from now. One hour = 60 minutes. Work already completed is excluded.
- **Difficulty:** how challenging you currently find the work: Easy = familiar/manageable; Moderate = some thought or support needed; Challenging = substantial uncertainty or effort. This is personal, not a course-wide fixed value.
- **Importance:** how much the task matters to you overall: Low / Medium / High. This is separate from which task you would choose first right now.
- **Chosen rank:** order of preference among this snapshot's tasks. Use 1 first, 2 next, etc. For ties use dense ranks, e.g. 1, 1, 2, 3. Do not assign unique ranks just because a form requires a choice.

### Researcher-only ranking preparation

- Do not show a priority formula, adviser ordering, or model output before collecting student labels.
- Keep the entire snapshot together. Do not train on individual rows split randomly from the same set.
- Preserve missing or uncertain fields and any incomplete ranks; flag them for review instead of filling with invented values.
- A single-task group has no between-task preference information. An all-tied group has no ordering contrast. Keep them in raw data but report/exclude appropriately from an informative ranking experiment.
- A possible later label conversion is `max(chosen_rank within snapshot) - chosen_rank`, giving higher scores to earlier choices and preserving ties. It is a proposed preprocessing rule to document and validate, not an additional human judgment. Keep the original ranks unchanged and check implementation label limits.
- Do not feed the chosen rank, converted label, choice-reason text explaining the rank, participant ID, snapshot ID, or task ID into the model as predictors. For the initial model, use only agreed pre-choice task/context features.
- Programme/course identifiers and preferences should only be added as predictors if justified and evaluated; they are not automatically useful just because they were collected.
- Preserve repeated task IDs so related observations and near-duplicates can be kept out of incompatible train/test partitions.

## C. Availability: one row per time block

| Field | Meaning |
| --- | --- |
| participant_id | Participant code |
| availability_version | Version/date when this information was confirmed |
| block_id | Stable identifier for the time block |
| block_kind | Allowed study / Fixed commitment / Protected time / Preferred study |
| activity_label | Generic name: Class, Work, Sport, Sleep, Personal |
| recurrence | Weekly / One-off |
| weekday_or_date | Monday–Sunday for weekly; exact date for one-off |
| start_time | HH:MM, 24-hour Malaysia time |
| end_time | HH:MM, 24-hour Malaysia time |
| ends_next_day | Yes / No; explicitly support cross-midnight sleep blocks |
| effective_from | First applicable date |
| effective_until | Last applicable date if known |
| movable_by_student | Yes / No; not authorization for automatic movement |

Fixed/protected blocks take precedence over allowed study windows. Preferred study periods are soft choices inside feasible availability. A university teaching break does not automatically mean a student is free or willing to study all day.

## D. Supplied example: incomplete, not a training observation

| Task | Course | Clarified deadline | Clarified remaining effort | Difficulty | Importance | Chosen rank |
| --- | --- | --- | --- | --- | --- | --- |
| Exercise 3 | DEQ3093 | 21 October 2026, 11:59 PM, Malaysia time | 30 minutes | Easy | Medium | Not provided |

The explicit date is the user's correction to the original Friday wording: 21 October 2026 is Wednesday. On 18 October 2026 the user clarified the remaining effort as 30 minutes, superseding the original ambiguous value 1. This row comes from the project researcher, with no planning timestamp or comparison set. Do not mix it into participant observations or assume its missing values.
