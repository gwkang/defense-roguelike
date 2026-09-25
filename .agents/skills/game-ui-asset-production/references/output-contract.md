# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

## Production mode

Choose exactly one handoff-authorized mode:

- `new-production` — create or change raster/vector bytes and record reproducible transforms.
- `verified-reuse-only` — change no asset bytes; every visible family uses an existing runtime asset.
- `no-new-raster` — change no asset bytes; at least one visible family is code-native. Generation, transform, migration, and bundle delta are `NOT APPLICABLE`.

Use image generation only for approved new bitmap work and follow the available tool's rights rules. Produce text-free components, never a full-screen runtime texture. Store editable sources and optimized outputs in project-declared locations.

Make crop/resize/cleanup/pack/compression reproducible with a checked-in script or exact command/config; record input/output hashes. Never crop mockups at runtime, bake live content/semantic labels, or overwrite shared assets without approved consumer migration.

## Component production disposition

Include every reusable handoff binding in the matrix below. Resolve representations only from the same-fingerprint approved catalog; screenshots, similar exports and convenient helpers are not substitutes.

Use catalog `kind` for representation kind, never an implementation target, adapter/class name or component ID. Source representation is the catalog runtime representation: for code-native bindings, its exact declared adapter or implementation source.

### Non-negotiable matrix serialization

Emit the exact title and header below once each, in order before rows; do not rename, annotate or substitute them:

`Component production disposition matrix`

`binding | catalog artifact fingerprint | consumer | representation kind | source representation | production disposition | allowed instance inputs | protected-property evidence | required states | output artifact/evidence`

One row per reusable binding. Copy handoff cells for binding, catalog artifact fingerprint, consumer, allowed instance inputs, protected-property evidence and required states verbatim, without additions. Put adapter/capability/probe annotations and production explanations only in output artifact/evidence. Cell 5 must still contain the catalog-declared representation; its required adapter/source is not an annotation.

Ten-cell order: handoff binding; fingerprint; consumer; catalog kind; catalog runtime representation; disposition; handoff allowed inputs; protected-property evidence; required states; output artifact/evidence. Omit the handoff implementation target; never shift kind or representation.

Before return, check exact title/header occurrence and order, ten cells/nine pipes per row, no outer pipes, verbatim copied cells, required representation in cell 5 and annotations only in cell 10. Correct failures before returning.

Use exactly one production disposition per row:

- `REUSE_CANONICAL` — reuse the exact approved raster, vector, mixed, or other file-backed representation; any deterministic packaging stays source-linked to that representation and does not create a new component identity or version.
- `ASSET_NOT_REQUIRED` — the approved representation is code-native or a native widget and needs no produced asset bytes. Emit `production-asset-not-required`, name the catalog-declared adapter and evidence capability, and do not create a bitmap, raster export, placeholder, or atlas entry merely to produce an asset.
- `NEW_PRODUCTION` — create bytes only when the current catalog identity, handoff, and approval authorize that representation and every protected property and required state remains covered.
- `BLOCKED` — identity, fingerprint, representation kind, source representation, adapter, evidence capability, protected-property coverage, or required state is missing, stale, conflicting, or broadened.

Atlas slices, optimized exports and packages are adapter artifacts only for approved file-backed sources, never code-native/native-widget sources. Record exact source representation, deterministic transform, output hash, consumers and state mapping. Do not change component identity/version, inputs, protected properties or states.

If a proposed asset changes the approved representation, component identity/version, allowed inputs, protected properties, or required states, reject it from the current binding and use:

`Next route: game-ui-component-system`

If the canonical representation remains valid, preserve its REUSE_CANONICAL or ASSET_NOT_REQUIRED path and return only the rejected proposal. Otherwise mark the row BLOCKED and emit:

`Blocked downstream: game-ui-implementation`

If the handoff row is absent, not `READY`, or bound to a different catalog fingerprint, use `Next route: game-ui-handoff` and block implementation. Asset production does not repair catalog or handoff decisions.

After the matrix, report these two scopes separately:

