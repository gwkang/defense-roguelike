# Persona contract

Use this lightweight contract when a UI decision depends on who is using the screen or what they need to notice first. Keep it evidence-backed and small; it is not a marketing persona or a substitute for product authority.

## Required fields

- `player_state`: current familiarity or learning state relevant to this screen
- `primary_task`: the one task the player should complete or understand first
- `first_notice`: the first information or action that must be discoverable
- `secondary_disclosure`: information revealed on demand, by scrolling, or in another state
- `main_constraint`: the dominant density, text, motor, vision, device, or input constraint
- `success_signal`: observable evidence that the priority is working

Unknown values remain `OPEN` or explicitly `PROVISIONAL`. Do not invent demographic traits, preferences, or accessibility needs. Translate the contract into information priority, simultaneous-content budget, disclosure rules, text-fit checks, and interaction emphasis; it does not approve visual style, runtime behavior, or release readiness.
