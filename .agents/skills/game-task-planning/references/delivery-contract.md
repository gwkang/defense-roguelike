# Execution and completion contract

This reference is shipped with the unified workflow bundle. Read the section for the current responsibility; an implementer need not run the coordinator's procedure. Project instructions and existing authorization govern execution. This document does not grant delegation, installation or publication permission.

Before producing or checking an artifact, apply [bounded artifact verification](verification-scope.md), including direct invocation. Necessary read scope and project-wide commands do not enlarge repair authority.

## Implementation completion

Apply this section even when an implementation skill is invoked directly. Inspect the affected existing code, callers, tests and project conventions before editing; preserve unrelated changes. Read the relevant profile/project verification commands, not commands from another game. If a required command is unknown, determine it from the project or record the blocked check.

Use these coding decisions only where the assigned change touches them; apply them within the existing implementation/review, without a new document or gate:
- **Responsibility:** group behavior that protects the same state or changes for the same reason. Split a function/class when unrelated policy and I/O obscure that responsibility; do not split merely to meet a size rule.
- **Encapsulation:** keep objects valid at creation and through updates. Expose only necessary operations; do not return mutable internals that let callers bypass invariants. Use read-only views, snapshots or explicit ownership transfer as appropriate, without forcing copies in hot paths.
- **Dependencies:** make time, RNG, storage and service dependencies explicit where they affect behavior or testing. Avoid hidden globals and cycles. Prefer composition when inheritance would couple unrelated behavior; extract an interface only for an actual boundary or variation, not a hypothetical extension.
- **Complexity:** choose the simplest sufficient algorithm/data structure for expected input size and call frequency. Check repeated traversal and allocations in affected hot paths; measure only when a cost claim or reported problem needs evidence. Avoid speculative optimization or generic frameworks.
- **Testability:** separate decisions from effects when that makes the changed behavior observable. Reuse existing seams and tests; do not add abstractions solely to mirror private implementation details in tests.

Keep routine local choices with the implementer. Return consequential contract/ownership changes to technical design. Review these decisions only for concrete effects on the requested change; unrelated cleanup remains out of scope.

Before changing worker/job/thread execution or a shared-state execution boundary, including behind an unchanged public interface, read [the runtime concurrency contract](../../game-technical-design/references/runtime-concurrency.md). Confirm that the current technical contract covers the proposed execution and data-access change. Reuse an adequate contract; if missing or incomplete, route that design to game-technical-design before the dependent implementation. Direct invocation does not skip this requirement. Ordinary async I/O without such a boundary change does not require multithreading design.

Implement within the assigned state and write scope. Keep local regression tests with their implementation owner; own a cross-module test only when explicitly assigned by the plan. Use a test that exercises the changed behavior, including the original defect when applicable; do not mirror implementation details or change expectations merely to pass. Return a changed interface to its contract owner and invalidate dependent work.

Run the applicable focused checks and project-required static/type/build checks for this stage. Distinguish a failed assertion, an unavailable tool and an unrelated existing failure. Do not add mandatory tools or repeat a full build for every role. The coordinator runs required final gates once on the assembled candidate; a direct invocation serving as final delivery must arrange those gates itself.

When another writer can change inputs read by a check or review, apply Stable verification inputs below before using its result, including during direct invocation.

Hand off changed files, source/configuration identity (including relevant dirty changes), input contract revision, test commands/results, remaining failures and next owner. Separate implementation-ready from final accepted. For direct final delivery, also apply Code review and Final candidate below; do not silently bypass them because no orchestrator was invoked.

## Code review

For a code change in development, improvement or bugfix, record the review decision under project policy and change risk. Use game-code-review or an available equivalent for substantive logic, interface, persistence, concurrency or platform changes. A trivial change may omit review only where project policy allows; record the reason. Functional tests alone do not replace required review.

Bind review to the current candidate and read findings before declaring completion. The implementing owner repairs actionable findings; rerun affected verification and review against the repaired candidate. Required unresolved findings block acceptance. Label author review as self-review; if independent review is required and no authorized independent reviewer is available, preserve that unmet gate. Do not invent a new approval authority.

