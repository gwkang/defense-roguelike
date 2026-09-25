#!/usr/bin/env python3
"""Validate cross-field component-catalog invariants using only the standard library."""

import json
import hashlib
import copy
import re
import sys
from pathlib import Path


CATALOG_FIELDS = {'catalogVersion', 'artifactFingerprint', 'profileFingerprint', 'components'}
COMPONENT_FIELDS = {
    'componentId', 'version', 'kind', 'variants', 'authorities', 'structure',
    'allowedInputs', 'protectedProperties', 'states', 'accessibility', 'adapter',
    'evidence', 'consumers', 'exceptions', 'approval',
}
SCHEMA_PATH = Path(__file__).parents[1] / 'references' / 'component-catalog.schema.json'


def _resolve_ref(root, reference):
    node = root
    for part in reference.removeprefix('#/').split('/'):
        node = node[part]
    return node


def _matches_condition(value, condition):
    for name, child in condition.get('properties', {}).items():
        if name not in value or value[name] != child.get('const'):
            return False
    return True


def _validate_node(value, schema, root, path):
    if '$ref' in schema:
        schema = _resolve_ref(root, schema['$ref'])
    issues = []
    expected = schema.get('type')
    type_map = {'object': dict, 'array': list, 'string': str}
    if expected in type_map and not isinstance(value, type_map[expected]):
        return [f'{path}: expected {expected}']
    if 'enum' in schema and value not in schema['enum']:
        issues.append(f'{path}: value not in enum')
    if isinstance(value, str):
        if len(value) < schema.get('minLength', 0):
            issues.append(f'{path}: string is too short')
        if 'pattern' in schema and re.fullmatch(schema['pattern'], value) is None:
            issues.append(f'{path}: pattern mismatch')
    if isinstance(value, dict):
        for name in schema.get('required', []):
            if name not in value:
                issues.append(f'{path}: missing required property: {name}')
        properties = schema.get('properties', {})
        if schema.get('additionalProperties') is False:
            for name in value.keys() - properties.keys():
                issues.append(f'{path}: unexpected property: {name}')
        if len(value) < schema.get('minProperties', 0):
            issues.append(f'{path}: expected at least {schema["minProperties"]} properties')
        for name, child in properties.items():
            if name in value:
                issues.extend(_validate_node(value[name], child, root, f'{path}.{name}'))
    if isinstance(value, list):
        if len(value) < schema.get('minItems', 0):
            issues.append(f'{path}: expected at least {schema["minItems"]} items')
        if schema.get('uniqueItems'):
            encoded = [json.dumps(item, sort_keys=True) for item in value]
            if len(encoded) != len(set(encoded)):
                issues.append(f'{path}: duplicate array item')
        if 'items' in schema:
            for index, item in enumerate(value):
                issues.extend(_validate_node(item, schema['items'], root, f'{path}[{index}]'))
    for clause in schema.get('allOf', []):
        if _matches_condition(value, clause.get('if', {})):
            issues.extend(_validate_node(value, clause.get('then', {}), root, path))
    return issues


def validate_schema(catalog):
    schema = json.loads(SCHEMA_PATH.read_text(encoding='utf-8'))
    return _validate_node(catalog, schema, schema, '$')


def compute_catalog_fingerprint(catalog):
    canonical = copy.deepcopy(catalog)
    canonical['artifactFingerprint'] = ''
    components = canonical.get('components', [])
    for component in components if isinstance(components, list) else []:
        if isinstance(component, dict) and isinstance(component.get('approval'), dict):
            component['approval']['artifactFingerprint'] = ''
    payload = json.dumps(
        canonical, ensure_ascii=False, sort_keys=True, separators=(',', ':'),
    ).encode('utf-8')
    return hashlib.sha256(payload).hexdigest()


