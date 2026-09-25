# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

## Evidence contract

For partial revisions, apply [incremental runtime evidence](../../game-task-planning/references/ui-fast-iteration.md#부분-변경의-runtime-증거). Keep all required coverage; only independently substantiated unaffected observations from an accepted baseline may use historical runtime evidence.

Bind every screenshot/video/input trace/log to hash, build fingerprint, environment, target, fixture, coverage ID, font/asset/runtime health and timestamp in a raw manifest. Summaries alone cannot pass.

Use screen-spec IDs and risk-based pairwise coverage: baseline at every target; all primary-action, maximum-stress and target-sensitive cases; every other applicable state at least once. Add combinations only for interactions or found defects, not a full Cartesian product. Use the declared baseline, never an invented `default`.

## Component runtime evidence contract

Emit the exact title once and its header on the immediately following line, without a blank line:

`Component runtime evidence matrix`

Use the exact header once, without outer pipes:

`binding | catalog artifact fingerprint | build fingerprint | consumer | declared adapter | viewport | required state | protected-property evidence | runtime evidence IDs | coverage status`

Index the approved integration matrix by exact header names. Ten-cell rows copy binding, catalog fingerprint, consumer, declared adapter and protected-property evidence verbatim; copy viewport from screen-spec coverage. Insert the frozen current candidate fingerprint, one required state, raw evidence IDs and VERIFIED/OPEN/BLOCKED. This build field identifies the candidate being judged; the linked applicability record distinguishes CURRENT/HISTORICAL_REUSE and preserves each raw capture fingerprint. Keep that record outside matrix cells and do not annotate or replace raw IDs. Adapter comes only from declared adapter, never target/name/inputs. Put observations only in runtime evidence IDs; never replace copied property evidence with observed values, none or missing.

Follow the declared coverage map: baseline at every supported target, other required states at least once at their selected viewports. Add non-baseline targets only for target sensitivity, interacting dimensions or defects. Do not synthesize default states, viewports, prose alternatives or Cartesian coverage. Missing explicit baseline or exact copied/selected values blocks the input.

- `VERIFIED` requires actual runtime evidence for the declared adapter, every protected property, and that required state/target, either captured on the current candidate or independently justified as HISTORICAL_REUSE under the linked incremental rules. Both require a current applicability decision; historical capture identity remains unchanged.
- `OPEN` is limited to optional exploratory coverage outside the required risk-based matrix; it never contributes to downstream readiness.
- `BLOCKED` covers a missing capture, missing state, missing protected-property evidence, unavailable raw evidence ID, unjustified capture/candidate fingerprint difference or stale applicability record, or an observed adapter/identity conflict.

Catalog declarations, implementation tests, static snapshots and matching dimensions are context, not actual runtime evidence for properties/states.

Route missing explicit baseline to `Next route: game-ui-screen-spec`; uncaptured evidence with reproducible unchanged runtime to `Next route: game-ui-runtime-validation`; observed wrong adapter/property/state to `Next route: game-ui-implementation`; identity/adapter/contract/catalog-fingerprint conflicts to `Next route: game-ui-component-system`. Other defects retain their existing upstream owners.

Until every required component row is `VERIFIED`, emit this exact line:

`Blocked downstream: game-ui-acceptance-review`

## Output contract

Return a **runtime validation evidence packet** with:

1. current build lock, build result, and frozen-candidate confirmation; link the per-observation applicability record when reusing historical evidence
2. runtime environment and capture configuration
3. full-screen and focused evidence for every supported target, distinguishing current captures from justified historical reuse; changed compositions need current evidence
4. state/content/target/input coverage matrix with evidence IDs, including the Component runtime evidence matrix
5. shortest/longest text, numeric/data boundaries, fallbacks, and missing assets
6. center/edge input, disabled behavior, conditional controls, focus, and Back/navigation evidence
7. handoff landmark comparison with expected, observed, delta, rejection rule and reference-versus-runtime renderer role
8. full-screen art fidelity by visible family at actual target size
9. logs, errors/warnings, font/asset load, surface size, performance signals, and unwanted scroll/overflow
10. findings with reproduction, expected/actual, severity, owner, and route
11. runtime decision record under the shared UI decision rules, bound to the exact fingerprint and evidence IDs; record pending acceptance honestly, not an automatic user checkpoint

Use project severity definitions when supplied; otherwise: P0 app/data failure, P1 primary or required failure, P2 secondary use or fidelity failure, P3 polish.

## Verification and stop conditions

- Inspect original-detail evidence for clipping, overlap, overflow, edge artifacts, distortion, and safe-area collision.
- Compare approved mockup and runtime side by side for agreed visual properties and hierarchy. When renderers differ, classify expected font/raster/scaling differences separately from actual violations of the handoff; do not require pixel identity unless an explicit same-basis metric and tolerance were approved. Judge motion with actual-runtime timing/state evidence, not a static reference capture.
- For decoded-pixel comparisons, measure the visible color channels explicitly and record the channels and metric. A no-difference bound on a multichannel difference image is not proof of visual identity when an unchanged alpha channel can hide color changes. Evaluate required baseline component properties before expanding state captures; a scoped capture `PASS` cannot clear a failed approved threshold.
- Cover representative actual content, exact live formatting, all input edges, navigation and persistence where applicable. Exercise affected cases on the current candidate; unaffected cases may use only independently justified HISTORICAL_REUSE. The linked record must account for every required case.
- If the candidate build/fingerprint changes, invalidate its applicability decisions and reassess affected coverage under the incremental rules. Preserve historical raw manifests; never rewrite their build identity.
- Stop as blocked when required current observations cannot be reproduced or historical applicability cannot be substantiated for the runtime, fixture, state, target, font, asset or fingerprint. Uncertainty widens current observation; it never removes required coverage.
- Stop after reporting findings and route defects to their owning stage without editing them.

Technical or geometry success does not prove art fidelity. The independent `game-ui-acceptance-review` owns the final UI verdict.

## Coverage map input binding

Read the approved map by named columns and copy exact values. New maps use unique coverage IDs. Explicitly approved shared groups use group ID + declared component/consumer + state as the observation key; attach evidence to each observation. A group screenshot cannot verify every observation. Preserve the component evidence matrix.

Return duplicate keys, conflicting group targets/fixtures, undeclared states/targets, missing required rows/baseline, multiple consumer baselines or incomplete baseline targets to game-ui-screen-spec. Missing executable fixtures block with their owner. Never modify source or substitute data. Different selected viewports require separate observations.