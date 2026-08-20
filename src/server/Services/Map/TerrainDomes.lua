--!strict

-- Single source of truth for every terrain hill dome. buildCampTerrain fills
-- these; every prop-seating height model reads them through heightAt. Four
-- files used to carry hand-copied mirrors of the same layout ("keep in
-- lockstep" comments everywhere) and they drifted more than once — a dome
-- moved in one file seated props on ghost hills in another. Edit ONLY here.
--
-- Entry shape: { x, y, z, ballRadius, ground? } — ground=true fills
-- Material.Ground instead of Grass.
--
-- INTERIOR is the old 14-dome formula ring made explicit (2026-08-09). The
-- POI hills keep their exact formula positions — the waterfall cave, lookout
-- tower, Cabin Zero ruin, ranger station and mines are all BUILT INTO them.
-- The four non-POI domes moved outward: they used to stand within ~25 studs
-- of the cabins and counselor quarters ("hills very tight by the cabins"),
-- pinching the camp bowl.

export type DomeEntry = { number | boolean }

local INTERIOR: { { any } } = {
	{ 76.7, -3, 108.2, 24 }, -- waterfall bluff (falls + cave carved into it)
	{ 23.4, -2, 114.4, 26, true }, -- lookout hill (fire tower footings)
	{ -37, -3, 173, 24 }, -- north knoll (moved out of the bowl from -25,123)
	{ -76.7, -2, 108.2, 22 }, -- Cabin Zero hill (ruin sits on its toe)
	{ -152, -3, 84, 26, true }, -- west ridge (from -95,58 — crowded the quarters)
	{ -170, -2, 12, 28 }, -- far west knoll (from -114,12 — crowded Pine Cabin)
	{ -150, -3, -64, 22 }, -- southwest knoll (from -111,-41)
	{ -72, -2, -80, 22, true }, -- ranger hill (station stilts on its slope)
	{ 102.7, -2, -37.4, 22 }, -- mines bluff (sealed rock rooms inside)
}

-- Fifth-expansion boundary ring (830x670 slab north/west edges plus northeast
-- span along x ~250). Creek gate open at x ~112..168 north.
local OUTER: { { any } } = {
	{ 250, -3, 196, 30 },
	{ 252, -2, 258, 32 },
	{ 249, -3, 320, 30 },
	{ 251, -2, 382, 32 },
	{ 246, -3, 436, 32 },
	{ 248, -2, 486, 34 }, -- northeast corner
	{ 198, -3, 514, 30 }, -- east bank of the creek's north gate
	{ 92, -2, 516, 30 }, -- west bank of the creek's north gate
	{ 24, -2, 516, 32, true },
	{ -48, -3, 520, 32 },
	{ -120, -2, 514, 34 },
	{ -192, -3, 518, 32, true },
	{ -264, -2, 510, 34 },
	{ -336, -3, 516, 32 },
	{ -408, -2, 508, 34, true },
	{ -472, -3, 498, 32 }, -- turning the northwest corner
	{ -516, -2, 446, 34 },
	{ -534, -3, 380, 32, true },
	{ -524, -2, 314, 34 },
	{ -536, -3, 248, 32 },
	{ -526, -2, 182, 34, true },
	{ -534, -3, 116, 32 },
	{ -524, -2, 50, 34 },
	{ -532, -3, -16, 32, true },
	{ -566, -2, -68, 32 }, -- southwest corner above the town's west strip
}

-- Far-shore ridge enclosing the lake from the east. The old northeast corner
-- fillers are gone: the water-sports basin owns that meadow.
local FAR_SHORE: { { any } } = {
	{ 250, -3, -118, 28 },
	{ 252, -2, -84, 30 },
	{ 249, -3, -50, 26, true },
	{ 251, -2, -16, 32 },
	{ 250, -3, 18, 28 },
	{ 252, -2, 52, 30, true },
	{ 249, -3, 86, 26 },
	{ 251, -2, 120, 32 },
	{ 250, -3, 150, 28, true },
}

-- Analytic height of the dome layout at a point: flat slab base plus the
-- highest dome bulge. NOTE this is the NOMINAL model — the voxelized surface
-- renders ~2 studs higher on flat slab (see the raycast-first seat helpers
-- in LakeAndWilds/HighFrontier). Use for relative seating on slopes and as
-- the fallback where raycasts can't run.
local function heightAt(x: number, z: number): number
	local height = 0.5
	local function raiseFor(entry: { any })
		local dx = x - (entry[1] :: number)
		local dz = z - (entry[3] :: number)
		local ballRadius = entry[4] :: number
		local flat = math.sqrt(dx * dx + dz * dz)
		if flat < ballRadius - 0.5 then
			height = math.max(
				height,
				(entry[2] :: number) + math.sqrt(ballRadius * ballRadius - flat * flat)
			)
		end
	end
	for _, entry in INTERIOR do
		raiseFor(entry)
	end
	for _, entry in OUTER do
		raiseFor(entry)
	end
	for _, entry in FAR_SHORE do
		raiseFor(entry)
	end
	return height
end

return table.freeze({
	INTERIOR = table.freeze(INTERIOR),
	OUTER = table.freeze(OUTER),
	FAR_SHORE = table.freeze(FAR_SHORE),
	heightAt = heightAt,
})
