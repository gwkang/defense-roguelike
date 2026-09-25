# Output and acceptance rules

Before each stage, read its rules below. Exact headers, tables, approvals and recovery routes are binding.

## Authority order

Resolve conflicts in this order and record the result:

1. current user decisions that explicitly revise earlier direction
2. authoritative product and design requirements
3. current approved screen-specific direction
4. shared visual language from current canonical references
5. runtime implementation, used only to inventory the present state and defects

References may supply visual language without prescribing layout/content. Exclude superseded sources.

## Output contract

Return one concise **Art-direction brief** with these slots, in order:

1. **Authority ledger** — current, supporting, superseded, `OPEN`, and `BLOCKED` sources.
2. **Visual thesis** — the intended player impression in one sentence, or `BLOCKED` when authority is insufficient.
3. **Shared visual language** — palette roles, materials, contour, lighting, typography, icons, and depth supported by current sources.
4. **Component-family decisions** — for every repeated visible family, record exactly `reuse:<componentId>@<version>`, `screen-specific-exception`, `new-family-required`, or `BLOCKED`, with its authority. Similarity alone never establishes reuse.
5. **Screen-specific expression** — qualitative hierarchy, mood, density, and distinction.
6. **Protected invariants** — supplied content, data, navigation, interaction, font, accessibility, and gameplay facts.
7. **Anti-goals** — concrete inconsistent or unreadable outcomes.
8. **Style and motion options** — exact selected existing style/template identity when reused; otherwise first record matching prebuilt [library](sample-library.md) sample IDs/versions/source fingerprints and fit; create only missing project-local options. Return an option map organized by functionally required component family and unresolved consequential choice: family ID, independently versioned form/style and motion candidate IDs, what changes, constraints/tradeoffs, representative sample paths, playback method, and source/tool provenance. Give at least two materially distinct feasible options per such choice, using the same representative content, states, scale and viewing conditions. Cover the visual families and motion events that determine the intended experience, not only an isolated decorative detail. Playable motion must show timing, impact and recovery where relevant; static frames alone do not prove animation. For each applicable style within a family, provide its playable motion sample or an explicit source-backed no-motion reason; one global motion reel does not cover unrepresented family/style pairs. Resolve relevant independent axes from project inputs, such as form, depth, corner treatment, text density, label/supporting-description visibility, actual font candidates and motion. Offer enough materially distinct choices for each unresolved consequential axis; do not default to minimal text or one font, and do not require an exhaustive Cartesian product. Render actual candidate fonts rather than naming them or simulating their appearance. Record font source, availability, usage constraints and supported-language coverage; unsupported glyphs or undocumented fallback cannot prove that font option. These axes are examples, not a mandatory universal family or variant list. Keep family, form/style and motion choices separately identifiable and independently revisable. Record selected, rejected and unresolved choices per family and show compatibility between proposed combinations. Combined boards are optional supporting context, never a prerequisite or substitute for isolated family comparison.
   Include an optional reference-URL input in both the option map and user-facing selection prompt, with scope (shared visual language, family, variation axis or motion event), elements to study and elements to avoid. Keep a reference record per supplied URL: source, access/observation status, observed evidence, usage/licensing and replication boundaries, affected candidate IDs, and used/not-used disposition with reason. No URL is required; record none supplied without treating it as a missing prerequisite. Follow the [optional reference procedure](independent-samples.md#optional-reference-links).
9. **Open decisions and handoff** — unresolved choices, exact selected sample identities and decision authority, and the inputs needed by `game-ui-component-system`, `game-ui-screen-spec`, and `game-ui-mockup`.

## Independent sample production

For unresolved choices, inspect the [sample library](sample-library.md) first. Sufficient prebuilt options require no regeneration; record searched IDs and the gap before minimal project-local additions. Then apply [Independent sample guide](independent-samples.md). Give each family/form or motion-event candidate its own ID, revision and independently inspectable/replayable artifact or selector in a shared page. Shared rendering code is allowed; a combined screen or global style switch is not the sole evidence unit. Separate editable variation axes so a request about one family, contour, font or event can be repaired without redesigning unrelated choices. Motion alternatives must differ in movement language appropriate to the event, not only playback speed. Inspect the resulting form and motion differences before asking for selection; expand insufficient options within the affected axis rather than enumerating a Cartesian product. Record cross-family visual compatibility separately without requiring a full-screen composition before individual choices. Samples remain selection evidence and cannot become design templates before their authorized selection.

## Scope boundary

- Exploratory style frames and playable motion samples may use an appropriate image, vector, code-native, or animation tool. They are selection evidence, not production assets, runtime layout, or final-screen mockups. Do not generate bitmap art merely to fill a slot.
- Invent no product meaning, data, controls, states, navigation or accessibility policy; specify no final-screen pixel geometry, production asset manifests, test matrices or runtime verdicts. Font and text-density variants are exploratory choices, not changes to the approved product content or typography. Use source-backed representative wording for each project-supported language. Less visible text must preserve the action meaning, units, status, error cause and access to necessary labels or descriptions through the existing supported keyboard/accessibility paths. Do not substitute ambiguous icons or invent hidden interactions to achieve minimalism; return incompatible reductions to the content/input owner.
- Classify family needs and route to game-ui-component-system; do not create/revise/approve catalogs.
- Stop at this brief; do not perform mockup, asset production, implementation or runtime validation in the same response.

## Verification and approval

- Confirm every cited source exists or is explicitly marked `OPEN` or `BLOCKED`. For supplied URLs, confirm actual observation or a documented access limitation, separate observation from reuse permission, and check that non-use reasons and affected choices are recorded. A reference link alone cannot approve its design, wording or functionality.
- Confirm every output slot is present and each factual statement traces to a listed authority.
- If style or motion is unresolved, inspect samples at their intended viewing size and play the motion examples. Check the option map against every unresolved consequential style/motion decision, inspect every sample at its intended viewing size, and verify alternatives are meaningfully distinguishable beyond cosmetic recolors. Verify that each required family can be inspected, replayed where applicable, selected and returned for revision without selecting or remaking unrelated families. Check family-by-style motion coverage and language-by-font/text-density coverage. Inspect actual wording, glyph coverage/fallback, expansion and shortening, wrapping/clipping, layout and state distinction at the intended size for every supported language relevant to the decision. Compare equivalent functional meaning across density options, including labels, supporting descriptions and error causes; an unreadable or inaccessible reduction is not a feasible choice. Preserve valid choices for unaffected families and axes. A bundle-only choice or mandatory combined scene fails this requirement. If the samples do not let the decision-maker judge the important visual or motion differences, add or repair the affected family samples before requesting a choice. If a compatible selected style already exists, record its identity and why it applies instead of making redundant samples.
- Confirm no component catalog/template, final-screen mockup, or product artifact was produced.
- Keep the brief `DRAFT` until its decision is resolved under the shared UI decision rules. Cite applicable approval reuse or authorized delegation; superseded references and author preference are not approval.

Stop at the draft or selected direction. Route new-family-required/BLOCKED families to game-ui-component-system before reuse claims. An unselected style or motion sample cannot authorize a new appearance template. If authority cannot support the visual thesis, request only the necessary product decision/source.