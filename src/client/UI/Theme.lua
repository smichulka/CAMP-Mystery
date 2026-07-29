--!strict

local Theme = {
	Colors = {
		-- Core UI palette
		Background = Color3.fromRGB(8, 12, 14),
		Panel = Color3.fromRGB(16, 22, 23),
		PanelRaised = Color3.fromRGB(24, 31, 31),
		PanelSoft = Color3.fromRGB(34, 42, 40),
		Border = Color3.fromRGB(93, 105, 94),
		Text = Color3.fromRGB(240, 235, 218),
		TextMuted = Color3.fromRGB(181, 183, 169),
		Gold = Color3.fromRGB(218, 172, 79),
		Amber = Color3.fromRGB(226, 127, 49),
		Danger = Color3.fromRGB(175, 54, 51),
		DangerBright = Color3.fromRGB(232, 81, 70),
		Success = Color3.fromRGB(79, 162, 107),
		Info = Color3.fromRGB(72, 139, 173),
		Ghost = Color3.fromRGB(126, 184, 203),
		White = Color3.fromRGB(255, 255, 255),
		Black = Color3.fromRGB(0, 0, 0),
		-- Environment-specific accents (drawn from cabin & old-town reference images)
		WoodRust = Color3.fromRGB(112, 78, 45),     -- weathered log cabin timber
		MossStone = Color3.fromRGB(68, 88, 60),     -- mossy cabin walls
		TinRoof = Color3.fromRGB(105, 102, 88),     -- corrugated tin roof grey
		FogMist = Color3.fromRGB(148, 158, 162),    -- abandoned town fog atmosphere
		RustedIron = Color3.fromRGB(130, 82, 42),   -- rusted water tower / old iron
		GhostTown = Color3.fromRGB(88, 90, 95),     -- desolate street pavement
	},
	CornerRadius = 10,
	SmallCornerRadius = 6,
	PanelTransparency = 0.08,
	StrokeTransparency = 0.38,
	AnimationTime = 0.18,
	Typography = {
		DisplayFont = Enum.Font.GothamBlack,
		HeadingFont = Enum.Font.GothamBold,
		BodyFont = Enum.Font.GothamMedium,
		CaptionFont = Enum.Font.Gotham,
		DisplaySize = 32,
		HeadingSize = 18,
		SubheadingSize = 15,
		BodySize = 13,
		CaptionSize = 11,
		LetterSpacing = 3,
	},
	Motion = {
		PopDuration = 0.25,
		SlideDuration = 0.24,
		FadeDuration = 0.18,
		ReducedFadeDuration = 0.12,
		HoverDuration = 0.12,
		PressDuration = 0.08,
		ReleaseDuration = 0.16,
		ShakeStepDuration = 0.035,
		StaggerDelay = 0.035,
		PopScale = 0.92,
		PressScale = 0.97,
		SlideOffset = 28,
		ShakeDistance = 8,
		PopEasingStyle = Enum.EasingStyle.Back,
		PopEasingDirection = Enum.EasingDirection.Out,
		ExitEasingStyle = Enum.EasingStyle.Quint,
		ExitEasingDirection = Enum.EasingDirection.In,
		StandardEasingStyle = Enum.EasingStyle.Quint,
		StandardEasingDirection = Enum.EasingDirection.Out,
	},
	Notebook = {
		PageColor = Color3.fromRGB(245, 238, 210),
		PageLines = Color3.fromRGB(180, 190, 200),
		InkColor = Color3.fromRGB(28, 32, 40),
		InkMuted = Color3.fromRGB(90, 95, 105),
		TapeColor = Color3.fromRGB(220, 200, 140),
		StampConfirmed = Color3.fromRGB(40, 120, 60),
		StampDenied = Color3.fromRGB(160, 40, 40),
		CardWidth = 280,
		CardHeight = 142,
		CardPadding = 10,
		LineHeight = 20,
	},
}

return table.freeze(Theme)
