---
name: game-ui-component-system
description: Use when multiple game screens should share a UI component, a reusable control has drifted from approved references, or a shared component family needs versioning or review.
---

## Role
Decide whether repeated UI belongs to an approved reusable family and maintain visible component design templates in the selected style. Reuse is a versioned, evidence-backed contract, not a visual resemblance or a convenient shared helper.

## Inputs
- The current project's approved profile, including catalog location, supported representations, runtime adapter, evidence capabilities, presentation roles, and approval authority.
- Current authoritative references and their fingerprints.
- The exact selected style and motion identity when appearance is in scope; unresolved style or motion blocks approval of new appearance templates, but not the separately labeled exploratory screen path.
- The proposed consumers, states, accessibility requirements, and known exceptions.
- The current UX decision for those consumers, or its documented compatible reuse, when task flow, information hierarchy, or interaction structure is in scope.

Keep missing values `OPEN` or `BLOCKED`. Never infer component roles, dimensions, locale, input modality, rendering technology, evidence tools, tolerances, commands, build/source identity fields, signing mechanisms, or approval identities from conventions.

## Work and handoff
1. Inventory actual consumer needs. Reuse compatible approved templates; add or revise only missing or incompatible components. Do not remake the library because one family is absent.
2. Before building a new or revised visible family, choose its structure from the current UX decision and actual consumers' purpose, content/action density, and interaction hierarchy; do not let the easiest generic container define the family. Resolve identity/version, allowed inputs, protected properties and evidence capabilities. Create representative design templates covering required states and relevant motion from the selected style. Keep these distinct from production assets and runtime code. If the needed UX decision is unresolved, return that consumer to game-ui-ux-design rather than freezing a generic structure.
3. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
4. Produce the catalog/decision packet and template evidence; do not self-approve, design screens or implement runtime components.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Iteration mode
For early editable screen drafts or an existing screen revision, read [fast iteration](../game-task-planning/references/ui-fast-iteration.md). Preserve role ownership and apply formal approval/readiness gates when promoting a draft or changing runtime.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
