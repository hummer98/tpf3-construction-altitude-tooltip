-- Offline tests for the build-cursor altitude line. Run from anywhere:
--   luajit tests/run.lua
-- The game globals the script expects (api, ug_require, _, debugPrint) are
-- stubbed with just enough behaviour.

local root = (arg and arg[0] or "tests/run.lua"):match("^(.*)/tests/[^/]*$") or "."

local loaders = package.loaders or package.searchers
table.insert(loaders, 2, function(name)
	local rel = name:match("^hummer_construction_altitude_tooltip::/(.*)$")
	if rel then return assert(loadfile(root .. "/content/" .. rel)) end
end)

local failures, passes = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passes = passes + 1
		print("PASS " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error((msg or "values differ") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end
local function near(a, b, msg)
	if type(a) ~= "number" or math.abs(a - b) > 1e-6 then
		error((msg or "not near") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
	end
end

------------------------------------------------------------------------
-- cht_core (pure)
------------------------------------------------------------------------
local core = require "hummer_construction_altitude_tooltip::/gui/cht_core.lua"

test("placementAltitude: first known origin wins", function()
	near(core.placementAltitude({ 38.86, 50 }), 38.86)
	near(core.placementAltitude({ false, false, -4.1 }), -4.1)
end)

test("placementAltitude: empty / unknown / NaN / inf give nil", function()
	eq(core.placementAltitude(nil), nil)
	eq(core.placementAltitude({}), nil)
	eq(core.placementAltitude({ false }), nil)
	eq(core.placementAltitude({ 0 / 0 }), nil)
	eq(core.placementAltitude({ math.huge }), nil)
	eq(core.placementAltitude({ "12" }), nil)
end)

test("formatAltitude: plain metres, one decimal, negatives, no -0.0", function()
	eq(core.formatAltitude("標高", 38.864), "標高: 38.9 m")
	eq(core.formatAltitude("標高", -4.1), "標高: -4.1 m")
	eq(core.formatAltitude("標高", -0.01), "標高: 0.0 m")
end)

test("formatAltitude: uses the game formatter, falls back when it fails", function()
	local seen
	local fmt = function(v, d) seen = d; return string.format("%.1f m*", v) end
	eq(core.formatAltitude("標高", 12.34, fmt), "標高: 12.3 m*")
	eq(seen, 1)
	eq(core.formatAltitude("標高", 2, function() error("x") end), "標高: 2.0 m")
	eq(core.formatAltitude("標高", 2, function() return nil end), "標高: 2.0 m")
	eq(core.formatAltitude("標高", 2, function() return "" end), "標高: 2.0 m")
end)

test("label: translation, missing key echo, error and non-function", function()
	eq(core.label(function() return "標高" end, "cht_altitude", "Altitude"), "標高")
	eq(core.label(function(k) return k end, "cht_altitude", "Altitude"), "Altitude")
	eq(core.label(function() error("x") end, "cht_altitude", "Altitude"), "Altitude")
	eq(core.label(nil, "cht_altitude", "Altitude"), "Altitude")
end)

test("appendLine: copies, never mutates the input", function()
	local base = { "Reputation: -1%" }
	local out = core.appendLine(base, "標高: 1.0 m")
	eq(#base, 1)
	eq(#out, 2)
	eq(out[2], "標高: 1.0 m")
	eq(#core.appendLine(nil, nil), 0)
end)

------------------------------------------------------------------------
-- cht.script.lua glue (stubbed engine)
------------------------------------------------------------------------
local logs = {}
_G.debugPrint = function(s) logs[#logs + 1] = s end
local ja = { cht_altitude = "標高" }
_G._ = function(k) return ja[k] or k end
-- no api.util.formatAltitude: glue falls back to plain metres
_G.api = { type = { Vec3f = { new = function(x, y, z) return { x = x, y = y, z = z } end } } }

local function transfAt(z)
	return { transformPosition = function(self, v) return { x = v.x, y = v.y, z = v.z + z } end }
end

local cru = {}
cru.getActionParams = function(kind)
	local action = { getProposalStringsFn = function() return { "Reputation: -2%" } end }
	if kind == "construction" then
		action.constructionBuilder = {}
	elseif kind == "nofn" then
		action.constructionBuilder = {}
		action.getProposalStringsFn = nil
	elseif kind == "throws" then
		action.constructionBuilder = {}
		action.getProposalStringsFn = function() error("base failed") end
	elseif kind == "track" then
		action.trackEdgeBuilder = {}
	end
	return { constructionActionParams = action }
end
_G.ug_require = function(path)
	if path == "::/gui/construction/construction_react_util.tl" then return cru end
	error("unexpected ug_require " .. path)
end

local chunk = assert(loadfile(root .. "/content/gui/cht.script.lua"))
chunk()
local exports = data()
exports.prepare(nil)

local function proposalAt(...)
	local toAdd = {}
	for i, z in ipairs({ ... }) do toAdd[i] = { transf = transfAt(z) } end
	return { toAdd = toAdd }, { toAddData = {} }
end

local function strings(kind, p, d)
	return cru.getActionParams(kind).constructionActionParams.getProposalStringsFn(p, d)
end

test("glue: construction tooltip gets the altitude after base lines", function()
	local s = strings("construction", proposalAt(38.864))
	eq(#s, 2)
	eq(s[1], "Reputation: -2%")
	eq(s[2], "標高: 38.9 m")
end)

test("glue: raised/lowered preview shows the shifted origin (slider)", function()
	-- in game: origin z 1.55 -> -1.10 -> -4.10 for slider 0, -3, -6
	eq(strings("construction", proposalAt(1.55))[2], "標高: 1.6 m")
	eq(strings("construction", proposalAt(-1.10))[2], "標高: -1.1 m")
	eq(strings("construction", proposalAt(-4.10))[2], "標高: -4.1 m")
end)

test("glue: template uses the first construction's origin", function()
	eq(strings("construction", proposalAt(10, 30, 5))[2], "標高: 10.0 m")
end)

test("glue: game formatter is used when api.util.formatAltitude exists", function()
	api.util = { formatAltitude = function(v, d) return string.format("%.1f m (game)", v) end }
	local s = strings("construction", proposalAt(7))
	api.util = nil
	eq(s[2], "標高: 7.0 m (game)")
end)

test("glue: native first entry is preferred over the converted list", function()
	local native = { at = function(self, i) return { transf = transfAt(21) } end }
	local p = setmetatable({ toAdd_native = native }, { __index = function(_, k)
		if k == "toAdd" then error("converted list must not be read") end
	end })
	eq(strings("construction", p)[2], "標高: 21.0 m")
end)

test("glue: failing native access falls back to the converted list", function()
	local native = { at = function() error("out of range") end }
	local p = { toAdd_native = native, toAdd = { { transf = transfAt(4) } } }
	eq(strings("construction", p)[2], "標高: 4.0 m")
end)

test("glue: throwing api.util lookup still shows plain metres", function()
	local saved = api
	_G.api = setmetatable({ type = saved.type }, { __index = function(_, k)
		if k == "util" then error("restricted") end
	end })
	local s = strings("construction", proposalAt(6))
	_G.api = saved
	eq(s[2], "標高: 6.0 m")
end)

test("glue: formatter returning a non-string falls back", function()
	api.util = { formatAltitude = function() return 42 end }
	local s = strings("construction", proposalAt(6))
	api.util = nil
	eq(s[2], "標高: 6.0 m")
end)

test("glue: track/street tools are left untouched", function()
	eq(#strings("track", proposalAt(5)), 1)
end)

test("glue: nothing to add keeps only base lines", function()
	eq(#strings("construction", { toAdd = {} }, {}), 1)
	eq(#strings("construction", nil, nil), 1)
end)

test("glue: an engine error is swallowed and logged once", function()
	local bad = setmetatable({}, { __index = function() error("restricted") end })
	local before = #logs
	eq(#strings("construction", bad, bad), 1)
	eq(#strings("construction", bad, bad), 1)
	eq(#logs, before + 1)
	assert(logs[#logs]:find("altitude line failed", 1, true))
end)

test("glue: transf without transformPosition reads index 15", function()
	local t = {}; t[15] = 50
	eq(strings("construction", { toAdd = { { transf = t } } })[2], "標高: 50.0 m")
end)

test("glue: unreadable transf entries are skipped", function()
	local bad = setmetatable({}, { __index = function() error("restricted") end })
	eq(strings("construction", { toAdd = { { transf = bad }, { transf = transfAt(3) } } })[2], "標高: 3.0 m")
	eq(#strings("construction", { toAdd = { {} } }), 1)
end)

test("glue: base strings fn missing is tolerated", function()
	local s = strings("nofn", proposalAt(8))
	eq(#s, 1)
	eq(s[1], "標高: 8.0 m")
end)

test("glue: install is idempotent (second prepare does not double-wrap)", function()
	exports.prepare(nil)
	eq(#strings("construction", proposalAt(5)), 2)
end)

test("glue: an error in the wrapped base fn propagates (not ours to hide)", function()
	local ok, err = pcall(strings, "throws", proposalAt(5))
	eq(ok, false)
	assert(tostring(err):find("base failed", 1, true))
end)

test("glue: another mod wrapping after us keeps both lines", function()
	local ours = cru.getActionParams
	cru.getActionParams = function(...)
		local res = ours(...)
		local a = res.constructionActionParams
		local inner = a.getProposalStringsFn
		a.getProposalStringsFn = function(p, d)
			local t = inner(p, d)
			t[#t + 1] = "Other mod line"
			return t
		end
		return res
	end
	local s = strings("construction", proposalAt(9))
	cru.getActionParams = ours
	eq(#s, 3)
	eq(s[2], "標高: 9.0 m")
	eq(s[3], "Other mod line")
end)

-- A fresh install (new modules, new chunk) from its very first prepare:
-- a working install and normal tooltip lines must log nothing at all.
test("a working install and its tooltip lines log nothing", function()
	local before = #logs
	local fresh = { getActionParams = cru.getActionParams }
	local savedRequire = _G.ug_require
	_G.ug_require = function() return fresh end
	local c = assert(loadfile(root .. "/content/gui/cht.script.lua"))
	c()
	data().prepare(nil)
	_G.ug_require = savedRequire
	local a = fresh.getActionParams("construction").constructionActionParams
	a.getProposalStringsFn(proposalAt(12))
	a.getProposalStringsFn(proposalAt(13))
	eq(#logs, before)
	-- the timing log used os.clock (process CPU time); keep it out
	local f = assert(io.open(root .. "/content/gui/cht.script.lua"))
	local src = f:read("*a")
	f:close()
	assert(not src:find("os.clock", 1, true), "os.clock in the script")
end)

test("res file points at the install script", function()
	dofile(root .. "/content/gui/cht.res.lua")
	local d = data()
	eq(d.type, "react-replacement-config")
	eq(d.data.filePath, "hummer_construction_altitude_tooltip::/gui/cht.script")
	eq(d.data.doReplaceFn, "prepare")
	-- the script must export that function
	local c = assert(loadfile(root .. "/content/gui/cht.script.lua"))
	c()
	eq(type(data().prepare), "function")
end)

-- a small JSON decoder (objects, arrays, strings with escapes, numbers,
-- true/false/null): enough for strings.json and _metadata/modinfo.json,
-- whose keys contain spaces and escaped quotes
local function decodeJson(src)
	local pos = 1
	local function ws() pos = src:find("[^ \t\r\n]", pos) or #src + 1 end
	local value
	local function str()
		local out, i = {}, pos + 1
		while true do
			local c = src:sub(i, i)
			assert(c ~= "", "unterminated string")
			if c == '"' then pos = i + 1; return table.concat(out) end
			assert(c:byte() >= 0x20, "control character in string")
		if c == "\\" then
				local e = src:sub(i + 1, i + 1)
				local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if e == "u" then
					local cp = tonumber(src:sub(i + 2, i + 5), 16)
					assert(cp and cp < 0x80, "only ASCII \\u escapes are expected")
					out[#out + 1] = string.char(cp); i = i + 6
				else
					out[#out + 1] = assert(map[e], "bad escape"); i = i + 2
				end
			else
				out[#out + 1] = c; i = i + 1
			end
		end
	end
	function value()
		ws()
		local c = src:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1; ws()
			if src:sub(pos, pos) == "}" then pos = pos + 1; return t end
			while true do
				ws(); assert(src:sub(pos, pos) == '"', "key expected at " .. pos)
				local k = str(); ws()
				assert(src:sub(pos, pos) == ":", ": expected at " .. pos); pos = pos + 1
				assert(t[k] == nil, "duplicate key " .. k)
				t[k] = value(); ws()
				local d = src:sub(pos, pos); pos = pos + 1
				if d == "}" then return t end
				assert(d == ",", ", or } expected at " .. pos)
			end
		elseif c == "[" then
			local t = {}
			pos = pos + 1; ws()
			if src:sub(pos, pos) == "]" then pos = pos + 1; return t end
			while true do
				t[#t + 1] = value(); ws()
				local d = src:sub(pos, pos); pos = pos + 1
				if d == "]" then return t end
				assert(d == ",", ", or ] expected at " .. pos)
			end
		elseif c == '"' then
			return str()
		end
		for lit, v in pairs({ ["true"] = true, ["false"] = false, ["null"] = false }) do
			if src:sub(pos, pos + #lit - 1) == lit then pos = pos + #lit; return v end
		end
		local num = src:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		local n = num and tonumber(num)
		assert(n, "bad value at " .. pos)
		pos = pos + #num
		return n
	end
	local v = value(); ws()
	assert(pos > #src, "trailing data at " .. pos)
	return v
end

local function readJson(rel)
	local f = assert(io.open(root .. "/" .. rel))
	local src = f:read("*a")
	f:close()
	return decodeJson(src)
end

local GAME_LANGS = { "en", "ja", "de", "es", "fr", "it", "ko", "nl", "pl", "pt_BR", "ru", "zh_CN", "zh_TW" }

test("decodeJson: escapes, nesting, rejects broken input", function()
	local v = decodeJson('{"a \\"b\\"": ["x", 1, true], "c": {"d": "\\u0041\\n"}}')
	eq(v['a "b"'][1], "x"); eq(v['a "b"'][2], 1); eq(v['a "b"'][3], true)
	eq(v.c.d, "A\n")
	eq((pcall(decodeJson, '{"a": "b"')), false)
	eq((pcall(decodeJson, '{"a": "b",}')), false)
	eq((pcall(decodeJson, '{"a": 1, "a": 2}')), false)
	eq((pcall(decodeJson, '[1-]')), false)
	eq((pcall(decodeJson, '["a\\nb"]')), true) -- an escaped newline is fine
	eq((pcall(decodeJson, '["a' .. "\n" .. 'b"]')), false) -- a raw one is not
end)

test("_metadata/modinfo.json: readable name, summary, author, tag", function()
	local info = readJson("_metadata/modinfo.json")
	local keys = {}
	for k in pairs(info) do keys[#keys + 1] = k end
	table.sort(keys)
	eq(table.concat(keys, ","), "authors,description,name,summary,tags,url")
	-- English only (user, 2026-11-22): the mod list and mod.io show one name
	-- for every language; Japanese stays in the summary and description
	eq(info.name, "Construction Altitude Tooltip")
	assert(not info.name:find("[\128-\255]"), "name must be plain ASCII")
	assert(info.summary:find(" / ", 1, true) and info.summary:find("[\128-\255]"), "summary keeps the Japanese half")
	-- mod.io limits, counted in characters (UTF-8 lead bytes)
	local function chars(str) return select(2, str:gsub("[^\128-\191]", "")) end
	assert(chars(info.name) <= 50, "name too long for mod.io")
	assert(chars(info.summary) <= 250, "summary too long for mod.io")
	assert(chars(info.description) <= 50000, "description too long for mod.io")
	eq(info.authors[1].name, "hummer")
	eq(info.authors[1].role, "CREATOR")
	eq(info.tags[1], "Script Mod")
	eq(info.url, "https://github.com/hummer98/tpf3-construction-altitude-tooltip")
end)

local function sections(text)
	local paras, from = {}, 1
	while true do
		local at = text:find("\n\n", from, true)
		paras[#paras + 1] = text:sub(from, (at or 0) - 1)
		if not at then break end
		from = at + 2
	end
	local found = {}
	for _, para in ipairs(paras) do
		local head = para:match("^%[([^%]\n]+)%] ")
		assert(head, "paragraph without a language heading: " .. para:sub(1, 30))
		found[#found + 1] = { head = head, text = para }
	end
	return found
end

-- each language names the slider as the game does (base.mo "Height"), or
-- players can't find it
test("modinfo description: every language, each naming the official slider", function()
	local info = readJson("_metadata/modinfo.json")
	local official = {
		en = { "English", "Height" }, ja = { "日本語", "高度" },
		de = { "Deutsch", "Höhe" }, es = { "Español", "Altura" },
		fr = { "Français", "Hauteur" }, it = { "Italiano", "Altezza" },
		ko = { "한국어", "높이" }, nl = { "Nederlands", "Hoogte" },
		pl = { "Polski", "Wysokość" }, pt_BR = { "Português (Brasil)", "Altura" },
		ru = { "Русский", "Высота" }, zh_CN = { "简体中文", "高度" },
		zh_TW = { "繁體中文", "高度" },
	}
	local found = sections(info.description)
	eq(#found, #GAME_LANGS, "one section per game language")
	for i, lang in ipairs(GAME_LANGS) do
		eq(found[i].head, official[lang][1], "section " .. i)
		assert(found[i].text:find(official[lang][2], 1, true), lang .. " doesn't name " .. official[lang][2])
	end
	assert(found[1].text:find("License: MIT", 1, true)
		and found[1].text:find("github.com/hummer98/tpf3-construction-altitude-tooltip", 1, true), "licence and source link")
end)

-- the mod.io web page text is kept in docs/ (the uploader has no field for
-- it); it must say the same as the in-game description
test("docs/modio_description.md matches modinfo.json", function()
	local info = readJson("_metadata/modinfo.json")
	local f = assert(io.open(root .. "/docs/modio_description.md"))
	local md = f:read("*a")
	f:close()
	assert(md:find(info.summary, 1, true), "summary differs")
	for _, s in ipairs(sections(info.description)) do
		local head, title, body = s.text:match("^%[([^%]]+)%] ([^\n]+)\n(.*)$")
		assert(md:find("## " .. head .. ": " .. title .. "\n\n" .. body .. "\n", 1, true), head .. " section differs")
	end
end)

test("strings.json: the label in every game language, nothing else", function()
	local langs = readJson("strings.json")
	local known = {}
	for _, lang in ipairs(GAME_LANGS) do
		known[lang] = true
		local t = assert(langs[lang], "missing language " .. lang)
		assert(type(t.cht_altitude) == "string" and t.cht_altitude ~= "", lang .. " lacks cht_altitude")
		for k in pairs(t) do eq(k, "cht_altitude", lang .. " unused key") end
	end
	for lang in pairs(langs) do assert(known[lang], "unknown language " .. lang) end
end)

-- the game resolves "<modId>::/..." by mod.json's modId and loads the mod
-- from "<modId>_<major>", so a rename must change all of them
test("modId, folder name and every require prefix agree", function()
	local f = assert(io.open(root .. "/mod.json"))
	local modId = f:read("*a"):match('"modId"%s*:%s*"([^"]+)"')
	f:close()
	eq(modId, "hummer_construction_altitude_tooltip")
	local folder = (root == "." and io.popen("pwd"):read("*l") or root):match("([^/]+)/?$")
	if folder:match("_%d+$") then eq((folder:gsub("_%d+$", "")), modId, "folder name") end
	for _, name in ipairs({ "cht.res.lua", "cht.script.lua", "cht_core.lua" }) do
		local h = assert(io.open(root .. "/content/gui/" .. name))
		local src = h:read("*a")
		h:close()
		for prefix in src:gmatch('"([%w_]+)::/') do eq(prefix, modId, name) end
	end
end)

-- the README is the GitHub landing page; both languages must point at the
-- published mod.io page, not the pre-release placeholder
test("README links the mod.io page in both languages", function()
	local f = assert(io.open(root .. "/README.md"))
	local src = f:read("*a")
	f:close()
	local url = "https://mod.io/g/transportfever3/m/construction-altitude-tooltip"
	local split = assert(src:find("\n## 日本語", 1, true), "Japanese section")
	assert(src:sub(1, split):find(url, 1, true), "English section link")
	assert(src:sub(split):find(url, 1, true), "Japanese section link")
	assert(not src:find("link follows after", 1, true), "English placeholder left")
	assert(not src:find("リンクを載せます", 1, true), "Japanese placeholder left")
end)

print(string.format("\n%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
