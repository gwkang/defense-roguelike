"""Validate a formal UI capture preflight result without touching the product."""
from __future__ import annotations

import json
import sys
from pathlib import Path


REQUIRED = {
    "status", "inputRevision", "rendererIdentity", "command", "budgetMinutes",
    "elapsedMinutes", "smokeCases", "checks", "formalAllowed", "blockedReason",
}
STATUSES = {"PASS", "BLOCKED", "OPEN"}
CASE_RESULTS = {"PASS", "FAIL", "NOT_APPLICABLE"}


def validate(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["result must be a JSON object"]
    missing = REQUIRED - data.keys()
    if missing:
        errors.append(f"missing fields: {', '.join(sorted(missing))}")
        return errors
    if data["status"] not in STATUSES:
        errors.append("status must be PASS, BLOCKED, or OPEN")
    if not isinstance(data["smokeCases"], list) or not data["smokeCases"]:
        errors.append("smokeCases must be a non-empty list")
    if not isinstance(data["checks"], dict):
        errors.append("checks must be an object")
    if not isinstance(data["formalAllowed"], bool):
        errors.append("formalAllowed must be boolean")
    if data["formalAllowed"] != (data["status"] == "PASS"):
        errors.append("formalAllowed must be true only when status is PASS")
    if not isinstance(data["budgetMinutes"], (int, float)) or data["budgetMinutes"] <= 0:
        errors.append("budgetMinutes must be positive")
    if not isinstance(data["elapsedMinutes"], (int, float)) or data["elapsedMinutes"] < 0:
        errors.append("elapsedMinutes must be non-negative")
    if data["elapsedMinutes"] > data["budgetMinutes"] and data["status"] == "PASS":
        errors.append("an over-budget preflight cannot be PASS")
    for index, case in enumerate(data["smokeCases"]):
        if not isinstance(case, dict):
            errors.append(f"smokeCases[{index}] must be an object")
            continue
        if case.get("result") not in CASE_RESULTS:
            errors.append(f"smokeCases[{index}].result is invalid")
        if case.get("result") != "NOT_APPLICABLE":
            for field in ("viewport", "state", "fixture", "exitCode", "readback", "dimensions", "repeatHashes"):
                if field not in case:
                    errors.append(f"smokeCases[{index}] missing {field}")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_capture_preflight.py RESULT.json", file=sys.stderr)
        return 2
    try:
        errors = validate(Path(sys.argv[1]))
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        print(f"invalid preflight: {exc}", file=sys.stderr)
        return 1
    if errors:
        print("INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
