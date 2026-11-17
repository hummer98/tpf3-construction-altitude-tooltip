-- Pure helpers for the build-cursor altitude line (no engine access, testable
-- offline). The engine-facing glue lives in cht.script.lua.
local M = {}

local function isNumber(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Altitude of the placement point: the first construction's origin z. For a
-- template this is the first construction in the proposal (not verified to
-- be the one under the cursor); one number keeps the line short. World z is
-- what the game itself shows as altitude (TerrainTooltip "Height" mode
-- prints mouse terrain pos.z).
--   origins : list of origin z values (false for unknown entries)
function M.placementAltitude(origins)
	for i = 1, #(origins or {}) do
		if isNumber(origins[i]) then return origins[i] end
	end
	return nil
end

-- Use the game's own altitude formatter when it works, so units and number
-- style match the terrain tooltip; fall back to plain metres.
function M.formatAltitude(label, z, formatFn)
	if math.abs(z) < 0.05 then z = 0 end -- avoid "-0.0 m"
	if type(formatFn) == "function" then
		local ok, s = pcall(formatFn, z, 1)
		if ok and type(s) == "string" and s ~= "" then
			return string.format("%s: %s", label, s)
		end
	end
	return string.format("%s: %.1f m", label, z)
end

-- Resolve a strings.json key with the game's _(), falling back when the
-- key is missing (then _() echoes the key back) or _ is unavailable.
function M.label(translate, key, fallback)
	if type(translate) ~= "function" then return fallback end
	local ok, v = pcall(translate, key)
	if not ok or type(v) ~= "string" or v == "" or v == key then return fallback end
	return v
end

-- Copy the strings another layer produced so we never mutate a list the
-- caller (base reputation line, other mods) might keep.
function M.appendLine(base, line)
	local out = {}
	for i = 1, #(base or {}) do out[i] = base[i] end
	if line then out[#out + 1] = line end
	return out
end

return M
