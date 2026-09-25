---
name: game-ui-screen-spec
description: Use when an existing game screen needs an exact content, state, interaction, text-fit, or responsive contract before visual mockup work.
---

## Role
Turn approved visual direction and product authority into a truthful screen contract. Every visible or interactive requirement has a source, certainty, and responsive rule.

Before visual selection, prepare a preliminary source-backed content/target/state contract under [fast iteration](../game-task-planning/references/ui-fast-iteration.md), leaving unresolved appearance/bindings OPEN for an exploratory screen. The formal approval inputs below apply before promotion to a formal candidate.

## Formal inputs
- An approved `game-ui-art-direction` brief with the exact selected style/motion identity or a compatible previously approved style.
- The current `game-ui-ux-design` decision, or its documented compatible reuse, for the screen's task flow, information hierarchy and interaction intent.
- A current persona contract from [persona-contract.md](references/persona-contract.md), or an explicitly marked provisional contract when product authority has not supplied one. Consume it as evidence for the resolved UX decision, not authority to change that decision; return consequential conflicts to game-ui-ux-design.
- Current user decisions, authoritative product documents, and approved screen references.
- The approved `game-ui-component-system` catalog decision, visible template evidence, and exact artifact fingerprint when a repeated family or reuse claim is in scope. Existing templates are reused; only missing or incompatible components require additions.
- Content, data, behavior, navigation, font, input, and accessibility contracts.
- Supported target environments, viewports, safe areas, locales, and runtime evidence when an implementation exists.

Record unavailable required inputs as `OPEN` or `BLOCKED`. Do not replace them with platform conventions, placeholder copy, remembered standards, or values from unrelated projects.

## Work and handoff
1. Translate the UX decision's task flow and priorities into sourced visible content, state, input and responsive rules; trace exact reusable bindings. Return a UX-structure conflict to game-ui-ux-design rather than silently redesigning the flow.
2. Make the resolved UX priorities and their persona evidence explicit in a small information-priority contract: primary task, first-read region, secondary/disclosed content, maximum simultaneous groups, and state-specific visibility. Do not treat a complete content inventory as a requirement to show everything at once or silently redesign the UX hierarchy.
3. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
4. Produce the screen contract and runtime coverage map. Keep required design approval separate from changing implementation evidence; do not invent thresholds or downstream work.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Iteration mode
For early editable screen drafts or an existing screen revision, read [fast iteration](../game-task-planning/references/ui-fast-iteration.md). Preserve role ownership and apply formal approval/readiness gates when promoting a draft or changing runtime.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
