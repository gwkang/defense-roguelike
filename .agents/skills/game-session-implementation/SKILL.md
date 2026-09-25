---
name: game-session-implementation
description: Implement or repair game session start, restart, scene transitions, shared pause and state restoration; excludes resource decoding and save serialization.
---

## Inputs and owned output
Require the session state/transition contract and interfaces for input, loading, persistence and presentation. Own the session coordinator, transition state and lifecycle regression tests.

## Execute
Trace entry/exit, restart, resume and failure paths. Implement allowed transitions and their cancellation/reentry semantics. Bind asynchronous work to a session generation or equivalent lifetime identity; an obsolete result must not activate a replaced session.

Implement the project-defined transition order for blocking input, cancelling work, unsubscribing presentation, returning resource references and preparing the next state. Individual adapters clean up their own subscriptions/resources; the coordinator owns the order, not their internal implementation.

Keep shared pause/time ownership here and expose it to movement, camera and playback adapters. Respect multiple pause reasons if the contract supports them; releasing one reason must not clear another. Do not duplicate local sound/animation cleanup code in the coordinator.

Restore gameplay state only from an accepted save result. The save owner reads/serializes it, the loader acquires resources, and the rule owner validates domain transitions. Make partial initialization failures recoverable according to the specified user flow.

Test repeated restart, interruption during loading, late completion, pause/resume and failed restoration as applicable. Observe that old subscriptions and resource references are released, not just that a new scene appears.

## Handoff
Deliver transition changes, lifecycle evidence and unresolved adapter dependencies. Return acquisition/refcount defects to game-content-loading, persistence defects to game-save-implementation and missing ownership decisions to game-technical-design. New game rules and transition artwork remain outside this role.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
