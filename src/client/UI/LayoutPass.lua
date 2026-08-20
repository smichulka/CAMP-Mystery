--!strict

local Theme = require(script.Parent:WaitForChild("Theme"))

local LayoutPass = {}

type Deps = {
	isCompactViewport: (viewport: Vector2) -> boolean,
	ensureLayoutScale: (host: Instance, name: string) -> UIScale,
	ensureMinSizeConstraint: (host: Instance) -> UISizeConstraint,
	compactUiScale: number,
}

function LayoutPass.ApplyCompactTouchLayout(self: any, active: boolean, viewport: Vector2, deps: Deps)
	local topScale = deps.ensureLayoutScale(self.topStatus, "CompactTopScale")
	local missionScale = deps.ensureLayoutScale(self.missionPanel, "CompactMissionScale")
	local rosterPanel = self.rosterPanel
	local rosterScale = if rosterPanel then deps.ensureLayoutScale(rosterPanel, "CompactRosterScale") else nil
	local toastLayout = self.toastList:FindFirstChildOfClass("UIListLayout")
	local monsterPanel = self.monsterPanel
	local hauntPanel = self.hauntPanel
	local notebookButton = self.notebookButton
	local settingsButton = self.settingsButton
	local codexButton = self.codexButton
	local lobby = self.lobbyPanel
	local voteMin = deps.ensureMinSizeConstraint(self.voteModal)
	local targetMin = deps.ensureMinSizeConstraint(self.targetModal)
	local resultMin = deps.ensureMinSizeConstraint(self.resultModal)

	if active then
		self.root.AnchorPoint = Vector2.new(0.5, 0)
		self.root.Position = UDim2.fromScale(0.5, 0)
		topScale.Scale = 0.85
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.new(0.5, 0, 0, 6)
		self.topStatus.Size = UDim2.fromOffset(460, 96)
		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -6, 0, 6)
		self.menuPanel.Size = UDim2.fromOffset(118, 112)
		if notebookButton then
			notebookButton.Size = UDim2.fromOffset(112, 44)
			notebookButton.Position = UDim2.fromOffset(6, 0)
		end
		if settingsButton then
			settingsButton.Size = UDim2.fromOffset(112, 44)
			settingsButton.Position = UDim2.fromOffset(6, 38)
		end
		if codexButton then
			codexButton.Size = UDim2.fromOffset(112, 44)
			codexButton.Position = UDim2.fromOffset(6, 76)
		end
		missionScale.Scale = 0.8
		self.missionPanel.Position = UDim2.fromOffset(6, 6)
		self.missionPanel.Size = UDim2.fromOffset(280, 310)
		local halfX = viewport.X / 2
		local reserveSpan = math.max(0, (halfX - 180) / deps.compactUiScale)
		local leftClear = halfX - reserveSpan
		local rightClear = halfX + reserveSpan
		local healthX = leftClear + 8
		local hotbarX = healthX + 202
		self.healthPanel.AnchorPoint = Vector2.new(0, 1)
		self.healthPanel.Position = UDim2.new(0, healthX, 1, -10)
		self.healthPanel.Size = UDim2.fromOffset(190, 62)
		self.hotbar.AnchorPoint = Vector2.new(0, 1)
		self.hotbar.Position = UDim2.new(0, hotbarX, 1, -8)
		self.hotbar.Size = UDim2.new(0, math.max(120, rightClear - 12 - hotbarX), 0, 74)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -92)
		self.interaction.Size = UDim2.fromOffset(360, 54)
		self.toastList.AnchorPoint = Vector2.new(0.5, 0)
		self.toastList.Position = UDim2.new(0.5, 0, 0, 104)
		self.toastList.Size = UDim2.fromOffset(340, 150)
		if toastLayout then
			toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		end
		self.announcement.Size = UDim2.fromOffset(440, 82)
		if rosterPanel then
			rosterPanel.AnchorPoint = Vector2.new(1, 0)
			rosterPanel.Position = UDim2.new(1, -6, 0, 132)
		end
		if rosterScale then
			rosterScale.Scale = 0.72
		end
		if monsterPanel then
			monsterPanel.Position = UDim2.new(1, -6, 1, -140)
		end
		if hauntPanel then
			hauntPanel.Position = UDim2.new(1, -140, 0, 110)
		end
		if lobby then
			lobby.AnchorPoint = Vector2.new(0.5, 1)
			lobby.Position = UDim2.new(0.5, 0, 1, -10)
			lobby.Size = UDim2.new(0, math.min(520, math.max(300, rightClear - leftClear - 16)), 0, 228)
			local strip = lobby:FindFirstChild("HeaderStrip")
			if strip and strip:IsA("GuiObject") then
				strip.Size = UDim2.new(1, 0, 0, 32)
			end
			local progressionButton = lobby:FindFirstChild("Progression")
			if progressionButton and progressionButton:IsA("GuiObject") then
				progressionButton.Position = UDim2.new(0.55, 6, 0, 168)
				progressionButton.Size = UDim2.new(0.45, -24, 0, 48)
			end
			self.lobbyText.Position = UDim2.fromOffset(18, 4)
			self.lobbyText.Size = UDim2.new(1, -36, 0, 26)
			self.lobbyRoster.Visible = true
			self.lobbyRoster.Position = UDim2.fromOffset(18, 36)
			self.lobbyRoster.Size = UDim2.new(1, -36, 0, 56)
			self.lobbyTip.Visible = true
			self.lobbyTip.Position = UDim2.fromOffset(18, 96)
			self.lobbyTip.Size = UDim2.new(1, -36, 0, 44)
			self.readyButton.Position = UDim2.fromOffset(18, 148)
			self.readyButton.Size = UDim2.new(0.55, -24, 0, 48)
		end
		voteMin.MinSize = Vector2.new(440, 300)
		targetMin.MinSize = Vector2.new(380, 300)
		resultMin.MinSize = Vector2.new(460, 280)
	else
		self.root.AnchorPoint = Vector2.new(0, 0)
		self.root.Position = UDim2.fromScale(0, 0)
		topScale.Scale = 1
		missionScale.Scale = 1
		if notebookButton then
			notebookButton.Size = UDim2.fromOffset(130, 44)
		end
		if settingsButton then
			settingsButton.Size = UDim2.fromOffset(130, 44)
		end
		if codexButton then
			codexButton.Size = UDim2.fromOffset(130, 44)
		end
		self.healthPanel.AnchorPoint = Vector2.new(0, 1)
		self.toastList.AnchorPoint = Vector2.new(1, 1)
		if toastLayout then
			toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
		if rosterPanel then
			rosterPanel.AnchorPoint = Vector2.new(1, 1)
			rosterPanel.Position = UDim2.new(1, -18, 1, -96)
		end
		if rosterScale then
			rosterScale.Scale = 1
		end
		if monsterPanel then
			monsterPanel.Position = UDim2.new(1, -16, 1, -88)
		end
		if hauntPanel then
			hauntPanel.Position = UDim2.new(1, -18, 0, 158)
		end
		if lobby then
			local strip = lobby:FindFirstChild("HeaderStrip")
			if strip and strip:IsA("GuiObject") then
				strip.Size = UDim2.new(1, 0, 0, 28)
			end
			self.lobbyText.Position = UDim2.fromOffset(12, 4)
			self.lobbyText.Size = UDim2.new(1, -24, 0, 20)
			self.lobbyRoster.Visible = true
			self.lobbyRoster.Position = UDim2.fromOffset(12, 28)
			self.lobbyRoster.Size = UDim2.new(1, -24, 0, 54)
			self.lobbyTip.Visible = true
			self.lobbyTip.Position = UDim2.fromOffset(12, 86)
			self.lobbyTip.Size = UDim2.new(1, -24, 0, 48)
			self.readyButton.Position = UDim2.fromOffset(12, 140)
			self.readyButton.Size = UDim2.new(1, -24, 0, 44)
			local progressionButton = lobby:FindFirstChild("Progression")
			if progressionButton and progressionButton:IsA("GuiObject") then
				progressionButton.Position = UDim2.fromOffset(12, 190)
				progressionButton.Size = UDim2.new(1, -24, 0, 40)
			end
			lobby.Size = UDim2.fromOffset(300, 238)
		end
		voteMin.MinSize = Vector2.zero
		targetMin.MinSize = Vector2.zero
		resultMin.MinSize = Vector2.zero
	end
