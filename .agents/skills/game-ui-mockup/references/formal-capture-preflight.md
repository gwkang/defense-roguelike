# Formal capture preflight

Use this preflight immediately before formal production-representative composition. It reduces wasted renderer runs without weakening the formal candidate contract. The default preflight budget is 10 minutes unless the project profile or dispatch brief sets another limit.

## Phase 0: contract lint

Check without starting the renderer:

- approved direction, screen-spec, catalog and component fingerprints exist and match the current source locks;
- every required binding has a current consumer, allowed inputs, protected properties and declared evidence capability;
- the requested candidate count, target viewports, safe areas, coverage IDs, fixtures and text-fit cases are closed;
- protected content and provenance paths resolve inside the declared write scope.
- the project profile or dispatch brief names the capture command and renderer identity; do not invent a command or fall back to an undocumented launcher.

Any missing, stale or conflicting input is `OPEN` or `BLOCKED`; do not substitute a placeholder or launch a formal capture.

## Phase 1: bounded smoke capture

Run the named compositor and renderer path against a deterministic, non-retained smoke set. Select cases in this order: (1) the smallest and largest named viewport when both exist, (2) one required state transition or dialog, (3) the densest text/content fixture. If a category is absent, record `not-applicable`; never invent a state. Check process exit, draw/readback availability, dimensions, crop safety and one repeated output hash for the same case. Do not count smoke images toward formal coverage or approval, and discard them or mark them explicitly as non-evidence.

If the environment cannot produce a stable smoke result, route the issue to test infrastructure and stop before formal composition. Do not spend formal repair attempts on an environment failure.

## Phase 2: formal batch

After the smoke gate passes, run the formal compositor once where the tool supports batching, producing exactly the requested candidate count and every named viewport/state. Keep the formal packet and its hashes separate from smoke outputs. The formal verifier still inspects every retained image and requires deterministic reproduction; the preflight never replaces that review.

Record the result as JSON and validate it with `scripts/validate_capture_preflight.py`. Required fields are `status` (`PASS`, `BLOCKED`, or `OPEN`), `inputRevision`, `rendererIdentity`, `command`, `budgetMinutes`, `elapsedMinutes`, `smokeCases`, `checks`, `formalAllowed`, and `blockedReason`. Each smoke case records its viewport/state/fixture, exit code, readback status, dimensions, repeat hashes and `result` (`PASS`, `FAIL`, or `NOT_APPLICABLE`). `formalAllowed` is true only for `PASS`; a budget overrun is `BLOCKED` with owner `test-infrastructure` or the named contract owner. A preflight failure is not a product or visual-quality verdict.
