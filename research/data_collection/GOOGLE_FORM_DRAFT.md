# Planova Google Forms draft

Version GF-0.1 - 18 October 2026. English copy-ready draft, not a published Google Form.
Based on `STUDENT_QUESTIONNAIRE.md`, adapted for Google Forms question types and section routing. Use this file as the build specification for the first preferences/requirements form. Task snapshots remain a separate follow-up.

## Form title

Planova: Study Planning Needs and Preferences of UPSI Students

## Form description - copy after completing the brackets

Hello! I am [researcher name], a student in the Faculty of Computing & Meta-Technology at Universiti Pendidikan Sultan Idris (UPSI), developing Planova for my Final Year Project.

Planova is a proposed study planner that uses reviewed course-proforma information and student-provided preferences to suggest personal study schedules around classes and other commitments. Its features are still under development.

This questionnaire asks how you currently plan your studies, what makes planning difficult, and what you would want a planner to respect. It is intended for UPSI undergraduate students in Software Engineering, Information Technology, and Creative Multimedia.

Participation is voluntary. There are no right or wrong answers about your preferences. Please do not provide your matric number, password, medical information, other people's names, or detailed personal circumstances. Use general labels such as Work, Sport, or Personal commitment.

Responses use a participant code rather than your name. If you join a follow-up, records may be linked using that code; we do not promise complete anonymity. Follow-up contact arrangements, if needed, are handled separately.

Researcher: [name and UPSI contact]
Supervisor: [name and contact]
Data access and storage: [who can access responses and where they are stored]
Retention period: [period and deletion arrangements]
Withdrawal: [how to request withdrawal using the participant code, and any cutoff]
University review/approval details, if applicable: [confirm with supervisor; do not claim approval until obtained]

Do not promise a completion time until the pilot establishes one.

## Section 1 - Participation choice

### Q1. Have you read the information above and do you agree to participate?

- Type: Multiple choice.
- Required: Yes.
- Options and routing:
  - Yes, I agree to participate. → Section 2.
  - No, I do not agree to participate. → Section 8 (Exit).
- Set Section 1's default next destination to Section 2; answer routing overrides it.

## Section 2 - Eligibility

### Q2. Are you currently a UPSI undergraduate studying Software Engineering, Information Technology, or Creative Multimedia?

- Type: Multiple choice.
- Required: Yes.
- Options and routing:
  - Yes. → Section 3.
  - No. → Section 8 (Exit).
- Set Section 2's default next destination to Section 3.

## Section 3 - About your studies

Description: Please use the participant code supplied by the researcher. Do not enter a matric number.

### Q3. Participant code

- Type: Short answer.
- Required: Yes, for an invited coded pilot.
- Description: Enter the code supplied by the researcher, for example P001. If you have not received a code, contact the researcher before completing this pilot.
- Researcher note: Do not publicly distribute this coded-pilot version without arranging code assignment. If switching to an open survey, revise the linking/recruitment procedure first.

### Q4. Which programme are you currently studying?

- Type: Multiple choice.
- Required: Yes.
- Options: Software Engineering / Information Technology / Creative Multimedia.
- Researcher note: Confirm the university's official programme wording before publication.

### Q5. What is your current semester of study?

- Type: Short answer.
- Required: Yes.
- Description: Enter your semester number, for example 3. This is not the academic-session code such as A261.
- Validation: Regular expression matches `^[1-9][0-9]*$`.
- Error text: Enter a positive whole semester number, for example 3.
- After Section 3: Continue to Section 4.

## Section 4 - Your current planning experience

### Q6. How do you currently keep track of academic tasks and deadlines?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply.
- Options:
  - Phone or online calendar.
  - Paper planner or notebook.
  - Notes app.
  - Task or study-planning app.
  - LMS announcements, course pages, or messages.
  - I mainly rely on memory.
  - Other (enable the built-in Other option).

### Q7. During the past two weeks, which difficulties have you experienced when planning your studies?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply. If you choose None, do not select another option.
- Options:
  - Remembering deadlines.
  - Deciding which task to start.
  - Estimating how much time I still need to finish a task.
  - Fitting study around classes and other commitments.
  - Updating my plan after missing a session or a change in circumstances.
  - None of these.
  - Other (built-in).