def validate_catalog(catalog, profile):
    issues = validate_schema(catalog)
    if not isinstance(catalog, dict):
        return issues
    if not isinstance(profile, dict):
        return issues + ['$profile: expected object']
    for field in sorted(CATALOG_FIELDS - set(catalog)):
        issues.append(f'missing required catalog field: {field}')
    components = catalog.get('components', [])
    if not isinstance(components, list) or not components:
        issues.append('components must contain at least one entry')
    if catalog.get('profileFingerprint') != profile.get('artifactFingerprint'):
        issues.append('profile fingerprint mismatch')
    if catalog.get('artifactFingerprint') != compute_catalog_fingerprint(catalog):
        issues.append('catalog fingerprint mismatch')

    seen = set()
    supported_kinds = set(profile.get('supportedKinds', []))
    adapters = set(profile.get('adapters', []))
    capabilities = set(profile.get('evidenceCapabilities', []))
    authority_refs = set(profile.get('authorityRefs', []))
    approval_authorities = set(profile.get('approvalAuthorities', []))
    fallback_owners = set(profile.get('fallbackOwners', []))
    schema_root = json.loads(SCHEMA_PATH.read_text(encoding='utf-8'))
    component_schema = schema_root['$defs']['component']

    for index, component in enumerate(components if isinstance(components, list) else []):
        prefix = f'components[{index}]'
        if not isinstance(component, dict):
            continue
        if _validate_node(component, component_schema, schema_root, f'$.{prefix}'):
            continue
        for field in sorted(COMPONENT_FIELDS - set(component)):
            issues.append(f'{prefix}: missing required component field: {field}')
        identity = component.get('componentId')
        if identity in seen:
            issues.append(f'{prefix}: duplicate componentId')
        seen.add(identity)

        if component.get('kind') not in supported_kinds:
            issues.append(f'{prefix}: undeclared component kind')

        structure = component.get('structure', {})
        if not isinstance(structure, dict):
            structure = {}
        if structure.get('capability') not in capabilities:
            issues.append(f'{prefix}: undeclared structure capability')

        adapter = component.get('adapter', {})
        if not isinstance(adapter, dict):
            adapter = {}
        if adapter.get('id') not in adapters:
            issues.append(f'{prefix}: undeclared adapter')
        if adapter.get('fallbackOwner') not in fallback_owners:
            issues.append(f'{prefix}: undeclared fallback owner')

        authorities = component.get('authorities', [])
        for authority in authorities if isinstance(authorities, list) else []:
            if not isinstance(authority, dict):
                continue
            if authority.get('ref') not in authority_refs:
                issues.append(f'{prefix}: undeclared source authority')

        coverage = set()
        evidence_items = component.get('evidence', [])
        for evidence in evidence_items if isinstance(evidence_items, list) else []:
            if not isinstance(evidence, dict):
                continue
            if evidence.get('capability') not in capabilities:
                issues.append(f'{prefix}: undeclared evidence capability')
            declared_coverage = evidence.get('coverage', [])
            if isinstance(declared_coverage, list):
                coverage.update(declared_coverage)

        protected = component.get('protectedProperties', [])
        for prop in protected if isinstance(protected, list) else []:
            if prop not in coverage:
                issues.append(f'{prefix}: uncovered protected property: {prop}')
        states = component.get('states', [])
        for state in states if isinstance(states, list) else []:
            if f'state:{state}' not in coverage:
                issues.append(f'{prefix}: uncovered state: {state}')

        approval = component.get('approval', {})
        if not isinstance(approval, dict):
            approval = {}
        if approval.get('status') == 'approved' and not approval.get('authorityRef'):
            issues.append(f'{prefix}: approved entry missing authorityRef')
        elif (approval.get('status') == 'approved'
              and approval.get('authorityRef') not in approval_authorities):
            issues.append(f'{prefix}: undeclared approval authority')
        if approval.get('artifactFingerprint') != catalog.get('artifactFingerprint'):
            issues.append(f'{prefix}: approval fingerprint mismatch')

    return issues


def main(argv):
    if len(argv) != 3:
        print('usage: validate_component_catalog.py CATALOG.json PROFILE.json', file=sys.stderr)
        return 2
    catalog = json.loads(Path(argv[1]).read_text(encoding='utf-8'))
    profile = json.loads(Path(argv[2]).read_text(encoding='utf-8'))
    issues = validate_catalog(catalog, profile)
    for issue in issues:
        print(issue)
    return 1 if issues else 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
