---
name: game-camera-implementation
description: Implement or repair runtime game camera tracking, bounds, transitions and effects from a camera contract; excludes cutscene authoring and UI layout.
---

## Inputs and owned output
Require camera behavior, world target, observed subjects, viewport policy and control ownership. Own runtime camera state/control and relevant regression tests. Camera composition requirements come from the design/visual owner.

## Execute
Resolve projection and coordinate space from the world profile; 2D does not automatically imply orthographic projection. For applicable 2D views, handle bounds, aspect coverage and target framing. For applicable 3D views, handle up-axis, orbit, collision/occlusion and projection limits. Keep screen UI scaling under its own profile.

Implement tracking, limits and transitions in the intended update phase relative to movement. Account for time scale, teleport, target loss and scene replacement. Blend requested shake/zoom effects without permanently overwriting the base camera state.

Define ownership transfer and restoration for gameplay, authored sequences and spectator modes when present. The sequence owner authors the timeline; this controller accepts and releases camera authority. Do not add movement/input behavior to make a camera test pass.

Test target changes, boundaries, interrupted blends, repeated effects and return to normal control. Capture the affected viewport/aspect cases on the current candidate when claiming visible correctness; report inaccessible cases as unverified.

## Handoff
Provide changed controller, transition/restoration behavior and evidence. Return unclear framing to the visual/design owner, ownership conflicts to game-technical-design, and broken scene cleanup to game-session-implementation. Do not alter HUD layout or author a cutscene here.

## Required contracts
Apply [role, output, language and independent verification rules](../game-task-planning/references/role-contract.md) even for direct invocation. Read only your role card and output type.
For implementation and final delivery, apply [the delivery contract](../game-task-planning/references/delivery-contract.md).
