---
name: game-improvement-assessment
description: Assess an existing game-quality problem and define a comparable improvement goal; do not implement changes.
---

## Input/output
Read current build/capture/measurement and user intent. Produce baseline, observed problem, hypothesis, proposed alternatives, preserved behavior and comparison criteria.
Separate observations from cause hypotheses. Obtain a suitable specialist measurement when needed and available. Record unavailable evidence instead of inventing numbers. For visual quality use source-backed criteria and comparison images; do not force a numeric score.
Recommend a bounded change with its expected benefit and cost. A violation of agreed behavior belongs to bug diagnosis. Return unclear player goals through the shared question route; send technical hypotheses to the measurement owner. Do not edit the game or approve your proposed result as improved.

For difficulty, reward, price or pacing experiments, read [balance experiments](references/balance-experiments.md). Define the experiment and comparison handoff; execution stays with the assigned owners.

Use [intent states](../game-feature-spec/references/intent-rules.md) for goals, alternatives and delegated selections. Preserve intent/source IDs; proposed or unresolved choices cannot authorize dependent implementation.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
