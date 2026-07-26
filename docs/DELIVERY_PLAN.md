# CAMP-Mystery Autonomous Delivery Plan

The production code path is complete through the release-candidate milestone. Routine
design and approval questions remain removed from the workflow. The remaining gates are
Roblox-engine, private-server, device, moderation, and final-asset acceptance checks
listed in `RELEASE_CHECKLIST.md`.

## Milestones

| Milestone | Deliverable | Exit criteria |
|---|---|---|
| 3. Domain foundation | Human/bot participants, eight roles, lifecycle events, profile schema, monster catalog | Complete |
| 4. Survival systems | Inventory, equipment, combat, injuries, healing, ghosts, role abilities | Complete in code |
| 5. Mystery systems | Seeded real/fake evidence, searches, board, Detective verification, witnesses | Complete; 512 deterministic simulations pass |
| 6. Computer players | Bot roster fill, objectives, abilities, attacks, evidence, voting | Complete in code |
| 7. Monster roster | Common framework and all eight distinct transformations | Complete in code |
| 8. Transforming world | Asset-first camp/town, fallback world, counselors, safe relocation | Complete in code |
| 9. Progression and UX | Persistence, rewards, upgrades, cosmetics, responsive UI, settings, audio | Complete in code |
| 10. Release candidate | Accessibility, tutorial, exploit controls, CI, checklist, documentation | Repository gate complete; Studio/private-server gates pending |

## Remaining external production work

Final custom monster rigs, animation clips, audio assets, thumbnails, UI icons, and
authored environment models must be installed through Roblox Studio and pass Roblox
moderation. Audio exposes concrete `SoundService` attribute hooks; authored monster and
counselor animation folders plus optional role, equipment, and evidence icons have
defensive runtime hooks with procedural/text fallbacks.
Multiplayer balance, DataStore behavior, device input, performance, memory, navigation,
and published-server replication require the Roblox engine and are explicit release
gates rather than missing repository systems.

## Automation policy

- Keep `master` at the latest validated autonomous checkpoint.
- Run repository static contracts, a Rojo build, and available logic tests before opening
  a draft pull request; run Roblox Studio `Script Analysis` before release.
- Merge automatically after its documented acceptance criteria pass.
- Do not request routine choices already resolved by `PRODUCT_SPEC.md`.
- Stop only for account permissions, unavailable private assets, policy/moderation blocks,
  or an irreversible product decision not covered by the specification.
