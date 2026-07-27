# Chat_Request-0053 — Role-Aware Announcements + Evidence Ceremony

## 1. Summary

Request 0053 is implemented on `main`. The three server-broadcast phase
announcements now retain their original kind, duration, and presentation but
substitute Murderer-specific title/message copy on the client. New evidence now
gives the Murderer an amber warning toast without the positive discovery flash or
ceremony; all non-Murderers, including ghosts and spectators, retain the existing
ceremony.

The required gate also exposed an inherited publication defect in
`src/client/UI/GameView.lua`: commit `b18eadc` had inserted two truncation-warning
lines and replaced 158 lines of the evidence notebook implementation with a
literal truncation marker. That published file could not compile despite the
prior handoff report. This implementation restores the complete pre-0052
notebook/evidence code, reapplies Request 0052's intended self-marker and timer
changes, and verifies both 0052 and 0053 through the real full gate.

## 2. Exact Files Changed

- `src/client/Controllers/RoundController.lua`
  - Maps only the three live server announcement titles to the requested
    Murderer copy.
  - Resolves the local role from the latest game snapshot, with the existing
    legacy player snapshot as fallback.
  - Clones a payload only when applying an override, preserving kind, duration,
    and all other fields.
  - Routes Murderer evidence discoveries to the exact `Warning` toast.
  - Keeps `FlashEvidenceFound()` and `PlayEvidenceDiscovery()` exclusively on the
    non-Murderer branch.
- `src/client/UI/GameView.lua`
  - Removes the inherited non-Luau truncation text and restores the complete
    evidence notebook implementation from the last clean parent.
  - Reapplies Request 0052's local ` (you)` vote marker and Murderer Campfire
    timer thresholds without the corrupted notebook replacement.
- `scripts/test_phase_cinematics.py`
  - Adds Request 0053 regression coverage for all exact announcement strings,
    role gating, cloned payload forwarding, warning severity, and ceremony/flash
    branch isolation.
  - Existing Request 0052 coverage remains green against the repaired source.
- `ClaudChat/Archive/Claude_Request-0053-server-phase-announcements-role-aware-and-evidence-ceremony.md`
  - Archived the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0053-server-phase-announcements-role-aware-and-evidence-ceremony.md`
  - Removed after the archive copy was committed.

## 3. Commit Ledger

- `8a3919e87f03cc3523c12f7da6c877244d333de7` — Archive Claude Request 0053
- `1e7e7a01b9be65ca3b7d418734a5d426ee0b9479` — Remove processed Claude Request 0053
- `b45842f581734e874f9452214f59823c2a51a148` — Add role-aware announcements and evidence warning

## 4. DONE and Verification

- DONE: MurderPlanning gives the Murderer `YOUR PLAN` and the exact target copy.
- DONE: NightTransform gives the Murderer `YOUR HUNT BEGINS` and the exact unseen
  movement copy.
- DONE: Investigation gives the Murderer `THEY ARE SEARCHING` and the exact blend
  in/cast doubt copy.
- DONE: All other Murderer announcements remain unchanged.
- DONE: Every announcement remains unchanged for non-Murderers.
- DONE: Announcement kind, duration, color path, font, and animation are
  unchanged.
- DONE: Murderer evidence discovery produces the exact amber `Warning` toast.
- DONE: Murderer evidence discovery does not call the positive flash or ceremony.
- DONE: Living campers, ghosts, and spectators retain both discovery behaviors.
- DONE: The inherited `GameView.lua` truncation corruption is removed and the
  missing notebook/evidence implementation is restored.
- DONE: Request 0052 behavior remains covered and passes.
- DONE: The focused phase-cinematics suite passes all 17 tests.
- DONE: `git diff --check` passes.
- DONE: The complete required gate passes with pinned Luau 0.726 and Rojo 7.7.0.

```text
$ python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (967,792 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of the three Murderer banners and warning toast
  is deferred.
- Live multiplayer proof for Murderer, living camper, ghost, and spectator clients
  is deferred.
- No server announcement broadcast, shared runtime type, layout, asset, or
  unrelated phase behavior changed.

## 6. Review Request

Please confirm Request 0053 is accepted and specifically verify that the repaired
`GameView.lua` contains the complete evidence notebook implementation while
retaining Request 0052's intended behavior.
