---
name: game-ui-runtime-validation
description: Use when an implemented game UI needs actual-runtime evidence for rendering, content, states, input, and fidelity before acceptance review.
---

## Role
Validate a frozen candidate in its actual runtime. For partial revisions, use the [incremental runtime evidence rules](../game-task-planning/references/ui-fast-iteration.md#부분-변경의-runtime-증거) to distinguish current observations from independently justified historical reuse; keep full required coverage. Static tests do not prove rendered fidelity, loaded assets, content boundaries, or usable input geometry.

## Inputs
- Approved screen specification, mockup, handoff comparison map, asset verdict, and implementation evidence.
- The screen specification's persona-derived priority and disclosure rules.
- The implementation packet's current `Component runtime integration matrix` and matching catalog artifact fingerprint.
- Exact build fingerprint, launch/capture method, fixture data, expected states, targets, locales, and safe areas.
- Approved composite hashes and source-parity records.

Use the declared browser/engine/emulator/simulator/device/harness for the actual product candidate. Before capture, identify each reference's role and renderer, the target runtime/renderer, and the frozen comparable properties, fixtures and tolerances. A browser mockup is a visual-intent reference when the product runs in another renderer; it cannot be the actual-runtime result. Compare geometry, hierarchy, text fit, state, hit geometry and motion timing against the agreed contract, allowing documented renderer/font/scaling differences. Require pixel metrics only when the contract explicitly makes comparable pixels and tolerance part of acceptance. Record environment, scale, target dimensions, safe area, fixture, state, locale, timestamp and fingerprint; recheck fingerprint after capture.

Separate design identity from capture freshness: code changes need not erase historical design approval, but that approval proves nothing about the current build. Review changed design authorities for relevance. Before requesting current approval, run the declared freshness/readiness check on current source/build, not archived evidence. Scoped PASS or author readiness cannot override overall BLOCKED, missing coverage/raw evidence or changed inputs. Without an executable check, explicitly compare complete locked source/build inventories and required coverage with raw evidence. Historical evidence is applicable only through the linked incremental record; unresolved/stale or unjustified evidence remains BLOCKED from acceptance and the runtime decision. Never relabel a historical raw capture as current.

Keep the repository read-only. Use normal runtime controls and isolated fixtures; do not fix code/assets/data/evidence or self-approve.

## Work and handoff
1. Observe affected coverage on the frozen current candidate and verify any historical reuse under the incremental rules, retaining all required screen/state/viewport rows and source identities.
2. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
3. Return raw observations and coverage verdicts for acceptance review. Do not repair product or evidence during verification.

Before judging, apply [current-state and prior-record review](../game-task-planning/references/verification-scope.md#review-the-current-state-before-alleging-a-defect): inspect relevant implementation and available wiki/decision/review records, check counterevidence, and report no findings when warranted. Do not expand scope or manufacture defects.

For each representative runtime state, verify that the primary task and first-read region are discoverable without scanning every panel, that secondary content is disclosed according to the screen contract, and that text/controls do not create avoidable density or competition. Record a failure when the implementation is functionally correct but violates the persona-derived information priority.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
