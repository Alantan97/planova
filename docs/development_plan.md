# Planova development roadmap

Status: proposed for discussion, not a finalized research protocol.
Updated: 18 October 2026. The innovation showcase is cancelled. FYP deadline: early January 2027; exact date not yet specified.

Confirmed direction: LambdaMART and GA are provisional choices and may change if a more suitable approach is established. Although course-proforma import began as a supervisor suggestion, the student has now chosen it as a central workflow, targeting their own university's students. Exact document formats and extraction scope still need inspection of real examples.

## Recommended development order and targets

The sequence in this table is the recommended implementation order. The workstream notes below provide technical detail, not a second competing sequence. Dates are proposed targets, not estimates backed by measured development velocity. Review progress weekly and preserve the December evaluation/submission buffer. Confirm the exact January deadline and university reporting requirements with the supervisor.

Keep the existing interface and task management. Complete each increment with a usable flow, relevant tests, and a short review before extending it.

| Order | Proposed window | Build | Completion check |
| --- | --- | --- | --- |
| 1 | 19–25 October | Inspect 2–3 representative proformas; finalize a one-week example, field definitions, and scheduling rules. Define the ranking collection instrument and pilot plan. | Know what comes from the PDF, what students must confirm, and how a missed session changes the example. |
| 2 | 19–25 October, after agreeing the core fields | Add local persistence, semester/course records, and task relationships. Design service boundaries for extraction and planning. | A subject and task survive restart with their IDs, dates, effort, and status intact. Existing task interactions still work. |
| 3 | 26 October–1 November | Proforma import for one selected text-based university template: extraction proof of concept, editable review, source references, and confirmed course/tasks. | A real supported PDF produces useful drafts. Missing dates are flagged; retry/reimport does not duplicate or overwrite confirmed records silently. Manual entry still works. |
| 4 | 2–8 November | Availability, classes and personal commitments, protected sleep time, and study preferences. Add a deterministic baseline scheduler and plan review. | Confirmed tasks generate a feasible weekly proposal; accept/cancel works and accepted sessions survive restart. Impossible work is explained. |
| 5 | 9–15 November | Session outcomes, remaining-effort updates, missed-session handling, and before/after adjustment review. Update Today and Progress from real records. | One complete import → task → plan → progress → adjustment flow works on Android without trained AI. No fabricated study hours or lost history. |
| 6 | 16–29 November | Python ranking and scheduling experiments using the agreed data. Evaluate LambdaMART and GA independently against their baselines; use repeated GA runs and held-out evaluation. | Document the results and limitations, select feasible approaches with the supervisor, and define the API inputs/outputs for integration. |
| 7 | 30 November–6 December | Connect the selected Python planning service to Flutter. Finish error/retry handling and stale-proposal protection. Add Firebase accounts/sync only if required by the agreed scope. | The full journey works with the selected real planning logic; failures preserve student inputs and do not replace accepted plans. |
| 8 | 7–13 December | Conduct the main student usability evaluation and complete held-out algorithm/document tests. Finish any scope-critical notification or account requirements. | Collect usable evidence, identify failures, and freeze new feature scope. |
| 9 | 14–20 December | Fix evaluation findings, run physical-device regression tests, analyze results, and finish the report, screenshots, and demonstration material. | A stable build and defensible evaluation are ready before the submission buffer. |
| 10 | 21 December–submission | Submission buffer: packaging, documentation, supervisor corrections, and critical fixes only. | No new major feature or algorithm dependency remains. |

### Parallel data and research track

- 19–25 October: prepare a few manually verified proformas, draft consent/collection materials for supervisor review, and define the priority-judgment target.
- 26 October–8 November: pilot the collection instrument, correct unclear questions, then expand as feasible. Maintain anonymous participant and snapshot IDs, sources, and collection dates. Reserve evaluation participants/documents before tuning.
- By 8 November: review whether task-ranking labels, variety, and evaluation access are sufficient to justify the proposed experiment. Decide with the supervisor whether to expand collection or simplify/change the approach. Do not manufacture labels from the baseline and present them as independent validation.
- During 16–29 November: tune only on development data, preserve held-out evaluation, and record experiments. Complete representative algorithm comparisons before integrating their outputs into Flutter.
- From the beginning: write methods, design decisions, and test evidence as work is completed. Do not leave the entire report until December.

### Early checkpoints to prevent late surprises

- Test a real PDF during the first increment; do not build a finished upload UI before knowing what can be extracted.
- Investigate ranking labels immediately; do not wait until November's model-development window to discover the dataset is unsuitable.
- Define planning and extraction contracts early. If extraction needs a small Python endpoint before the full planning backend, introduce only that narrow service rather than waiting for all AI work.
- Local persistence is the first usable storage layer. If authentication/cloud sync is mandatory, prototype that integration during November alongside algorithms rather than reserving all of it for the final integration week.
- Prefer one supported proforma format and a reliable full journey before broader OCR, chatbot, extra dashboards, or new UI styling.
- A baseline version should be usable by 15 November. Real algorithms improve and are compared with it; their research uncertainty should not prevent the application from functioning.

