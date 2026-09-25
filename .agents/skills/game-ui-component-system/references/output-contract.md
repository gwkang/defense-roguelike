# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

## Decision rule

Classify every repeated family as exactly one of:

| Decision | Use when |
|---|---|
| `reuse:<componentId>@<version>` | An approved entry covers the consumer, state, adapter, and evidence capability. |
| `screen-specific-exception` | Current authority requires a deliberate non-shared expression and records its scope. |
| `new-family-required` | No approved entry covers the requested structure or protected appearance. |
| `BLOCKED` | Authority, capability, compatibility, or approval evidence is missing or conflicting. |

Similarity, majority usage, averaged values, shared primitives or partial evidence never establish reuse.

## Output contract

Produce one concise **Component catalog decision** containing:

1. **Authority ledger** — current, supporting, superseded, conflicting, `OPEN`, and `BLOCKED` sources.
2. **Family inventory** — proposed stable ID, semantic version, representation kind, variants, consumers, exceptions, and reuse/add/revision disposition. Inventory actual needs such as buttons, frames, labels, banners or dialogs; do not create unused families to complete a generic list.
3. **Contract** — structure, allowed instance inputs, protected properties, states, and accessibility invariants. For a new or revised content-bearing family, state the consumer task, why the chosen grouping and control hierarchy fit its representative content/actions, and which materially different use needs a separate variant or family. Choose this structure before committing to reusable source; do not generalize a convenient short example into a dense consumer.
4. **Adapter binding** — the project-declared implementation adapter and fallback owner.
5. **Component template evidence** — exact selected form/style and motion identities for each required family, including selected typography, text-density/disclosure and motion variants plus supported-language evidence and any recorded cross-family compatibility constraints; do not flatten partial selections into a globally approved style or silently restore unselected font/density defaults. Investigate compatible existing templates per family and add or revise only missing or incompatible coverage. For each required family, a compatible approved template locator and fingerprint or a new reusable design source plus preview covering required states and motion where relevant. Record the source fingerprint, allowed instance inputs and how a downstream screen reproduces each state. Show new component examples before freezing protected appearance. A screenshot or catalog description alone is not a reusable template.
6. **Evidence map** — declared capabilities, protected-property coverage, landmarks or probes, and project-owned tolerances.
7. **Compatibility** — covered presentation roles, consumers, and explicit incompatibilities. For each claimed consumer, compare the template's actual structure and allowed inputs with that consumer's sourced content/action boundaries and required steady state at the declared target sizes. Use a reproducible representative instance when content length, action count, wrapping, scrolling, or fixed controls can change the layout. A generic short example does not establish coverage for a materially different consumer. If the required boundary is unknown, leave that consumer `OPEN`; if the template cannot represent it, classify it `new-family-required` or `BLOCKED` rather than approving reuse. Screen-owned placement remains with game-ui-screen-spec.
8. **Decision and approval** — one classification per family plus the exact artifact fingerprint and approval status.
9. **Next route** — the smallest upstream decision or downstream owner allowed to proceed.

Use [the catalog schema](component-catalog.schema.json) for machine-readable catalogs. Run `scripts/validate_component_catalog.py CATALOG.json PROFILE.json` to check profile, evidence coverage, identity and approval invariants across fields.

## Scope boundary

- Do not design screen composition, invent product content, measure an unapproved reference, produce production assets, or implement runtime components. Component design templates are review evidence, not runtime assets.
- Do not convert a conflicting family into a new standard by averaging values.
- Do not approve the catalog you authored or treat approval of one version as approval of another.
- Do not claim visual fidelity from evidence that fails to cover every protected property and required state.

## Verification and stop conditions

Require source-ledger traceability for each value, an evidence capability for every protected property and approval matching the exact catalog fingerprint. Inspect every new or revised template at usable size, including relevant states and playable motion, and compare it with the selected style. Reproduce at least one instance from its declared source and allowed inputs; a preview without working reusable source is incomplete. For content-bearing or multi-action variants, inspect a readable settled instance at the consumer's stress boundary as well as motion evidence; transition frames alone cannot prove usable steady-state hierarchy. Missing selected style, required template evidence, authority, capability, compatibility or approval blocks formal downstream screen composition; it does not block the explicitly unapproved draft path in [fast iteration](../../game-task-planning/references/ui-fast-iteration.md). After approval, route measurements to handoff, applicable representation readiness to asset production, integration to implementation, and observed drift to runtime validation/independent acceptance.

## Common mistakes

- A shared low-level helper is not an approved component family.
- A new label or callback may be an allowed input; a new material treatment is a protected-property change.
- Lack of raster evidence does not block a project whose declared hierarchy, vector, command-trace, or native evidence covers the contract.
