"""Conservative research extraction; every record remains machine-unverified.

This independent Python baseline mirrors the narrow Flutter table convention.
It does not infer assessment dates, difficulty, or individual remaining effort.
"""

from __future__ import annotations

import hashlib
import io
import re
from pathlib import Path

from pypdf import PdfReader

NUMBER = r"\d+(?:\.\d+)?"
ASSESSMENT_ROW = re.compile(
    rf"^(\d+)\s+(.+?)\s+({NUMBER})\s+{NUMBER}\s+{NUMBER}\s+{NUMBER}\s+{NUMBER}$"
)


def parse_pages(pages: list[str], document_id: str, source_path: str) -> list[dict]:
    pages = ["\n".join(" ".join(line.split()) for line in page.splitlines()) for page in pages]
    first = pages[0] if pages else ""
    code = re.search(r"Course Code:\s*([A-Z]{2,4}\d{4})\b", first)
    if not code or "Maklumat Kursus" not in first:
        raise ValueError("Unsupported course-info template or missing course code")
    section = None
    records: list[dict] = []
    seen = set()
    for page_number, page in enumerate(pages, 1):
        for raw_line in page.splitlines():
            line = " ".join(raw_line.split())
            if line.startswith("Continuous Assessment"):
                section = "continuous"
                continue
            if line.startswith("Final Assessment"):
                section = "final"
                continue
            if line.startswith(("TOTAL", "GRAND TOTAL")):
                section = None
            match = ASSESSMENT_ROW.fullmatch(line) if section else None
            if not match:
                continue
            row_id = f"{section}-{match[1]}"
            weight = float(match[3])
            if row_id in seen or not 0 <= weight <= 100:
                raise ValueError(f"Ambiguous/invalid assessment row: {row_id}")
            seen.add(row_id)
            records.append({
                "source_document_id": document_id,
                "source_path": source_path,
                "source_page": page_number,
                "source_row_id": row_id,
                "course_code": code[1],
                "assessment_name": match[2],
                "assessment_weight_percent": weight,
                "source_excerpt": line,
                "verification_status": "machine_extracted_unverified",
                "deadline_status": "not_extracted",
                "remaining_effort_status": "not_inferred",
            })
    if not records:
        raise ValueError("No complete assessment rows recognized")
    total = sum(row["assessment_weight_percent"] for row in records)
    if abs(total - 100) > 0.01:
        raise ValueError(f"Recognized weights total {total:g}%, not 100%; manual review required")
    return records


def extract_directory(project_root: Path) -> tuple[list[dict], list[dict]]:
    directory = project_root / "research/proformas"
    if not directory.is_dir():
        raise ValueError(f"Missing source directory: {directory}")
    records, audit = [], []
    seen_fingerprints = set()
    for path in sorted(directory.rglob("*.pdf")):
        relative_path = path.relative_to(project_root).as_posix()
        entry = {"source_path": relative_path}
        if path.name.lower() == "timetable.pdf":
            audit.append({**entry, "status": "excluded", "reason": "Timetable is not a proforma"})
            continue
        raw = path.read_bytes()
        entry["original_sha256"] = hashlib.sha256(raw).hexdigest()
        try:
            offset = raw[:4096].find(b"%PDF-")
            if offset < 0 or len(raw) > 10 * 1024 * 1024:
                raise ValueError("Missing PDF header or source exceeds 10 MB")
            normalized = raw[offset:]
            fingerprint = hashlib.sha256(normalized).hexdigest()
            entry.update(source_document_id=fingerprint, leading_bytes_skipped=offset)
            if fingerprint in seen_fingerprints:
                audit.append({**entry, "status": "duplicate", "reason": "Identical normalized PDF"})
                continue
            seen_fingerprints.add(fingerprint)
            reader = PdfReader(io.BytesIO(normalized))
            if reader.is_encrypted or not 1 <= len(reader.pages) <= 40:
                raise ValueError("Encrypted PDF or unsupported page count")
            pages = [page.extract_text() or "" for page in reader.pages]
            entry["text_extraction_mode"] = "pypdf_plain_no_ocr"
            extracted = parse_pages(pages, fingerprint, relative_path)
            records.extend(extracted)
            audit.append({**entry, "status": "included_unverified", "course_code": extracted[0]["course_code"],
                          "assessment_count": len(extracted), "pages": len(pages)})
        except Exception as error:
            # Never silently replace failed extraction with made-up assessments.
            audit.append({**entry, "status": "needs_review", "reason": str(error)})
    return records, audit
