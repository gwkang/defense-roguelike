---
name: game-ui-implementation
description: Implement a minimal playable interface for an agreed gameplay slice, prepare bounded code-native UI sources, or integrate final UI after approved design and asset readiness.
---

## Role
Implement the contract for the selected mode. Preserve approved gameplay and interaction meaning; defer unresolved appearance only in the playable functional mode. Keep visual, live-data, layout, and input ownership explicit and testable.

## Playable functional interface
For an agreed gameplay slice before final visual polish, consume the recorded code-impact decision (or make it within a directly invoked bounded task) and implement the smallest product UI that exposes approved player actions, live state and outcomes in the target runtime. Use the current gameplay/interaction contract, real data and target/input constraints; reuse existing controls or provisional code-native components. Keep presentation replaceable and record deferred visual choices. Resolve consequential layout, hit-area and state decisions early enough to avoid rebuilding the interaction code during polish. This mode may bind live content and input, unlike bounded source preparation below.

Consume a current technical-design decision before this mode changes consequential orchestration, state ownership, shared interfaces, lifecycle or component boundaries. A directly invoked implementation task may make routine local coding choices, but it does not own missing architecture. If provisional UI introduces maintained product structure, record its permitted consumers, forbidden expansion, owner and replacement or promotion criteria in the functional handoff.

This mode does not require selected visual mockups, a final component catalog, handoff or asset packet. It does require authority for the gameplay and visible actions, usable target-runtime input and state feedback, and focused functional verification of the player loop by a separate verifier. Follow [the functional-interface output rules](references/output-contract.md#playable-functional-interface) and return a functional candidate, not a formal UI integration matrix, asset READY claim or visual acceptance. Do not use provisional UI to override a user-reserved design decision, invent gameplay behavior, bypass required rights for actual assets, or call final polish complete. If a postponed visual choice would change the interaction structure materially, return that decision before implementing the affected part.

## Bounded runtime-source preparation
Only when a `READY` row in an approved handoff and matching approved catalog declare an `ASSET_NOT_REQUIRED` code-native/native-widget binding whose exact source lacks target-size rendered parity, prepare that catalog-declared adapter/source and the minimal isolated component render fixture needed by game-ui-asset-production. Freeze the binding identity, fingerprint, allowed inputs, protected properties, states, declared adapter contract, intended source locator, target and consumer. If the source file is uncreated, record pre-state `ABSENT` without a pre-hash; hash the produced source and fixture before separate verification and asset parity. This is a separate candidate with its own scoped evidence and independent verification; leave asset packet and full implementation readiness `BLOCKED` until their owners verify the required evidence.

Do not integrate the screen, bind live content/input, implement navigation or behavior, create or replace a product screen or entry controller, own shared runtime state, substitute a helper for the declared adapter, change component design or produce replacement art in this mode. Return source and isolated target-size component evidence to asset production for parity assessment; do not claim composed-screen runtime fidelity in this preparation mode. An uncreated file at the declared locator is permitted; a missing or conflicting approved handoff/catalog, adapter contract or intended locator returns to its owner. If isolated parity cannot be produced without crossing these boundaries, return the dependency instead of broadening this mode. Full integration still requires every readiness gate below.

## Inputs for full integration
- Approved screen specification and handoff.
- The screen specification's persona-derived priority, information budget, and disclosure rules; implementation must preserve these visibility decisions and must not surface every available field by default.
- The handoff's current `Component implementation binding matrix`, including reusable template source identities and allowed instance inputs.
- Resolved mockup selection under the shared UI decision rules, bound to exact composite hashes.
- Asset-readiness packet in an explicit production mode and its matching independent asset-review disposition.
- The asset packet's current `Component production disposition matrix`, binding readiness, and packet readiness.
- Source-parity records, supported targets, acceptance map, component/state IDs, and current code/data/input/test owners.
- Current technical-design revision for any consequential responsibility, state, interface, lifecycle or component-boundary change introduced by integration.

Before full integration tests/code, recompute locks: every visible family must be new production or verified reuse, none missing; file-backed target-size evidence must use intended runtime bytes, while code-native pre-integration evidence may use the exact declared source in an isolated target-size fixture. Whole-screen fidelity is checked after integration in the actual runtime. Return stale/incomplete/mismatched/unapproved inputs upstream. The bounded source-preparation mode above uses only its stated prerequisites and cannot be treated as full integration.

Produced/file-backed art requires `Decision: APPROVE ASSET QUALITY`; otherwise only that art verdict is NOT APPLICABLE. Packet readiness, parity and target-size rendered evidence remain required.

Each binding must share catalog identity/fingerprint across handoff, asset packet and current catalog. Require handoff READY and both asset binding/packet READY_FOR_IMPLEMENTATION. Code-native/native-widget ASSET_NOT_REQUIRED never waives readiness.

After full integration, compare each declared code-native component source and relevant parity fixture/render dependency with the asset packet's exact parity evidence before handing off to runtime validation. Record the integrated build identity separately for runtime validation; a changed whole-build hash alone is not source-parity drift. If the declared representation, protected-property source or parity fixture dependency drifted, treat that affected binding and packet readiness as `BLOCKED` and return to asset production to recheck parity and obtain independent verification. A screen composition, live-content or input-only change that leaves those pre-integration inputs intact goes to affected runtime validation; do not reopen asset readiness solely because the integrated screen/build fingerprint changed. Preserve unaffected valid evidence; resume full integration only after readiness is restored.

## Full-integration work and handoff
1. Implement only approved content, geometry, components and reviewed assets; instantiate compatible reusable component templates wherever possible and create a screen-specific implementation only for a documented exception. Return a missing or incompatible template to its component owner. Separate live data, layout and input ownership.
2. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
3. Return the implementation packet for runtime validation. Do not redesign or claim acceptance from successful compilation.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Iteration mode
For exploratory screen drafts or formal UI revisions, read [fast iteration](../game-task-planning/references/ui-fast-iteration.md). Preserve role ownership and apply formal approval/readiness gates when promoting a draft or changing formal UI runtime. The playable functional interface is a separate product-code mode with its own approved interaction inputs and functional verification; it is not promotion of an exploratory draft.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
