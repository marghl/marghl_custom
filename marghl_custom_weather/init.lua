-- Die Daten bleiben absichtlich im Speicher des bisherigen Hauptmods. So
-- bleiben bereits konfigurierte wetterfreie Areas nach der Aufteilung erhalten.
local storage = assert(marghl_custom.storage)
local storage_key = "weather_area_ids"

local function load_ids()
	local stored = minetest.deserialize(storage:get_string(storage_key))
	local result = {}
	if type(stored) == "table" then
		for id, enabled in pairs(stored) do
			local numeric_id = tonumber(id)
			if numeric_id and enabled then
				result[numeric_id] = true
			end
		end
	end
	return result
end

local weather_area_ids = load_ids()

local function save_ids()
	storage:set_string(storage_key, minetest.serialize(weather_area_ids))
end

local function weather_disabled_at(pos)
	if not pos then
		return false
	end
	for id in pairs(areas:getAreasAtPos(pos)) do
		if weather_area_ids[id] then
			return true
		end
	end
	return false
end

-- Regional Weather uses the "indoors" influence for block effects such as
-- puddles and snow cover. Treat weather-free areas as indoors while retaining
-- Climate API's normal roof detection everywhere else.
local original_indoors = climate_mod.influences.indoors
climate_api.register_influence("indoors", function(pos)
	if weather_disabled_at(pos) then
		return true
	end
	return original_indoors and original_indoors(pos) or false
end)

-- Excluding players here stops every visual and audible weather effect,
-- including presets which do not use the "indoors" condition.
local original_get_active_effects = climate_mod.trigger.get_active_effects
climate_mod.trigger.get_active_effects = function(players)
	local weather_players = {}
	for _, player in ipairs(players) do
		if not weather_disabled_at(player:get_pos()) then
			weather_players[#weather_players + 1] = player
		end
	end
	return original_get_active_effects(weather_players)
end

local function parse_area_id(param)
	local id = tonumber(param:match("^%s*(%d+)%s*$"))
	if not id then
		return nil, "Bitte eine gueltige Areas-ID angeben."
	end
	if not areas.areas[id] then
		return nil, "Area " .. id .. " existiert nicht."
	end
	return id
end

minetest.register_chatcommand("weather_area_add", {
	description = "Schaltet das Wetter in einer Area aus",
	params = "<Area-ID>",
	privs = {server = true},
	func = function(_, param)
		local id, err = parse_area_id(param)
		if not id then
			return false, err
		end
		if weather_area_ids[id] then
			return false, "Area " .. id .. " ist bereits wetterfrei."
		end
		weather_area_ids[id] = true
		save_ids()
		return true, "Wetter fuer Area " .. id .. " ausgeschaltet."
	end,
})

minetest.register_chatcommand("weather_area_remove", {
	description = "Schaltet das automatische Wetter in einer Area wieder ein",
	params = "<Area-ID>",
	privs = {server = true},
	func = function(_, param)
		local id = tonumber(param:match("^%s*(%d+)%s*$"))
		if not id then
			return false, "Bitte eine gueltige Areas-ID angeben."
		end
		if not weather_area_ids[id] then
			return false, "Area " .. id .. " ist nicht als wetterfrei eingetragen."
		end
		weather_area_ids[id] = nil
		save_ids()
		return true, "Automatisches Wetter fuer Area " .. id .. " wieder eingeschaltet."
	end,
})

minetest.register_chatcommand("weather_area_list", {
	description = "Listet alle wetterfreien Areas auf",
	privs = {server = true},
	func = function()
		local ids = {}
		for id in pairs(weather_area_ids) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		if #ids == 0 then
			return true, "Es sind keine wetterfreien Areas eingetragen."
		end

		local entries = {}
		for _, id in ipairs(ids) do
			local area = areas.areas[id]
			local label = area and area.name or "Area nicht mehr vorhanden"
			entries[#entries + 1] = string.format("%d (%s)", id, label)
		end
		return true, "Wetterfreie Areas: " .. table.concat(entries, ", ")
	end,
})

areas:registerOnRemove(function(id)
	if weather_area_ids[id] then
		weather_area_ids[id] = nil
		save_ids()
	end
end)