end

function LayoutPass.UpdateLayout(self: any, deps: Deps)
	if self.destroyed then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local narrow = viewport.X < Theme.Breakpoints.narrow
	local compact = not narrow and (viewport.X < Theme.Breakpoints.compact or viewport.Y < Theme.Breakpoints.narrow)
	self.uiScale.Scale = 1
	local compactTouch = deps.isCompactViewport(viewport)
	if compactTouch then
		narrow = false
		compact = false
		self.uiScale.Scale = deps.compactUiScale
	end

	if narrow then
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.new(0.5, 0, 0, 8)
		self.topStatus.Size = UDim2.new(1, -16, 0, 80)
		self.menuPanel.AnchorPoint = Vector2.new(0.5, 0)
		self.menuPanel.Position = UDim2.new(0.5, 0, 0, 94)
		self.menuPanel.Size = UDim2.fromOffset(280, 42)
		if self.notebookButton then self.notebookButton.Position = UDim2.fromOffset(6, 0) end
		if self.settingsButton then self.settingsButton.Position = UDim2.fromOffset(144, 0) end
		if self.codexButton then self.codexButton.Position = UDim2.fromOffset(6, 46) end
		self.missionPanel.Position = UDim2.fromOffset(8, 142)
		self.missionPanel.Size = UDim2.new(1, -16, 0, 310)
		self.healthPanel.Position = UDim2.new(0, 8, 1, -92)
		self.healthPanel.Size = UDim2.new(1, -16, 0, 66)
		self.hotbar.AnchorPoint = Vector2.new(0.5, 1)
		self.hotbar.Position = UDim2.new(0.5, 0, 1, -8)
		self.hotbar.Size = UDim2.new(1, -16, 0, 76)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -166)
		self.interaction.Size = UDim2.new(1, -20, 0, 60)
		self.toastList.Position = UDim2.new(1, -8, 1, -170)
		self.toastList.Size = UDim2.new(1, -16, 0, 210)
		self.announcement.Size = UDim2.new(1, -16, 0, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(0.5, 1)
			self.lobbyPanel.Position = UDim2.new(0.5, 0, 1, -8)
			self.lobbyPanel.Size = UDim2.new(1, -16, 0, 172)
		end
	elseif compact then
		self.topStatus.AnchorPoint = Vector2.new(1, 0)
		self.topStatus.Position = UDim2.new(1, -10, 0, 10)
		self.topStatus.Size = UDim2.new(1, -310, 0, 96)
		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -10, 0, 114)
		self.menuPanel.Size = UDim2.fromOffset(140, 94)
		if self.notebookButton then self.notebookButton.Position = UDim2.fromOffset(10, 0) end
		if self.settingsButton then self.settingsButton.Position = UDim2.fromOffset(10, 48) end
		if self.codexButton then self.codexButton.Position = UDim2.fromOffset(10, 96) end
		self.missionPanel.Position = UDim2.fromOffset(10, 10)
		self.missionPanel.Size = UDim2.fromOffset(280, 310)
		self.healthPanel.Position = UDim2.new(0, 10, 1, -10)
		self.healthPanel.Size = UDim2.fromOffset(220, 66)
		self.hotbar.Position = UDim2.new(1, -10, 1, -10)
		self.hotbar.AnchorPoint = Vector2.new(1, 1)
		self.hotbar.Size = UDim2.new(1, -250, 0, 80)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -100)
		self.interaction.Size = UDim2.new(0.55, 0, 0, 60)
		self.toastList.Position = UDim2.new(1, -10, 1, -100)
		self.toastList.Size = UDim2.fromOffset(math.min(320, viewport.X - 20), 220)
		self.announcement.Size = UDim2.new(1, -310, 0, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(1, 1)
			self.lobbyPanel.Position = UDim2.new(1, -10, 1, -10)
			self.lobbyPanel.Size = UDim2.fromOffset(300, 172)
		end
	else
		self.topStatus.AnchorPoint = Vector2.new(0.5, 0)
		self.topStatus.Position = UDim2.fromScale(0.5, 0.018)
		self.topStatus.Size = UDim2.fromOffset(540, 96)
		self.menuPanel.AnchorPoint = Vector2.new(1, 0)
		self.menuPanel.Position = UDim2.new(1, -18, 0, 18)
		self.menuPanel.Size = UDim2.fromOffset(140, 94)
		if self.notebookButton then self.notebookButton.Position = UDim2.fromOffset(10, 0) end
		if self.settingsButton then self.settingsButton.Position = UDim2.fromOffset(10, 48) end
		if self.codexButton then self.codexButton.Position = UDim2.fromOffset(10, 96) end
		self.missionPanel.Position = UDim2.fromOffset(18, 18)
		self.missionPanel.Size = UDim2.fromOffset(310, 310)
		self.healthPanel.Position = UDim2.new(0, 18, 1, -18)
		self.healthPanel.Size = UDim2.fromOffset(270, 66)
		self.hotbar.AnchorPoint = Vector2.new(0.5, 1)
		self.hotbar.Position = UDim2.new(0.5, 0, 1, -18)
		self.hotbar.Size = UDim2.new(0.52, 0, 0, 80)
		self.interaction.Position = UDim2.new(0.5, 0, 1, -112)
		self.interaction.Size = UDim2.fromOffset(390, 60)
		self.toastList.Position = UDim2.new(1, -18, 1, -122)
		self.toastList.Size = UDim2.fromOffset(360, 250)
		self.announcement.Size = UDim2.fromOffset(520, 82)
		if self.lobbyPanel then
			self.lobbyPanel.AnchorPoint = Vector2.new(1, 1)
			self.lobbyPanel.Position = UDim2.new(1, -18, 1, -18)
			self.lobbyPanel.Size = UDim2.fromOffset(300, 172)
		end
	end

	LayoutPass.ApplyCompactTouchLayout(self, compactTouch, viewport, deps)

	if narrow then
		for _, modal in { self.notebook, self.settings, self.voteModal, self.resultModal, self.targetModal, self.progression } do
			modal.Size = UDim2.new(1, -16, 1, -24)
		end
		local resultContinue = self.resultModal:FindFirstChild("Continue")
		local resultProgression = self.resultModal:FindFirstChild("Progression")
		if resultContinue and resultContinue:IsA("GuiObject") then
			resultContinue.Size = UDim2.new(0.5, -18, 0, 44)
			resultContinue.Position = UDim2.new(0.5, 6, 1, -64)
		end
		if resultProgression and resultProgression:IsA("GuiObject") then
			resultProgression.Size = UDim2.new(0.5, -18, 0, 44)
			resultProgression.Position = UDim2.new(0, 12, 1, -64)
		end
	else
		self.notebook.Size = UDim2.new(0.72, 0, 0.72, 0)
		self.settings.Size = UDim2.new(0.58, 0, 0.76, 0)
		self.voteModal.Size = UDim2.new(0.46, 0, 0.64, 0)
		self.resultModal.Size = UDim2.new(0.52, 0, 0.5, 0)
		self.targetModal.Size = UDim2.new(0.4, 0, 0.62, 0)
		self.progression.Size = UDim2.new(0.72, 0, 0.78, 0)
		local resultContinue = self.resultModal:FindFirstChild("Continue")
		local resultProgression = self.resultModal:FindFirstChild("Progression")
		if resultContinue and resultContinue:IsA("GuiObject") then
			resultContinue.Size = UDim2.fromOffset(170, 44)
			resultContinue.Position = UDim2.new(0.5, 8, 1, -64)
		end
		if resultProgression and resultProgression:IsA("GuiObject") then
			resultProgression.Size = UDim2.fromOffset(170, 44)
			resultProgression.Position = UDim2.new(0.5, -178, 1, -64)
		end
	end
end

return LayoutPass
