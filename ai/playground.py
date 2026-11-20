"""Local UI for inspecting the saved model. Does not retrain or write app data."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

# Streamlit and AppTest may start from a working directory outside ai/.
AI_DIRECTORY = Path(__file__).resolve().parent
if str(AI_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(AI_DIRECTORY))

import pandas as pd
import streamlit as st

from planova_ranking.playground import (
    available_runs, compare_tasks, input_fingerprint, load_run,
    prepare_tasks, saved_example, starter_tasks,
)

PROJECT_ROOT = AI_DIRECTORY.parent


def replace_inputs(rows: list[dict], source: str) -> None:
    st.session_state["input_rows"] = rows
    st.session_state["input_source"] = source
    st.session_state["editor_version"] = st.session_state.get("editor_version", 0) + 1
    st.session_state.pop("ranking_result", None)


def main() -> None:
    st.set_page_config(page_title="Planova · Ranking lab", page_icon="📚", layout="wide")
    st.html("""
      <style>
      .stApp {background:#fff; color:#111;}
      .block-container {max-width:1200px; padding-top:2rem; padding-bottom:3rem;}
      h1,h2,h3 {color:#111; letter-spacing:-.035em;}
      .ranking-hero {background:#111; border-radius:20px; padding:28px; margin:18px 0 24px;}
      .ranking-hero .eyebrow {color:#ff6600; font-size:12px; letter-spacing:.08em; font-weight:700;}
      .ranking-hero h1 {color:white; margin:8px 0; padding:0; font-size:36px;}
      .ranking-hero p {color:#c4c4c4; margin:0; line-height:1.6;}
      [data-testid="stBaseButton-primary"] {background:#c74700; color:white; border-color:#c74700;}
      [data-testid="stBaseButton-primary"]:hover {background:#a93c00; color:white; border-color:#a93c00;}
      [data-testid="stBaseButton-primary"]:disabled {color:white;}
      </style>
    """)
    st.image(str(PROJECT_ROOT / "assets/branding/planova_wordmark_black.png"), width=150)
    st.html("""<section class="ranking-hero"><div class="eyebrow">LOCAL EXPERIMENT</div>
      <h1>See how your tasks rank.</h1>
      <p>Edit a few tasks, run the saved model, and compare its suggestions with the teaching rule.</p>
      </section>""")
    st.caption("Experimental rule imitation · Not independently validated academic priorities · Not connected to Flutter")

    runs = available_runs(PROJECT_ROOT)
    if not runs:
        st.error("No completed model run was found. Run the training experiment first; see ai/README.md.")
        return
    run_dir = st.selectbox("Saved model", options=runs, format_func=lambda path: path.name, key="model_run")
    try:
        report, config = load_run(run_dir)
    except (OSError, ValueError, KeyError, TypeError) as error:
        st.error(f"This model run cannot be opened: {error}")
        return
    if "input_rows" not in st.session_state:
        replace_inputs(starter_tasks(), "Illustrative tasks. All deadlines and work estimates below are invented test inputs.")

    with st.expander("About this model and the rule"):
        st.write(f"{report['source_assessments']} machine-extracted assessment records from "
                 f"{report['documents_included']} proformas were used in simulated planning groups. "
                 "Extracted fields still need manual checking. Survey responses were not used as training labels.")
        policy = config["label_policy"]
        st.write(f"The provisional rule combines urgency ({policy['urgency_weight']:.0%}), assessment weight "
                 f"({policy['assessment_weight']:.0%}), and work pressure ({policy['pressure_weight']:.0%}). "
                 "It assigns teaching labels 0–3. These are prototype choices, not supervisor-approved priorities.")
        st.caption("Loading a model does not train it again. This page reads saved artifacts and keeps edits in your browser session.")

    st.subheader("1. Try a task list")
    first, second, _ = st.columns([1, 1, 2])
    if first.button("Reset illustrative tasks", key="reset_tasks", width="stretch"):
        replace_inputs(starter_tasks(), "Illustrative tasks. All deadlines and work estimates below are invented test inputs.")
    if second.button("Load saved test example", key="load_example", width="stretch"):
        try:
            replace_inputs(saved_example(run_dir),
                           "Saved test example: names/weights were machine-extracted from proformas; deadlines and effort are simulated.")
        except (OSError, ValueError, KeyError) as error:
            st.error(f"The example could not be loaded: {error}")
    st.caption(st.session_state["input_source"])
    st.write("Double-click a cell to edit it. **Days until due: 0 = today, 1 = tomorrow.** "
             "Remaining minutes means work still needed. Weight is the assessment percentage in its course.")
    frame = pd.DataFrame(st.session_state["input_rows"])
    edited = st.data_editor(
        frame, num_rows="dynamic", hide_index=True, width="stretch",
        key=f"tasks_editor_{st.session_state['editor_version']}",
        column_config={
            "task_name": st.column_config.TextColumn("Task name", required=True, max_chars=100, width="large"),
            "days_until_due": st.column_config.NumberColumn("Days until due", min_value=0, step=1, required=True),
            "remaining_minutes": st.column_config.NumberColumn("Minutes remaining", min_value=1, max_value=10080, step=1, required=True),
            "assessment_weight_percent": st.column_config.NumberColumn("Assessment weight (%)", min_value=0, max_value=100, step=0.5, required=True),
        },
    )
    raw_rows = edited.to_dict("records")
    fingerprint = input_fingerprint(raw_rows, run_dir)
    tasks = None
    try:
        tasks = prepare_tasks(raw_rows)
    except ValueError as error:
        st.error(str(error))
    if tasks and any(task["days_until_due"] > 30 or not 30 <= task["remaining_minutes"] <= 240 for task in tasks):
        st.info("Some inputs are outside the simulated training range (0–30 days, 30–240 minutes). "
                "You can test them, but the model's behavior there has not been established.")
    if st.button("Rank tasks", type="primary", key="rank_tasks", disabled=tasks is None):
        try:
            result = compare_tasks(run_dir, tasks)
            st.session_state["ranking_result"] = {**result, "fingerprint": fingerprint}
        except (OSError, ValueError, KeyError, TypeError) as error:
            st.session_state.pop("ranking_result", None)
            st.error(f"Ranking could not be completed: {error}")

    result = st.session_state.get("ranking_result")
    if result and result["fingerprint"] != fingerprint:
        st.info("Inputs or model changed. Click Rank tasks to update the results.")
        return
    if not result:
        st.caption("Tip: rank once, change only one deadline, then rank again to investigate its effect.")
        return

    st.subheader("2. Compare the recommendations")
    st.caption("Rank 1 comes first. Equal ranks are ties. The rule uses four teaching levels, so several tasks may tie.")
    left, right = st.columns(2)
    rows = result["rows"]
    with left:
        st.markdown("**Saved model**")
        st.dataframe(pd.DataFrame([
            {"Rank": row["model_rank"], "Task": row["task_name"], "Days until due": row["days_until_due"]}
            for row in sorted(rows, key=lambda row: (row["model_rank"], row["task_id"]))
        ]), hide_index=True, width="stretch")
    with right:
        st.markdown("**Provisional teaching rule**")
        st.dataframe(pd.DataFrame([
            {"Rank": row["rule_rank"], "Task": row["task_name"], "Teaching level": row["rule_label"]}
            for row in sorted(rows, key=lambda row: (row["rule_rank"], row["task_id"]))
        ]), hide_index=True, width="stretch")
    st.write("Differences are findings to investigate. Agreement with this rule does not prove that a "
             "recommendation is academically correct. This page does not generate a timetable.")
    with st.expander("See inputs and raw scores"):
        st.caption("Model scores may be negative. They are relative ranking values, not probabilities or percentages. "
                   "The rule's 0–3 labels and continuous scores are different quantities.")
        st.dataframe(pd.DataFrame(rows).drop(columns=["task_id"]), hide_index=True, width="stretch")
    csv_buffer = io.StringIO()
    pd.DataFrame(rows).to_csv(csv_buffer, index=False)
    st.download_button("Download comparison CSV", csv_buffer.getvalue(), "planova-ranking-comparison.csv",
                       mime="text/csv", key="download_comparison")
    st.download_button("Download test inputs JSON", json.dumps(tasks, indent=2), "planova-test-tasks.json",
                       mime="application/json", key="download_tasks")


if __name__ == "__main__":
    main()
