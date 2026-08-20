--!strict

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent:WaitForChild("Components"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local TipCatalog = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("TipCatalog")
)
local CosmeticCatalog = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CosmeticCatalog")
)

local LobbyView = {}

type BuildDeps = {
	addCanvasSizing: (scroll: ScrollingFrame, layout: UIListLayout) -> (),
	readNumber: (value: any, key: string, defaultValue: number) -> number,
	readString: (value: any, key: string, defaultValue: string) -> string,
	readBoolean: (value: any, key: string, defaultValue: boolean) -> boolean,
	asTable: (value: any) -> { any },
}

function LobbyView.Build(self: any, deps: BuildDeps)
	local lobby = Components.ElevatedPanel(self.root, "Lobby", "modal")
	lobby.AnchorPoint = Vector2.new(1, 1)
	lobby.Position = UDim2.new(1, -18, 1, -18)
	lobby.Size = UDim2.fromOffset(300, 196)
	local headerStrip = Instance.new("Frame")
	headerStrip.Name = "HeaderStrip"
	headerStrip.Size = UDim2.new(1, 0, 0, 28)
	headerStrip.Position = UDim2.fromOffset(0, 0)
	headerStrip.BackgroundColor3 = Theme.Colors.WoodRust
	headerStrip.BackgroundTransparency = 0.30
	headerStrip.BorderSizePixel = 0
	headerStrip.ZIndex = 1
	headerStrip.Parent = lobby
	Components.Corner(headerStrip)
	local text = Components.Label(
		lobby,
		"LobbyText",
		"CAMPERS ARE ARRIVING",
		Theme.Typography.CaptionSize,
		Theme.Typography.HeadingFont
	)
	text.Position = UDim2.fromOffset(12, 4)
	text.Size = UDim2.new(1, -24, 0, 20)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextColor3 = Theme.Colors.Gold
	text.ZIndex = 2

	local routeChip = Components.Label(
		lobby,
		"RouteChip",
		"ROUTE  —",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	routeChip.AnchorPoint = Vector2.new(0.5, 0)
	routeChip.Position = UDim2.new(0.5, 0, 0, 28)
	routeChip.Size = UDim2.fromOffset(268, 22)
	routeChip.TextXAlignment = Enum.TextXAlignment.Center
	routeChip.TextColor3 = Theme.Colors.Text
	routeChip.BackgroundColor3 = Theme.Colors.MossStone
	routeChip.BackgroundTransparency = 0.15
	routeChip.Visible = false
	routeChip.ZIndex = 2
	Components.Corner(routeChip, 11)

	local roster = Instance.new("ScrollingFrame")
	roster.Name = "Roster"
	roster.Position = UDim2.fromOffset(18, 50)
	roster.Size = UDim2.new(1, -36, 0, 254)
	roster.BackgroundTransparency = 1
	roster.BorderSizePixel = 0
	roster.CanvasSize = UDim2.fromOffset(0, 0)
	roster.ScrollBarThickness = 4
	roster.Visible = false
	roster.Parent = lobby
	local rosterLayout = Components.List(roster, 6)
	deps.addCanvasSizing(roster, rosterLayout)

	local tip = Components.Panel(lobby, "CampTip")
	tip.Position = UDim2.fromOffset(18, 312)
	tip.Size = UDim2.new(1, -36, 0, 118)
	tip.Visible = false
	tip.BackgroundColor3 = Theme.Colors.MossStone
	local tipCategory = Components.Label(
		tip,
		"Category",
		"",
		Theme.Typography.CaptionSize,
		Theme.Typography.CaptionFont
	)
	tipCategory.Position = UDim2.fromOffset(14, 9)
	tipCategory.Size = UDim2.new(1, -28, 0, 20)
	tipCategory.TextColor3 = Theme.Colors.Gold
	local tipBody = Components.Label(
		tip,
		"Body",
		"",
		Theme.Typography.BodySize,
		Theme.Typography.BodyFont
	)
	tipBody.Position = UDim2.fromOffset(14, 31)
	tipBody.Size = UDim2.new(1, -28, 0, 74)
	tipBody.TextWrapped = true
	tipBody.TextYAlignment = Enum.TextYAlignment.Top

	local ready = Components.Button(lobby, {
		name = "Ready",
		text = "SIGN UP TONIGHT",
		size = UDim2.new(1, -24, 0, 52),
		position = UDim2.fromOffset(12, 38),
		color = Theme.Colors.Success,
	})
	ready.Activated:Connect(function()
		local enrolling = ready.Text ~= "WITHDRAW"
		self.lastActionControl = ready
		local sent, reason = self.actionHandler(if enrolling then "Enroll" else "Withdraw", {})
		if not sent then
			Motion.Shake(ready)
			self.lastActionControl = nil
			self:Notify("Not available", reason or "Sign-up is not active.", "Warning")
		end
	end)
	local progression = Components.Button(lobby, {
		name = "Progression",
		text = "PROGRESS",
		size = UDim2.new(1, -24, 0, 44),
		position = UDim2.fromOffset(12, 98),
		color = Theme.Colors.Gold,
	})
	progression.TextColor3 = Theme.Colors.Background
	progression.Activated:Connect(function()
		self:ToggleProgression()
	end)

	local invite = Components.Button(lobby, {
		name = "InviteFriends",
		text = "INVITE",
		size = UDim2.fromOffset(72, 34),
		position = UDim2.new(1, -84, 0, 4),
		color = Theme.Colors.Info,
	})
	invite.ZIndex = 3
	invite.Activated:Connect(function()
		pcall(function()
			SocialService:PromptGameInvite(Players.LocalPlayer)
		end)
	end)

	local quickCamp = Components.Button(lobby, {
		name = "QuickCampToggle",
		text = "FULL CAMP (~16m)",
		size = UDim2.new(1, -24, 0, 34),
		position = UDim2.fromOffset(12, 148),
		color = Theme.Colors.Panel,
	})
	quickCamp.Activated:Connect(function()
		local preferQuick = false
		local current = self.currentState
		if type(current) == "table" and type(current.profile) == "table" then
			local settings = current.profile.profile.settings
			if type(settings) == "table" and settings.preferQuickCamp == true then
				preferQuick = true
			end
		end
		self.lastActionControl = quickCamp
		local sent, reason = self.actionHandler("SetSettings", {
			settings = { preferQuickCamp = not preferQuick },
		})
		if not sent then
			Motion.Shake(quickCamp)
			self.lastActionControl = nil
			self:Notify("Not available", reason or "Could not update camp pace.", "Warning")
		end
	end)

	local countdown = Components.Label(
		self.root,
		"LobbyCountdown",
		"",
		Theme.Typography.DisplaySize * 2,
		Theme.Typography.DisplayFont
	)
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.26)
	countdown.Size = UDim2.fromOffset(220, 90)
	countdown.TextXAlignment = Enum.TextXAlignment.Center
	countdown.TextColor3 = Theme.Colors.Gold
	countdown.Visible = false
	countdown.ZIndex = 45
	local countdownScale = Instance.new("UIScale")
	countdownScale.Scale = 1
	countdownScale.Parent = countdown

	self.readyButton = ready
	self.lobbyText = text
	self.lobbyRouteChip = routeChip
	self.lobbyRoster = roster
	self.lobbyTip = tip
	self.lobbyTipCategory = tipCategory
	self.lobbyTipBody = tipBody
	self.lobbyCountdown = countdown
	self.lobbyCountdownScale = countdownScale
	self.lobbyPanel = lobby
	self.quickCampButton = quickCamp
	local featuredId = CosmeticCatalog.GetFeaturedCosmeticId()
	local featured = CosmeticCatalog.byId[featuredId]
	if featured then
		tipCategory.Text = "FEATURED"
		tipBody.Text = string.format(
			"This week: %s — discounted camp tokens in Progress. Never Robux.",
			featured.displayName
		)
	else
		-- Default discovery sell: Fairgrounds + rotating night routes
		tipCategory.Text = "FAIRGROUNDS"
		tipBody.Text =
			"Day: Midway Festival northeast of camp. Night: Midnight Circus (optional tickets). Routes rotate — watch the Route chip."
	end
