--!strict

local Theme = {
	Colors = {
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
	},
	CornerRadius = 10,
	SmallCornerRadius = 6,
	PanelTransparency = 0.08,
	StrokeTransparency = 0.38,
	AnimationTime = 0.18,
}

return table.freeze(Theme)
