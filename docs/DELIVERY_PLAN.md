# CAMP-Mystery Autonomous Delivery Plan

The Milestone 2 Studio smoke test passed and PR #2 was merged. Routine design and approval
questions are removed from the workflow. Development proceeds through reviewable,
reversible branches and automated checks. Human testing is reserved for major Roblox
runtime gates that cannot be executed outside Studio.

## Milestones

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| 3. Domain foundation | Human/bot participants, eight roles, lifecycle events, profile schema, monster catalog | Static validation and compatibility smoke pass |
| 4. Survival systems | Inventory, equipment, combat, injuries, healing, ghosts, role abilities | Multi-client injury/death/recovery test |
| 5. Mystery systems | Generated real/fake evidence, searchable objects, board, Detective verification, witnesses | Mystery can be solved without direct culprit disclosure |
| 6. Computer players | Bot roster fill, navigation, objectives, abilities, deception, memory, voting | Repeated solo and mixed-roster simulation |
| 7. Monster roster | Common framework and all eight distinct transformations | Every monster has attack, evidence, weakness, and bot policy |
| 8. Transforming world | Authored camp/town chunks, deterministic variants, NPC counselors, navigation | Safe streamed transformation and full round traversal |
| 9. Progression and UX | Rewards, persistence, upgrades, cosmetics, lobby, final UI, settings, audio | Leave/rejoin persistence and desktop/touch/gamepad tests |
| 10. Release candidate | Performance, accessibility, exploit validation, soak tests, tutorial, documentation | Ten-round server soak and complete acceptance matrix |

## Schedule estimate

- Systems-complete alpha: 4–7 weeks
- Content-complete beta: 10–16 weeks
- Polished public-launch candidate: 16–24 weeks

Final custom monster rigs, animation, audio, Roblox asset moderation, multiplayer balance,
and device testing are the critical path. Parallel agents shorten independent code and
content work, but shared contracts and Roblox Studio verification remain sequential gates.

## Automation policy

- Preserve `main` as the last validated state.
- Build each milestone on an `agent/...` branch.
- Run structural validation, Rojo build, static analysis, and available logic tests before
  opening a draft pull request.
- Merge automatically after its documented acceptance criteria pass.
- Do not request routine choices already resolved by `PRODUCT_SPEC.md`.
- Stop only for account permissions, unavailable private assets, policy/moderation blocks,
  or an irreversible product decision not covered by the specification.

