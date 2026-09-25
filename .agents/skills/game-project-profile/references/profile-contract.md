# Profile scope, resolution and checks

## Content boundary

A profile supplies shared settings and precise authoritative references. It does not own installation history, per-task approvals/delegation, supervisor procedures or detailed review reports. For stateful workflows, provide one `workflowRunRegistryPath`; the linked registry and run records own execution state. When the host supports capability-tier dispatch, `modelRoutingProfilePath` may point to the project-owned current tier-to-model mapping; selection policy stays with supervision. Omit irrelevant fields without filling the body with not-applicable explanations. A referenced existing profile can satisfy a setting; "inspect the repository" cannot.

Use short source links beside values. Mark unknown/conflicting/proposed values explicitly and keep current facts separate from desired changes. Preserve existing evidence history when updating; a new profile does not require a dedicated JSON ledger or hashes for every setting. Keep required verification metadata in the existing handoff under the shared artifact contract.

## Resolution

Resolve [document language](artifact-language.md) separately from game locale. Default preferredLanguage is ko; artifactLanguage is only needed for an override. Do not inject these keys into existing UI schemas.

For mixed targets or inheritance, resolve within the domain: authorized work value, target value, referenced defaults. Merge nested objects by field; replace supplied lists. Omission inherits; none means explicitly unused. Screen UI never inherits world camera/physics. Asset and spatial groups defining the same field conflict. Do not invent target IDs/default groups when direct values or existing references suffice. Unknown required values block only dependent work; do not infer physics from a camera.

Reuse an existing UI profile/catalog by exact path without duplicating its declarations or changing approval. Only when an authorized task needs a new UI projection, provide its declared artifactFingerprint, supportedKinds, adapters, evidenceCapabilities, authorityRefs, approvalAuthorities and fallbackOwners with source provenance. Preserve the project's fingerprint convention and validate catalog profileFingerprint with the selected validator. If no convention exists, use sorted compact UTF-8 JSON excluding artifactFingerprint. A changed projection reopens affected approvals; ordinary reference-only profile edits do not.

## Independent verification

Freeze these checks for the requested profile; do not add a new gate or game execution:

- Accuracy: compare relevant values and exact references with current config/locks and documents. Distinguish command existence from execution evidence; state drift or missing evidence honestly.
- Sufficiency: a consumer can obtain applicable environment, target/input, language, workflow registry locator, commands and product/UI references from this profile or its precise links. Omit irrelevant settings; show consequential unknowns rather than inventing them.
- Lookup: locate an implementer's run command, a UI worker's target/profile (if applicable), and a document worker's output language without reading installation or approval procedures. These are bounded reading checks, not a full workflow simulation.

No finding quota, document-size quota or mandatory product tests. The separate verifier returns only supported scoped failures; the author repairs and the verifier rechecks affected criteria within the existing retry budget. Installation/link success alone is not content acceptance.