### Immediate next task

Review 2–3 student-supplied proformas and turn the existing illustrative week into one concrete university example. Agree on the initial data fields and constraints. The first coding increment is then persistent course/task records, followed by the narrow document-import flow. Do not start a broad redesign or model training first.

## Product definition

See `docs/workflow.md` for the proposed screen-by-screen student journey, scheduling rules, worked example, and implementation increments.

Planova helps university students turn academic responsibilities into a realistic personal study plan, monitor progress, and adjust remaining sessions when plans change.

The app schedules independent study around fixed classes and commitments. It does not rearrange the university's official timetable. Confirm this interpretation with the supervisor.

The core journey is:

1. Add subjects and assessments manually, or review drafts imported from a course proforma.
2. Confirm exact deadlines, estimated remaining effort, and task importance/difficulty.
3. Enter weekly study availability and fixed commitments.
4. Generate a proposed study plan and review any unscheduled work.
5. Accept the plan and record completed, partial, or missed sessions.
6. Review and accept changes to future sessions.

## Existing application

Implemented: branded interface, four navigation tabs, editable academic tasks, sample sessions, and sample progress. Tasks now persist locally across restarts; sample tasks are seeded only on first use. Deleting all tasks remains an empty list after restart. Calendar sessions and study-time totals remain samples.

Semester/course records and explicit task-to-course relationships now also persist locally, with automatic migration of existing task data, duplicate-code checks within each semester, and deletion protection for referenced records. Manual subjects remain supported.

The first narrow proforma increment now reads a supported text-based UPSI PDF locally, extracts course/assessment drafts, requires review and missing task inputs, and commits confirmed records atomically with source-row deduplication. It has a replaceable PDF text-reader boundary. See `docs/proforma_import.md` for scope and limits.

Not implemented: real planning, session progress recording, adaptive rescheduling, broader document formats/OCR, weekly topic extraction, Firebase, Python API, or trained ranking. The next increments are representative document evaluation and availability/preferences with a deterministic baseline scheduler.

Keep the current UI as a foundation. Avoid a broad redesign while the behavior is being defined.

## Responsibilities and terminology

| Part | Responsibility |
| --- | --- |
| Document import | Extract candidate subjects, topics, assessments, and workload information; ask for missing or uncertain values |
| Task management | Store confirmed academic work, deadlines, remaining effort, and completion state |
| Prioritization | Order active tasks and explain the factors used |
| Scheduling | Allocate remaining effort to feasible time slots |
| Adaptation | Update future sessions after availability or progress changes |
| UI | Collect inputs, show explanations, and let students review decisions |

Document extraction, learned task ranking, and schedule optimization are separate problems. LambdaMART is a proposed ranking approach requiring training data and relevance labels. A Genetic Algorithm is a proposed optimization approach requiring a schedule representation, constraints, objective function, and search procedure; it is not a model trained on proformas.

## Workstream: agree on the specification

Deliverable: one worked example using a real student week, plus an agreed requirements list.

Define subjects, assessments, study tasks, sessions, fixed commitments, availability, and semester dates. Keep task completion distinct from recorded study time. Specify how remaining effort changes after partial progress and how students correct inaccurate estimates.

Agree on hard constraints: no overlapping sessions, no conflict with fixed commitments, valid duration, and sessions within allowed study windows. Define deadline handling explicitly: preserve unscheduled work and flag infeasibility rather than silently creating a late or conflicting plan.

Agree on soft preferences: breaks, preferred session length, daily workload limits, earlier preparation, and avoiding unnecessary movement of accepted sessions.

Decide the planning horizon, minimum session length, treatment of overdue work, and whether adjustments need approval.

Exit criterion: the student and supervisor can explain the same inputs, expected output, and missed-session example.

## Workstream: establish a functional baseline

Deliverable: a complete manual-entry-to-study-plan workflow using transparent rules.

Add availability and fixed commitments. Introduce a planning-service contract and a deterministic baseline, such as deadline ordering with explicit priority tie-breaks and placement in available slots. Support session completion, partial progress, missed sessions, and adjustment review. Show conflicts and unscheduled effort.

Add local persistence so records survive restarts, keeping repositories replaceable. Label the baseline accurately as rule-based planning, not trained AI.

Exit criterion: real task inputs produce valid sessions, progress updates remaining effort consistently, and the plan survives restart. Test normal weeks, impossible deadlines, no availability, and missed sessions.

## Workstream: investigate research feasibility in parallel

Start this investigation during specification and baseline work, rather than waiting for polished screens.

Confirm whether LambdaMART and GA are mandatory or provisional. Define the ranking decision context, task features, and who will provide relevance judgments. Collect representative examples and decide how to separate training and evaluation data without leaking the same student's near-identical planning situations across sets. Synthetic examples can help debug the pipeline but cannot establish effectiveness for real students.

