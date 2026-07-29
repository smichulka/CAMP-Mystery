--!strict

local Cleanup = require(script.Parent.Parent.Utilities:WaitForChild("Cleanup"))

export type LifecycleEventName =
	"RoundStarted"
	| "PhaseChanged"
	| "ParticipantInjured"
	| "ParticipantCritical"
	| "ParticipantIncapacitated"
	| "ParticipantEliminated"
	| "ParticipantGhostTransition"
	| "RoundEnded"
	| "RoundReset"

export type LifecycleEvent = {
	name: LifecycleEventName,
	roundId: number,
	revision: number,
	serverTime: number,
	payload: { [string]: unknown },
}

type Listener = (event: LifecycleEvent) -> ()

type RoundLifecycleState = {
	roundId: number,
	revision: number,
	listeners: { [LifecycleEventName]: { Listener } },
	cleanup: Cleanup.Cleanup,
	destroyed: boolean,
}

local RoundLifecycle = {}
RoundLifecycle.__index = RoundLifecycle

export type RoundLifecycle = typeof(
	setmetatable({} :: RoundLifecycleState, RoundLifecycle)
)

local EVENT_NAMES: { LifecycleEventName } = {
	"RoundStarted",
	"PhaseChanged",
	"ParticipantInjured",
	"ParticipantCritical",
	"ParticipantIncapacitated",
	"ParticipantEliminated",
	"ParticipantGhostTransition",
	"RoundEnded",
	"RoundReset",
}

function RoundLifecycle.new(): RoundLifecycle
	local listeners = {}
	for _, eventName in EVENT_NAMES do
		listeners[eventName] = {}
	end

	return setmetatable({
		roundId = 0,
		revision = 0,
		listeners = listeners,
		cleanup = Cleanup.new(),
		destroyed = false,
	}, RoundLifecycle)
end

function RoundLifecycle:GetRoundId(): number
	return self.roundId
end

function RoundLifecycle:GetRevision(): number
	return self.revision
end

function RoundLifecycle:BeginRound(roundId: number)
	assert(roundId > self.roundId, "Round IDs must increase")
	self.roundId = roundId
	self.revision = 0
	self:Emit("RoundStarted", {})
end

function RoundLifecycle:On(eventName: LifecycleEventName, listener: Listener): () -> ()
	assert(not self.destroyed, "Cannot subscribe to a destroyed lifecycle")
	local listeners = self.listeners[eventName]
	assert(listeners, "Unknown lifecycle event: " .. eventName)
	table.insert(listeners, listener)

	local connected = true
	local function disconnect()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end

	-- Not registered with self.cleanup: Destroy() clears the listener tables
	-- directly, and accumulating one closure per subscription for the server
	-- lifetime leaked every disconnected listener and its upvalues.
	return disconnect
end

function RoundLifecycle:Emit(
	eventName: LifecycleEventName,
	payload: { [string]: unknown }
): LifecycleEvent
	assert(not self.destroyed, "Cannot emit from a destroyed lifecycle")
	self.revision += 1

	local event: LifecycleEvent = {
		name = eventName,
		roundId = self.roundId,
		revision = self.revision,
		serverTime = workspace:GetServerTimeNow(),
		payload = payload,
	}

	local listeners = table.clone(self.listeners[eventName])
	for _, listener in listeners do
		local success, message = pcall(listener, event)
		if not success then
			warn(
				string.format(
					"[RoundLifecycle] %s listener failed: %s",
					eventName,
					tostring(message)
				)
			)
		end
	end

	return event
end

function RoundLifecycle:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.cleanup:Destroy()
	for _, listeners in self.listeners do
		table.clear(listeners)
	end
end

return RoundLifecycle
