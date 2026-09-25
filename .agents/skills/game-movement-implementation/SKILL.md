---
name: game-movement-implementation
description: Implement or repair game object movement and collision response from an agreed movement contract; excludes game outcome rules and camera control.
---

## Inputs and owned output
Require movement/collision behavior, commands, world target, units, clock and position authority. Own the movement controller and its focused regression tests. Missing feel or collision requirements go to the design owner; conflicting writers go to game-technical-design.

## Execute
Read the target's 2D/3D physics and coordinate configuration. Keep 2D plane/layer and 3D up-axis, slope and volume assumptions explicit. Select only the dimensional branch used by this object; a 3D asset does not establish a 3D movement world.

Translate commands into velocity/displacement through the existing simulation model. Preserve the specified fixed/variable-step behavior; test materially different frame intervals when timing affects the result. Do not introduce a second transform writer alongside physics or root motion.

Implement applicable grounding, collision response, acceleration, stopping, teleport and recovery behavior. Treat navigation output as a path request and animation root motion as a displacement input under the agreed authority. Damage, rewards and victory remain semantic events for the rule owner.

Check pause/resume, spawn/respawn and controller teardown with the session contract. Test representative obstacles and boundary speeds; include tunneling, slopes or moving supports only when relevant to the change.

## Handoff
Deliver controller changes, authority/clock assumptions and observed movement/collision evidence. Rendered feel needs an actual play observation; physics unit tests alone do not establish it. Camera defects return to game-camera-implementation, animation asset defects to the available animation owner, and rule outcomes to game-rule-implementation.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
