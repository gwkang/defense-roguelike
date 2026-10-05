"""Read-only observations of explicit workflow records and JSON ID sets."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
import sys

# Importing the existing parser must not create a cache artifact.
sys.dont_write_bytecode = True
import workflow_evidence as evidence

PRIVATE = {".agents", ".git", ".codex", ".aws", ".instructions"}


class InputError(ValueError):
    pass


def local(root: Path, name: str) -> Path:
    if not isinstance(name, str) or not name or "\\" in name or ":" in name:
        raise InputError("expected a project-relative path")
    parts = PurePosixPath(name).parts
    if PurePosixPath(name).is_absolute() or ".." in parts or PRIVATE.intersection(p.casefold() for p in parts):
        raise InputError("path outside permitted project scope")
    path = root.resolve().joinpath(*parts).resolve()
    if not path.is_relative_to(root.resolve()) or PRIVATE.intersection(p.casefold() for p in path.parts):
        raise InputError("resolved path outside permitted project scope")
    return path


def locator(root: Path, name: str) -> Path:
    """Stored raw locators may be absolute, but never escape the explicit root."""
    if not isinstance(name, str):
        raise InputError("invalid evidence locator")
    path = Path(name)
    if path.is_absolute():
        try:
            name = path.relative_to(root.resolve()).as_posix()
        except ValueError as exc:
            raise InputError("evidence locator escapes root") from exc
    return local(root, name)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True).encode("utf-8")


def read_json(path: Path):
    raw = path.read_bytes()
    try:
        return json.loads(raw.decode("utf-8-sig")), {"path": str(path), "sha256": sha(raw)}
    except (UnicodeError, ValueError) as exc:
        raise InputError("invalid UTF-8 JSON") from exc


def fingerprint(path: Path) -> dict:
    return {"exists": path.is_file(), "sha256": sha(path.read_bytes()) if path.is_file() else None}


def require_hash(value, label):
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{64}", value) is None:
        raise InputError(f"{label} must be a SHA256 string")


def validate_fingerprint(row, label, raw=False):
    if not isinstance(row, dict) or type(row.get("exists")) is not bool:
        raise InputError(f"{label} fingerprint requires boolean exists")
    if row["exists"]:
        require_hash(row.get("sha256"), label)
    elif row.get("sha256") is not None:
        raise InputError(f"{label} missing fingerprint must have null hash")
    if raw and not isinstance(row.get("path"), str):
        raise InputError(f"{label} requires path string")


def validate_spec(spec):
    if not isinstance(spec, dict) or spec.get("adapter") not in evidence.ADAPTERS:
        raise InputError("invalid check adapter")
    if type(spec.get("minimumCount")) is not int or spec["minimumCount"] < 1:
        raise InputError("minimumCount must be a positive integer")
    for label in ("expectedNames", "artifacts"):
        if label in spec and (not isinstance(spec[label], list) or any(not isinstance(v, str) for v in spec[label])):
            raise InputError(f"{label} must be string array")
    if spec["adapter"] == "images":
        artifacts, coverage_rows = spec.get("artifacts"), spec.get("coverage")
        if (not isinstance(artifacts, list) or not artifacts or len(set(artifacts)) != len(artifacts)
                or not isinstance(coverage_rows, list) or not coverage_rows
                or any(not isinstance(row, dict) for row in coverage_rows)
                or sorted(row.get("artifact", "") for row in coverage_rows) != sorted(artifacts)):
            raise InputError("images require exact nonempty artifact coverage")
    for coverage in spec.get("coverage", []):
        if (not isinstance(coverage, dict) or not isinstance(coverage.get("artifact"), str)
                or not isinstance(coverage.get("target"), str)
                or re.fullmatch(r"[1-9][0-9]*x[1-9][0-9]*", coverage["target"]) is None):
            raise InputError("invalid image coverage target")


def validate_attempt(attempt):
    for label in ("number", "actualCount", "exitCode"):
        if label in attempt and attempt[label] is not None and type(attempt[label]) is not int:
            raise InputError(f"{label} must be integer, excluding bool")
    if "number" in attempt and (attempt["number"] is None or attempt["number"] < 1):
        raise InputError("attempt number must be positive")
    if attempt.get("actualCount") is not None and attempt["actualCount"] < 0:
        raise InputError("actualCount must be nonnegative")
    for label in ("PASS", "timedOut"):
        if label in attempt and type(attempt[label]) is not bool:
            raise InputError(f"{label} must be boolean")
    for label in ("runId", "startedUtc", "completedUtc", "error"):
        if label in attempt and attempt[label] is not None and not isinstance(attempt[label], str):
            raise InputError(f"{label} must be string or null")
    if "identity" in attempt:
        require_hash(attempt["identity"], "attempt identity")
    if "names" in attempt and (not isinstance(attempt["names"], list) or any(not isinstance(n, str) for n in attempt["names"])):
        raise InputError("attempt names must be string array")
    for label in ("stdout", "stderr"):
        if label in attempt:
            validate_fingerprint(attempt[label], label, raw=True)


def drift(root: Path, rows: dict) -> list:
    if not isinstance(rows, dict):
        raise InputError("fingerprint map must be an object")
    changed = []
    for name, expected in rows.items():
        validate_fingerprint(expected, "source")
        path = local(root, name)
        if not isinstance(expected, dict) or fingerprint(path) != expected:
            changed.append(name)
    return changed


def attempt_projection(root: Path, record: dict, check_id: str, spec: dict, attempt: dict) -> dict:
    reasons, raws, sources = [], [], {}
    for label in ("stdout", "stderr"):
        row = attempt.get(label)
        if not isinstance(row, dict) or "path" not in row:
            reasons.append(f"{label} missing")
            continue
        path = locator(root, row["path"])
        sources[label] = str(path)
        if fingerprint(path) != {"exists": row.get("exists"), "sha256": row.get("sha256")} or not path.is_file():
            reasons.append(f"{label} missing or drift")
        else:
            raws.append(path.read_bytes())
    if len(raws) == 2:
        observed = evidence.parse_output(spec["adapter"], b"\n".join(raws).decode("utf-8", errors="replace"), evidence.expected_suites(spec))
        if spec["adapter"] == "images":
            artifacts = attempt.get("artifacts", {})
            if not isinstance(artifacts, dict) or set(artifacts) != set(spec.get("artifacts", [])):
                reasons.append("capture coverage differs")
            else:
                if drift(root, artifacts):
                    reasons.append("capture artifact drift")
                for coverage in spec.get("coverage", []):
                    try:
                        if evidence.png_size(local(root, coverage["artifact"])) != coverage["target"]:
                            reasons.append("capture target differs")
                    except (evidence.EvidenceError, OSError, ValueError) as exc:
                        reasons.append(f"capture decode unverified: {exc}")
            observed["actualCount"] = len(artifacts)
        if not observed["complete"] or attempt.get("actualCount") != observed["actualCount"] or attempt.get("names") != observed["names"]:
            reasons.append("raw count/names/completion differs")
        if observed["actualCount"] < spec["minimumCount"] or not set(spec.get("expectedNames", [])).issubset(observed["names"]):
            reasons.append("required count/names missing")
        if len(observed["names"]) != len(set(observed["names"])):
            reasons.append("duplicate observed names")
    if attempt.get("identity") != record["identity"] or attempt.get("runId") != record["plan"]["runId"]:
        reasons.append("attempt identity differs")
    if attempt.get("PASS") is not True or attempt.get("exitCode") != 0 or attempt.get("timedOut") or attempt.get("error") or not attempt.get("completedUtc"):
        reasons.append("latest attempt failed or incomplete")
    return {"id": check_id, "number": attempt.get("number"), "storedPASS": attempt.get("PASS"),
            "actualCount": attempt.get("actualCount"), "observation": "unverified" if reasons else "current",
            "reasons": reasons, "raw": sources, "startedUtc": attempt.get("startedUtc"), "completedUtc": attempt.get("completedUtc")}


def status(root: Path, record_name: str) -> dict:
    record, source = read_json(local(root, record_name))
    if not isinstance(record, dict) or type(record.get("schemaVersion")) is not int or record.get("schemaVersion") != 1 or not isinstance(record.get("root"), str) or Path(record.get("root", "")).resolve() != root.resolve():
        raise InputError("unsupported record schema or root mismatch")
    require_hash(record.get("identity"), "record identity")
    require_hash(record.get("toolSha256"), "execution tool")
    plan = record["plan"]
    if not isinstance(plan, dict) or not isinstance(plan.get("runId"), str) or not plan["runId"]:
        raise InputError("plan requires runId string")
    checks, attempts = plan["checks"], record["attempts"]
    if not isinstance(checks, dict) or not checks or not isinstance(attempts, list):
        raise InputError("checks must be nonempty object and attempts an array")
    candidate_drift, input_drift = drift(root, record["candidate"]), drift(root, record["inputs"])
    metadata = sha(encoded({"root": record["root"], "runId": plan["runId"], "plan": plan, "candidate": record["candidate"], "inputs": record["inputs"]})) == record["identity"]
    tool_current = fingerprint(local(root, "planning/tools/workflow_evidence.py"))["sha256"] == record["toolSha256"]
    for spec in checks.values():
        validate_spec(spec)
    latest = {}
    for attempt in attempts:
        if not isinstance(attempt, dict) or attempt.get("check") not in checks:
            raise InputError("attempt refers to an undeclared check")
        validate_attempt(attempt)
        latest[attempt["check"]] = attempt
    projections = [attempt_projection(root, record, key, spec, latest[key]) for key, spec in checks.items() if key in latest]
    pending = [key for key in checks if key not in latest]
    failed = [row["id"] for row in projections if row["observation"] == "unverified"]
    identity_current = metadata and tool_current and not candidate_drift and not input_drift
    review = record.get("review")
    review_current = False
    review_source = None
    review_reasons = []
    if review is not None:
        validate_fingerprint(review, "review receipt", raw=True)
        require_hash(review.get("evidenceIdentity"), "review evidence identity")
        review_path = locator(root, review["path"])
        review_source = str(review_path)
        review_current = (identity_current and not pending and not failed and
                          fingerprint(review_path) == {"exists": review.get("exists"), "sha256": review.get("sha256")} and
                          review.get("evidenceIdentity") == sha(encoded(attempts)) and
                          review.get("executorId") == plan["actors"]["reviewer"]["executorId"])
        if review_path.is_file():
            try:
                content, _ = read_json(review_path)
                required_findings = ("design", "readability", "failureBoundaries", "coverage", "preservation", "uiImpact", "knowledge", "completion")
                images = sorted(p for spec in checks.values() if spec["adapter"] == "images" for p in spec.get("artifacts", []))
                valid_content = (isinstance(content, dict) and content.get("candidateIdentity") == record["identity"]
                                 and content.get("runId") == plan["runId"] and content.get("evidenceIdentity") == sha(encoded(attempts))
                                 and content.get("executorId") == plan["actors"]["reviewer"]["executorId"]
                                 and content.get("verdict") == "PASS" and content.get("blockingFindings") == []
                                 and isinstance(content.get("findings"), dict)
                                 and all(isinstance(content["findings"].get(k), str) and content["findings"][k].strip() for k in required_findings)
                                 and isinstance(content.get("inspectedArtifacts"), list)
                                 and all(isinstance(n, str) for n in content["inspectedArtifacts"])
                                 and sorted(content["inspectedArtifacts"]) == images)
                if not valid_content:
                    review_reasons.append("review contents not applicable to current record/coverage")
                    review_current = False
            except InputError as exc:
                review_reasons.append(f"review JSON unverified: {exc}")
                review_current = False
        else:
            review_reasons.append("review source missing")
            review_current = False
    return {"source": source, "runId": plan["runId"], "candidateIdentity": record["identity"],
            "observation": "current" if identity_current and not pending and not failed else "unverified",
            "identity": {"metadataCurrent": metadata, "toolCurrent": tool_current, "candidateDrift": candidate_drift, "inputDrift": input_drift},
            "pendingChecks": pending, "failedChecks": failed, "latestChecks": projections,
            "actualCount": sum(row["actualCount"] for row in projections if type(row["actualCount"]) is int),
            "attemptCount": len(attempts), "review": {"applicability": "current" if review_current else "absent" if review is None else "unverified", "source": review_source, "reasons": review_reasons},
            "timing": {"createdUtc": record.get("createdUtc"), "preInit": "unmeasured; consult exact run/actor ACK start locator", "stages": record.get("stages", [])},
            "limits": "Observation only. No game acceptance, authority, runtime/actor authentication, external guards or engine identity determination."}


def compare_set(root: Path, expected_name: str, actual_name: str) -> tuple[dict, int]:
    expected, expected_source = read_json(local(root, expected_name))
    actual, actual_source = read_json(local(root, actual_name))
    problems, duplicates = {}, {}
    for label, values in (("expected", expected), ("actual", actual)):
        if not isinstance(values, list) or not values or any(not isinstance(item, str) or not item.strip() for item in values):
            problems[label] = "requires a nonempty array of nonempty string IDs"
        else:
            duplicates[label] = sorted(item for item, count in Counter(values).items() if count > 1)
    missing = sorted(set(expected) - set(actual)) if not problems else []
    extra = sorted(set(actual) - set(expected)) if not problems else []
    passed = not problems and not missing and not extra and not any(duplicates.values())
    return {"PASS": passed, "expectedSource": expected_source, "actualSource": actual_source,
            "missing": missing, "extra": extra, "duplicates": duplicates, "inputErrors": problems,
            "limits": "ID identity only; source extraction, semantics and runtime coverage require independent review."}, 0 if passed else 2 if problems else 1


def inspect_json(root: Path, name: str, fields: list[str], maximum: int) -> tuple[dict, int]:
    if not 32 <= maximum <= 20000:
        raise InputError("max-chars must be 32..20000")
    value, source = read_json(local(root, name))
    projection, errors = {}, {}
    for field in fields:
        current = value
        for key in field.split("."):
            if not key or not isinstance(current, dict) or key not in current:
                errors[field] = "missing field or non-object parent"
                break
            current = current[key]
        else:
            projection[field] = current
    text = json.dumps(projection, ensure_ascii=False)
    truncated = len(text) > maximum
    return {"source": source, "selectedFields": fields, "fieldErrors": errors,
            "truncated": truncated, "projectionChars": len(text), "maxChars": maximum,
            "projection": None if truncated else projection, "preview": text[:maximum] if truncated else None}, 2 if errors else 0


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    status_parser = commands.add_parser("status")
    status_parser.add_argument("--root", required=True)
    status_parser.add_argument("--record", required=True)
    compare_parser = commands.add_parser("compare-set")
    compare_parser.add_argument("--expected", required=True)
    compare_parser.add_argument("--actual", required=True)
    inspect_parser = commands.add_parser("inspect")
    inspect_parser.add_argument("--json", required=True)
    inspect_parser.add_argument("--field", nargs="+", required=True)
    inspect_parser.add_argument("--max-chars", type=int, default=2000)
    args = parser.parse_args()
    try:
        if args.command == "status":
            result, code = status(Path(args.root).resolve(), args.record), 0
        elif args.command == "compare-set":
            result, code = compare_set(Path.cwd(), args.expected, args.actual)
        else:
            result, code = inspect_json(Path.cwd(), args.json, args.field, args.max_chars)
    except (InputError, evidence.EvidenceError, OSError, KeyError, TypeError, AttributeError) as exc:
        result, code = {"error": str(exc), "observation": "unverified"}, 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