For scheduling, define valid schedules, workload objectives, and acceptable runtime. Compare a GA against the functional baseline using the same inputs and constraints.

Exit criterion: a supervisor-reviewed data and evaluation plan, with a feasible algorithm choice. If suitable ranking labels cannot be obtained, discuss the scope or approach before committing to model training.

## Workstream: add course-proforma import

Deliverable: import support for a small, explicitly defined set of document formats.

Inspect actual documents before choosing extraction tools. Start with text-based PDFs from one course template. Extract structured drafts with source references and editable review. Missing deadlines or assessment weeks must not become invented exact dates. Map teaching weeks using the academic calendar, including breaks. Keep suggested study effort separate from confirmed effort and avoid counting contact hours twice.

Verify duplicate handling when a document is imported again. Retain manual entry as a fallback. Add scanned documents/OCR only if required by the agreed scope.

Exit criterion: field-level extraction checks against manually verified examples and successful student correction of missing or incorrect values.

Because document import is now a chosen central workflow, inspect representative proformas during the specification increment and develop a narrow extraction proof of concept early. Full import integration should still output the same confirmed task format used by the baseline.

## Workstream: integrate the evaluated planning approach

Deliverable: a Python planning API and Flutter integration using the established service contract.

Implement and evaluate ranking and optimization in Python outside the UI first. Integrate the selected approach after it meets the agreed tests. Handle loading, errors, stale planning results after task edits, and retry without losing entered work.

Add Firebase authentication and synchronization when accounts or cross-device storage are needed. Define which layer owns confirmed tasks and accepted plans. External API credentials belong on the backend, not in Flutter.

Exit criterion: the complete student journey works with the real planning service and handles failures clearly.

## Workstream: evaluate and refine

Evaluate software correctness, scheduling feasibility, comparison against the baseline, usability, and the research question separately. Possible measures include deadline violations, unscheduled minutes, workload balance, planning runtime, correction effort, and task completion rate during a defined study.

Use held-out judgments for ranking evaluation where applicable. An attractive interface or a good synthetic example does not establish better learning outcomes.

Refine UI based on student feedback. Complete physical Android tests, notifications if in scope, accessibility checks, and release preparation.

## Deferred unless explicitly justified

Chatbot, voice input, WhatsApp integration, broad OCR format support, social features, extensive gamification, and advanced dashboards.

## Questions to resolve before the next implementation

1. What real student task examples and independently collected priority judgments can be obtained?
2. Confirmed ranking target: students' stated preferences. Finalize the collection instructions and evaluation claims on that basis; do not frame them as adviser-recommended or objectively optimal priorities.
3. What participant access, consent process, and assessment criteria does the supervisor expect?
4. What is the exact submission date in early January 2027?

## Data collection starting point

Public datasets, including Kaggle datasets, are optional supplements rather than automatically compatible training data. Check the unit of observation, available features, label meaning, ranking groups, provenance, and reuse terms before choosing one. Student-level grade or study-hours records cannot simply be appended to task-level priority judgments. Keep source identifiers and independent local evaluation when using compatible external data.

For the proforma workflow, collect representative university documents and manually verify the fields to extract. These document/field pairs serve extraction development and evaluation; they do not automatically supply priority-ranking labels.

Local materials have now been supplied for UPSI. See `research/data_collection/README.md` for an English questionnaire draft, task-snapshot and availability table specifications, a pilot protocol, and source review. The intended participant programmes are Software Engineering, Information Technology, and Creative Multimedia; official names/coverage and supervisor collection arrangements are still to be checked. These drafts are not published forms or an approved research protocol.

Separate application records, ranking training examples, scheduler test cases, and final evaluation feedback.

For ranking, one planning snapshot groups all active tasks a student is choosing between at a given time. Record an anonymous student ID, snapshot ID and timestamp, time to deadline, remaining effort, difficulty, assessment weight if known, and a separate priority judgment. Keep provenance for real, synthetic, and rubric-generated examples. Do not use IDs as predictive features.

Start with a small collection-instrument pilot (for example, 5–8 students with two snapshots each). This is a feasibility exercise, not a claim of enough training data or a statistically adequate final study. Review label consistency and example diversity with the supervisor before expanding collection.

Collect relevance judgments or a preferred ordering independently of the baseline formula. Decide what the model is intended to learn: student preference and adviser recommendation are different targets. Record ties and disagreement instead of treating subjective judgments as an objective ground truth.

Keep each ranking snapshot intact. For a claim about new students, separate students between training and evaluation; for a claim about future planning for existing students, consider a time-based split with controls for repeated tasks. Reserve evaluation examples before tuning.

GA development needs realistic scheduling scenarios and agreed constraints/objectives, not a labeled training dataset. Compare repeated GA runs with the same deterministic baseline on matched inputs. Student feedback evaluates usability separately from ranking and schedule quality.

Immediate next deliverable: a one-week worked planning example and a short specification, before further interface expansion or AI implementation.