- Builder note: This is a respondent instruction, not an automatically enforced exclusive-checkbox rule. Check contradictory responses during cleaning; do not claim Google Forms enforces it.

### Q8. Where do you usually access a course proforma or course outline?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply. If you choose Not sure or I do not use these, choose that option only.
- Options:
  - PDF or file shared by a lecturer.
  - University LMS or course website.
  - Printed copy.
  - I am not sure what a course proforma is.
  - I do not usually access one.
  - Other (built-in).
- Builder note: Check contradictory selections in cleaning rather than invent a native exclusivity setting.

### Q9. If a planner reads a course proforma, which information would you want to check or correct before using it?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply. Choose Not sure alone if applicable.
- Options:
  - Course name and code.
  - Topics and teaching weeks.
  - Assessment names and weightings.
  - Assessment dates or weeks.
  - Suggested study tasks or preparation time.
  - I would not want to use document import.
  - Not sure.
  - Other (built-in).
- Builder note: Allow students to express rejection of the feature; do not interpret selection as an endorsement or an accuracy measurement. Treat feature-rejection combined with checked fields as a clarification case if its meaning is unclear.

### Q10. Describe one recent situation where you had to change your study plan.

- Type: Paragraph.
- Required: No.
- Description: A short example is enough. Do not include names or sensitive personal details.
- After Section 4: Continue to Section 5.

## Section 5 - How you prefer to study

Description: These are preferences, not rules about how students should study. Scheduled classes are excluded from independent study. You can change your preferences later.

### Q11. Which time of day would you most prefer for independent study?

- Type: Multiple choice.
- Required: Yes.
- Options:
  - Morning (6 AM to before 12 noon).
  - Afternoon (12 noon to before 6 PM).
  - Evening (6 PM to before 10 PM).
  - Late night / early hours (10 PM to before 6 AM).
  - No particular preference.
  - It varies by day.
- Description: A preference does not override time you reserve for sleep or other commitments. Exact permitted study windows are collected separately.

### Q12. How long would you prefer one study session to last?

- Type: Multiple choice.
- Required: Yes.
- Options: 25 minutes / 45 minutes / 60 minutes / 90 minutes / It varies / Other (built-in; ask for minutes).

### Q13. How long a break would you prefer between study sessions?

- Type: Multiple choice.
- Required: Yes.
- Options: 5 minutes / 10 minutes / 15 minutes / It varies / Other (built-in; ask for minutes).

### Q14. What daily maximum would you currently choose for independent study, excluding classes?

- Type: Multiple choice.
- Required: Yes.
- Options: 30 minutes / 60 minutes / 90 minutes / 120 minutes / 180 minutes / It varies / Not sure / Other (built-in; ask for minutes).
- Description: This is the limit you would choose for planning, not the number of hours you must study or a health recommendation. Exact numeric limits can be confirmed during the follow-up.
- Builder note: Other/It varies/Not sure cannot be silently converted to zero or a guessed numeric limit.
- After Section 5: Continue to Section 6.

## Section 6 - Activities and protected time

### Q15. Which commitments should your study planner work around?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply. If you choose None, choose that option only. You do not need to explain personal circumstances.
- Options:
  - Classes or laboratory sessions.
  - Part-time work.
  - Clubs, societies, or volunteering.
  - Sports or exercise.
  - Travel or commuting.
  - Family or personal responsibilities.
  - Meals or other personal routines.
  - None.
  - Other (built-in).

### Q16. If you chose to enter sleep times, how would you want the planner to protect them?

- Type: Multiple choice.
- Required: Yes.
- Options:
  - Use the same protected sleep period each day.
  - Let me set different sleep periods for different days.
  - I prefer to specify allowed study hours without giving sleep times.
  - Not sure.
- Description: We are asking about planner settings, not sleep quality or medical conditions. This form does not ask for your exact bedtime.

### Q17. How would you prefer the planner to decide when study sessions are allowed?

- Type: Multiple choice.
- Required: Yes.
- Options:
  - Only use study windows I explicitly allow.
  - Suggest possible free times, but let me confirm them first.
  - Not sure.