- `Binding downstream: READY_FOR_IMPLEMENTATION` when the row is `REUSE_CANONICAL`, `ASSET_NOT_REQUIRED` with its exact declared source and isolated target-size component parity verified, or `NEW_PRODUCTION` with complete output hashes, protected-property and required-state evidence, source parity, and required independent asset review. Otherwise emit `Binding downstream: BLOCKED` and name the unfinished production evidence.
- `Packet downstream: READY_FOR_IMPLEMENTATION` only when every visible art family and source-parity gate is ready and an independent approved verdict covers every produced or file-backed art family. The independent-verdict requirement is `NOT APPLICABLE` only when the packet has no produced or file-backed art. Otherwise emit `Packet downstream: BLOCKED` and name the missing packet evidence or verdict.

Packet downstream is always READY_FOR_IMPLEMENTATION or BLOCKED, never NOT APPLICABLE. For ASSET_NOT_REQUIRED, only the binding art-review field may be NOT APPLICABLE; packet/visible-family evidence remains required. Before integration, code-native/native-widget parity is the declared source in an isolated target-size component fixture covering its protected properties and required states. Whole composed-screen and interactive fidelity are runtime-validation and acceptance obligations after integration, not packet prerequisites.

A ready binding cannot bypass a blocked packet. For `ASSET_NOT_REQUIRED` only, the game-ui-implementation owner may prepare the exact catalog-declared code-native/native-widget runtime source and an isolated target-size component render fixture before packet readiness, solely to supply source-parity evidence. Asset production checks that evidence against the approved handoff, catalog source and intended runtime consumer; absent, stale or mismatched source/render keeps the binding or packet `BLOCKED`. This preparation is not full screen integration and cannot set the implementation matrix `READY`. Resolve in order: `bounded runtime-source preparation when needed -> packet evidence and required review -> full implementation -> runtime validation`.

Binding disposition must not require post-implementation runtime evidence. Carry states/evidence locators forward as runtime-validation obligations.

## Fidelity and source parity

Inventory every visible art family as `new production`, `verified reuse`, or `missing`. File-backed reuse requires target-size composed-screen evidence against the approved mockup using the intended runtime bytes; technical validity or zero byte cost is insufficient. For code-native/native-widget families, verify the declared source and isolated component fixture before integration and carry whole-screen composition to runtime validation. For file-backed pre-integration composition, compare material, contour, lighting, perspective, detail density, color harmony and optical weight across the visible families available in that composition. Judge code-native cross-family composition in the integrated runtime and acceptance review; isolated protected-property/state parity remains required before packet readiness.

For each family, record classification, runtime destination/current source hash, mockup/QA input/hash, candidate output, consumer and provenance. Reuse evidence must read exact runtime bytes; new-production evidence must read the exact candidate destined there. Any disagreement blocks readiness.

## Output contract

Return a `DRAFT` **asset-readiness packet** with:

1. source lock, rights, dimensions, hashes, and exclusions
2. asset manifest: stable ID, file, consumer, slot, state, format, and fallback
3. component production disposition matrix plus fidelity coverage for every visible family and its parity row
4. generation record, or `NOT APPLICABLE`
5. deterministic transform and hash procedure, or `NOT APPLICABLE`
6. intrinsic/visible bounds, padding, pivot, crop safety, stretch region, and fit mode
7. isolated-pixel and, for file-backed art, composed-screen visual QA; code-native whole-screen fidelity remains a runtime obligation
8. per-file and total bundle impact against the approved budget
9. provenance record in the project-owned registry
10. open defects and reviewed inputs for `game-ui-implementation`

Use REVIEW_READY only after reproducibility and visual QA pass. Independent art-asset-review owns produced/file-backed art quality; ASSET_NOT_REQUIRED bindings mark it NOT APPLICABLE but retain catalog evidence and later runtime/UI fidelity checks.

## Scope and verification

- Do not change content, live typography, input, layout, or scene code.
- Do not redesign the approved mockup or delete superseded assets; migration owns cleanup.
- Regenerate changed outputs and compare hashes; in reuse modes recompute runtime hashes without inventing production work.
- Inspect file-backed original pixels and target-size composites over relevant backgrounds at every supported target; inspect code-native source and isolated target-size fixture for declared protected properties and states.
- Verify alpha/edge artifacts, aspect, padding, pivot, state distinction, text clearance, frame isolation, and source parity.
- Require independent asset review before implementation for produced or file-backed art; record it `NOT APPLICABLE` for `ASSET_NOT_REQUIRED` bindings.

Block missing rights/source/measurement/slot/consumer fields required by the selected representation; do not invent asset-only fields for ASSET_NOT_REQUIRED. Missing visible families, unproven reuse, production-byte mismatch or style mismatch block implementation.
