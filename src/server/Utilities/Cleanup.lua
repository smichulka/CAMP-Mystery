--!strict

export type CleanupTask = RBXScriptConnection | Instance | (() -> ())

type CleanupState = {
	tasks: { CleanupTask },
	destroyed: boolean,
}

local Cleanup = {}
Cleanup.__index = Cleanup

export type Cleanup = typeof(setmetatable({} :: CleanupState, Cleanup))

function Cleanup.new(): Cleanup
	return setmetatable({
		tasks = {},
		destroyed = false,
	}, Cleanup)
end

function Cleanup:Add(taskToClean: CleanupTask): CleanupTask
	if self.destroyed then
		if typeof(taskToClean) == "RBXScriptConnection" then
			taskToClean:Disconnect()
		elseif typeof(taskToClean) == "Instance" then
			taskToClean:Destroy()
		else
			taskToClean()
		end
		return taskToClean
	end

	table.insert(self.tasks, taskToClean)
	return taskToClean
end

function Cleanup:Clean()
	for index = #self.tasks, 1, -1 do
		local taskToClean = self.tasks[index]
		self.tasks[index] = nil

		local kind = typeof(taskToClean)
		if kind == "RBXScriptConnection" then
			(taskToClean :: RBXScriptConnection):Disconnect()
		elseif kind == "Instance" then
			(taskToClean :: Instance):Destroy()
		else
			local success, message = pcall(taskToClean :: () -> ())
			if not success then
				warn("[Cleanup] Cleanup callback failed:", message)
			end
		end
	end
end

function Cleanup:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:Clean()
end

return Cleanup

