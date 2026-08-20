"""Focused contracts for role reveals, phase titles, and phase tips."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class RoleRevealPhaseTitleTests(unittest.TestCase):
    def test_phase_title_catalog_is_strict_frozen_and_complete(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        self.assertTrue(catalog.startswith("--!strict"))
        for phase in (
            "MurderPlanning",
            "NightTransform",
            "Investigation",
            "Day",
            "Campfire",
            "Resolution",
        ):
            self.assertIn(f"\t{phase} = table.freeze(", catalog)
        self.assertNotIn("\tLobby =", catalog)
        self.assertNotIn("\tRewards =", catalog)
        self.assertIn("return table.freeze(PhaseTitles)", catalog)

    def test_phase_tip_catalog_is_strict_frozen_and_wired(self) -> None:
        catalog = read("src/shared/Config/PhaseTips.lua")
        view = read("src/client/UI/GameView.lua")
        self.assertTrue(catalog.startswith("--!strict"))
        for phase in (
            "MurderPlanning",
            "NightTransform",
            "Investigation",
            "Day",
            "Campfire",
            "Resolution",
        ):
            self.assertIn(f"\t{phase}", catalog)
        self.assertNotIn("\tLobby", catalog)
        self.assertNotIn("\tRewards", catalog)
        self.assertIn("return table.freeze(PhaseTips)", catalog)
        self.assertIn(
            'local PhaseTips = require(SharedConfig:WaitForChild("PhaseTips"))',
            view,
        )
        self.assertIn("else PhaseTips[phaseName]", view)
        self.assertIn('"PhaseTip"', view)

    def test_request_0070_tip_catalog_role_filter_and_murderer_strategy_tips(self) -> None:
        catalog = read("src/shared/Config/TipCatalog.lua")
        view = read("src/client/UI/GameView.lua")
        # Tip type has both filter fields
        for token in (
            "excludeRoles: { string }?",
            "includeRoles: { string }?,",
        ):
            self.assertIn(token, catalog)
        # Murderer-only STRATEGY tips exist
        for token in (
            'category = "STRATEGY"',
            'includeRoles = { "Murderer" }',
            '"Your notebook tracks evidence collected against you. Check it often to gauge how close they are."',
            '"Vote last when possible — watch where suspicion falls before committing your vote."',
            '"Keep up with camp tasks. An idle Murderer stands out; participation builds trust."',
            '"If evidence mounts against you, redirect — point to contradictions in the clues and cast doubt on the accuser."',
        ):
            self.assertIn(token, catalog)
        # excludeRoles tips exist for teamwork/counterplay
        self.assertIn('excludeRoles = { "Murderer" }', catalog)
        # GameView cycling applies includeRoles filter
        for token in (
            'if not excluded and candidate and type(candidate.includeRoles) == "table" then',
            "local included = false",
            "if r == localRole0 then included = true; break end",
            "if not included then excluded = true end",
        ):
            self.assertIn(token, view)
        # GameView cycling applies excludeRoles filter
        for token in (
            'if candidate and type(candidate.excludeRoles) == "table" then',
            "if r == localRole0 then excluded = true; break end",
        ):
            self.assertIn(token, view)

    def test_request_0049_murderer_phase_copy(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        view = read("src/client/UI/GameView.lua")
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            'title = "THE NIGHT IS CHOSEN"',
            'subtitle = "A hidden plan takes shape."',
            'title = "NIGHT FALLS"',
            'subtitle = "The monster awakens."',
            'title = "YOUR PREY IS CHOSEN"',
            'subtitle = "Strike before dawn."',
            'tip = "Study your target now. Your window is short."',
            'title = "YOU ARE THE MONSTER NOW"',
            'subtitle = "The hunt begins. Move in shadow."',
            'tip = "Your ability is your greatest weapon. Use it wisely."',
        ):
            self.assertIn(token, catalog)
        for token in (
            "local murdererEntry = if type(defaultEntry) == \"table\"",
            'local entry = if localRole == "Murderer"',
            'local tipText = if localRole == "Murderer"',
            "else defaultEntry",
            "else PhaseTips[phaseName]",
        ):
            self.assertIn(token, view)
        self.assertIn(
            'currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName, isGhost or roleName == "Spectator")',
            controller,
        )

    def test_request_0054_named_monster_cooldowns_and_phase_tip_routing(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        view = read("src/client/UI/GameView.lua")
        for token in (
            'tip = "Study your target now. Your window is short."',
            'tip = "Your ability is your greatest weapon. Use it wisely."',
            "local abilityIds = table.clone(MONSTER_ABILITIES[monsterId] or {})",
            "for _, abilityId in abilityIds do",
            "cooldowns[abilityId]",
            "then endsAt - currentTime",
            "else 0",
            "%s  %ds</font>",
            "%s  READY</font>",
            'table.concat(abilityLines, "\\n")',
        ):
            self.assertIn(token, catalog if token.startswith("tip =") else view)
        self.assertIn("monsterAbilityLabel.RichText = true", view)
        self.assertIn(
            "monsterAbilityLabel.Size = UDim2.new(1, -20, 0, 26)",
            view,
        )
        self.assertIn("TipCatalog.definitions[self.lobbyTipIndex]", view)
        self.assertEqual(view.count("PhaseTips[phaseName]"), 1)

    def test_request_0055_remaining_murderer_phase_copy(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        effects = read("src/client/UI/EffectsView.lua")
        for token in (
            'title = "THEY ARE SEARCHING"',
            'subtitle = "Stay hidden. Destroy the evidence."',
            'tip = "The evidence board builds against you. Steer suspicion before it locks in."',
            'subtitle = "Hide in plain sight. Play your role."',
            'tip = "Act like a Camper. Suspicion spreads fastest when you seem nervous."',
            'subtitle = "Steer the blame. Survive the accusations."',
            'tip = "A tie breaks in your favor. Spread doubt before votes are cast."',
            'title = "THE VERDICT"',
            'subtitle = "Did they catch you?"',
            'tip = ""',
        ):
            self.assertIn(token, catalog)
        self.assertEqual(catalog.count("murderer = table.freeze({"), 6)
        for token in (
            'title = "YOUR PLAN IS SET"',
            'body = "You chose your prey. Strike before dawn."',
            'title = "YOU ARE THE MONSTER"',
            'body = "The hunt begins. Move in shadow."',
            'title = "THEY ARE SEARCHING"',
            'body = "Stay hidden. Let them doubt each other."',
            'title = "A NEW DAY"',
            'body = "Play your role. Act like the rest."',
            'title = "THE VOTE"',
            'body = "Steer the blame. A tie favors you."',
            'title = "THE VERDICT"',
            'body = "Did they catch you?"',
            'localRole == "Murderer"',
            "and not isGhost",
            "then murdererCopy",
            "else copy",
            "self:ShowPhase(selected.title, selected.body)",
        ):
            self.assertIn(token, effects)

    def test_request_0056_murderer_tutorial_and_roster_header(self) -> None:
        tutorial = read("src/client/Controllers/TutorialController.lua")
        roster = read("src/client/UI/PlayerStatusView.lua")
        for token in (
            'id = "murderplanning_murderer"',
            'title = "YOU ARE CHOOSING"',
            "Select your target and monster form before the night falls.",
            'id = "nighttransform_murderer"',
            'title = "YOU ARE THE MONSTER"',
            "Your form has changed. Hunt your target and avoid detection.",
            'id = "investigation_murderer"',
            'title = "STAY HIDDEN"',
            "The camp is searching for evidence. Blend in. Steer suspicion.",
            'id = "vote_murderer"',
            'body = "You are being considered. Redirect suspicion. A tie breaks in your favor."',
            'if role == "Spectator" then',
            'if role == "Murderer" then',
            'return "MurderPlanningMurderer"',
            'return "NightTransformMurderer"',
            'return "InvestigationMurderer"',
            'return "VoteMurderer"',
            'if murdererStep then',
            'return role == "Murderer"',
            'if camperEquivalent then',
            'return role ~= "Murderer"',
        ):
            self.assertIn(token, tutorial)
        for token in (
            "titleLabel: TextLabel",
            "titleLabel = title",
            'localRole == "Murderer"',
            'then "SUSPECTS"',
            "elseif localIsGhost",
            'then "SPIRIT VIEW"',
            'elseif localRole == "Spectator"',
            'then "SPECTATOR VIEW"',
            'else "CAMP ROSTER"',
            "Components.SetLetterspacedText(self.titleLabel, headerText)",
        ):
            self.assertIn(token, roster)

    def test_request_0057_round_controller_toasts_are_role_aware(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            '"The vote is sealed. Your fate is decided."',
            '"The campfire vote is sealed. Watch the verdict."',
            '"The campfire vote is sealed. The verdict is coming."',
            'survivorText .. " Stay calm. Deflect suspicion."',
            '"One player remains. Cast your vote."',
            '"You have been unmasked"',
            '"The camp named you. Watch the resolution unfold."',
            '"You have been eliminated"',
            '"You are now a ghost. Observe the round and witness the verdict."',
            '"TARGET ELIMINATED"',
            '"ELIMINATED"',
            'displayName .. " has been taken out."',
            'displayName .. " has been eliminated"',
            '"A player has been taken out."',
        ):
            self.assertIn(token, controller)

        all_votes = controller.split(
            "and roundNumber ~= lastVoteCompleteRound", 1
        )[1].split("lastVoteCompleteRound = roundNumber", 1)[0]
        self.assertLess(all_votes.index('roleName == "Murderer"'), all_votes.index("isGhost"))

        elimination = controller.split(
            "if monsterTargetId ~= nil and monsterTargetId == participantId", 1
        )[1].split("lastParticipantAliveStates[participantId] = alive", 1)[0]
        self.assertLess(elimination.index('"TARGET ELIMINATED"'), elimination.index('"ELIMINATED"'))

        campfire = controller.split(
            'if phaseName == "Campfire" and not reconnect then', 1
        )[1].split('if phaseName == "MurderPlanning"', 1)[0]
        self.assertIn('not isGhost and roleName ~= "Spectator"', campfire)
        self.assertIn('roleName == "Murderer"', campfire)

        ghost_death = controller.split("if ghostJustDied and currentView then", 1)[1].split(
            "if isGhost ~= lastIsGhost then", 1
        )[0]
        self.assertLess(
            ghost_death.index("currentView:PlayDeathCinematic(deathCause, roleName)"),
            ghost_death.index('if roleName == "Murderer"'),
        )

    def test_round_controller_fires_once_and_suppresses_reconnect(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            "local lastRoleRevealRound: number? = nil",
            'previousPhase == "Lobby"',
            'roleName ~= "Spectator"',
            "and not reconnect",
            "and lastRoleRevealRound ~= roundNumber",
            "lastRoleRevealRound = roundNumber",
            "currentView:PlayRoleReveal(",
            'roleName == "Murderer"',
            "lastRoleRevealRound = nil",
        ):
            self.assertIn(token, controller)
        reconnect_branch = controller.split("if isReconnectSnapshot then", 1)[1]
        self.assertIn("lastRoleRevealRound = round.roundNumber", reconnect_branch)

    def test_role_reveal_card_is_skippable_reduced_and_cancel_safe(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "roleRevealToken: number",
            "roleRevealOverlay: CanvasGroup?",
            "roleRevealActive: boolean",
            "function GameView:_cancelRoleReveal()",
            "function GameView:PlayRoleReveal(",
            'overlay.Name = "RoleRevealOverlay"',
            "overlay.GroupTransparency = 1",
            "cardHost.Size = UDim2.fromOffset(280, 200)",
            "card.BackgroundColor3 = Theme.Notebook.PageColor",
            "strip.Size = UDim2.new(1, 0, 0, 8)",
            "Theme.Colors.DangerBright",
            '"YOUR ROLE"',
            "Components.PlayUISound(\"open\")",
            "Motion.SlideUp(cardHost",
            "Motion.PopIn(card",
            "overlay.InputBegan:Connect",
            "if reducedMotion then 1 else 2.35",
            "restingPosition.Y.Offset - 120",
        ):
            self.assertIn(token, view)

    def test_phase_band_has_required_timing_style_and_guards(self) -> None:
        view = read("src/client/UI/GameView.lua")
        for token in (
            "phaseTitleToken: number",
            "phaseTitleActive: boolean",
            "function GameView:_cancelPhaseTitle()",
            "function GameView:PlayPhaseTitleCard(phaseName: string, isReconnect: boolean, localRole: string?, isObserver: boolean?)",
            "or isReconnect",
            "or self.roleRevealActive",
            'band.Name = "PhaseTitleBand"',
            "band.Size = UDim2.new(1, 0, 0, 120)",
            "band.BackgroundTransparency = 0.45",
            "scale.Scale = 0.97",
            "math.floor(Theme.Typography.HeadingSize * 1.4)",
            "Components.SetLetterspacedText(title, entry.title)",
            "subtitle.TextTransparency = 0.7",
            "task.delay(0.9, cleanup)",
            "TweenInfo.new(0.25",
            "task.delay(2.05",
            "TweenInfo.new(0.4",
        ):
            self.assertIn(token, view)

    def test_request_0068_observer_phase_title_entries_and_routing(self) -> None:
        catalog = read("src/shared/Config/PhaseTitles.lua")
        view = read("src/client/UI/GameView.lua")
        controller = read("src/client/Controllers/RoundController.lua")
        # PhaseTitles type has observer field
        self.assertIn("observer: PhaseTitleOverride?", catalog)
        # Observer entries exist for Investigation and Campfire
        for token in (
            'title = "INVESTIGATION BEGINS"',
            '"Watch the survivors search for clues."',
            'title = "CAMPFIRE VOTE"',
            '"Watch the verdict unfold."',
        ):
            self.assertIn(token, catalog)
        # GameView routes observer to observer entry
        for token in (
            "isObserver: boolean?",
            "local observerEntry = if type(defaultEntry) == \"table\" then defaultEntry.observer else nil",
            "elseif isObserver and type(observerEntry) == \"table\"",
            "then observerEntry",
            "elseif isObserver and type(observerEntry) == \"table\"",
        ):
            self.assertIn(token, view)
        # RoundController passes isObserver at call site
        self.assertIn(
            'currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName, isGhost or roleName == "Spectator")',
            controller,
        )

    def test_request_0072_murderer_announcement_copy_is_complete(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        for token in (
            '["Your Role Is Ready"] = {',
            'title = "YOUR ROLE IS SET"',
            '"You are among them, and you are the threat. Keep your composure."',
            '["Daylight Objectives"] = {',
            'title = "A NEW DAY"',
            '"Blend in with the camp. Complete tasks and draw no suspicion."',
            '["Dusk Settles Over Camp"] = {',
            'title = "YOUR PLAN"',
            '"Choose your target. You have until dawn."',
            '["The Town Is Appearing"] = {',
            'title = "YOUR HUNT BEGINS"',
            '"You are the threat. Move unseen."',
            '["Night Investigation"] = {',
            'title = "THEY ARE SEARCHING"',
            '"Stay calm. Blend in. Cast doubt."',
            '["Campfire Accusation"] = {',
            'title = "THE VOTE"',
            '"Steer the blame. A tie breaks in your favor."',
            "announcementPayload.title = replacement.title",
            "announcementPayload.message = replacement.message",
        ):
            self.assertIn(token, controller)

    def test_request_0082_phase_transition_toasts_are_role_aware(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        # MurderPlanning toast fires only for Murderer
        self.assertIn(
            'if phaseName == "MurderPlanning" and not reconnect and roleName == "Murderer"',
            controller,
        )
        self.assertIn('"Night is falling"', controller)
        self.assertIn('"You must eliminate %s. Use the shadows."', controller)
        # Investigation: Ghost / Murderer / Spectator-silent / Camper
        invest_start = controller.index('if phaseName == "Investigation" and not reconnect then')
        invest_end = controller.index('if phaseName == "NightTransform" and not reconnect then', invest_start)
        invest = controller[invest_start:invest_end]
        self.assertIn('"Night investigation begins"', invest)
        self.assertIn('"Hunt carefully. Blend in when they gather."', invest)
        self.assertIn(
            '"Not everyone may have made it. Search the town and watch each other."',
            invest,
        )
        self.assertIn('"Investigation begins"', invest)
        self.assertIn('"You are a ghost. Watch as the survivors search for the truth."', invest)
        self.assertIn('elseif roleName ~= "Spectator" then', invest)
        # NightTransform: Ghost / Murderer / Spectator-silent / Camper
        night_start = controller.index('if phaseName == "NightTransform" and not reconnect then')
        night_end = controller.index("-- Keybind hint", night_start)
        night = controller[night_start:night_end]
        self.assertIn('"Your moment is now"', night)
        self.assertIn("Strike true. Day payoff:", night)
        self.assertIn("Night falls — day work pays off", night)
        self.assertIn("Stay alert — someone won't make it to morning.", night)
        self.assertIn("Watch from beyond. The hunt begins.", night)
        self.assertIn("dayOutcomes", night)
        self.assertIn('elseif roleName ~= "Spectator" then', night)
        # Keybind hints are suppressed for ghosts and Spectators
        self.assertIn("and not hintIsGhost", controller)
        self.assertIn('and hintRole ~= "Spectator"', controller)
        self.assertIn('and hintRole == "Murderer"', controller)

    def test_request_0093_server_announcement_titles_match_murderer_override_keys(self) -> None:
        runtime = read("src/server/Services/GameRuntimeService.lua")
        controller = read("src/client/Controllers/RoundController.lua")
        # Server sends these exact titles — Murderer override keys must match
        server_titles = (
            "Your Role Is Ready",
            "Daylight Objectives",
            "Dusk Settles Over Camp",
            "The Town Is Appearing",
            "Night Investigation",
            "Campfire Accusation",
        )
        for title in server_titles:
            self.assertIn(f'\ttitle = "{title}"', runtime)
            self.assertIn(f'["{title}"] = {{', controller)
        # Server also sends these (no Murderer override needed — they are not Murderer-active)
        for title in ("Back at Camp", "Mystery Resolution", "Round Complete"):
            self.assertIn(f'\ttitle = "{title}"', runtime)

    def test_request_0092_spectator_tutorial_step_and_role_skip_logic(self) -> None:
        tutorial = read("src/client/Controllers/TutorialController.lua")
        # Spectator tutorial step content
        for token in (
            'id = "spectator"',
            'context = "Spectator"',
            '"You Joined Late"',
            '"This round is already underway. You can observe the current game',
            '"WATCH THE ROUND \xe2\x80\x94 YOU PLAY NEXT"',
        ):
            self.assertIn(token, tutorial) if '\xe2\x80\x94' not in token else self.assertIn(
                token.replace('\xe2\x80\x94', '—'),
                tutorial,
            )
        # The step is only relevant for Spectators
        self.assertIn("stepId == TutorialController.StepIds.Spectator", tutorial)
        self.assertIn('return role == "Spectator"', tutorial)
        # camperEquivalent and murdererStep skip logic is complete
        for step_id in (
            "MurderPlanningMurderer",
            "NightTransformMurderer",
            "InvestigationMurderer",
            "VoteMurderer",
            "MurderPlanning",
            "NightTransform",
            "Investigation",
            "Vote",
        ):
            self.assertIn(f'TutorialController.StepIds.{step_id}', tutorial)

    def test_request_0089_player_status_view_observer_inspect_and_status_dot(self) -> None:
        roster = read("src/client/UI/PlayerStatusView.lua")
        # statusFor: Ghost maps to "GHOST" status with Ghost color
        status_start = roster.index("local function statusFor(participant: any)")
        status_end = roster.index("end\n\nlocal function appendSignatureValue", status_start)
        status_fn = roster[status_start:status_end]
        self.assertIn('"GHOST"', status_fn)
        self.assertIn('"DEAD"', status_fn)
        self.assertIn('"INJURED"', status_fn)
        self.assertIn('"DOWN"', status_fn)
        # Ghost is checked before alive/healthState
        self.assertLess(status_fn.index("isGhost"), status_fn.index("not alive"))
        # observerCanInspectRoles: Ghost or Spectator can see role labels
        for token in (
            'local observerCanInspectRoles = readBoolean(localPlayer, "isGhost", false)',
            'or readString(localPlayer, "role", "") == "Spectator"',
            '"(Role: ?)"',
        ):
            self.assertIn(token, roster)
        # Local Murderer gets Gold label color; other self gets Info; stranger gets TextMuted
        for token in (
            'readString(localPlayer, "role", "") == "Murderer"',
            "Theme.Colors.Gold",
            "Theme.Colors.Info",
            "Theme.Colors.TextMuted",
        ):
            self.assertIn(token, roster)

    def test_request_0088_keybind_hints_catalog_completeness(self) -> None:
        hints = read("src/shared/Config/KeybindHints.lua")
        controller = read("src/client/Controllers/RoundController.lua")
        self.assertTrue(hints.startswith("--!strict"))
        self.assertIn("return table.freeze(HINTS)", hints)
        # All phases have both keyboard and controller variants
        for phase in ("Day", "Investigation", "Campfire", "MurderPlanning", "NightTransform"):
            self.assertIn(f"\t{phase} = {{", hints)
            phase_start = hints.index(f"\t{phase} = {{")
            phase_end = hints.index("\t},\n", phase_start)
            entry = hints[phase_start:phase_end]
            self.assertIn("keyboard", entry)
            self.assertIn("controller", entry)
        # Murderer-only hints are action-specific
        for token in (
            '"CLICK  Choose target"',
            '"CLICK  Monster ability"',
        ):
            self.assertIn(token, hints)
        # Campfire hint has vote action
        self.assertIn('"E  Vote"', hints)
        # RoundController routes Murderer phases via MURDERER_HINT_PHASES
        self.assertIn("local MURDERER_HINT_PHASES:", controller)
        for phase in ("MurderPlanning", "NightTransform"):
            self.assertIn(f"\t{phase} = true", controller)
        self.assertIn("local HINT_PHASES:", controller)
        for phase in ("Day", "Investigation", "Campfire"):
            self.assertIn(f"\t{phase} = true", controller)

    def test_phase_title_dispatch_order_follows_cinematic(self) -> None:
        controller = read("src/client/Controllers/RoundController.lua")
        cinematic = controller.index(
            "currentCinematics:PlayPhaseTransition(phaseName)"
        )
        title = controller.index(
            'currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName, isGhost or roleName == "Spectator")'
        )
        resolution = controller.index(
            'if phaseName == "Resolution" and currentView then'
        )
        self.assertLess(cinematic, title)
        self.assertLess(title, resolution)

    def test_request_0107_tutorial_view_murderer_briefing_header(self) -> None:
        tutorial_view = read("src/client/UI/TutorialView.lua")
        tutorial_ctrl = read("src/client/Controllers/TutorialController.lua")
        # Constructor sets default header to "NEW CAMPER BRIEFING" before any step is shown
        self.assertIn('"NEW CAMPER BRIEFING"', tutorial_view)
        # Show method derives role-aware header from step id containing "_murderer"
        show_start = tutorial_view.index("function TutorialView:Show(")
        show_end = tutorial_view.index("\nend\n", show_start)
        show_fn = tutorial_view[show_start:show_end]
        self.assertIn('string.find(step.id, "_murderer")', show_fn)
        self.assertIn('"MURDERER BRIEFING"', show_fn)
        self.assertIn('"NEW CAMPER BRIEFING"', show_fn)
        # Murderer briefing header appears only for _murderer steps — camper steps keep default
        self.assertLess(
            show_fn.index('"MURDERER BRIEFING"'),
            show_fn.index('"NEW CAMPER BRIEFING"', show_fn.index('"MURDERER BRIEFING"')),
        )
        # TutorialController has _murderer step ids in its step catalog
        for step_id in (
            '"murderplanning_murderer"',
            '"nighttransform_murderer"',
            '"investigation_murderer"',
            '"vote_murderer"',
        ):
            self.assertIn(step_id, tutorial_ctrl)


    def test_request_0114_tutorial_context_key_murderer_phase_dispatch(self) -> None:
        tutorial = read("src/client/Controllers/TutorialController.lua")
        # _getContextKey: Spectator short-circuits before any phase branching
        spectator_idx = tutorial.index('if role == "Spectator" then')
        murderer_idx = tutorial.index('if role == "Murderer" then')
        self.assertLess(spectator_idx, murderer_idx)
        # Murderer phase dispatch block exists and maps each Murderer phase to a distinct key
        context_fn_start = tutorial.index('if role == "Murderer" then')
        context_fn_end = tutorial.index('if phase == "RoleReveal"', context_fn_start)
        murderer_block = tutorial[context_fn_start:context_fn_end]
        self.assertIn('phase == "MurderPlanning"', murderer_block)
        self.assertIn('return "MurderPlanningMurderer"', murderer_block)
        self.assertIn('phase == "NightTransform"', murderer_block)
        self.assertIn('return "NightTransformMurderer"', murderer_block)
        self.assertIn('phase == "Investigation"', murderer_block)
        self.assertIn('return "InvestigationMurderer"', murderer_block)
        self.assertIn('phase == "Campfire"', murderer_block)
        self.assertIn('return "VoteMurderer"', murderer_block)
        # Murderer phase block appears before the standard camper phase keys
        role_reveal_idx = tutorial.index('if phase == "RoleReveal"', murderer_idx)
        self.assertLess(murderer_idx, role_reveal_idx)
        # Camper Investigation context: evidenceFound > 0 switches to Evidence,
        # then Deduction before Vote; Ghost fires when isGhost.
        inv_camper_idx = tutorial.index(
            'return "Evidence"', role_reveal_idx
        )
        self.assertIn('readNumber(round, "evidenceFound", 0)', tutorial[role_reveal_idx:inv_camper_idx])
        self.assertIn("evidenceFound > 0", tutorial[role_reveal_idx:inv_camper_idx])
        self.assertIn('Deduction = "deduction"', tutorial)
        self.assertIn('Ghost = "ghost"', tutorial)
        self.assertIn('return "Deduction"', tutorial)
        self.assertIn('return "Ghost"', tutorial)
        self.assertIn("COMPARE THREE CLUES BEFORE YOU ACCUSE", tutorial)
        self.assertIn("STAY USEFUL AFTER DEATH", tutorial)


if __name__ == "__main__":
    unittest.main(verbosity=2)
