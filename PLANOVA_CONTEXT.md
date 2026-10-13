# Planova – Project Context

## 1. Project Overview

**Project Name:** Planova

**Project Title:** AI-Powered Adaptive Study Planner

**Project Type:** Final Year Project (FYP), mobile application

**Target Users:** University students

**Primary Platform:** Android, with potential future iOS support

**Framework:** Flutter (Dart)

Planova is an AI-powered mobile study planner designed to help university students manage academic responsibilities more effectively.

Unlike basic task management applications, Planova aims to automatically prioritize academic tasks, generate personalized study schedules, and adjust those schedules when students miss planned activities.

## 2. Problem Statement

University students often face three challenges:

1. Poor time management when handling multiple academic commitments.
2. Difficulty deciding which assignments, quizzes, or revision activities to prioritize.
3. Traditional planning applications often require users to manually reorganize their schedules when plans change.

Planova aims to address these challenges through intelligent task prioritization and adaptive scheduling.

## 3. Project Objectives

1. Identify suitable approaches for academic task prioritization and adaptive time management.
2. Develop an AI-powered study planner that prioritizes tasks and adjusts study schedules based on student progress.
3. Test and evaluate the functionality of the developed application.

## 4. Core Features

### Task Management
- Create, view, update, and delete academic tasks.
- Enter task title, description, deadline, difficulty, importance, and estimated duration.
- Track task status and completion progress.

### AI Task Prioritization
- Rank tasks based on their characteristics.
- Help students understand which tasks should receive attention first.
- Intended algorithm: LambdaMART (Learning-to-Rank).

### Adaptive Study Scheduling
- Generate study sessions based on task rankings, available study hours, deadlines, and estimated durations.
- Adjust future study sessions when planned sessions are missed or progress changes.
- Intended algorithm: Genetic Algorithm (GA).

### Calendar and Study Planner
- Display scheduled study sessions.
- Provide daily and weekly calendar views.
- Allow students to inspect upcoming activities.

### Dashboard
- Show academic workload, upcoming deadlines, completed tasks, and study progress.
- Provide an overview of planned activities.

### Notifications
- Remind students about upcoming study sessions and deadlines.

### Analytics
- Visualize task completion and study productivity.

## 5. Intended AI Architecture

**LambdaMART:** Ranks tasks according to their relative priority. The ranking model will require suitable task-level training data and relevance labels.

**Genetic Algorithm:** Searches for effective study schedules based on task priorities, deadlines, available study time, and scheduling constraints.

The intended workflow:

Student enters tasks → LambdaMART ranks tasks → GA generates a study schedule → Flutter displays the result → Student records progress → Schedule is recalculated when necessary.

The algorithms are intended to run on a Python backend, with Flutter communicating through an API.

Proposed technologies:
- Flutter and Dart for the mobile application.
- Firebase Authentication and Cloud Firestore for user accounts and data.
- Python for AI implementation.
- LightGBM for LambdaMART, subject to final implementation decisions.
- Genetic Algorithm implementation using suitable Python libraries.
- REST API using FastAPI or Flask, subject to final selection.

## 6. Development Methodology

Staged Incremental Model.

Planned development stages:

1. Task Prioritization Engine
2. Adaptive Scheduling Engine
3. Study Planning Module
4. Dashboard, Analytics, and Refinement

For the upcoming innovation showcase, interface prototyping is being prioritized as a practical demonstration milestone. This does not replace the intended full development methodology.

## 7. Behavioral Foundation

Self-Regulated Learning (SRL).

Planova supports:
- Planning academic activities.
- Monitoring task progress.
- Reflecting on completed and missed activities.
- Adjusting future study plans.

## 8. Current Innovation Prototype

**Showcase Date: 31 October 2026**

The immediate goal is to build a polished, interactive Flutter prototype demonstrating the intended user experience.

Prototype priorities:
- Professional interface and coherent design system.
- Dashboard and academic task overview.
- Task creation and management.
- Priority ranking visualization.
- Generated study schedule demonstration.
- Calendar interface.
- Simulated adaptive rescheduling when a study session is missed.
- Simple progress analytics.

Use realistic mock data and local prototype logic where necessary.

**Important:** Do not represent mock prioritization or simulated rescheduling as completed LambdaMART or GA implementations. Clearly distinguish prototype behavior from production AI functionality.

Full AI model training, backend deployment, and Firebase integration can be implemented in later development stages.

## 9. Product Direction

Planova should feel like a modern student productivity application.

Design principles:
- Clean, modern, polished, and intuitive.
- Student-friendly but professional.
- Consistent typography, spacing, navigation, and color system.
- Clear visual hierarchy.
- Responsive layouts suitable for mobile screens.
- Support for light and dark themes where practical.
- Meaningful empty, loading, and success states.

The interface should make task prioritization and adaptive scheduling easy to understand, especially during a live demonstration.

## 10. Important Constraints

- Prioritize Android for the FYP.
- Keep the codebase compatible with future iOS development where practical.
- Use Flutter and Dart.
- Separate UI, data models, services, and business logic.
- Do not introduce unnecessary backend dependencies during UI prototyping.
- Avoid claiming AI functionality is complete when it is simulated.
- Keep the implementation maintainable for future FYP development.
