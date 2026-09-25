# Output and acceptance rules

The rules below apply to formal mockup candidates. Exploratory editable screens use the separate draft record and limits in [fast iteration](../../game-task-planning/references/ui-fast-iteration.md); Review-only compositor/layout source may be created or edited for both exploratory and formal candidates; preserve approved snapshots and freeze each new formal composite from its source revision. Drafts cannot satisfy formal approval, fidelity or readiness. For formal candidates, exact headers, tables, approvals and recovery routes remain binding.

## Tool routing

Use an available image tool only for bitmap generation/editing required by approved direction. Inspect references first; follow tool rights/editing rules.

If existing assets/code-native primitives suffice for the already selected style and component templates, record `concept-not-required` and make deterministic production-representative composites only. This flag only omits new bitmap concept generation at the mockup stage; it never waives unresolved style/motion selection or missing visible component templates. Do not generate to fill a slot.

The formal candidate contract is not reduced by preflight. Smoke captures are non-retained readiness evidence only; the packet must still contain exactly the requested candidates, every named target viewport and all required coverage rows.

## Candidate contract

Produce two distinct artifact types when generation is required:

- **Concept candidate** — retained output bytes used to evaluate visual treatment. Generated text, data, icons, or protected content are illustrative and never source-parity evidence.
- **Production-representative composite** — deterministic composition of approved visual treatment, exact protected bytes, and exact rendered live content. Record the compositor or reproducible procedure, inputs, output dimensions, and hash.

Only a production-representative composite can receive mockup approval or enter downstream evidence.

### Component reuse fidelity

Preserve bound catalog identity/version, reusable template source identity, visible appearance, protected properties and required states. Reuse templates for each compatible family and vary only approved screen-owned inputs and placement. Record every screen-specific exception; do not redraw a reusable control for convenience.

Generated appearance may explore surroundings but never proves reuse or replaces, retouches, averages or approximates the canonical component. Helpers, screenshots and visual matches count only when the same-fingerprint catalog declares that evidence capability.

### Composition before full capture

Before composing, make a compact layout decision for each materially different content/layout family: use the current UX decision's immediate task and scan order, the densest sourced content/actions, the available target space, and the chosen grouping, control placement and overflow behavior. Use selected style and canonical templates, not generic screen symmetry or whichever container is easiest to implement. Compare any available current or approved screen at a matching target/state as a regression reference, while treating its defects as evidence rather than requirements. If the arrangement is not determined by approved references and materially different structures are plausible, compare lightweight layouts against task clarity, content fit and target scale; choose one and record the reason without creating extra formal candidates. If the chosen structure needs a component capability that is absent, return it to its owner before composition; if it changes the approved UX hierarchy, return to game-ui-ux-design.

Run the required [formal-capture preflight](formal-capture-preflight.md) before producing retained formal composites; its smoke outputs remain readiness-only evidence. Arrange content and actions in a readable settled state first; motion and decorative space must not determine the panel size or hide the primary task. Render and inspect one representative full-screen composite per such family at original size before producing the remaining state/target coverage. If its hierarchy, legibility, spacing, or task affordances are materially weak, revise that composition within the approved inputs or return the conflicting constraint to its owner before batch capture. This author inspection prepares, but never replaces, independent verification or selection.

For each candidate packet, emit this block in order:

`Component reuse-fidelity matrix`

`binding | catalog artifact fingerprint | consumer | represented states | allowed instance inputs | protected-property evidence | result`

One row per binding. represented states lists every required state and representation status. protected-property evidence lists each property with a locator or explicit missing/drift status; never summarize untouched/unavailable properties away.

Use only these results:

- `MATCH` — the exact bound identity and fingerprint are current, every required represented state is visible, all protected properties have declared reproducible evidence, and only allowed instance inputs vary.
- `DRIFT` — evidence exists but a protected property, state, identity, fingerprint, or allowed-input boundary differs. Reject that composite.
- `BLOCKED` — required binding, fingerprint, canonical representation, state, evidence capability, or protected-property evidence is absent, stale, or conflicting. Do not claim fidelity or select the composite.

