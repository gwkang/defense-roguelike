# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

For preliminary content/target/state work, use [fast iteration](../../game-task-planning/references/ui-fast-iteration.md). Keep the existing specification slots and unknowns; the blocking routes below prevent formal candidates, not a scoped exploratory draft. The screen-spec author still does not produce the screen.

## Source and certainty rule

For every requirement, record its source and one certainty:

- `REQUIRED` — stated by a current authority.
- `DERIVED` — calculated from cited evidence; include the derivation and assumptions.
- `OPEN` — not yet authorized or measurable.

Authority: product owns content/behavior; UX design owns the resolved player task flow, information/interaction hierarchy and layout intent; art direction owns selected visual and motion language; catalog and its visible templates own reusable identity/version, protected properties, states and allowed inputs. Screen-spec owns authorized consumer content/actions/exact placement/responsiveness. Runtime/captures evidence current behavior, not permission to preserve defects. Baked text/numbers/icons are illustrative unless another authority makes them exact.

A state/control name alone does not authorize transitions, side effects, scope, timing or recovery. Keep unspecified fields OPEN.

## Output contract

Return one `DRAFT` **Screen specification** with these slots:

1. **Source ledger** — current authorities, including UX decision identity/revision or compatible approved reuse, conflicts, superseded material, missing inputs, and certainty labels.
2. **Protected content lock** — assets, fonts, icons, copy, data families, and behavior that must survive unchanged. Use reproducible locators and hashes when available; use canonical owners and format contracts for live content.
3. **Component binding inventory** — for every repeated family, record exactly `reuse:<componentId>@<version>`, `screen-specific-exception`, `new-family-required`, or `BLOCKED`; include the catalog artifact fingerprint, consumer, allowed instance inputs, inherited protected properties and required states, and the screen-owned rules. Compare each screen-owned content/action boundary and required behavior with the canonical template's actual structure and allowed inputs, not just catalog metadata. A helper name or visual similarity is not a binding. If the screen requires a fixed control, scrolling content, or an action layout the template cannot produce, return the binding to game-ui-component-system instead of declaring reuse ready.
4. **Content inventory** — each visible label and live field, its source, format, valid boundary, fallback, and certainty.
5. **Action and navigation inventory** — each control, availability rule, destination or effect, persistence boundary, and certainty.
6. **State matrix** — every authorized state and explicitly sourced transition; keep unspecified transitions, effects, timing, and state scope `OPEN`, and mark unsupported or non-applicable states explicitly.
7. **Responsive region contract** — the player's primary task and scan priority in each materially different state, then ordered regions, containment, target-specific behavior, safe areas, and evidence-based dimensions. For content-dense surfaces, state which content remains immediately visible, which area may grow or scroll, how actions stay reachable, and what visual space is intentionally reserved. Derive any hard dimensions from approved references or measured constraints; leave unresolved geometry open rather than filling it with arbitrary canvas space.
8. **Text-fit matrix** — approved fonts and fallbacks, representative shortest and longest strings for every supported locale, numeric boundaries, wrapping or scaling policy, and owned bounds.
9. **Accessibility and input contract** — authorized non-color identities, reduced-effects behavior, semantic labels, focus and Back behavior, and hit-area requirements.
10. **Open decisions and handoff** — when any binding is unresolved, start with exactly `Next route: game-ui-component-system` and then `Blocked downstream: game-ui-mockup`; otherwise start with exactly `Next route: game-ui-mockup`. Then list unresolved choices and the exact approved inputs that route needs.

Use this row shape for inventories: `ID | visible content or action | source | states | responsive rule | certainty`.

## Scope boundary

- Do not generate or outline a mockup.
- Do not create assets, write image-generation prompts, or write implementation code.
- Do not turn current coordinates or common platform values into requirements without cited authority or measurement.
- Do not invent copy, currency, prices, controls, states, breakpoints, geometry, fonts, limits, or accessibility thresholds.
- Do not omit conditional content merely because it is absent from one capture.
- Do not create, revise, approve, or version a component catalog. Do not turn screen-owned labels, callbacks, or placement into permission to override catalog-owned protected properties or required states.

## Verification and approval

- When a project uses hashed approval snapshots, bind a screen-spec decision to its design authorities and protected reference content. Keep implementation sources, tests, capture artifacts, and build outputs in a separate runtime lock; later code edits do not retroactively erase an unchanged design approval. Check changed design authorities for relevance rather than silently carrying a stale decision forward.
- Trace every visible field, action, state, and responsive rule to the source ledger; there must be no orphan requirements.
- Exercise authorized content boundaries and supported locales without substituting invented examples for missing data.
- Confirm every cited locator exists or is explicitly `OPEN` or `BLOCKED`.
- Confirm every reuse binding matches the exact approved catalog artifact fingerprint and uses only declared instance inputs, consumers, and required states.
- Confirm the screen's scan priority, action path, feedback and recovery match the resolved UX decision. Return a change of UX hierarchy to game-ui-ux-design; do not silently rewrite it as an exact-placement detail.
- For layout-sensitive bindings, verify that the template can present the longest sourced content and full action set under the stated target/responsive rules. A claim such as wrapping, scrolling, fixed chrome, or grid arrangement needs an actual compatible template mechanism or stays `BLOCKED`; do not infer it from an approved consumer name. Current runtime geometry is comparison evidence, not automatically a requirement.
- Confirm every output slot is present and no downstream artifact was produced.
- Keep the specification `DRAFT` until its decision is resolved under the shared UI decision rules. Art-direction or mockup approval alone does not approve this contract.

Conflicting authorities or missing required product values need a product decision. Missing/stale/conflicting selected style or motion returns to game-ui-art-direction. Missing/stale/conflicting component templates or catalog decisions/fingerprints, or uncovered consumers/inputs/property changes/states, return to game-ui-component-system before mockup. Stop after the draft; only resolved, approved inputs enter the formal game-ui-mockup candidate path.

## Runtime coverage map contract

Own the runtime coverage map; include it with state/target specifications without replacing existing slots or approvals.

Emit `Runtime coverage map` and the plain pipe-delimited header:

`coverage ID | consumer | state | viewport | fixture | interaction | reason | baseline`

Each row: unique stable ID, declared consumer, exact state/viewport, authorized reproducible fixture, interaction/observation, selection reason, baseline YES/NO. Exactly one baseline state per consumer covers every supported viewport. Cover other required states at least once, all primary actions/content stress boundaries, and extra targets for state/target interactions. No invented defaults or unrequired Cartesian products.

Trace values to current sources; required unknowns stay OPEN/BLOCKED. Runtime validation cannot substitute targets, fixtures or baselines. Map changes reopen affected evidence/approvals under the existing contract.

For existing approved shared-capture maps, retain group IDs and use group ID + declared component/consumer + state as a unique observation key. A group shares target/fixture, but each observation needs its own verdict. Never reinterpret an unapproved map or default new maps to grouped IDs.
