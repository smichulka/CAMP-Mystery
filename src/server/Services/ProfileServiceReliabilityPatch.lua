--!strict

local Players = game:GetService("Players")

local ProfileService = require(script.Parent:WaitForChild("ProfileService"))

local PATCH_MARKER = "__campMysteryReleaseRetryPatchApplied"
local PENDING_KEY = "__campMysteryPendingReleaseSaves"
local MAX_RETRY_DELAY_SECONDS = 30

type PendingRelease = {
	player: Player,
	state: any,
}

local ProfileServiceReliabilityPatch = {}

local function pendingReleases(service: any): { [number]: PendingRelease }
	local existing = service[PENDING_KEY]
	if existing then
		return existing
	end
	local created: { [number]: PendingRelease } = {}
	service[PENDING_KEY] = created
	return created
end

local function clearIfStillDeparted(service: any, userId: number, state: any)
	if service.profiles[userId] == state and Players:GetPlayerByUserId(userId) == nil then
		service.profiles[userId] = nil
	end
end

local function scheduleRetry(service: any, userId: number, entry: PendingRelease)
	task.spawn(function()
		local delaySeconds = 1
		local pending = pendingReleases(service)
		while service.running and pending[userId] == entry do
			task.wait(delaySeconds)
			if pending[userId] ~= entry then
				return
			end
			if Players:GetPlayerByUserId(userId) then
				pending[userId] = nil
				return
			end
			if service.profiles[userId] ~= entry.state then
				pending[userId] = nil
				return
			end

			local saved, reason = service:SavePlayer(entry.player)
			if saved or reason == "GuestMode" then
				clearIfStillDeparted(service, userId, entry.state)
				pending[userId] = nil
				return
			end
			warn(
				string.format(
					"[ProfileService] Release save retry failed for user %d: %s",
					userId,
					reason or "UnknownFailure"
				)
			)
			delaySeconds = math.min(delaySeconds * 2, MAX_RETRY_DELAY_SECONDS)
		end
	end)
end

function ProfileServiceReliabilityPatch.Apply()
	local class = ProfileService :: any
	if class[PATCH_MARKER] then
		return
	end
	class[PATCH_MARKER] = true

	local originalLoadPlayer = class.LoadPlayer
	local originalStop = class.Stop

	class.LoadPlayer = function(self: any, player: Player)
		local pending = pendingReleases(self)
		pending[player.UserId] = nil
		return originalLoadPlayer(self, player)
	end

	class.ReleasePlayer = function(self: any, player: Player): (boolean, string?)
		local userId = player.UserId
		local state = self.profiles[userId]
		if not state then
			return true, nil
		end

		local saved, reason = self:SavePlayer(player)
		if saved or reason == "GuestMode" then
			clearIfStillDeparted(self, userId, state)
			pendingReleases(self)[userId] = nil
			return saved, reason
		end

		local entry: PendingRelease = {
			player = player,
			state = state,
		}
		pendingReleases(self)[userId] = entry
		warn(
			string.format(
				"[ProfileService] Release save failed for user %d; retaining state for retry: %s",
				userId,
				reason or "UnknownFailure"
			)
		)
		scheduleRetry(self, userId, entry)
		return false, reason
	end

	class.Stop = function(self: any)
		local pending = pendingReleases(self)
		for userId, entry in pending do
			if self.profiles[userId] == entry.state then
				local saved, reason = self:SavePlayer(entry.player)
				if saved or reason == "GuestMode" then
					clearIfStillDeparted(self, userId, entry.state)
					pending[userId] = nil
				else
					warn(
						string.format(
							"[ProfileService] Final retained save failed for user %d: %s",
							userId,
							reason or "UnknownFailure"
						)
					)
				end
			else
				pending[userId] = nil
			end
		end
		return originalStop(self)
	end
end

return ProfileServiceReliabilityPatch