end

function LobbyView.RebuildRoster(self: any, lobby: any, deps: BuildDeps)
	local players = deps.asTable(lobby.players)
	local target = math.max(#players, math.floor(deps.readNumber(lobby, "standardTarget", 10)))
	local signatureParts: { string } = { tostring(target) }
	for _, entry in players do
		if type(entry) == "table" then
			table.insert(signatureParts, string.format(
				"%d:%s:%s",
				math.floor(deps.readNumber(entry, "userId", 0)),
				deps.readString(entry, "displayName", ""),
				deps.readString(entry, "status", "Waiting")
			))
		end
	end
	local signature = table.concat(signatureParts, "|")
	if signature == self.lobbyRosterSignature then
		return
	end
	local previousSignature = self.lobbyRosterSignature
	self.lobbyRosterSignature = signature
	Components.ClearGenerated(self.lobbyRoster)
	local nextReadyStates: { [number]: boolean } = {}
	for index = 1, target do
		local entry = players[index]
		local card = Components.Panel(self.lobbyRoster, "RosterCard_" .. tostring(index))
		card:SetAttribute("Generated", true)
		card.LayoutOrder = index
		card.Size = UDim2.new(1, -8, 0, 48)
		card.BackgroundColor3 = Theme.Notebook.PageColor
		card.BackgroundTransparency = 0
		local name = Components.Label(
			card,
			"DisplayName",
			"Waiting for players...",
			Theme.Typography.BodySize,
			Theme.Typography.BodyFont
		)
		name.Position = UDim2.fromOffset(16, 0)
		name.Size = UDim2.new(1, -58, 1, 0)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = Theme.Notebook.InkMuted
		local dot = Instance.new("Frame")
		dot.Name = "ReadyDot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(1, -24, 0.5, 0)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = Theme.Colors.Border
		dot.BorderSizePixel = 0
		dot.Parent = card
		Components.Corner(dot, 6)
		if type(entry) == "table" then
			local userId = math.floor(deps.readNumber(entry, "userId", 0))
			local isReady = deps.readBoolean(entry, "isReady", false)
				or deps.readString(entry, "status", "Waiting") == "Locked"
			nextReadyStates[userId] = isReady
			name.Text = deps.readString(entry, "displayName", "Player")
			name.TextColor3 = Theme.Notebook.InkColor
			dot.BackgroundColor3 = if isReady then Theme.Colors.Success else Theme.Colors.Border
			if isReady and self.lobbyReadyStates[userId] ~= true then
				dot.BackgroundColor3 = Theme.Colors.Gold
				Motion.PopIn(card)
				if self.settingsValues.reducedMotion ~= true then
					TweenService:Create(
						dot,
						TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Theme.Colors.Success, Size = UDim2.fromOffset(16, 16) }
					):Play()
					task.delay(0.42, function()
						if dot.Parent then
							TweenService:Create(dot, TweenInfo.new(0.16), { Size = UDim2.fromOffset(12, 12) }):Play()
						end
					end)
				else
					dot.BackgroundColor3 = Theme.Colors.Success
				end
			end
		end
	end
	self.lobbyReadyStates = nextReadyStates
	if previousSignature ~= "" then
		Motion.StaggerChildren(self.lobbyRoster, {
			preset = "PopIn",
		})
	end
