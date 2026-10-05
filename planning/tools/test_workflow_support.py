"""CLI behavior checks for the read-only workflow support tool."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import shutil
import uuid
import unittest

TOOL = Path(__file__).with_name('workflow_support.py')
EVIDENCE = TOOL.with_name('workflow_evidence.py')
FIXTURE_BASE = TOOL.parents[2] / 'validation' / 'support-fixtures'


def owned_temporary(prefix):
    FIXTURE_BASE.mkdir(parents=True, exist_ok=True)
    temporary = FIXTURE_BASE / (prefix + uuid.uuid4().hex)
    temporary.mkdir()
    return temporary


def cleanup_owned(temporary):
    target = temporary.resolve()
    boundary = FIXTURE_BASE.resolve()
    if target == boundary or not target.is_relative_to(boundary):
        raise RuntimeError('temporary cleanup target escapes owned fixture base')
    shutil.rmtree(target)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True).encode('utf-8')


class SupportCLI(unittest.TestCase):
    def setUp(self):
        self.temporary = owned_temporary('main-')
        self.addCleanup(cleanup_owned, self.temporary)
        self.root = self.temporary.resolve()
        (self.root / 'planning/tools').mkdir(parents=True)
        (self.root / 'planning/tools/workflow_evidence.py').write_bytes(EVIDENCE.read_bytes())

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding='utf-8')
        return path

    def cli(self, *args):
        result = subprocess.run([sys.executable, '-B', str(TOOL), *args], cwd=self.root,
                                capture_output=True, text=True, encoding='utf-8', timeout=20)
        return result.returncode, json.loads(result.stdout)

    def fingerprint(self, path):
        return {'exists': True, 'sha256': digest(path.read_bytes())}

    def record(self, pending=False):
        candidate = self.write('candidate/value.json', {'value': 1})
        stdout = self.root / 'raw/stdout.log'
        stdout.parent.mkdir()
        stdout.write_text('PASS: 5 required pages, 6 settings, 1 local links, 41 source identities\n', encoding='utf-8')
        stderr = self.root / 'raw/stderr.log'
        stderr.write_bytes(b'')
        plan = {'runId': 'test-run', 'checks': {'wiki': {'adapter': 'docs', 'minimumCount': 41}},
                'actors': {'reviewer': {'executorId': 'reviewer'}}}
        if pending:
            plan['checks']['pending'] = {'adapter': 'docs', 'minimumCount': 1}
        record = {'schemaVersion': 1, 'root': str(self.root), 'plan': plan,
                  'candidate': {'candidate/value.json': self.fingerprint(candidate)}, 'inputs': {},
                  'toolSha256': digest(EVIDENCE.read_bytes()), 'attempts': [], 'review': None,
                  'createdUtc': '2026-10-05T00:00:00Z', 'stages': []}
        record['identity'] = digest(encoded({k: record[k] for k in ('root', 'plan', 'candidate', 'inputs')} | {'runId': plan['runId']}))
        record['attempts'].append({'check': 'wiki', 'number': 1, 'identity': record['identity'],
                                  'runId': plan['runId'], 'PASS': True, 'exitCode': 0,
                                  'completedUtc': '2026-10-05T00:01:00Z', 'actualCount': 41, 'names': [],
                                  'stdout': {'path': str(stdout), **self.fingerprint(stdout)},
                                  'stderr': {'path': str(stderr), **self.fingerprint(stderr)}})
        self.write('record.json', record)
        return record

    def review_content(self, record):
        return {'candidateIdentity': record['identity'], 'runId': record['plan']['runId'],
                'evidenceIdentity': digest(encoded(record['attempts'])), 'executorId': 'reviewer',
                'verdict': 'PASS', 'blockingFindings': [], 'inspectedArtifacts': [],
                'findings': {key: 'Checked within tool observation scope' for key in
                             ('design', 'readability', 'failureBoundaries', 'coverage', 'preservation',
                              'uiImpact', 'knowledge', 'completion')}}

    def test_initial_append_shape_is_unverified(self):
        record = self.record()
        record['attempts'] = [{'check': 'wiki', 'number': 1, 'identity': record['identity'],
                               'runId': record['plan']['runId'], 'PASS': False, 'exitCode': None,
                               'startedUtc': '2026-10-05T00:01:00Z'}]
        self.write('record.json', record)
        code, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(code, 0)
        self.assertEqual(result['observation'], 'unverified')
        self.assertEqual(result['failedChecks'], ['wiki'])
        self.assertIn('stdout missing', result['latestChecks'][0]['reasons'])
        self.assertIn('stderr missing', result['latestChecks'][0]['reasons'])
        self.assertIn('latest attempt failed or incomplete', result['latestChecks'][0]['reasons'])
        self.assertIsNone(result['latestChecks'][0]['actualCount'])

    def test_strict_schema_and_attempt_types(self):
        record = self.record()
        for scope, key, value in [('record', 'schemaVersion', True), ('record', 'schemaVersion', 1.0),
                                   ('attempt', 'actualCount', True), ('attempt', 'exitCode', False),
                                   ('attempt', 'number', True), ('attempt', 'actualCount', 41.0),
                                   ('attempt', 'PASS', 1), ('record', 'identity', 'invalid')]:
            with self.subTest(scope=scope, key=key, value=value):
                current = json.loads(json.dumps(record))
                target = current if scope == 'record' else current['attempts'][0]
                target[key] = value
                self.write('record.json', current)
                code, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
                self.assertEqual(code, 2)
                self.assertEqual(result['observation'], 'unverified')

    def test_review_content_must_match_current_evidence(self):
        record = self.record()
        base = self.review_content(record)
        cases = [('candidateIdentity', '0' * 64), ('runId', 'wrong'), ('verdict', 'FAIL'),
                 ('blockingFindings', ['unresolved']), ('evidenceIdentity', '0' * 64),
                 ('executorId', 'wrong'), ('findings', {}), ('inspectedArtifacts', ['uninspected.png'])]
        for key, value in cases:
            with self.subTest(key=key):
                content = dict(base, **{key: value})
                review = self.write('review.json', content)
                record['review'] = {'path': str(review), **self.fingerprint(review), 'executorId': 'reviewer',
                                    'evidenceIdentity': digest(encoded(record['attempts']))}
                self.write('record.json', record)
                code, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
                self.assertEqual(code, 0)
                self.assertEqual(result['review']['applicability'], 'unverified')

    def test_actual_png_and_corrupt_png_observation(self):
        from PIL import Image
        record = self.record()
        image = self.root / 'capture.png'
        Image.new('RGB', (2, 3), (12, 34, 56)).save(image)
        record['plan']['checks'] = {'wiki': {'adapter': 'images', 'minimumCount': 1,
                                           'artifacts': ['capture.png'],
                                           'coverage': [{'artifact': 'capture.png', 'target': '2x3'}]}}
        record['identity'] = digest(encoded({k: record[k] for k in ('root', 'plan', 'candidate', 'inputs')} |
                                            {'runId': record['plan']['runId']}))
        attempt = record['attempts'][0]
        attempt.update(identity=record['identity'], actualCount=1, artifacts={'capture.png': self.fingerprint(image)})
        (self.root / 'raw/stdout.log').write_text('CAPTURE PASS\n', encoding='utf-8')
        attempt['stdout'].update(self.fingerprint(self.root / 'raw/stdout.log'))
        self.write('record.json', record)
        code, good = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(code, 0)
        self.assertEqual(good['observation'], 'current')
        for invalid in ([2, 3], True, '0x3', '2X3', '2x', '2x-3'):
            record['plan']['checks']['wiki']['coverage'][0]['target'] = invalid
            self.write('record.json', record)
            code, rejected = self.cli('status', '--root', str(self.root), '--record', 'record.json')
            self.assertEqual(code, 2)
            self.assertIn('error', rejected)
        record['plan']['checks']['wiki']['coverage'][0]['target'] = '2x3'
        image.write_bytes(b'not a PNG')
        attempt['artifacts']['capture.png'] = self.fingerprint(image)
        self.write('record.json', record)
        code, bad = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(code, 0)
        self.assertEqual(bad['observation'], 'unverified')
        self.assertTrue(any('decode unverified' in reason for reason in bad['latestChecks'][0]['reasons']))

    def test_status_current_and_no_files_written(self):
        self.record()
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        code, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(code, 0)
        self.assertEqual(result['observation'], 'current')
        self.assertEqual(result['actualCount'], 41)
        self.assertEqual(result['review']['applicability'], 'absent')
        after = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        self.assertEqual(before, after)
        self.assertFalse(list(TOOL.parent.glob('__pycache__')))

    def test_latest_fail_does_not_use_old_pass(self):
        record = self.record()
        record['attempts'].append(dict(record['attempts'][0], number=2, PASS=False, exitCode=1))
        self.write('record.json', record)
        _, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(result['failedChecks'], ['wiki'])
        self.assertEqual(result['latestChecks'][0]['number'], 2)
        self.assertEqual(result['observation'], 'unverified')

    def test_pending_is_unverified(self):
        self.record(pending=True)
        _, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(result['pendingChecks'], ['pending'])
        self.assertEqual(result['observation'], 'unverified')

    def test_partial_attempt_is_unverified(self):
        record = self.record()
        del record['attempts'][0]['completedUtc']
        self.write('record.json', record)
        _, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(result['failedChecks'], ['wiki'])

    def test_raw_drift_and_missing_are_unverified(self):
        self.record()
        (self.root / 'raw/stdout.log').write_text('altered', encoding='utf-8')
        (self.root / 'raw/stderr.log').unlink()
        _, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(result['failedChecks'], ['wiki'])
        self.assertIn('stdout missing or drift', result['latestChecks'][0]['reasons'])
        self.assertIn('stderr missing or drift', result['latestChecks'][0]['reasons'])

    def test_candidate_drift_marks_review_unverified(self):
        record = self.record()
        review = self.write('review.json', self.review_content(record))
        record['review'] = {'path': str(review), **self.fingerprint(review), 'executorId': 'reviewer',
                            'evidenceIdentity': digest(encoded(record['attempts']))}
        self.write('record.json', record)
        _, good = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(good['review']['applicability'], 'current')
        self.write('candidate/value.json', {'value': 2})
        _, changed = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(changed['identity']['candidateDrift'], ['candidate/value.json'])
        self.assertEqual(changed['review']['applicability'], 'unverified')

    def test_raw_path_escape_refused(self):
        record = self.record()
        record['attempts'][0]['stdout']['path'] = str(self.root.parent / 'outside.log')
        self.write('record.json', record)
        code, result = self.cli('status', '--root', str(self.root), '--record', 'record.json')
        self.assertEqual(code, 2)
        self.assertIn('escapes root', result['error'])

    def test_compare_order_is_ignored(self):
        self.write('expected.json', ['I21', 'I22', 'I23'])
        self.write('actual.json', ['I23', 'I21', 'I22'])
        code, result = self.cli('compare-set', '--expected', 'expected.json', '--actual', 'actual.json')
        self.assertEqual(code, 0)
        self.assertTrue(result['PASS'])
        self.assertEqual(len(result['actualSource']['sha256']), 64)

    def test_same_count_wrong_member_fails(self):
        self.write('expected.json', ['I21', 'I22', 'I23'])
        self.write('actual.json', ['I21', 'I22', 'I24'])
        code, result = self.cli('compare-set', '--expected', 'expected.json', '--actual', 'actual.json')
        self.assertEqual(code, 1)
        self.assertEqual(result['missing'], ['I23'])
        self.assertEqual(result['extra'], ['I24'])

    def test_duplicate_ids_fail(self):
        self.write('expected.json', ['A', 'B'])
        self.write('actual.json', ['A', 'B', 'B'])
        code, result = self.cli('compare-set', '--expected', 'expected.json', '--actual', 'actual.json')
        self.assertEqual(code, 1)
        self.assertEqual(result['duplicates']['actual'], ['B'])

    def test_empty_and_wrong_type_inputs_rejected(self):
        for value in ([], [1], {'A': True}, ['']):
            with self.subTest(value=value):
                self.write('expected.json', ['A'])
                self.write('actual.json', value)
                code, result = self.cli('compare-set', '--expected', 'expected.json', '--actual', 'actual.json')
                self.assertEqual(code, 2)
                self.assertIn('actual', result['inputErrors'])

    def test_inspect_selected_field_and_truncation(self):
        self.write('data.json', {'selected': {'value': 'x' * 100}, 'secretOther': 'not requested'})
        code, result = self.cli('inspect', '--json', 'data.json', '--field', 'selected.value', '--max-chars', '32')
        self.assertEqual(code, 0)
        self.assertTrue(result['truncated'])
        self.assertEqual(len(result['preview']), 32)
        self.assertIsNone(result['projection'])
        self.assertNotIn('secretOther', json.dumps(result))
        code, result = self.cli('inspect', '--json', 'data.json', '--field', 'selected.value')
        self.assertEqual(result['projection'], {'selected.value': 'x' * 100})
        self.assertFalse(result['truncated'])

    def test_inspect_field_and_json_errors(self):
        self.write('data.json', {'a': [1]})
        code, result = self.cli('inspect', '--json', 'data.json', '--field', 'a.b', 'missing')
        self.assertEqual(code, 2)
        self.assertEqual(set(result['fieldErrors']), {'a.b', 'missing'})
        (self.root / 'data.json').write_text('{broken', encoding='utf-8')
        code, result = self.cli('inspect', '--json', 'data.json', '--field', 'a')
        self.assertEqual(code, 2)
        self.assertEqual(result['error'], 'invalid UTF-8 JSON')

    def test_private_traversal_and_absolute_paths_rejected(self):
        for name in ('.agents/x.json', '.instructions/x.json', '../outside.json', str(self.root / 'x.json')):
            with self.subTest(name=name):
                code, result = self.cli('inspect', '--json', name, '--field', 'a')
                self.assertEqual(code, 2)
                self.assertIn('error', result)

    def test_directory_link_escape_rejected(self):
        outside = owned_temporary('outside-')
        self.addCleanup(cleanup_owned, outside)
        self.write('inside.json', {'a': 1})
        target_file = outside / 'file.json'
        target_file.write_text('{"a": 1}', encoding='utf-8')
        before = target_file.read_bytes()
        link = self.root / 'escape'
        if os.name == 'nt':
            subprocess.run(['cmd.exe', '/d', '/c', 'mklink', '/J', str(link), str(outside)],
                           check=True, capture_output=True, timeout=20)
        else:
            link.symlink_to(outside, target_is_directory=True)
        try:
            self.assertEqual(link.resolve(), outside.resolve())
            code, result = self.cli('inspect', '--json', 'escape/file.json', '--field', 'a')
            self.assertEqual(code, 2)
            self.assertIn('resolved path', result['error'])
            self.assertEqual(target_file.read_bytes(), before)
        finally:
            if link.parent.resolve() != self.root or not outside.resolve().is_relative_to(FIXTURE_BASE.resolve()):
                raise RuntimeError('link cleanup outside owned roots')
            if os.name == 'nt':
                os.rmdir(link)
            else:
                link.unlink()


if __name__ == '__main__':
    unittest.main(verbosity=2)
