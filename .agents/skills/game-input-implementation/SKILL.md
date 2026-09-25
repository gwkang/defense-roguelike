---
name: game-input-implementation
description: Implement or repair device input conversion into gameplay commands, including buffering, focus and device transitions; excludes UI widget behavior.
---

## Inputs and owned output
Require the control contract, target input devices, activation contexts and command interface. Own device bindings, input state and command emission plus relevant regression tests. Read project-specific input APIs from the selected engine/version.

## Execute
Trace press, hold, release and cancellation separately. Convert device coordinates through the declared target mapping before emitting commands; do not reuse screen UI coordinates as world coordinates. Keep remapping/deadzones/sensitivity within the agreed control contract.

Implement context priority and capture so one action is consumed by the intended context. Respect the UI owner's focus/consumption signal without implementing widget navigation or click handlers here. Avoid duplicate actions when touch, mouse or multiple devices describe the same interaction.

Specify buffer expiry and the clock used. Clear or retain held/buffered inputs according to the contract on focus loss, pause, device disconnect and session replacement. Subscription setup/teardown must not multiply handlers on reentry.

Test applicable press/release, repeat, context switching, cancellation and reconnect cases. Use the actual target device path when claiming device support; a synthetic event test alone does not establish that support.

## Handoff
Report bindings, context/command mapping, changed files and evidence. Gameplay legality remains with game-rule-implementation; position changes belong to game-movement-implementation. Return missing command/context ownership to game-technical-design and shared pause defects to game-session-implementation. Do not silently add a new control scheme.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
