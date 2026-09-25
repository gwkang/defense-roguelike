---
name: game-test-design
description: Define focused functional and regression scenarios for an agreed game change; does not implement the harness or report unexecuted tests as passing.
---

## Inputs and owned output
Require acceptance criteria, changed contracts, target profile and known risks or defect reproduction. Own a scenario set with stable IDs, target, preconditions/fixture, actions, observable expected result and required evidence.

## Execute
Map each changed requirement to an observable outcome. Cover relevant normal, rejected, interrupted and recovery paths; choose risk-based cases instead of demanding every engine/device combination for each edit. Retain the original reproduction for a defect repair.

Define explicit clocks, data versions and seeds only when reproducibility requires them. Use actual device/runtime cases for claims that synthetic tests cannot establish. Separate correctness, visual/audio quality and player experience; one passing assertion cannot certify all three.

Identify the smallest useful regression boundary around affected consumers. Record which existing scenarios/evidence remain applicable and why. When an input revision changes, identify the dependent cases that need another run.

For each scenario, name the designer, test-code writer, executor and missing fixture/tool capability. For cross-module/contract tests, assign assertions and assembly to a relevant implementation owner even if no test file exists yet; game-test-infrastructure builds only the shared tools/fixtures. Target the assembled candidate, not just separately passing modules. game-functional-verification executes and reports; do not assign it a new harness or test implementation.

For a worker/job/thread change, consume the technical design's [runtime concurrency contract](../game-technical-design/references/runtime-concurrency.md). Include relevant competing schedules, cancellation/shutdown and sequential-result equivalence; use supported diagnostics and state stress-test limits. Ordinary sequential changes do not require concurrency tests.

## Handoff
Deliver scenarios and dependencies without fabricated actual results. For UI coverage, consume the existing game-ui-screen-spec coverage IDs and viewport/baseline contract; request missing rows from that owner rather than maintaining a competing coverage map. Return untestable acceptance criteria to the feature/contract owner. Scale the output to the change; a small repair may need only a few cases in its work record.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