## Planning concurrent work

The planner records a dependency graph or equivalent short task list; it does not spawn workers. For potentially concurrent tasks record task ID, owner, input revision/base candidate, dependencies, write paths, relevant read/verification scope, exclusive resources, expected output/evidence and join/integration owner. Include test accounts, editor sessions, caches, ports and output directories when shared; disjoint source files alone are insufficient. Compare checks' source/configuration read scope against every active writer, not just the source module assigned to that check's owner. If that scope is unknown, treat it conservatively as the project scope until narrowed from evidence.

Assign scenario designer, test-code writer and executor for each needed cross-module/contract test, even when no test file exists yet. Choose a relevant implementation owner for the test assertions and assembly; game-test-infrastructure owns only shared tools/fixtures. Declare the assembled candidate and required integration evidence at the join. An integration assignment does not authorize arbitrary edits outside the named scope.

## Coordinator execution

1. Choose parallel workers only when the current user/project authorization permits delegation, tools are available and ready tasks are independent. This reference alone is not authorization. Otherwise switch roles sequentially. Small tasks can remain sequential when coordination would add no value. Independent read-only tool calls may be batched using host capabilities; do not parallelize dependent reads/writes or shared mutations.
2. Confirm the input contracts before dispatch. Give each worker its bounded task, allowed paths/resources, input identity, required tests and return format. Use the host's actual concurrency limit; do not invent a fixed worker count or treat a different role as a new user-owned task.
3. Isolate overlapping paths/resources in suitable separate checkouts or test environments, or serialize them. In a shared checkout, workers may write only their assigned paths; designate one writer for shared files. Restrict tests that mutate shared fixtures/output and apply Stable verification inputs below when checks read another worker's write scope. Do not rely on a verbal ownership label to isolate an editor or account.
4. Collect each result with status, changed paths/candidate, input revision, evidence and unresolved items. If a contract changes, pause/replan affected work and invalidate its stale results. A failed/cancelled worker blocks dependent tasks, not independent useful work. Bound retries to a diagnosed recoverable problem; do not loop blindly or accept missing results.
5. At the join, the assigned implementation/integration owner checks actual changes against scope and input revisions, resolves conflicts within that scope and assembles the candidate. The coordinator tracks this handoff rather than silently implementing specialist changes. Route conflicting semantics to technical design. Individual green tests do not establish that the combined result passes.
6. Execute Final candidate below. Report which tasks actually overlapped, which serialized and why. A parallel plan is not proof of parallel execution. Preserve user changes and approved work when cancelling; do not reset or delete other workers' results.

## Stable verification inputs

For an overlapping reader and writer, either run the check/review against an isolated, stable candidate with the intended changes, or wait for the relevant writers to finish and keep those inputs unchanged until the observation completes. Separate output folders do not isolate source reads. A snapshot must be captured from a stable source state; copying files while a writer updates them is not a coherent candidate. Include relevant dirty changes and configuration in the actual input identity, not merely the dispatch base commit.

Record which candidate was observed and how stability was maintained. Before/after identity checks can detect drift but do not replace isolation or coordination. If inputs changed during observation, preserve the raw output, mark that evidence invalid due to changing inputs, and rerun on a stable candidate. Do not attribute that run to a product defect or use it as passing evidence. Unrelated work outside the read/resource scope can continue; no global repository lock is required for every check.

## Final candidate

Record one assembled source/configuration identity and maintain Stable verification inputs while observing it. Run applicable integration/functional verification and project-required final gates on that identity. Reuse evidence only when its inputs remain valid. Apply Code review for code changes and the existing UI/specialist acceptance gates where relevant. Keep unrelated gate failures separate but do not call the full gate green.

After a repair or integration edit, recheck the affected evidence on the new candidate before acceptance. Report accepted, ready for required review, blocked or unverified according to actual results and the project's authority. Local packaging or successful review does not authorize external release.
