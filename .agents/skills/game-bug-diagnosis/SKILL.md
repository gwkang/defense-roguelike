---
name: game-bug-diagnosis
description: Identify an indie-game defect cause and bounded repair ownership from reproduction and source evidence; do not implement the repair.
---

## Input/output
Use reproduction, logs and relevant source/data/assets. Output confirmed facts, alternative hypotheses, discriminating evidence, cause confidence, affected contracts and repair owner/scope.
Trace the failing state or event through its producers and consumers. Verify a counterexample or alternate explanation before labeling a cause confirmed. For resource issues separate duplicated events, duplicated objects and duplicated files.
Read-only analysis is default. Specify needed instrumentation to the relevant implementation owner if observation cannot settle the cause. Record temporary instrumentation cleanup needs. Do not alter expected product behavior to explain away the failure.
Return unresolved hypotheses with the next check. Send a confirmed repair scope to its specialist; route a failed regression back here rather than piling on patches.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