### Q18. Is there anything a planner should never move without your approval?

- Type: Paragraph.
- Required: No.
- Description: Use general activity labels such as Class, Work, Sleep, or Personal commitment. Do not provide private details.
- After Section 6: Continue to Section 7.

## Section 7 - Changes and optional follow-up

### Q19. If you miss a planned study session, how would you prefer the planner to respond?

- Type: Multiple choice.
- Required: Yes.
- Options:
  - Show proposed changes and ask me before applying them.
  - Adjust future sessions automatically and explain the changes.
  - Let me rearrange the plan manually.
  - Not sure.
- Builder note: This is requirements feedback, not permission to alter any real calendar during this research.

### Q20. What would you want to see before accepting a study plan?

- Type: Checkboxes.
- Required: Yes.
- Description: Select all that apply. Choose Not sure alone if applicable.
- Options:
  - Why some tasks receive attention before others.
  - Total study time for each day.
  - Breaks and protected personal time.
  - Tasks that cannot fit before their deadlines.
  - Which sessions changed from the previous plan.
  - Not sure.
  - Other (built-in).

### Q21. Would you be willing to join a separate follow-up about your current tasks and preferred task order?

- Type: Multiple choice.
- Required: Yes.
- Options: Yes / No / I would like more information first.
- Description: The follow-up would ask you to list several current academic tasks and say which you would choose to work on first. It is separate from this questionnaire. You will receive further information before deciding. No task-priority judgments are collected by this question.
- After Section 7: Submit form. Set this explicitly so eligible participants do not continue into the exit section.

## Section 8 - Exit

Title: Thank you for your interest

Description: This pilot is for participants who agree to take part and are currently enrolled in one of the three listed UPSI programmes. You do not need to answer any further questions. You may close this form without submitting.

- No research questions in this section.
- After Section 8: Submit form. A respondent who submits this route can leave an eligibility/participation-choice record; exclude it from substantive research analysis. Do not promise that Google Forms saves no record if they press Submit.

## Confirmation message

Thank you. Your response has been recorded. Your answers will help us understand study-planning needs and preferences. If you expressed interest in a follow-up, use the contact instructions supplied by the researcher; this questionnaire has not registered you for a separate study or generated a timetable.

## Builder settings

- Form type: Questionnaire, not Quiz.
- Collect email addresses: Do not collect for this coded-pilot design unless the supervisor-approved collection process changes.
- Limit to one response: Leave off for this draft; manage duplicate pilot submissions by participant code and collection version. Recheck institutional policies/settings before distributing.
- File uploads: None. Proforma collection and exact weekly timetable collection are separate.
- Shuffle question order: Off, to preserve the questionnaire sequence.
- Progress bar: On if available.
- Response summary visible to respondents: Off; do not expose other students' free-text answers.
- Link to a restricted-access response spreadsheet after choosing the appropriate research account. Keep source responses intact and clean a separate copy.
- Do not publish or send the respondent link while participant-information brackets remain incomplete.

## Branching and pilot checks

Create all eight sections first. Use Go to section based on answer on Q1 and Q2 only. Google documents this routing for Multiple choice and Dropdown questions, not checkbox questions.

Test these routes in Preview:

1. Q1 No → Exit, without participant/profile questions.
2. Q1 Yes + Q2 No → Exit, without participant/profile questions.
3. Q1 Yes + Q2 Yes → Sections 3–7 → Submit, skipping Exit.
4. Optional paragraphs may remain blank.
5. Semester rejects 0, decimals, negative numbers, and session codes.
6. Not sure and Other options remain valid and are not forced into made-up numeric values.
7. Check the phone layout, spelling, programme labels, and whether None/Not sure checkbox instructions are understood.
8. Record actual completion time and confusion in a small pilot before promising survey duration or expanding recruitment.

This form measures requirements and stated preferences. It is not a complete LambdaMART dataset. Keep repeated task snapshots in the separate collection, and do not call the form clinically validated or university-approved without evidence.

## Build references

- Google Forms section routing: https://support.google.com/docs/answer/141062?hl=en
- Response handling, email collection and spreadsheet linking: https://support.google.com/docs/answer/139706?hl=en
