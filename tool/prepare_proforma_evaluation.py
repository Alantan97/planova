"""Build local Flutter extraction references from reviewed CSVs; no model training."""

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATASET = ROOT / "research/datasets"
OUTPUT = ROOT / "research/evaluation/proforma_import/reference.json"


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def records(name):
    with (DATASET / name).open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if not rows or any(row["verification_status"] != "verified" for row in rows):
        raise ValueError(f"{name} must contain reviewed records only")
    return rows


def prepare():
    courses = records("courses.csv")
    assessments = records("assessments.csv")
    weekly = records("weekly_learning.csv")
    # Retain printed evidence where the reviewed CSV has an authorized correction.
    audit_path = DATASET / "review/FULL_VERIFICATION_2026-11-20.json"
    source_fields = {}
    if audit_path.exists():
        review = json.loads(audit_path.read_text(encoding="utf-8"))
        if any(fingerprint(DATASET / name) != expected
               for name, expected in review["output_sha256"].items()):
            raise ValueError("The source review no longer matches the dataset; update the review evidence first")
        for document in review["courses"]:
            for field in document["field_checks"]:
                if field.get("id", "").startswith("WL"):
                    source_fields[(field["id"], field["field"])] = field["source"]
    ids = {row["document_id"] for row in courses}
    if len(ids) != len(courses):
        raise ValueError("Duplicate course document ID")
    if any(row["document_id"] not in ids for row in assessments):
        raise ValueError("Assessment references an unknown document")
    if any(row["document_id"] not in ids for row in weekly):
        raise ValueError("Weekly learning references an unknown document")
    documents = []
    for course in courses:
        relative = Path(course["source_file"])
        source = (ROOT / relative).resolve()
        if relative.is_absolute() or not source.is_relative_to(ROOT / "research/proformas"):
            raise ValueError("Source must stay inside research/proformas")
        data = source.read_bytes()
        offset = data[:4096].find(b"%PDF-")
        if offset < 0:
            raise ValueError(f"Invalid PDF header: {relative}")
        expected = []
        for row in assessments:
            if row["document_id"] != course["document_id"]:
                continue
            expected.append({
                "row_id": row["source_row_id"],
                "name": row["assessment_name"],
                "weight": float(row["assessment_weight_percent"]),
                "page": int(row["source_page"]),
            })
        if len({row["row_id"] for row in expected}) != len(expected):
            raise ValueError("Duplicate source row identity")
        if abs(sum(row["weight"] for row in expected) - 100) > 1e-8:
            raise ValueError("Assessment weights must total 100%")
        documents.append({
            "document_id": course["document_id"],
            "source_file": relative.as_posix(),
            "source_sha256": hashlib.sha256(data).hexdigest(),
            "normalized_pdf_sha256": hashlib.sha256(data[offset:]).hexdigest(),
            "course_code": course["course_code"],
            "course_name": course["course_name"],
            "document_session": course["document_session"],
            "assessments": expected,
            "weekly": [
                {
                    "learning_id": row["learning_id"],
                    "week_start": int(source_fields.get((row["learning_id"], "week_range"), [row["week_start"], row["week_end"]])[0]),
                    "week_end": int(source_fields.get((row["learning_id"], "week_range"), [row["week_start"], row["week_end"]])[1]),
                    "topic": row["topic"],
                    "page": int(row["source_page"]),
                    "source_hours": [
                        float(value) if value != "" else None
                        for field in list(row)[5:12]
                        for value in [source_fields.get((row["learning_id"], field), row[field])]
                    ],
                }
                for row in weekly if row["document_id"] == course["document_id"]
            ],
        })
    reference = {
        "schema_version": 1,
        "scope": "Reviewed supplied PDFs. Known-format source extraction only; not held-out accuracy or AI evaluation. Each report identifies its evaluated fields.",
        "dataset_sha256": {
            name: fingerprint(DATASET / name)
            for name in ["courses.csv", "assessments.csv", "weekly_learning.csv"]
        },
        "documents": documents,
        "source_review_path": audit_path.relative_to(ROOT).as_posix() if audit_path.exists() else None,
        "source_review_sha256": fingerprint(audit_path) if audit_path.exists() else None,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(reference, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(documents)} courses, {len(assessments)} assessments and {len(weekly)} weekly references.")
    print(OUTPUT)


if __name__ == "__main__":
    prepare()