- Build prompts and compositions only from approved inputs; label each reference as composition, style, subject, or edit target.
- Produce exactly the requested candidate count and every target viewport named by the screen specification. Do not infer one target from another.
- Show one identified representative state per image. A candidate does not prove states it does not show.
- For each content-bearing overlay or other transient surface, retain a readable settled-state composite for every target needed to judge its content and controls. Capture entrance, exit, translucency, and reduced-motion states separately when required; none substitutes for the settled-state content/layout check.
- Use exact approved copy, symbols, data formats, controls, and protected content. Reject corrupt or substituted content instead of calling it illustrative.
- Preserve approved hierarchy, safe-area intent, responsive regions, and live-content space; record every departure.
- Keep retained concept bytes unchanged. Save deterministic composites separately with stable versioned names; never overwrite an approved reference.
- Record prompt, tool and mode, reference roles, generation identifier when available, dimensions, hashes, transformations, target screen and state, rights, and current/superseded status.
- Follow the supplied attempt budget. If none exists, stop after three failed attempts for one requested candidate and target, recording rejected hashes and the unresolved visual region.

## Output contract

Return one **Mockup candidate packet** containing:

1. concept path or `concept-not-required`, plus production-representative composite paths and previews
2. exact prompt or deterministic composition procedure, with reference roles and the concise pre-composition layout decision for each materially different family
3. screen-spec compliance matrix mapping each required region, content family, and represented state to visible evidence
4. component reuse-fidelity matrix for every reusable binding
5. observed defects, rejected candidates, and intentional differences
   - For a revision of an existing screen, include a same-target, same-content/state comparison with the available current or approved reference for layout, readability, hierarchy, and interaction affordances. Label the reference's authority and limitations; an old implementation is evidence, not automatic design authority. Explain any material regression or approved departure instead of silently passing it.
6. provenance, hashes, and current/superseded status
7. selection record under the shared UI decision rules; include a question only for a remaining required user decision

## Scope boundary

- Do not load a full-screen mockup as a runtime texture or production atlas.
- Do not create production assets, manifests, product scene/input/layout code, or invisible runtime input regions. Review-only compositor/layout source is allowed; it is not a product implementation or a replacement for formal candidate requirements.
- Do not continue into handoff, asset production, implementation, runtime validation, or approval review.
- Do not create, revise, approve, or version a component catalog from mockup work.
- Do not treat visual similarity, generation success, or the author's preference as approval.

## Verification and approval

- Inspect every retained image at original detail; verify dimensions, hashes, crop safety, text, data, controls, protected-content parity, and visible template reuse. Compare the composed hierarchy and motion evidence with the selected style; technical fidelity alone is not a visual-quality verdict.
- Judge settled-state legibility and visual hierarchy separately from counts and clipping: inspect whether content, controls, empty space, backdrop visibility, and target-specific scale support the intended task. Record an evidence-linked finding or an explicit no-finding verdict for each affected surface. If a material visual regression is unexplained, keep the candidate `DRAFT` and not selectable even when all technical probes pass; return structural incompatibility to game-ui-component-system and screen-owned layout/content conflicts to game-ui-screen-spec.
- Reproduce deterministic composites and require identical output hashes.
- Trace every visible requirement to the approved screen specification; there must be no orphan content or controls.
- Keep every candidate `DRAFT` until its exact composite hashes have a resolved selection under the shared UI decision rules.

Missing/stale/conflicting binding, fingerprint, canonical representation, required state, capability or property evidence makes the row BLOCKED. Return to game-ui-component-system before handoff.

Use this exact recovery handoff:

`Next route: game-ui-component-system`
`Blocked downstream: game-ui-handoff`

Stop after the packet. Only production-representative composites selected under the shared UI decision rules enter game-ui-handoff.
