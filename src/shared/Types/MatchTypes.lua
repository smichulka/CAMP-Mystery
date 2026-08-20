--!strict

export type MatchMode = "Solo" | "Small" | "Standard" | "Full"
export type LobbyStatus = "Waiting" | "Filling" | "Locked" | "InRound"
export type LobbyPlayerStatus = "Waiting" | "Ready" | "Locked" | "NextRound"
export type ControllerKind = "Human" | "Bot"

export type LobbyPlayerSnapshot = {
	userId: number,
	participantId: string,
	displayName: string,
	status: LobbyPlayerStatus,
	isReady: boolean,
	-- Explicit "not tonight" from the enrollment desk (opt-in mystery);
	-- the dusk reminder skips players who already said no.
	hasWithdrawn: boolean,
	joinedAt: number,
}

export type LobbySnapshot = {
	revision: number,
	status: LobbyStatus,
	mode: MatchMode?,
	standardTarget: number,
	maximumParticipants: number,
	humanCount: number,
	readyCount: number,
	nextRoundCount: number,
	fillStartedAt: number?,
	fillEndsAt: number?,
	serverNow: number,
	activeRoundId: string?,
	players: { LobbyPlayerSnapshot },
	-- Ready players who toggled Quick Camp in the lobby card (Track B pacing).
	quickCampPreferCount: number?,
	quickCampReadyCount: number?,
	-- Wave 5: preview of the next seeded night route (same Place).
	nightRoute: string?,
	worldRoute: string?,
	worldId: string?,
	nightRouteDisplayName: string?,
}

export type RosterParticipant = {
	participantId: string,
	displayName: string,
	controllerKind: ControllerKind,
	userId: number?,
	botId: string?,
}

export type LockedRoster = {
	roundId: string,
	revision: number,
	mode: MatchMode,
	targetSize: number,
	createdAt: number,
	participants: { RosterParticipant },
}

export type DisconnectContext = {
	userId: number,
	participantId: string,
	wasLocked: boolean,
	roundId: string?,
	wasQueuedForNextRound: boolean,
}

return {}
