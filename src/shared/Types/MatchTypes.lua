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
