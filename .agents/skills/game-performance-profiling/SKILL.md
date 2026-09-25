---
name: game-performance-profiling
description: Measure a game performance issue and produce reproducible bottleneck evidence or a before-and-after comparison; does not implement optimization patches.
---

## Inputs and owned output
Require the reported symptom or budget, candidate build, target environment and representative workload. Own the measurement record and evidence-based bottleneck assessment. If no target budget exists, report measurements without inventing a pass threshold.

## Execute
Before measuring, apply [Stable verification inputs](../game-task-planning/references/delivery-contract.md#stable-verification-inputs): isolate an immutable candidate or wait for overlapping writers; invalidate a trace if inputs drift. Direct invocation has the same rule.

Record build/configuration, device/runtime, workload/seed when relevant, viewport, quality settings and profiler configuration. Separate cold loading, warm steady state and long-session growth when they answer different questions.

Choose metrics that match the symptom: frame-time distribution and spikes, CPU/GPU timing, allocations/retained memory, loading latency or other relevant counters. State sampling duration/repetitions and known instrument overhead; average FPS alone cannot explain stutter.

Correlate a spike with the responsible work before assigning cause. Separate observations from hypotheses and confounding conditions such as thermal throttling or background load. Preserve raw traces so an implementer can inspect the claim.

For comparisons, hold relevant conditions constant and report variability plus tradeoffs. A faster result from lower quality or a different workload is not the same-condition improvement requested. Mark unavailable CPU/GPU/device measurements explicitly.

For worker/job/thread changes, use the measurement requirements in [the runtime concurrency contract](../game-technical-design/references/runtime-concurrency.md). Compare total costs, including scheduling, transfer and waiting, against the sequential baseline rather than reporting worker speed alone.

## Handoff
Provide scenario, exact commands/tools, metrics, raw evidence, likely owner and next discriminating observation. Route optimizations to the implementation owner and needed diagnostic hooks to game-test-infrastructure. Do not alter production code, lower quality settings as a fix or declare causality from one unmatched trace.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
