-- Adds "Altitude: N m" (placement point) to the build-cursor tooltip of
-- construction placement.
--
-- The cost line under the cursor is drawn by the C++ ConstructionAction; the
-- only Lua extension point is the action's getProposalStringsFn (base uses it
-- for the "Reputation: -x%" line, construction_react_util.tl). The action is
-- built by the exported construction_react_util.getActionParams, which
-- construction.tl calls through the module table, so wrapping that function
-- before the UI starts reaches every tool without overriding a base file.
-- Other installed mods (Gleisbauanzeige, UI Overhaul) wrap the same function;
-- we chain to whatever was there and keep their lines.
local core = require "hummer_construction_altitude_tooltip::/gui/cht_core.lua"

-- Logs only failures, once each: the line runs on every cursor move.
local reported = {}
local function reportOnce(key, msg)
	if not reported[key] then
		reported[key] = true
		debugPrint("[CHT] " .. msg)
	end
end

local function originZ(transf)
	if transf == nil then return nil end
	-- Mat4f is column-major with 1-based __index; 15 = translation z. Read it
	-- directly: this runs on every cursor move and needs no API allocation.
	local ok, z = pcall(function() return transf[15] end)
	if ok and type(z) == "number" then return z end
	ok, z = pcall(function()
		return transf:transformPosition(api.type.Vec3f.new(0, 0, 0)).z
	end)
	if ok and type(z) == "number" then return z end
	return nil
end

-- Origin z of the construction to add. It already includes the toolbar
-- "Height" slider (in game the origin moved 3 m per 3 m slider step), so
-- the shown altitude follows raising and lowering without extra work.
-- proposal.toAdd converts every construction (subconstructions included)
-- to Lua on each cursor move (17-18 ms seen for large ones); base reads
-- toAdd_native:at(1).transf (industry_util.tl), so try that first and only
-- fall back to the converted list if it fails.
local function readOrigins(proposal)
	if proposal == nil then return {} end
	local ok, transf = pcall(function() return proposal.toAdd_native:at(1).transf end)
	local z = ok and originZ(transf) or nil
	if z then return { z } end
	local origins = {}
	local toAdd = proposal.toAdd or {}
	for i = 1, #toAdd do
		local entry = toAdd[i]
		origins[i] = entry and originZ(entry.transf) or false
		if origins[i] then break end -- only the first known origin is shown
	end
	return origins
end

-- Looked up under pcall: in an API-restricted context touching api.util
-- may throw, and the plain-metres fallback should still be shown.
local function altitudeFormatter()
	local ok, fn = pcall(function() return api.util.formatAltitude end)
	if ok and type(fn) == "function" then return fn end
	return nil
end

local function altitudeLine(proposal)
	local z = core.placementAltitude(readOrigins(proposal))
	if not z then return nil end
	return core.formatAltitude(core.label(_, "cht_altitude", "Altitude"), z, altitudeFormatter())
end

local function wrapAction(action)
	local original = action.getProposalStringsFn
	action.getProposalStringsFn = function(proposal, proposalData)
		local base = original and original(proposal, proposalData) or {}
		local ok, line = pcall(altitudeLine, proposal)
		if not ok then
			reportOnce("err", "altitude line failed: " .. tostring(line))
			line = nil
		end
		return core.appendLine(base, line)
	end
end

local function install()
	local cru = ug_require "::/gui/construction/construction_react_util.tl"
	if cru.__chtInstalled then return end
	local originalGetActionParams = cru.getActionParams
	local wrapped = setmetatable({}, { __mode = "k" })
	cru.getActionParams = function(...)
		local result = originalGetActionParams(...)
		local action = result and result.constructionActionParams
		if action and action.constructionBuilder ~= nil and not wrapped[action] then
			wrapped[action] = true
			wrapAction(action)
		end
		return result
	end
	cru.__chtInstalled = true
end

function data()
	return {
		prepare = function(_replacementApi)
			local ok, err = pcall(install)
			if not ok then debugPrint("[CHT] install failed: " .. tostring(err)) end
		end,
	}
end
