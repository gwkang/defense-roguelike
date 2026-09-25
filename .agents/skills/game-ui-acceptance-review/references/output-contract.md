# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

For partial revisions, independently check the [incremental runtime evidence record](../../game-task-planning/references/ui-fast-iteration.md#부분-변경의-runtime-증거), including accepted baseline, source/dependency/environment/fixture/contract comparison and original raw identities. Unsupported reuse requires current observations, not reduced coverage.

## Component acceptance contract

Emit the exact title once and exact header on the next line without a blank line:

`Component acceptance matrix`

`binding | catalog artifact fingerprint | build fingerprint | consumer | declared adapter | required states | runtime evidence IDs | protected-property verdict | open severity | component verdict`

Ten-cell rows use implementation/runtime matrices indexed by exact headers. Copy binding, catalog fingerprint, consumer, adapter and required states verbatim. Insert the reviewed current candidate fingerprint (the applicability target, not a relabeling of capture builds), raw evidence IDs for every state, current property verdict, severity NONE/P0/P1/P2/P3 and component verdict ACCEPTED/REJECTED. Join evidence IDs only with comma-space (`, `) in required coverage order; append no fingerprint/status/annotation/prose.

- `ACCEPTED` requires CURRENT or independently justified HISTORICAL_REUSE runtime evidence under the linked incremental rules for every required state and protected property, complete required target coverage, no identity conflict, and no open P0/P1/P2.
- `REJECTED` covers missing evidence, stale evidence, conflicting evidence, partial evidence, substitute evidence, a missing required state or protected property, identity mismatch, or any open P0/P1/P2.

Close states, identity and properties per component; screen aggregates cannot substitute. Stale evidence remains stale despite a verified label, PO/asset approval, passing geometry or aggregate logs.

Missing/stale/incomplete runtime evidence → `Next route: game-ui-runtime-validation`; observed current adapter/state/input/property defects → `Next route: game-ui-implementation`; identity/contract/adapter/catalog-fingerprint conflicts → `Next route: game-ui-component-system`. Art defects retain their art owner.

Any REJECTED component requires a standalone `Decision: REJECT UI` line and one rationale on the next line, blocking broader feature review. Never emit `Decision: APPROVE FEATURE`; accepted UI may only route to that separate review.

## Output contract

Return one **UI acceptance report** with:

1. reviewer identity, excluded roles, conflicts, and date
2. current commit/build fingerprint, working-tree state, and evidence applicability; link CURRENT/HISTORICAL_REUSE records without rewriting original raw identities
3. artifact/state/content/target/input evidence sufficiency and gaps, including the Component acceptance matrix
4. visual landmark fidelity for every supported target
5. composed-screen art quality for every visible family and actual representative content
6. exact content, font, data, navigation, availability, persistence, input, and accessibility fidelity
7. runtime quality: clipping, overflow, aspect, edge artifacts, states, hit geometry, logs, font/asset load, and unwanted scroll
8. findings with severity, evidence, requirement, actual, owner, and reopen condition
9. exactly `Decision: APPROVE UI` or `Decision: REJECT UI`, with one rationale
10. next route: broader feature review or the owning upstream stage

Use project severity definitions when supplied; otherwise use the runtime-validation defaults.

Packets with produced/file-backed art require `Decision: APPROVE ASSET QUALITY`; only packets without either may mark asset review NOT APPLICABLE. This waives no packet readiness, rendered fidelity, parity or component runtime evidence.

APPROVE UI requires the applicable asset verdict, passing full-screen art fidelity, complete evidence currently applicable under the incremental rules, a runtime decision for the submitted fingerprint under the shared UI decision rules, verified parity, no open P0/P1/P2 and no unapproved difference. Retain P3 only with authorized acceptance of that exact deviation/fingerprint under the same decision rules. Reject missing/stale/conflicting/partial/substitute evidence.

## Verification and stop conditions

- Recompute the fingerprint and confirm no file changes during review.
- Inspect original-detail runtime evidence beside exact approved composites. Apply the handoff's property-level comparison when the reference and product use different renderers; do not turn pixel differences or capture-tool limitations into defects without a violated approved property. Require actual-runtime evidence for states, input and motion.
- Trace every screen-spec field, state, action, and required target to evidence.
- Reproduce critical/high-risk samples on the current candidate; independently check historical reuse dependencies and widen current observation when uncertain. Reproduce a risk-based sample of boundaries, center/edge inputs, disabled behavior, navigation, persistence, logs, fonts, and assets.
- Reject missing families, craft/style mismatch, stale runtime approval, parity conflict, or approval for another fingerprint.
- Route defects without fixing them and stop after the report.

This is a UI gate, not broader feature approval. Resolve product authority through the shared UI decision rules; approval reuse or delegation never replaces independent evidence review.
