---
name: game-test-infrastructure
description: Build or repair shared game test harnesses, isolated fixtures, diagnostic hooks and capture tools; excludes product fixes and final verification verdicts.
---

## Inputs and owned output
Require the scenarios that need tooling, current test/capture environment and permitted instrumentation scope. Own shared harness/fixture/diagnostic implementation and evidence that the tools observe the intended behavior.

## Execute
Reuse working project infrastructure. Keep test data, clocks, RNG, persistence and external adapters controllable only where the scenario needs control. Use isolated temporary state and ensure cleanup cannot remove user data or another run's artifacts.

Keep test controls out of ordinary player flows. Where product hooks are necessary, scope their activation and verify the production path remains unchanged. A UI capture entrypoint must exercise the same rendering/components as the tested screen rather than reconstructing a substitute screen.

Emit candidate identity, environment, fixture identity and raw failure/capture evidence. Preserve failure exit codes and distinguish setup/permission failures from observed assertion failures. Avoid retry policies that conceal intermittent defects.

Validate the harness with a known successful case and an intentionally failing case in an isolated test target. Check repeatability and cleanup. For temporary diagnostic hooks, record removal ownership and condition; do not remove useful evidence before diagnosis consumes it.

## Handoff
Provide commands, fixture controls, limitations and tool-validation results to game-functional-verification or the requesting specialist. Individual implementers retain ownership of their local regression tests. Return observed product defects to their code owner; do not repair the product while making the harness pass or claim final feature acceptance.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
