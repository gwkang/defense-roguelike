"""Project-local small-change preflight, execution evidence and completion report.

This records real subprocess observations; it does not dispatch agents, grant file
permissions or prove the authenticity of host acknowledgements. The coordinator
checks those acknowledgements against the actual host and owns integration.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import struct
import sys
import tempfile
import time
import uuid
import zlib
from datetime import datetime, timezone

SCHEMA = 1
PRIVATE = {".agents", ".git", ".codex", ".aws"}
ADAPTERS = {"unittest", "love", "smoke", "images", "docs"}
NATIVE_TIMEOUTS = {"regression": 180, "focused": 60, "smoke": 30, "captures": 60}


class EvidenceError(ValueError):
    pass


def utc():
    return datetime.now(timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True).encode("utf-8")


def load(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        raise EvidenceError(f"invalid JSON: {path}: {exc.msg}") from exc


def save(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if Path(temporary).exists():
            Path(temporary).unlink()


def local(root, name):
    if not isinstance(name, str) or not name or "\\" in name or ":" in name:
        raise EvidenceError(f"invalid relative path: {name!r}")
    relative = PurePosixPath(name)
    if relative.is_absolute() or ".." in relative.parts or PRIVATE.intersection(p.casefold() for p in relative.parts):
        raise EvidenceError(f"path outside public project scope: {name}")
    path = Path(root).resolve().joinpath(*relative.parts).resolve()
    if not path.is_relative_to(Path(root).resolve()):
        raise EvidenceError(f"link escapes project: {name}")
    if PRIVATE.intersection(p.casefold() for p in path.parts):
        raise EvidenceError(f"resolved path is private: {name}")
    return path


def fingerprint(path):
    path = Path(path)
    return {"exists": path.is_file(), "sha256": digest(path.read_bytes()) if path.is_file() else None}


def snapshot(root, names):
    return {name: fingerprint(local(root, name)) for name in names}


def guard_snapshot(guards):
    result = {}
    for item in guards:
        path = Path(item["path"])
        if (PRIVATE.intersection(p.casefold() for p in path.parts)
                or PRIVATE.intersection(p.casefold() for p in path.resolve().parts)):
            raise EvidenceError("guard cannot read private instruction paths")
        result[str(path.resolve())] = fingerprint(path)
    return result


def positive(value, name):
    if type(value) is not int or value < 1:
        raise EvidenceError(f"{name} must be a positive integer")


def native_settings(root, check):
    """Resolve a declared runtime entry and its distinct verification cwd."""
    native = check.get("native", {})
    mode = native.get("mode")
    if mode not in NATIVE_TIMEOUTS:
        raise EvidenceError("unsupported native mode")
    candidate = local(root, native.get("candidate"))
    entry = local(root, native.get("entry", native["candidate"]))
    if not candidate.is_dir() or not entry.is_dir():
        raise EvidenceError("native candidate and entry must be existing directories")
    if not entry.is_relative_to(candidate):
        raise EvidenceError("native entry must stay inside its candidate")
    engine = Path(native.get("engine", ""))
    if not engine.is_absolute() or not engine.is_file():
        raise EvidenceError("native engine must be an explicit existing absolute executable")
    timeout = native.get("timeoutSeconds", NATIVE_TIMEOUTS[mode])
    if isinstance(timeout, bool) or not isinstance(timeout, (int, float)) or not math.isfinite(timeout) or not 0 < timeout <= 3600:
        raise EvidenceError("native timeout must be finite and between zero and 3600 seconds")
    flag = {"regression": "--test", "smoke": "--smoke", "captures": "--capture"}.get(mode)
    command = [str(engine.resolve()), str(entry)] + ([flag] if flag else [])
    return command, candidate, timeout


def expected_suites(check):
    if check.get("native", {}).get("mode") == "regression":
        return ["core", "session", "integration"]
    return check.get("expectedSuites")


def png_size(path):
    # Verify chunk integrity, then decode pixels from the same bytes. A header
    # alone cannot establish that a capture is a usable image.
    try:
        from PIL import Image
    except ImportError as exc:
        raise EvidenceError("PNG validation requires Pillow; capture validation blocked") from exc
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise EvidenceError("capture is not a PNG")
    offset, ended = 8, False
    while offset < len(data):
        if len(data) - offset < 12:
            raise EvidenceError("capture has a truncated PNG chunk")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        end = offset + length + 12
        if end > len(data):
            raise EvidenceError("capture has a truncated PNG chunk")
        kind = data[offset + 4:offset + 8]
        crc = struct.unpack(">I", data[end - 4:end])[0]
        if zlib.crc32(data[offset + 4:end - 4]) != crc:
            raise EvidenceError("capture has a PNG chunk CRC mismatch")
        if offset == 8 and (kind != b"IHDR" or length != 13):
            raise EvidenceError("capture has an invalid PNG header")
        offset = end
        if kind == b"IEND":
            if length != 0 or end != len(data):
                raise EvidenceError("capture has an invalid PNG ending")
            ended = True
            break
    if not ended:
        raise EvidenceError("capture has no complete PNG ending")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format != "PNG":
                raise EvidenceError("capture is not a PNG")
            image.verify()
        with Image.open(io.BytesIO(data)) as image:
            image.load()
            width, height = image.size
    except (OSError, ValueError, SyntaxError) as exc:
        raise EvidenceError(f"capture is not a complete decodable PNG: {exc}") from exc
    return f"{width}x{height}"


def preflight(root, plan):
    """Validate the actual files, fixtures, declared names and actor receipts once."""
    if plan.get("schemaVersion") != SCHEMA or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", plan.get("runId", "")):
        raise EvidenceError("unsupported plan or invalid runId")
    for key in ("authority", "outcome", "designDecision"):
        if not isinstance(plan.get(key), str) or not plan[key].strip():
            raise EvidenceError(f"missing {key}")
    files = plan.get("candidateFiles")
    if not isinstance(files, list) or not files or len(files) != len(set(files)):
        raise EvidenceError("candidateFiles must be a non-empty unique list")
    candidate = snapshot(root, files)
    if not all(row["exists"] for row in candidate.values()):
        raise EvidenceError("candidate file missing")
    actors = plan.get("actors", {})
    actual = []
    input_paths = []
    for role in ("author", "reviewer"):
        actor = actors.get(role, {})
        acknowledgement = local(root, actor.get("acknowledgement"))
        input_paths.append(actor["acknowledgement"])
        receipt = load(acknowledgement)
        executor = actor.get("executorId")
        if not executor or receipt.get("executorId") != executor or receipt.get("source") != "host-acknowledgement":
            raise EvidenceError(f"missing actual host acknowledgement: {role}")
        actual.append(executor)
    if actual[0] == actual[1]:
        raise EvidenceError("author and reviewer must be different executors")
    checks = plan.get("checks")
    if not isinstance(checks, dict) or not checks:
        raise EvidenceError("at least one real check is required")
    for key, check in checks.items():
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", key) or check.get("adapter") not in ADAPTERS:
            raise EvidenceError("invalid check ID or adapter")
        positive(check.get("minimumCount"), "minimumCount")
        if "expectedSuites" in check:
            suites = check["expectedSuites"]
            if (not isinstance(suites, list) or not suites or any(not isinstance(s, str) or not re.fullmatch(r"[a-z][a-z0-9-]*", s) for s in suites)
                    or len(suites) != len(set(suites))):
                raise EvidenceError("invalid expected suite names")
        if "native" in check:
            _, _, _ = native_settings(root, check)
            entry = local(root, check["native"].get("entry", check["native"]["candidate"]))
            main = (entry / "main.lua").relative_to(Path(root).resolve()).as_posix()
            if main not in files:
                raise EvidenceError("native entry main.lua must be in the frozen candidate")
            conf = (entry / "conf.lua").relative_to(Path(root).resolve()).as_posix()
            if (entry / "conf.lua").exists() and conf not in files:
                raise EvidenceError("native entry conf.lua must be in the frozen candidate")
            expected_adapter = {"regression": "love", "focused": "love", "smoke": "smoke", "captures": "images"}[check["native"]["mode"]]
            if check["adapter"] != expected_adapter:
                raise EvidenceError("native mode and check adapter differ")
            if check["native"]["mode"] == "focused" and not check.get("expectedSuites"):
                raise EvidenceError("focused native check needs its expected suite names")
            if check["native"]["mode"] == "regression" and "expectedSuites" in check and set(check["expectedSuites"]) != {"core", "session", "integration"}:
                raise EvidenceError("regression must include all three suites")
        names = check.get("expectedNames", [])
        if not isinstance(names, list) or any(not isinstance(n, str) or not n for n in names) or len(set(names)) != len(names):
            raise EvidenceError("invalid or duplicate expected test names")
        if check["adapter"] in {"unittest", "love"} and not names:
            raise EvidenceError("test check must declare its meaningful test names")
        sources = check.get("testSources", [])
        if any(p not in files for p in sources):
            raise EvidenceError("test source must be in the frozen candidate")
        source = "\n".join(local(root, p).read_text(encoding="utf-8") for p in sources)
        if names and (not sources or any(n not in source for n in names)):
            raise EvidenceError("planned test name missing from actual registered source")
        for artifact in check.get("artifacts", []):
            local(root, artifact)
        if check["adapter"] == "images" and not check.get("artifacts"):
            raise EvidenceError("image check needs explicit output paths")
        if check["adapter"] == "images":
            coverage = check.get("coverage", [])
            if (not coverage or sorted(row.get("artifact", "") for row in coverage) != sorted(check["artifacts"])
                    or any(not row.get("state") or not re.fullmatch(r"[1-9]\d*x[1-9]\d*", row.get("target", "")) for row in coverage)):
                raise EvidenceError("image check must map each artifact to an actual state and target")
    for name in plan.get("jsonInputs", []):
        load(local(root, name))
        input_paths.append(name)
    for fixture in plan.get("fixtures", []):
        input_paths.append(fixture["path"])
        text = local(root, fixture["path"]).read_text(encoding="utf-8")
        if not fixture.get("anchor") or fixture["anchor"] not in text:
            raise EvidenceError("fixture anchor missing")
    impacts = plan.get("impacts", {})
    for key in ("layout", "minimumWidth", "alerts", "trade", "save", "battle", "formalArt"):
        row = impacts.get(key, {})
        if type(row.get("applicable")) is not bool or not row.get("reason"):
            raise EvidenceError(f"missing impact disposition: {key}")
        if row["applicable"] and (not row.get("checks") or any(c not in checks for c in row["checks"])):
            raise EvidenceError(f"uncovered impact: {key}")
        if row["applicable"] and key in {"layout", "minimumWidth", "alerts"}:
            images = [checks[c] for c in row["checks"] if checks[c]["adapter"] == "images"]
            if not images:
                raise EvidenceError(f"visible impact needs actual captures: {key}")
            if key == "minimumWidth" and not any(c["target"] == "480x270" for i in images for c in i["coverage"]):
                raise EvidenceError("minimum-width impact must cover 480x270")
    if impacts["formalArt"]["applicable"]:
        raise EvidenceError("formal art requires the full UI workflow")
    preservation = plan.get("preservation", {})
    if type(preservation.get("applicable")) is not bool or not preservation.get("reason"):
        raise EvidenceError("missing preservation disposition")
    guards = plan.get("guards", [])
    if preservation["applicable"] and not guards:
        raise EvidenceError("applicable preservation requires exact hash-only guards")
    for item in guards:
        if item.get("kind") not in {"original", "save"} or not item.get("path"):
            raise EvidenceError("invalid guard")
    return {"candidate": candidate, "guards": guard_snapshot(guards),
            "inputs": snapshot(root, sorted(set(input_paths)))}


def initialize(root, plan, record_path):
    record_path = Path(record_path)
    if record_path.exists():
        raise EvidenceError("record exists; resume it instead of resetting history")
    started = time.perf_counter()
    observations = preflight(root, plan)
    identity = digest(encoded({"root": str(Path(root).resolve()), "runId": plan["runId"], "plan": plan,
                              "candidate": observations["candidate"], "inputs": observations["inputs"]}))
    record = {"schemaVersion": SCHEMA, "root": str(Path(root).resolve()), "plan": plan,
              "identity": identity, "createdUtc": utc(), "toolSha256": digest(Path(__file__).read_bytes()),
              **observations, "attempts": [], "review": None,
              "timings": {"preflightSeconds": time.perf_counter() - started}}
    save(record_path, record)
    return record


def current(record):
    if record.get("schemaVersion") != SCHEMA:
        raise EvidenceError("unsupported record schema")
    if digest(Path(__file__).read_bytes()) != record["toolSha256"]:
        raise EvidenceError("execution tool changed; begin a linked new evidence record")
    expected = digest(encoded({"root": record["root"], "runId": record["plan"]["runId"], "plan": record["plan"],
                              "candidate": record["candidate"], "inputs": record["inputs"]}))
    if expected != record["identity"]:
        raise EvidenceError("plan or candidate identity metadata changed")
    if snapshot(record["root"], record["candidate"]) != record["candidate"]:
        raise EvidenceError("candidate changed; historic results cannot promote it")
    if guard_snapshot(record["plan"].get("guards", [])) != record["guards"]:
        raise EvidenceError("original/save guard drift")
    observations = preflight(record["root"], record["plan"])
    if observations["inputs"] != record["inputs"]:
        raise EvidenceError("input/actor acknowledgement drift")


def parse_output(adapter, output, expected_suite_names=None):
    suite_results, output_format = [], "legacy"
    if adapter == "unittest":
        names = re.findall(r"^(test\w+)\s+\([^\r\n]+\)\s+\.\.\.\s+ok\s*$", output, re.M)
        summaries = re.findall(r"^Ran (\d+) tests? in", output, re.M)
        count = int(summaries[-1]) if summaries else 0
        complete = bool(re.search(r"^OK\s*$", output, re.M)) and count == len(names)
    elif adapter == "love":
        names = [n.strip() for n in re.findall(r"^PASS (.+)$", output, re.M) if not n.startswith("all ")]
        legacy = [(suite, int(total), 0) for total, suite in re.findall(r"^PASS all (\d+) (\w+) tests\s*$", output, re.M)]
        session_summaries = re.findall(r"^(\d+) tests, (\d+) failures\s*$", output, re.M)
        legacy.extend(("session", int(total), int(failed)) for total, failed in session_summaries)
        structured = re.findall(r"^WORKFLOW SUITE (.*)$", output, re.M)
        valid = True
        if structured:
            output_format = "workflow-suite-v1"
            for raw in structured:
                try:
                    row = json.loads(raw)
                    if (type(row.get("schemaVersion")) is not int or row.get("schemaVersion") != 1 or not isinstance(row.get("suite"), str)
                            or not re.fullmatch(r"[a-z][a-z0-9-]*", row["suite"])
                            or type(row.get("count")) is not int or row["count"] < 1
                            or type(row.get("failures")) is not int or row["failures"] < 0):
                        valid = False
                    else:
                        suite_results.append(row)
                except (ValueError, AttributeError, TypeError):
                    valid = False
            valid = valid and not legacy
            # Each summary closes its actual preceding PASS/FAIL lines. Checking
            # only a grand total would allow two suites' counts to be swapped.
            pending, index = 0, 0
            for line in output.splitlines():
                if re.match(r"^PASS (?!all )", line) or re.match(r"^FAIL\b", line):
                    pending += 1
                elif line.startswith("WORKFLOW SUITE "):
                    if index >= len(suite_results) or suite_results[index]["count"] != pending:
                        valid = False
                    pending, index = 0, index + 1
            valid = valid and pending == 0
            required = expected_suite_names if expected_suite_names is not None else ["core", "session", "integration"]
            valid = valid and {r["suite"] for r in suite_results} == set(required)
        else:
            suite_results = [{"schemaVersion": 1, "suite": suite, "count": total, "failures": failed}
                             for suite, total, failed in legacy]
        count = len(names)
        complete = (valid and count > 0 and sum(r["count"] for r in suite_results) == count
                    and len(names) == len(set(names))
                    and len({r["suite"] for r in suite_results}) == len(suite_results)
                    and all(r["failures"] == 0 for r in suite_results)
                    and re.findall(r"^TEST SUITE: (\d+) file failures\s*$", output, re.M) == ["0"])
        if expected_suite_names is not None:
            complete = complete and {r["suite"] for r in suite_results} == set(expected_suite_names)
    elif adapter == "smoke":
        names = []
        count = len(re.findall(r"^SMOKE PASS\b", output, re.M))
        complete = count == 1 and not re.search(r"^SMOKE (?:FAIL|FAILED|ERROR)\b", output, re.M)
    elif adapter == "docs":
        names = []
        match = re.search(r"^PASS: (\d+) required pages, (\d+) settings, (\d+) local links, (\d+) source identities\s*$", output, re.M)
        count = int(match[4]) if match else 0
        complete = bool(match) and all(int(n) > 0 for n in match.groups())
    else:
        names, count = [], 0
        complete = bool(re.search(r"^CAPTURE PASS\b", output, re.M))
    failures = bool(re.search(r"^(FAIL\b|ERROR\b|FAILED\b|TEST SUITE: [1-9]\d* file failures)", output, re.M))
    return {"resultSchemaVersion": 1, "adapter": adapter, "outputFormat": output_format,
            "suiteResults": suite_results, "names": names, "actualCount": count, "complete": complete and not failures}


def execute(record_path, check_id, command, timeout=60, working_directory=None, native=False):
    record = load(record_path)
    current(record)
    spec = record["plan"]["checks"].get(check_id)
    if (not spec or not command or isinstance(timeout, bool) or not isinstance(timeout, (int, float))
            or not math.isfinite(timeout) or not 0 < timeout <= 3600):
        raise EvidenceError("unknown check, missing command or invalid timeout")
    root = Path(record["root"])
    if "native" in spec and not native:
        raise EvidenceError("declared native check must use the native subcommand")
    cwd = root if working_directory is None else Path(working_directory).resolve()
    if not cwd.is_relative_to(root.resolve()) or not cwd.is_dir():
        raise EvidenceError("execution cwd must stay inside the evidence root")
    number = len(record["attempts"]) + 1
    artifacts = spec.get("artifacts", [])
    # A stale image must never count, even when its contents would be identical.
    if any(local(root, p).exists() for p in artifacts):
        raise EvidenceError("capture output already exists; choose fresh artifact paths")
    evidence = Path(record_path).parent / "raw" / record["plan"]["runId"] / record["identity"] / f"{number:02d}-{check_id}-{uuid.uuid4().hex}"
    evidence.mkdir(parents=True, exist_ok=False)
    attempt = {"check": check_id, "number": number, "identity": record["identity"],
               "runId": record["plan"]["runId"], "command": command, "startedUtc": utc(),
               "exitCode": None, "timedOut": False, "error": None, "PASS": False}
    attempt.update(workingDirectory=str(cwd), timeoutSeconds=timeout)
    attempt["environment"] = {"PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"}
    if native:
        declared_command, declared_cwd, declared_timeout = native_settings(root, spec)
        if command != declared_command or cwd != declared_cwd or timeout != declared_timeout:
            raise EvidenceError("native execution differs from its frozen settings")
        attempt["nativeExecution"] = {"mode": spec["native"]["mode"], "candidate": str(cwd),
                                      "entry": command[1], "engine": command[0],
                                      "engineFingerprint": fingerprint(command[0])}
    record["attempts"].append(attempt)
    record["review"] = None
    save(record_path, record)  # A crash leaves an incomplete attempt, never PASS.
    start = time.perf_counter()
    try:
        environment = os.environ.copy()
        environment.update(PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
        process = subprocess.run(command, cwd=cwd, capture_output=True, timeout=timeout, shell=False, env=environment)
        stdout, stderr = process.stdout, process.stderr
        attempt["exitCode"] = process.returncode
    except subprocess.TimeoutExpired as exc:
        stdout, stderr = exc.stdout or b"", exc.stderr or b""
        attempt["timedOut"] = True
    except OSError as exc:
        stdout, stderr = b"", b""
        attempt["error"] = str(exc)
    for label, raw in (("stdout", stdout), ("stderr", stderr)):
        path = evidence / f"{label}.log"
        with path.open("xb") as stream:
            stream.write(raw)
        attempt[label] = {"path": str(path.resolve()), **fingerprint(path), "bytes": len(raw)}
    observed = parse_output(spec["adapter"], (stdout + b"\n" + stderr).decode("utf-8", errors="replace"), expected_suites(spec))
    captured = {p: fingerprint(local(root, p)) for p in artifacts}
    if spec["adapter"] == "images":
        observed["actualCount"] = sum(row["exists"] for row in captured.values())
        observed["complete"] = observed["complete"] and all(row["exists"] for row in captured.values())
        try:
            observed["complete"] = observed["complete"] and all(png_size(local(root, c["artifact"])) == c["target"] for c in spec["coverage"])
        except (EvidenceError, OSError):
            observed["complete"] = False
    attempt.update(observed, artifacts=captured, completedUtc=utc(), durationSeconds=time.perf_counter() - start)
    try:
        current(record)
        if native and fingerprint(command[0]) != attempt["nativeExecution"]["engineFingerprint"]:
            raise EvidenceError("native engine changed during execution")
        unchanged = True
    except (EvidenceError, OSError) as exc:
        unchanged = False
        attempt["error"] = str(exc)
    attempt["PASS"] = (unchanged and attempt["exitCode"] == 0 and not attempt["timedOut"]
                       and not attempt["error"] and observed["complete"]
                       and observed["actualCount"] >= spec["minimumCount"]
                       and len(observed["names"]) == len(set(observed["names"]))
                       and set(spec.get("expectedNames", [])).issubset(observed["names"]))
    save(record_path, record)
    return attempt


def execute_native(record_path, check_id):
    record = load(record_path)
    current(record)
    spec = record["plan"]["checks"].get(check_id)
    if not spec or "native" not in spec:
        raise EvidenceError("native check configuration missing")
    command, cwd, timeout = native_settings(record["root"], spec)
    return execute(record_path, check_id, command, timeout, cwd, native=True)


def validated_attempt(record, attempt):
    spec = record["plan"]["checks"][attempt["check"]]
    if "native" in spec:
        command, cwd, timeout = native_settings(record["root"], spec)
        expected_native = {"mode": spec["native"]["mode"], "candidate": str(cwd), "entry": command[1],
                           "engine": command[0], "engineFingerprint": fingerprint(command[0])}
        if (attempt.get("command") != command or attempt.get("workingDirectory") != str(cwd)
                or attempt.get("timeoutSeconds") != timeout or attempt.get("nativeExecution") != expected_native
                or attempt.get("environment") != {"PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8"}):
            raise EvidenceError("native execution settings or engine drift")
    raws = []
    for label in ("stdout", "stderr"):
        row = attempt[label]
        path = Path(row["path"])
        if fingerprint(path) != {"exists": row["exists"], "sha256": row["sha256"]}:
            raise EvidenceError("raw evidence drift")
        raws.append(path.read_bytes())
    observed = parse_output(spec["adapter"], b"\n".join(raws).decode("utf-8", errors="replace"), expected_suites(spec))
    if spec["adapter"] == "images":
        if set(attempt["artifacts"]) != set(spec["artifacts"]):
            raise EvidenceError("capture coverage changed")
        for name, row in attempt["artifacts"].items():
            if fingerprint(local(record["root"], name)) != row:
                raise EvidenceError("capture artifact drift")
        observed["actualCount"] = len(attempt["artifacts"])
        observed["complete"] = observed["complete"] and all(png_size(local(record["root"], c["artifact"])) == c["target"] for c in spec["coverage"])
    if attempt.get("actualCount") != observed["actualCount"] or attempt.get("names") != observed["names"]:
        raise EvidenceError("stored execution count differs from raw output")
    if (not attempt.get("PASS") or attempt.get("identity") != record["identity"]
            or attempt.get("runId") != record["plan"]["runId"] or attempt.get("exitCode") != 0
            or attempt.get("timedOut") or attempt.get("error") or not observed["complete"]
            or observed["actualCount"] < spec["minimumCount"]
            or len(observed["names"]) != len(set(observed["names"]))
            or not set(spec.get("expectedNames", [])).issubset(observed["names"])):
        raise EvidenceError("check has no current successful real execution")


def required_evidence(record):
    current(record)
    for check_id in record["plan"]["checks"]:
        attempts = [a for a in record["attempts"] if a["check"] == check_id]
        if not attempts:
            raise EvidenceError(f"required check not run: {check_id}")
        validated_attempt(record, attempts[-1])


def evidence_identity(record):
    return digest(encoded(record["attempts"]))


def stage(record_path, name, action):
    """Wall-clock stage spans are recorded separately from subprocess CPU time."""
    if name not in {"design", "implementation", "review", "integration", "knowledge"}:
        raise EvidenceError("unsupported stage")
    record = load(record_path)
    spans = record.setdefault("stages", [])
    opened = [s for s in spans if s["name"] == name and "endedUtc" not in s]
    if action == "begin":
        current(record)
        if opened:
            raise EvidenceError("stage already open; resume without resetting it")
        spans.append({"name": name, "startedUtc": utc(), "startedEpoch": time.time()})
    elif len(opened) == 1:
        try:
            current(record)
            identity_current, identity_error = True, None
        except (EvidenceError, OSError) as exc:
            identity_current, identity_error = False, str(exc)
        opened[0].update(endedUtc=utc(), elapsedWallSeconds=max(0, time.time() - opened[0]["startedEpoch"]))
        opened[0].update(endIdentityCurrent=identity_current, endIdentityError=identity_error)
    else:
        raise EvidenceError("stage not open")
    save(record_path, record)
    return {"PASS": True, "observationOnly": True, "stage": name, "action": action}


def accept_review(record_path, review_path):
    record = load(record_path)
    required_evidence(record)
    review = load(review_path)
    if (review.get("executorId") != record["plan"]["actors"]["reviewer"]["executorId"]
            or review.get("candidateIdentity") != record["identity"]
            or review.get("runId") != record["plan"]["runId"]
            or review.get("evidenceIdentity") != evidence_identity(record)
            or review.get("verdict") != "PASS" or review.get("blockingFindings") != []):
        raise EvidenceError("independent review is stale, wrong actor or not PASS")
    for key in ("design", "readability", "failureBoundaries", "coverage", "preservation", "uiImpact", "knowledge", "completion"):
        if not isinstance(review.get("findings", {}).get(key), str) or not review["findings"][key].strip():
            raise EvidenceError(f"missing independent review finding: {key}")
    images = [p for c in record["plan"]["checks"].values() if c["adapter"] == "images" for p in c["artifacts"]]
    if sorted(review.get("inspectedArtifacts", [])) != sorted(images):
        raise EvidenceError("direct independent inspection missing for applicable images")
    record["review"] = {"path": str(Path(review_path).resolve()), **fingerprint(review_path),
                        "executorId": review["executorId"], "acceptedUtc": utc(),
                        "evidenceIdentity": evidence_identity(record)}
    save(record_path, record)
    return record


def render(record_path, destination):
    record = load(record_path)
    required_evidence(record)
    review = record.get("review")
    if not review or review["evidenceIdentity"] != evidence_identity(record):
        raise EvidenceError("independent review not accepted for current evidence")
    path = Path(review["path"])
    if fingerprint(path) != {"exists": review["exists"], "sha256": review["sha256"]}:
        raise EvidenceError("independent review evidence drift")
    plan = record["plan"]
    lines = [f"# {plan['runId']} 완료", "", plan["outcome"], "",
             f"후보 `{record['identity']}` · 독립 리뷰 `{review['executorId']}` PASS.", "",
             "| 검사 | 실제 수 | 시간(초) | 증거 |", "| --- | ---: | ---: | --- |"]
    destination = Path(destination)
    for check_id in plan["checks"]:
        attempt = [a for a in record["attempts"] if a["check"] == check_id][-1]
        links = [f"[{label}]({os.path.relpath(attempt[label]['path'], destination.parent).replace(chr(92), '/')})" for label in ("stdout", "stderr")]
        lines.append(f"| {check_id} ({plan['checks'][check_id]['adapter']}) | {attempt['actualCount']} | {attempt['durationSeconds']:.3f} | {' · '.join(links)} |")
    lines += ["", f"preflight: {record['timings']['preflightSeconds']:.3f}초. 모든 시도 {len(record['attempts'])}회(실패 포함)를 단일 목록에 보존.", "",
              "이 기록은 도구가 관측한 검증 완료이며 원본 반영·배포나 목표 시간 달성을 뜻하지 않는다."]
    for span in record.get("stages", []):
        elapsed = f"{span['elapsedWallSeconds']:.3f}초" if "endedUtc" in span else "진행 중"
        lines.append(f"단계 {span['name']}: {elapsed} (벽시계 시간, 대기 포함).")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {"PASS": True, "identity": record["identity"], "attempts": len(record["attempts"])}


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    init = sub.add_parser("init")
    init.add_argument("--root", required=True, type=Path)
    init.add_argument("--plan", required=True, type=Path)
    init.add_argument("--record", required=True, type=Path)
    for name in ("check", "native", "review", "report", "validate", "stage"):
        command = sub.add_parser(name)
        command.add_argument("--record", required=True, type=Path)
        if name == "native":
            command.add_argument("--id", required=True)
        if name == "check":
            command.add_argument("--id", required=True)
            command.add_argument("--timeout", type=float, default=60)
            command.add_argument("command", nargs=argparse.REMAINDER)
        if name == "review":
            command.add_argument("--result", required=True, type=Path)
        if name == "report":
            command.add_argument("--output", required=True, type=Path)
        if name == "stage":
            command.add_argument("--name", required=True)
            command.add_argument("--state", choices=("begin", "end"), required=True)
    args = parser.parse_args()
    try:
        if args.action == "init":
            result = initialize(args.root, load(args.plan), args.record)
            result = {"PASS": True, "identity": result["identity"], "preflightOnly": True}
        elif args.action == "check":
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            result = execute(args.record, args.id, command, args.timeout)
        elif args.action == "native":
            result = execute_native(args.record, args.id)
        elif args.action == "review":
            result = accept_review(args.record, args.result)
            result = {"PASS": True, "independentReviewAccepted": True}
        elif args.action == "report":
            result = render(args.record, args.output)
        elif args.action == "stage":
            result = stage(args.record, args.name, args.state)
        else:
            record = load(args.record)
            required_evidence(record)
            result = {"PASS": True, "identity": record["identity"], "evidenceIdentity": evidence_identity(record)}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result.get("PASS") else 1
    except (EvidenceError, OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f"BLOCKED: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