end

function LobbyView.ShimmerRoster(self: any)
	local reducedMotion = self.settingsValues.reducedMotion == true
	for _, child in self.lobbyRoster:GetChildren() do
		if child:IsA("Frame") and child:GetAttribute("Generated") == true then
			if reducedMotion then
				child.BackgroundColor3 = Theme.Notebook.PageColor
			else
				local gold = TweenService:Create(
					child,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundColor3 = Theme.Colors.Gold }
				)
				local cream = TweenService:Create(
					child,
					TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ BackgroundColor3 = Theme.Notebook.PageColor }
				)
				gold.Completed:Connect(function(playbackState: Enum.PlaybackState)
					if playbackState == Enum.PlaybackState.Completed and child.Parent then
						cream:Play()
					end
				end)
				gold:Play()
			end
		end
	end
end

function LobbyView.Update(self: any, state: any, phase: string, deps: BuildDeps)
	local lobby = if type(state) == "table" then state.lobby else nil
	local parent = self.readyButton.Parent
	if not parent or not parent:IsA("GuiObject") then
		return
	end
	local inLobby = phase == "Lobby"
	if inLobby then
		Motion.Cancel(parent)
		parent.Visible = true
		parent.BackgroundTransparency = Theme.PanelTransparency
	elseif self.lobbyWasVisible and parent.Visible then
		Motion.FadeOut(parent, {
			duration = 0.4,
			onComplete = function(_completed: boolean)
				if parent.Parent and not self.lobbyWasVisible then
					parent.Visible = false
				end
			end,
		})
	else
		parent.Visible = false
	end
	self.lobbyWasVisible = inLobby
	self.healthPanel.Visible = phase ~= "Lobby"
	self.hotbar.Visible = phase ~= "Lobby"
	if not inLobby then
		self.lobbyCountdown.Visible = false
		self.lobbyCountdownSecond = -1
		return
	end
	if type(lobby) ~= "table" then
		self.lobbyText.Text = "The next mystery begins soon."
		Components.SetButtonEnabled(self.readyButton, false)
		return
	end
	local humans = deps.readNumber(lobby, "humanCount", 0)
	local readyCount = deps.readNumber(lobby, "readyCount", 0)
	local target = deps.readNumber(lobby, "standardTarget", 10)
	self.lobbyText.Text = string.format("CAMPERS  %d/%d     READY  %d", humans, target, readyCount)
	local preferCount = deps.readNumber(lobby, "quickCampPreferCount", 0)
	local readyCamp = deps.readNumber(lobby, "quickCampReadyCount", 0)
	if readyCamp > 0 then
		self.lobbyText.Text ..= string.format("     QUICK %d/%d", preferCount, readyCamp)
	end
	local preferQuick = false
	if type(state) == "table" and type(state.profile) == "table" then
		local settings = state.profile.profile.settings
		if type(settings) == "table" and settings.preferQuickCamp == true then
			preferQuick = true
		end
	end
	if self.quickCampButton then
		self.quickCampButton.Text = if preferQuick then "QUICK CAMP (~7m)" else "FULL CAMP (~16m)"
	end
	local fillRemaining = math.max(
		0,
		math.ceil(deps.readNumber(lobby, "fillEndsAt", 0) - Workspace:GetServerTimeNow())
	)
	if fillRemaining > 0 then
		self.lobbyText.Text ..= string.format("     FILL  %ds", fillRemaining)
	end
	local routeLabel = ""
	local routeDisplay = deps.readString(lobby, "nightRouteDisplayName", "")
	local nightRoute = deps.readString(lobby, "nightRoute", "")
	if nightRoute == "" then
		nightRoute = deps.readString(lobby, "worldRoute", "")
	end
	if type(state) == "table" then
		local world = state.world
		local round = state.round
		if routeDisplay == "" and type(world) == "table" then
			nightRoute = deps.readString(world, "nightRoute", nightRoute)
			if nightRoute == "" then
				nightRoute = deps.readString(world, "worldRoute", "")
			end
		end
		if routeDisplay == "" and type(round) == "table" then
			if nightRoute == "" then
				nightRoute = deps.readString(round, "nightRoute", "")
			end
			if nightRoute == "" then
				nightRoute = deps.readString(round, "worldRoute", "")
			end
		end
	end
	if routeDisplay ~= "" then
		routeLabel = routeDisplay
	elseif nightRoute ~= "" then
		routeLabel = nightRoute
	end
	if self.lobbyRouteChip then
		if routeLabel ~= "" then
			self.lobbyRouteChip.Text = "NIGHT ROUTE  " .. string.upper(routeLabel)
			self.lobbyRouteChip.Visible = true
		else
			self.lobbyRouteChip.Text = "NIGHT ROUTES  ROTATE EACH ROUND"
			self.lobbyRouteChip.Visible = true
		end
	end
	local tipIndex = self.lobbyTipIndex
	if #TipCatalog.definitions > 0 then
		local tip = TipCatalog.definitions[((tipIndex - 1) % #TipCatalog.definitions) + 1]
		if tip then
			self.lobbyTipCategory.Text = tip.category
			self.lobbyTipBody.Text = tip.body
		end
		if os.clock() - self.lobbyTipChangedAt > 18 then
			self.lobbyTipIndex = (tipIndex % #TipCatalog.definitions) + 1
			self.lobbyTipChangedAt = os.clock()
		end
	end
	self.lobbyTip.Visible = true
	local players = deps.asTable(lobby.players)
	LobbyView.RebuildRoster(self, lobby, deps)
	local isReady = false
	for _, entry in players do
		if type(entry) == "table" and entry.userId == Players.LocalPlayer.UserId then
			isReady = deps.readBoolean(entry, "isReady", false)
			break
		end
	end
	self.readyButton.Text = if isReady then "WITHDRAW" else "SIGN UP TONIGHT"
	Components.SetButtonEnabled(self.readyButton, true)
	local fillStartedAt = deps.readNumber(lobby, "fillStartedAt", 0)
	local fillSignature = if fillStartedAt > 0 then tostring(fillStartedAt) else ""
	if fillSignature ~= "" and fillSignature ~= self.lobbyFillSignature then
		LobbyView.ShimmerRoster(self)
	end
	self.lobbyFillSignature = fillSignature
end

return LobbyView
