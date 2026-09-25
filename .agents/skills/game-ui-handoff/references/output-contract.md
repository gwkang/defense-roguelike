# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

## Measurement rule

Measure at original resolution. Express each rectangle in source pixels and normalized coordinates `(x/W, y/H, width/W, height/H)`. Label every value `MEASURED`, `DERIVED`, or `OPEN` and cite its source. A derived runtime value includes its formula and assumptions.

Do not invent coordinates, tolerances, font sizes, copy, breakpoints, states, or fit behavior. Visual plausibility is not measurement.

## Component implementation binding

Preserve each binding ID/version/fingerprint, allowed inputs, required states and protected-property evidence. Similar helpers or matching bounds prove reuse only if the same-fingerprint catalog declares that exact target adapter and evidence capability.

Emit this block in order:

`Component implementation binding matrix`

`binding | catalog artifact fingerprint | consumer | implementation target | declared adapter | allowed instance inputs | protected-property evidence | required states | mockup fidelity | handoff status`

One row per binding; list inputs, states and protected properties separately. Carry each mockup locator into its property/state entry and specify the implementation evidence needed to reproduce it.

Copy upstream binding, fingerprint, consumer, allowed inputs and protected-property names/locators verbatim; copy mockup result unchanged to mockup fidelity. Required states come from exact approved catalog state IDs for this binding/fingerprint; represented states are coverage evidence, not IDs. Reject missing/unrepresented states. Preserve reuse: prefixes and IDs; never substitute helpers. Even BLOCKED packets emit title, header and complete binding rows before recovery routes.

Use plain pipe-delimited header/rows: ten cells, nine separators, no outer pipes. Inside cells use commas/semicolons, not pipes. Check cell counts before return.

Use only these handoff statuses:

- `READY` — upstream mockup fidelity is current `MATCH`; the implementation target is the exact catalog-declared adapter for the same identity and fingerprint; every allowed input, protected property, required state, and required implementation-evidence method is explicit.
- `OPEN` — an optional measurement or implementation choice remains unresolved but does not weaken identity, fingerprint, allowed-input, protected-property, or state requirements. Keep the affected downstream input open.
- `BLOCKED` — required identity, fingerprint, implementation target, declared adapter, evidence capability, protected-property evidence, state mapping, or upstream fidelity is missing, stale, conflicting, or broadened. Do not hand off the affected component.

## Output contract

Return one `DRAFT` **UI handoff packet** with:

1. **Source lock** — selected files, hashes, dimensions, states, approvals, exclusions, and source parity.
2. **Region geometry** — hierarchy, rectangles, normalized coordinates, anchors, alignment, spacing, safe areas, and z-order.
3. **Component inventory** — ID, role, source region, intrinsic and visible bounds, pivot, padding, and reuse status.
4. **Component implementation binding matrix** — exact catalog identity, implementation target, allowed variation, protected evidence, state coverage, and readiness.
5. **Asset-versus-live ownership** — raster/vector/code chrome, live text/data, input owner, fallback, and parity row for every element.
6. **Typography and content bounds** — font, text rectangle, alignment, line policy, representative boundaries, and unresolved minimums.
7. **State and interaction coverage** — visual state, transition owner, hit rectangle, semantic label, disabled behavior, and conditional presence.
8. **Responsive transformation rules** — anchors, constraints, fit mode, crop-safe area, and behavior for every approved target.
9. **Acceptance comparison map** — approved landmark, runtime evidence rectangle, allowed difference, and rejection condition.
10. **Open decisions and handoff** — unresolved measurements and separate readiness for `game-ui-asset-production` and `game-ui-implementation`.

All packets, including BLOCKED, retain all ten slots in order. For unavailable evidence, keep the slot with OPEN/BLOCKED and its missing source; matrix/routes alone are insufficient.

Use component rows shaped as `ID | source rect | owner | intrinsic/visible bounds | anchor | fit mode | states | fallback | certainty`.

## Scope and verification

- Keep dynamic content and controls live; never bake them into component art or invisible image hit regions.
- Do not create assets, code, atlases, manifests, or layout modules.
- Do not create, revise, approve, or version a component catalog or mockup fidelity decision from handoff work.
- Do not declare a stretchable region without measured border and corner evidence; distinguish frame bounds from visible bounds.
- Recompute normalized values and require pixel round-trip within an explicitly sourced tolerance.
- Overlay measured rectangles on a copy and inspect at original detail.
- Confirm every screen-spec row has visual, content, input, and state ownership and every protected source retains its approved hash.

Missing/stale/conflicting target, version/fingerprint, adapter, evidence capability or protected-property evidence blocks the row. Return to game-ui-component-system before asset production or implementation.

Use this exact recovery handoff:

`Next route: game-ui-component-system`
`Blocked downstream: game-ui-asset-production, game-ui-implementation`

An absent or non-MATCH upstream fidelity row returns to game-ui-mockup; never repair/reinterpret that decision here.

Resolve visual fidelity authority under the shared UI decision rules; implementation owners may reject infeasible or ambiguous measurements. Stop after the packet and do not begin asset production or implementation.
