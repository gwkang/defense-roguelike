---
name: art-asset-review
description: Use when game UI assets need an independent quality, provenance, target-slot, or composed-screen fidelity verdict before implementation.
---

## Role
Independently decide whether production assets and verified reuse meet both technical and composed-screen craft requirements. Review is read-only; the producer cannot approve their own work.

## Inputs
- Approved art direction, production-representative mockup, handoff, and asset-readiness packet.
- Exact source/output hashes, rights, transforms, geometry, target slots, consumers, and production status.
- Source-parity rows for every visible art family.
- Target-size composites for every supported target using the exact intended runtime bytes.

## Work and handoff
1. Read the locked production/reuse packet and inspect both exact bytes and target-size composed screens.
2. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
3. Return the independent verdict and criterion-linked defects to game-ui-asset-production; never repair assets or evidence.

Before judging, apply [current-state and prior-record review](../game-task-planning/references/verification-scope.md#review-the-current-state-before-alleging-a-defect): inspect relevant implementation and available wiki/decision/review records, check counterevidence, and report no findings when warranted. Do not expand scope or manufacture defects.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
