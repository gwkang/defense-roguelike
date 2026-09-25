---
name: game-ui-asset-production
description: Use when an approved game UI handoff has visible art families that need production readiness or reuse verification before implementation.
---

## Role
Turn an approved handoff into a reproducible, independently reviewable asset-readiness packet while keeping live content and input in code.

## Inputs
- Approved art direction, screen specification, mockup, and handoff.
- The handoff's current `Component implementation binding matrix` and the exact approved component catalog artifact or project-declared resolver for its fingerprint.
- Locked sources, hashes, geometry, states, fit rules, target slots, and consumers.
- Rights, license, bundle budget, runtime asset conventions, and migration authority.

## Work and handoff
1. Use only the handoff-authorized production/reuse mode. Preserve canonical identity, states, protected properties and deterministic provenance.
2. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
3. Produce the asset-readiness packet and exact disposition matrix; send produced/file-backed art to art-asset-review before full UI integration. For code-native/native-widget bindings, the UI implementation owner may first prepare only the declared runtime source and isolated target-size component rendering evidence under its bounded source-preparation mode; this does not grant packet readiness or screen integration.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
