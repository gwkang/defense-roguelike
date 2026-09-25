"""Validate and resolve the small pointer registry used by game-workflow."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import tempfile


OPEN_STATUSES = {"needs-clarification", "needs-reconciliation", "ready", "running", "blocked"}
ALL_STATUSES = OPEN_STATUSES | {"completed", "cancelled"}


class RegistryError(ValueError):
    pass


def _strings(value, field):
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        raise RegistryError(f"{field} must be a list of non-empty strings")
    if len(value) != len(set(value)):
        raise RegistryError(f"{field} must not contain duplicates")


def _safe_record_path(value):
    if not isinstance(value, str) or not value:
        raise RegistryError("recordPath must be a non-empty relative path")
    path = PurePosixPath(value.replace("\\", "/"))
    if path.is_absolute() or ".." in path.parts or ":" in value:
        raise RegistryError("recordPath must stay inside the project")
    return path


def validate(data):
    if not isinstance(data, dict) or set(data) != {"schemaVersion", "runs"}:
        raise RegistryError("registry must contain only schemaVersion and runs")
    if data["schemaVersion"] != 1 or not isinstance(data["runs"], list):
        raise RegistryError("unsupported registry")
    seen = set()
    for run in data["runs"]:
        required = {"runId", "recordPath", "status", "goalRevision", "goalKeys", "targetPaths"}
        allowed = required | {"conversationKey"}
        if not isinstance(run, dict) or not required <= set(run) or not set(run) <= allowed:
            raise RegistryError("run has missing or unknown fields")
        run_id = run["runId"]
        if not isinstance(run_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", run_id) or run_id in seen:
            raise RegistryError("runId must be a unique non-empty string")
        seen.add(run_id)
        _safe_record_path(run["recordPath"])
        if run["status"] not in ALL_STATUSES:
            raise RegistryError(f"unsupported status: {run['status']}")
        if not isinstance(run["goalRevision"], int) or isinstance(run["goalRevision"], bool) or run["goalRevision"] < 1:
            raise RegistryError("goalRevision must be a positive integer")
        _strings(run["goalKeys"], "goalKeys")
        _strings(run["targetPaths"], "targetPaths")
        if "conversationKey" in run and run["conversationKey"] is not None and not isinstance(run["conversationKey"], str):
            raise RegistryError("conversationKey must be a string or null")
    return data


def load(path):
    return validate(json.loads(Path(path).read_text(encoding="utf-8")))


def match(data, project_root, run_id=None, conversation_key=None, goal_keys=(), target_paths=()):
    validate(data)
    root = Path(project_root).resolve()
    goals, targets = set(goal_keys), set(target_paths)
    open_runs = [run for run in data["runs"] if run["status"] in OPEN_STATUSES]
    if run_id:
        selected = [(run, 1) for run in open_runs if run["runId"] == run_id]
        if not selected:
            return {"decision": "not-found", "matches": [], "requestedRunId": run_id}
    else:
        tiers = []
        if conversation_key:
            tiers.append([(run, 1) for run in open_runs if run.get("conversationKey") == conversation_key])
        tiers.append([(run, len(targets.intersection(run["targetPaths"]))) for run in open_runs
                      if targets.intersection(run["targetPaths"])])
        tiers.append([(run, len(goals.intersection(run["goalKeys"]))) for run in open_runs
                      if goals.intersection(run["goalKeys"])])
        selected = next((tier for tier in tiers if tier), [])
    candidates, stale = [], []
    for run, score in selected:
        record = root.joinpath(*_safe_record_path(run["recordPath"]).parts)
        row = {"runId": run["runId"], "score": score, "recordPath": run["recordPath"]}
        (candidates if record.is_file() else stale).append(row)
    if stale:
        return {"decision": "reconcile", "matches": stale}
    candidates.sort(key=lambda row: (-row["score"], row["runId"]))
    if not candidates:
        return {"decision": "new", "matches": []}
    best = candidates[0]["score"]
    best_rows = [row for row in candidates if row["score"] == best]
    return {"decision": "resume" if len(best_rows) == 1 else "select", "matches": best_rows}


def write_atomic(path, data):
    validate(data)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def upsert(data, run):
    validate({"schemaVersion": 1, "runs": [run]})
    rows = [row for row in data["runs"] if row["runId"] != run["runId"]]
    rows.append(run)
    rows.sort(key=lambda row: row["runId"])
    return validate({"schemaVersion": 1, "runs": rows})


def close(data, run_id, status):
    if status not in {"completed", "cancelled"}:
        raise RegistryError("close status must be completed or cancelled")
    found = False
    for row in data["runs"]:
        if row["runId"] == run_id:
            row["status"] = status
            found = True
    if not found:
        raise RegistryError(f"unknown run: {run_id}")
    return validate(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("registry", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--run-id")
    parser.add_argument("--conversation-key")
    parser.add_argument("--goal-key", action="append", default=[])
    parser.add_argument("--target-path", action="append", default=[])
    args = parser.parse_args()
    result = match(load(args.registry), args.project_root, args.run_id, args.conversation_key,
                   args.goal_key, args.target_path)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
