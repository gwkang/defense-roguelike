# Sample library: reuse before generation

1. Preserve a compatible existing user selection with its exact identity. Otherwise read `assets/sample-library/manifest.json` from this skill and find matching kinds, events and unresolved axes **before producing samples**. Present suitable prebuilt samples first. If they suffice, generate no new sample images, code or captures merely because the project is new.
2. Record sampleId/version, source fingerprint, preview path/selector and fit/limits in the option map. A single page may contain separately identifiable/replayable choices; independent choice does not require separate HTML files. Keep the user's requested presentation format.
3. For a mismatch, record requested type → searched IDs → missing capability → smallest project-local addition. Use declared overrides only within limits, recording base identity + overrides; the immutable seed has no runtime override interface. Do not edit an installed/shared library from a project task.
4. Independently review the local addition's visual/motion quality, rights and portability. The common-source owner may then add it once under a new immutable version. Recolors or renames alone do not justify duplicates. A library version changes the inventory; an entry version changes its source. Existing selections keep their prior source identity.

## Meaning and fit
Library-ready/source-reviewed means available for comparison, not user-selected, template-approved, project-approved or released. A generic motion square proves a movement language only: actual project content, fonts, supported languages, density, states and accessibility still need their bounded project checks. Missing project fit must not trigger recreation of already sufficient motion examples. After authorized selection, investigate compatible templates and add only missing coverage.

The initial square/no-particle/ten-option/one-page presentation is this seed's metadata, not a universal rule. Other kinds and viewing conditions may be added when needed. Optional user reference URLs and focused revisions remain supported by the independent-sample guide.

## Manifest and validation
Root `assets/sample-library/manifest.json`: schemaVersion 1, libraryId, libraryVersion, entries. Each entry has sampleId/version/kind/tags/description, previewPath/candidateSelector, sourceFiles (root-relative path→SHA256), dependencies, comparisonConditions, editableParameters/limits, provenance, rights and verification. `verification.sourceFingerprint` is SHA256 of sourceFiles JSON sorted by key with compact separators. The source closure may be shared among entries. The manifest itself is locked by bundle.lock, not self-hashed.

Use `python -B scripts/validate_sample_library.py` (optional root argument). It verifies identities, containment/link rejection, hashes, declared local references, rights and independent source-review identity. It cannot replace actual playback or legal/project judgment. New or changed sources require current independent evidence before selectable library entry status. User selection records stay in the project, never fabricated in the library.

## Portable seed
The library contains two immutable motion source families. `square-motion/1.0.0` uses five runtime files; `playful-ui-motion/1.0.0` uses three code-native HTML/CSS/JavaScript files and exposes mechanical, elastic and sticker selectors on one comparison page. Serve a version directory using any local static server. No build step, framework, network, packaged font or game dependency is required. Provenance contains original source and review hashes; permissions cover owner-authorized workflow reuse, not a new public license or publication action.

## Supported sample kinds

`motion` uses its exact figure[data-motion] selector and playable evidence. The playful motion seed covers button, item and status roles across idle, hover, press, item-event, success and reduced-motion states; it remains a comparison source rather than a product component. `button-shape` uses an exact #Bnn figure selector and static SVG evidence with equivalent label/size/viewport/font conditions; no cycle or new motion language is required. Four button shapes in 1.1.0 are a seed, not a universal four-option requirement. Their six unchanged HTML/CSS/SVG runtime files use installed Malgun Gothic by name, never a bundled font. Other OS typography and held-press intermediate frames remain unverified. Existing sample identities remain unchanged.
