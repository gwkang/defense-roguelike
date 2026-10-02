"""Focused workflow-tool regressions; no game, production save or native UI runs."""
from copy import deepcopy
import json
import io
from pathlib import Path
import sys
import shutil
import struct
import zlib
import unittest
import uuid
from unittest.mock import patch

import workflow_evidence as w


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.fixture_parent = (Path.cwd() / ".workflow-test-fixtures").resolve()
        self.fixture_parent.mkdir(exist_ok=True)
        self.root = self.fixture_parent / uuid.uuid4().hex
        self.root.mkdir()
        self.addCleanup(self.cleanup_fixture)
        self.record = self.root / "evidence.json"
        self.source = self.root / "test_sample.py"
        self.source.write_text("import unittest\nclass Sample(unittest.TestCase):\n def test_positive(self): self.assertEqual(2+3,5)\n", encoding="utf-8")
        for role in ("author", "reviewer"):
            w.save(self.root / (role + ".json"), {"executorId": "/root/" + role, "source": "host-acknowledgement"})
        self.guard = self.root / "preserved.save"
        self.guard.write_bytes(b"original save bytes")
        self.plan = {"schemaVersion": 1, "runId": "tool-regression", "authority": "explicit local test",
                     "outcome": "one meaningful unit", "designDecision": "known boundary",
                     "candidateFiles": ["test_sample.py"],
                     "actors": {r: {"executorId": "/root/" + r, "acknowledgement": r + ".json"} for r in ("author", "reviewer")},
                     "checks": {"unit": {"adapter": "unittest", "minimumCount": 1,
                                          "expectedNames": ["test_positive"], "testSources": ["test_sample.py"]}},
                     "jsonInputs": [], "fixtures": [{"path": "test_sample.py", "anchor": "self.assertEqual"}],
                     "impacts": {k: {"applicable": False, "reason": "tool-only fixture"}
                                 for k in ("layout", "minimumWidth", "alerts", "trade", "save", "battle", "formalArt")},
                     "preservation": {"applicable": True, "reason": "original fixture save remains unchanged"},
                     "guards": [{"kind": "save", "path": str(self.guard)}]}

    def cleanup_fixture(self):
        # Remove only this test's generated directory; never reset permissions.
        target = self.root.resolve()
        if target.parent != self.fixture_parent or len(target.name) != 32:
            raise RuntimeError("unexpected fixture cleanup path")
        shutil.rmtree(target)

    def init(self):
        return w.initialize(self.root, self.plan, self.record)

    def run_unit(self):
        return w.execute(self.record, "unit", [sys.executable, "-B", "-m", "unittest", "-v", "test_sample"], 10)

    def review(self):
        d = w.load(self.record)
        result = {"executorId": "/root/reviewer", "runId": self.plan["runId"], "candidateIdentity": d["identity"],
                  "evidenceIdentity": w.evidence_identity(d), "verdict": "PASS", "blockingFindings": [],
                  "findings": {k: "bounded fixture reviewed" for k in
                               ("design", "readability", "failureBoundaries", "coverage", "preservation", "uiImpact", "knowledge", "completion")}}
        p = self.root / "review.json"
        w.save(p, result)
        return p

    def test_real_execution_review_and_report(self):
        self.init()
        self.assertTrue(self.run_unit()["PASS"])
        w.accept_review(self.record, self.review())
        out = self.root / "report.md"
        self.assertTrue(w.render(self.record, out)["PASS"])
        self.assertIn("[stdout](raw/01-unit.stdout.log)", out.read_text(encoding="utf-8"))
        self.assertIn("[stderr](raw/01-unit.stderr.log)", out.read_text(encoding="utf-8"))
        self.assertEqual(w.load(self.record)["attempts"][0]["actualCount"], 1)

    def test_zero_execution_never_completes(self):
        self.init()
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))
        with self.assertRaises(w.EvidenceError):
            w.render(self.record, self.root / "report.md")

    def test_zero_tests_exit_zero_is_failure(self):
        self.init()
        result = w.execute(self.record, "unit", [sys.executable, "-c", "print('Ran 0 tests in 0.0s\\n\\nOK')"])
        self.assertFalse(result["PASS"])
        self.assertEqual(result["actualCount"], 0)

    def test_nonzero_exit_preserves_raw_failure(self):
        self.init()
        result = w.execute(self.record, "unit", [sys.executable, "-c", "import sys; print('specific failure'); sys.exit(7)"])
        self.assertFalse(result["PASS"])
        self.assertEqual(result["exitCode"], 7)
        self.assertIn(b"specific failure", Path(result["stdout"]["path"]).read_bytes())

    def test_timeout_and_incomplete_invocation_cannot_pass(self):
        self.init()
        result = w.execute(self.record, "unit", [sys.executable, "-c", "import time; time.sleep(2)"], .05)
        self.assertTrue(result["timedOut"])
        self.assertFalse(result["PASS"])
        self.assertIsNone(result["exitCode"])

    def test_missing_executable_is_preserved(self):
        self.init()
        result = w.execute(self.record, "unit", [str(self.root / "no-such-tool")])
        self.assertFalse(result["PASS"])
        self.assertTrue(result["error"])

    def test_candidate_drift_invalidates_old_pass(self):
        self.init()
        self.run_unit()
        self.source.write_text(self.source.read_text() + "\n# drift\n", encoding="utf-8")
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))

    def test_candidate_changes_during_command_are_failure(self):
        self.init()
        command = "from pathlib import Path; p=Path('test_sample.py'); p.write_text(p.read_text()+'# drift'); print('test_positive (test_sample.Sample.test_positive) ... ok\\nRan 1 test in 0.1s\\nOK')"
        result = w.execute(self.record, "unit", [sys.executable, "-c", command])
        self.assertFalse(result["PASS"])
        self.assertIn("candidate changed", result["error"])

    def test_save_guard_changes_are_failure(self):
        self.init()
        command = "from pathlib import Path; Path('preserved.save').write_bytes(b'drift')"
        result = w.execute(self.record, "unit", [sys.executable, "-c", command])
        self.assertFalse(result["PASS"])
        self.assertIn("guard drift", result["error"])

    def test_raw_tampering_and_forged_count_are_blocked(self):
        self.init()
        self.run_unit()
        d = w.load(self.record)
        d["attempts"][0]["actualCount"] = 999
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(d)
        Path(d["attempts"][0]["stdout"]["path"]).write_text("changed", encoding="utf-8")
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))

    def test_wrong_run_and_stale_review_are_blocked(self):
        self.init()
        self.run_unit()
        p = self.review()
        result = w.load(p)
        result["runId"] = "other-run"
        w.save(p, result)
        with self.assertRaises(w.EvidenceError):
            w.accept_review(self.record, p)
        p = self.review()
        self.run_unit()
        with self.assertRaises(w.EvidenceError):
            w.accept_review(self.record, p)

    def test_same_actual_executor_is_not_independent(self):
        self.plan["actors"]["reviewer"] = deepcopy(self.plan["actors"]["author"])
        with self.assertRaises(w.EvidenceError):
            self.init()

    def test_host_acknowledgement_drift_is_blocked(self):
        self.init()
        w.save(self.root / "reviewer.json", {"executorId": "/root/other", "source": "host-acknowledgement"})
        with self.assertRaises(w.EvidenceError):
            w.current(w.load(self.record))

    def test_missing_names_json_and_fixture_fail_preflight(self):
        for field in ("name", "json", "fixture"):
            plan = deepcopy(self.plan)
            if field == "name":
                plan["checks"]["unit"]["expectedNames"] = ["missing_test"]
            elif field == "json":
                (self.root / "invalid.json").write_text("{", encoding="utf-8")
                plan["jsonInputs"] = ["invalid.json"]
            else:
                plan["fixtures"][0]["anchor"] = "missing anchor"
            with self.assertRaises(w.EvidenceError):
                w.preflight(self.root, plan)

    def test_path_escape_and_private_paths_are_rejected(self):
        for name in ("../outside", "/absolute", "C:/outside", ".agents/skill", "x\\y"):
            with self.assertRaises(w.EvidenceError):
                w.local(self.root, name)

    def test_uncovered_ui_and_formal_art_cannot_use_small_path(self):
        self.plan["impacts"]["minimumWidth"] = {"applicable": True, "reason": "new tab"}
        with self.assertRaises(w.EvidenceError):
            self.init()
        self.plan["impacts"]["minimumWidth"]["checks"] = ["unit"]
        self.plan["impacts"]["formalArt"] = {"applicable": True, "reason": "formal art", "checks": ["unit"]}
        with self.assertRaises(w.EvidenceError):
            self.init()

    def test_private_case_and_resolved_links_are_rejected(self):
        with self.assertRaises(w.EvidenceError):
            w.local(self.root, ".AGENTS/secret")
        with self.assertRaises(w.EvidenceError):
            w.guard_snapshot([{"kind": "original", "path": str(self.root / ".AGENTS/secret")}])
        original = Path.resolve
        def resolved(path, *args, **kwargs):
            return self.root / ".AGENTS/secret" if path.name == "alias" else original(path, *args, **kwargs)
        with patch.object(Path, "resolve", resolved):
            with self.assertRaises(w.EvidenceError):
                w.local(self.root, "alias")

    def test_execution_root_metadata_drift_is_blocked(self):
        self.init()
        record = w.load(self.record)
        other = self.root / "different-cwd"
        other.mkdir()
        for name in ("test_sample.py", "author.json", "reviewer.json"):
            (other / name).write_bytes((self.root / name).read_bytes())
        # All inputs and guard bytes remain identical; only the execution cwd differs.
        record["root"] = str(other)
        with self.assertRaises(w.EvidenceError):
            w.current(record)

    def test_images_require_fresh_outputs(self):
        spec = {"adapter": "images", "minimumCount": 1, "artifacts": ["screen.png"],
                "coverage": [{"artifact": "screen.png", "state": "alert", "target": "480x270"}]}
        self.plan["checks"] = {"capture": spec}
        self.init()
        (self.root / "screen.png").write_bytes(b"old")
        with self.assertRaises(w.EvidenceError):
            w.execute(self.record, "capture", [sys.executable, "-c", "print('CAPTURE PASS')"])

    def capture_bytes(self, data):
        self.plan["checks"] = {"capture": {
            "adapter": "images", "minimumCount": 1, "artifacts": ["screen.png"],
            "coverage": [{"artifact": "screen.png", "state": "fixture", "target": "2x1"}]}}
        self.init()
        command = [sys.executable, "-B", "-c",
                   "from pathlib import Path; Path('screen.png').write_bytes(bytes.fromhex('" +
                   data.hex() + "')); print('CAPTURE PASS')"]
        return w.execute(self.record, "capture", command, 10)

    def png_fixture(self):
        from PIL import Image
        stream = io.BytesIO()
        Image.new("RGB", (2, 1), (20, 40, 60)).save(stream, format="PNG")
        return stream.getvalue()

    def test_complete_png_capture_passes_and_revalidates(self):
        self.assertTrue(self.capture_bytes(self.png_fixture())["PASS"])
        w.required_evidence(w.load(self.record))

    def test_header_only_png_capture_fails(self):
        data = b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 2, 1)
        self.assertFalse(self.capture_bytes(data)["PASS"])
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))

    def test_png_capture_with_corrupt_chunk_fails(self):
        data = bytearray(self.png_fixture())
        data[data.index(b"IDAT") + 4] ^= 1
        self.assertFalse(self.capture_bytes(bytes(data))["PASS"])

    def test_png_capture_with_invalid_pixels_and_valid_crc_fails(self):
        data = self.png_fixture()
        offset = data.index(b"IDAT") - 4
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        payload = b"IDAT" + b"x" * length
        malformed = data[:offset + 4] + payload + struct.pack(">I", zlib.crc32(payload)) + data[offset + 12 + length:]
        self.assertFalse(self.capture_bytes(malformed)["PASS"])

    def test_truncated_png_capture_fails(self):
        self.assertFalse(self.capture_bytes(self.png_fixture()[:-1])["PASS"])

    def test_png_ending_truncations_and_crc_are_rejected(self):
        data = self.png_fixture()
        for missing in range(1, 13):
            with self.subTest(missing=missing):
                with patch.object(Path, "read_bytes", return_value=data[:-missing]):
                    with self.assertRaises(w.EvidenceError):
                        w.png_size("ending.png")
        corrupt = data[:-1] + bytes([data[-1] ^ 1])
        with patch.object(Path, "read_bytes", return_value=corrupt):
            with self.assertRaises(w.EvidenceError):
                w.png_size("ending.png")

    def test_smoke_completion_count_and_failure_mixing(self):
        self.plan["checks"] = {"smoke": {"adapter": "smoke", "minimumCount": 1}}
        self.init()
        for output, expected, count in (
                ("SMOKE PASS fixture\n", True, 1),
                ("SMOKE PASS\nSMOKE PASS\n", False, 2),
                ("SMOKE PASS\nSMOKE FAIL\n", False, 1),
                ("SMOKE ERROR\nSMOKE PASS\n", False, 1),
                ("SMOKE FAILED\nSMOKE PASS\n", False, 1),
                ("no completion\n", False, 0)):
            with self.subTest(output=output):
                result = w.execute(self.record, "smoke", [sys.executable, "-B", "-c", "print(" + repr(output) + ")"], 10)
                self.assertEqual(result["PASS"], expected)
                self.assertEqual(result["actualCount"], count)
                if expected:
                    w.required_evidence(w.load(self.record))
                else:
                    with self.assertRaises(w.EvidenceError):
                        w.required_evidence(w.load(self.record))

    def test_failed_latest_attempt_does_not_reuse_old_pass(self):
        self.init()
        self.run_unit()
        w.execute(self.record, "unit", [sys.executable, "-c", "raise SystemExit(1)"])
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))

    def test_stage_times_cannot_be_reset_and_report_needs_review(self):
        self.init()
        w.stage(self.record, "review", "begin")
        with self.assertRaises(w.EvidenceError):
            w.stage(self.record, "review", "begin")
        w.stage(self.record, "review", "end")
        self.assertGreaterEqual(w.load(self.record)["stages"][0]["elapsedWallSeconds"], 0)
        self.run_unit()
        with self.assertRaises(w.EvidenceError):
            w.render(self.record, self.root / "report.md")

    def test_parser_rejects_love_incomplete_or_duplicate_pass(self):
        output = "PASS real test\nPASS all 1 core tests\nTEST SUITE: 0 file failures\n"
        self.assertTrue(w.parse_output("love", output)["complete"])
        self.assertFalse(w.parse_output("love", output.replace("0 file failures", "1 file failures"))["complete"])
        self.assertFalse(w.parse_output("love", "PASS real test")["complete"])

    def test_stage_closes_changed_candidate_without_refreshing_evidence(self):
        self.init()
        w.stage(self.record, "implementation", "begin")
        self.run_unit()
        self.source.write_text(self.source.read_text() + "\n# normal implementation edit\n", encoding="utf-8")
        result = w.stage(self.record, "implementation", "end")
        self.assertTrue(result["observationOnly"])
        span = w.load(self.record)["stages"][0]
        self.assertIn("endedUtc", span)
        self.assertFalse(span["endIdentityCurrent"])
        self.assertIn("candidate changed", span["endIdentityError"])
        with self.assertRaises(w.EvidenceError):
            w.required_evidence(w.load(self.record))


if __name__ == "__main__":
    unittest.main(verbosity=2)
