# Intent specification rules

Own product behavior, not engine architecture. Treat source code as evidence of current behavior, not sole authority for desired behavior. Preserve user constraints when summarizing.

## Decision states
- confirmed: cite the user statement or applicable product authority.
- proposed: your recommendation, not an implementation requirement yet.
- delegated: cite actual scope of user delegation, criteria, and the specialist's selected outcome/reason. Delegation without a selected outcome leaves dependent work unready.
- unresolved: identify missing/conflicting information, impact and the next deciding owner.

For supervised work, return the question and recommendation to the overall supervisor to reconcile existing authority and batch questions; do not ask independently. For direct invocation, ask when a choice changes player experience, compatibility, acceptance or scope and cannot be resolved from current authority. Do not ask about an ordinary reversible implementation choice assigned to the technical owner. Do not ask the user to repeat documented decisions. A missing pause-resume policy must not silently become a countdown; visual polish is not permission to change navigation.

Each material statement has an intent ID and source. Each acceptance criterion links to intent IDs and states conditions, action, observable result, verification method and owner. Include relevant failure/interruption/recovery behavior and a counterexample. Do not manufacture numeric thresholds without a basis. Irrelevant sections may be marked not-applicable with reasons; blank headings do not satisfy required content.

Verification owners must resolve to an available skill or an explicitly identified external role, not an unspecified 'QA team'. If availability is unknown, mark that assignment unresolved and keep dependent execution unready. A drafting role may propose ownership but must not imply a staffed capability exists.

Ready means the next consumer can use the applicable decisions: no required behavior depends on an unresolved/proposed choice. Partially ready scope is allowed with explicit dependency blockers. The consumer checks semantic sufficiency; a populated template alone is not proof. Version changed intent, preserve earlier evidence and identify affected criteria/consumers.

## Optional professional reference
When a desired experience is too abstract to connect to rules, use Hunicke, LeBlanc and Zubek's [MDA](https://www.cs.northwestern.edu/~hunicke/MDA.pdf): distinguish desired experience, play dynamics and mechanics. Use it to formulate observable examples, not as a mandatory taxonomy or proof of fun. Check actual play against the user's goal; do not impose a prototype stage. Record the applied section and decision only when this reference materially informs the specification.
