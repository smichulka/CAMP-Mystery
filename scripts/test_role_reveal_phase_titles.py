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
            'murdererStep and role ~= "Murderer"',
            'camperEquivalent and role == "Murderer"',
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
