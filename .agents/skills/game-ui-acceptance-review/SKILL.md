---
name: game-ui-acceptance-review
description: Use when a completed game UI and runtime evidence need an independent, read-only fidelity verdict before broader feature review.
---

## Role
Decide whether the shipped screen matches approved visual, content, state, input, and runtime contracts. Passing code tests or isolated asset review alone is insufficient.

## Inputs
- Approved art direction, screen specification, mockup, handoff, and matching independent asset-review disposition.
- The persona-derived priority, information budget, and disclosure rules recorded by the screen specification.
- Implementation evidence and complete runtime-validation packet.
- The implementation packet's current `Component runtime integration matrix` and the runtime packet's current `Component runtime evidence matrix`.
- Runtime decision under the shared UI decision rules, bound to the exact build fingerprint and cited side-by-side evidence.
- Verified source parity, passing full-screen art fidelity, current build/commit fingerprint, working-tree state, and author/reviewer identities.

The reviewer must be independent of mockup, asset, and implementation authorship. Recompute current locks and reproduce critical or high-risk samples; do not trust summaries alone. The runtime/acceptance decisions must identify the submitted fingerprint. Raw evidence must either match it or retain its original identity with independently verified HISTORICAL_REUSE under the [incremental runtime evidence rules](../game-task-planning/references/ui-fast-iteration.md#부분-변경의-runtime-증거). Keep complete coverage and reject relabeled historical captures.

Review is read-only. Do not edit code, assets, documents, data, or evidence. A current product-owner fidelity objection reopens prior approval.

## Work and handoff
1. Compare the exact implementation candidate with approved design, binding coverage and actual runtime evidence.
2. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
3. Return a scoped acceptance verdict. Tests or isolated asset approval cannot substitute for composed-screen fidelity; do not change the candidate.

Before judging, apply [current-state and prior-record review](../game-task-planning/references/verification-scope.md#review-the-current-state-before-alleging-a-defect): inspect relevant implementation and available wiki/decision/review records, check counterevidence, and report no findings when warranted. Do not expand scope or manufacture defects.

Acceptance must include a composed-screen readability check: the primary task is visually dominant, the first-read region is apparent, secondary information is not competing in the default state, and required details remain reachable through the declared disclosure or scroll rules. Do not pass a screen merely because every component is present and individually readable.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
