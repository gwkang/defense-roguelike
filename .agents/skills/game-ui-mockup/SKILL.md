---
name: game-ui-mockup
description: Create editable exploratory game screens for early feedback, or formal full-screen visual candidates from approved direction and screen specifications.
---

## Role
Choose the exploratory draft path in [fast iteration](../game-task-planning/references/ui-fast-iteration.md) for early screen feedback before style/template approval. Its editable source and scoped draft record are separate from the formal path below. Formal mockups are immutable design evidence from approved direction and screen truth, not runtime screens or implementation shortcuts.

## Formal candidate inputs
- Approved `game-ui-art-direction` and `game-ui-screen-spec` artifacts, including the exact selected visual/motion language or compatible approved reuse.
- The current `game-ui-ux-design` decision, or documented compatible reuse, for player task, scan order, actions and state-specific layout intent.
- The screen specification's persona-derived information priorities and disclosure rules. A mockup must show the primary task clearly; it must not expose every available content field in the default state.
- The screen specification's approved component binding inventory and visible component templates. Compose from compatible approved templates wherever possible; create screen-specific expression only where the binding permits it. For every `reuse:<componentId>@<version>` entry, require its catalog artifact fingerprint, consumer, allowed instance inputs, protected properties, required states, canonical representation, and declared evidence capability.
- Current and superseded references, each labeled by role.
- Representative content, states, target viewports, safe areas, and text-fit cases named by the screen specification.
- The protected content lock, including reproducible locators and hashes for content that must remain exact.
- Provenance requirements, output destination, and requested candidate count. A user-supplied generation-attempt budget is optional.

If an approved input is missing or conflicting, stop and mark it `OPEN` or `BLOCKED`. Do not replace it with placeholders, common layouts, remembered platform conventions, or implementation details.

## Formal candidate work and handoff
1. Confirm UX, style/motion and required component templates are resolved before full-screen composition. Use the UX decision's task and information priority with real content and target scale to decide the layout architecture before writing compositor code or generating a full candidate. Compose with canonical templates; return a missing or incompatible family to game-ui-component-system instead of forcing content into it or drawing an untracked substitute.
2. Represent the persona's primary, secondary, and disclosed information as distinct visual priorities across representative states. Use progressive disclosure, scrolling, or state-specific omission when the screen would otherwise become overloaded; do not remove required content without recording where it is revealed.
3. Before expensive formal rendering, run the bounded [formal-capture preflight](references/formal-capture-preflight.md) and validate its JSON result with the linked script. A preflight is a fail-fast readiness check, not formal coverage or approval evidence.
4. Follow [output and approval rules](references/output-contract.md) for this stage; preserve exact schemas and required coverage.
5. Return immutable candidate hashes and fidelity evidence. Keep DRAFT until exact selection under the shared UI decision rules; never turn a mockup into a runtime texture.

## Verification boundary
Freeze artifact/revision, criteria, target and repair scope. A separate subagent verifies; the author repairs only returned in-scope failures and the verifier rechecks affected criteria. Preserve unaffected valid evidence. Follow the retry budget (default two); block on exhaustion or unavailable independent verification. Defer out-of-scope findings without new work/gates. Supervisors check report scope/evidence; do not create recursive reviewers.

## Iteration mode
For early editable screen drafts or an existing screen revision, read [fast iteration](../game-task-planning/references/ui-fast-iteration.md). Preserve role ownership and apply formal approval/readiness gates when promoting a draft or changing runtime.

## Shared workflow contract
Apply [role, output and language rules](../game-task-planning/references/role-contract.md), including direct calls. Resolve approval/selection through the [shared UI decision rules](../game-task-planning/references/ui-adapter.md); preserve exact UI schemas and independent quality gates.
