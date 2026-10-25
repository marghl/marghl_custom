local FLOOR_Y = -30000
local EMPTY_MIN_Y = FLOOR_Y + 1
local EMPTY_MAX_Y = -29000
local CEILING_Y = EMPTY_MAX_Y + 1
local PREGENERATE_POS = {x = 0, y = -29999, z = 0}
local PREGENERATE_KEY = "origin_column_generated_v3"
local PREGENERATE_CEILING_KEY = "origin_ceiling_generated_v1"
local ORIGIN_MIN = {x = -40, y = FLOOR_Y, z = -40}
local ORIGIN_MAX = {x = 39, y = CEILING_Y, z = 39}
local LIGHT_AIR_NAME = "marghl_custom_warehouse:light_air"
local SKY_LAYER_NAME = "marghl_custom_warehouse:sky"
local LIGHTING_CHANGE_NAME = "marghl_custom_warehouse:lighting"
local SKY_COLOR = "#87CEEB"

local warehouse_light_level = tonumber(minetest.settings:get("warehouse_light_level"))
	 or minetest.LIGHT_MAX
warehouse_light_level = math.max(0, math.min(minetest.LIGHT_MAX,
	math.floor(warehouse_light_level)))

local air_content_id
local light_air_content_id
local bedrock_content_id

minetest.register_node(LIGHT_AIR_NAME, {
	description = "Warehouse-Lichtluft",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = false,
	drop = "",
	is_ground_content = false,
	light_source = warehouse_light_level,
	groups = {not_in_creative_inventory = 1},
})

local function is_light_position()
	-- Gleiche Verteilung wie planet_mars: Im Mittel wird jeder sechste
	-- freie Luftnode zu einer unsichtbaren Lichtquelle.
	return math.random(0, 5) == 1
end

local function generate_warehouse_chunk(minp, maxp)
	local touches_floor = minp.y <= FLOOR_Y and maxp.y >= FLOOR_Y
	local touches_ceiling = minp.y <= CEILING_Y and maxp.y >= CEILING_Y
	local touches_empty_layer = maxp.y >= EMPTY_MIN_Y and minp.y <= EMPTY_MAX_Y
	if not touches_floor and not touches_ceiling and not touches_empty_layer then
		return
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()

	if touches_empty_layer then
		local y_min = math.max(minp.y, EMPTY_MIN_Y)
		local y_max = math.min(maxp.y, EMPTY_MAX_Y)
		for z = minp.z, maxp.z do
			for y = y_min, y_max do
				local index = area:index(minp.x, y, z)
				for x = minp.x, maxp.x do
					data[index] = is_light_position(x, y, z)
						and light_air_content_id or air_content_id
					index = index + 1
				end
			end
		end
	end

	if touches_floor then
		for z = minp.z, maxp.z do
			local index = area:index(minp.x, FLOOR_Y, z)
			for _ = minp.x, maxp.x do
				data[index] = bedrock_content_id
				index = index + 1
			end
		end
	end

	if touches_ceiling then
		for z = minp.z, maxp.z do
			local index = area:index(minp.x, CEILING_Y, z)
			for _ = minp.x, maxp.x do
				data[index] = bedrock_content_id
				index = index + 1
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting(minp, maxp)
	vm:write_to_map(false)
end

minetest.register_on_mods_loaded(function()
	local bedrock_name = "nextgen_bedrock:bedrock"
	if not minetest.registered_nodes[bedrock_name] then
		error("[marghl_custom_warehouse] Required node " .. bedrock_name .. " is not registered")
	end
	bedrock_content_id = minetest.get_content_id(bedrock_name)
	air_content_id = minetest.get_content_id("air")
	light_air_content_id = minetest.get_content_id(LIGHT_AIR_NAME)

	-- Erst nach dem Laden aller Mods registrieren. Damit laeuft diese
	-- Bereinigung hinter den normal waehrend des Mod-Ladens registrierten
	-- Mapgen-Callbacks und entfernt auch deren Fluessigkeiten, Loot-Truhen und
	-- sonstige Strukturen aus neu erzeugten Warehouse-Chunks.
	minetest.register_on_generated(generate_warehouse_chunk)
end)

local function remove_warehouse_liquid(pos)
	if pos.y >= EMPTY_MIN_Y and pos.y <= EMPTY_MAX_Y then
		minetest.swap_node(pos, {name = "air"})
	end
end

-- Entfernt Quellen und fliessende Varianten auch aus bereits erzeugten
-- Mapblocks, sobald diese geladen werden.
minetest.register_lbm({
	label = "Remove liquids from Warehouse",
	name = "marghl_custom_warehouse:remove_liquids",
	nodenames = {"group:liquid"},
	run_at_every_load = true,
	action = remove_warehouse_liquid,
})

-- Faengt neu platzierte oder von Maschinen erzeugte Fluessigkeiten ab,
-- solange der betreffende Bereich aktiv ist.
minetest.register_abm({
	label = "Keep Warehouse free of liquids",
	nodenames = {"group:liquid"},
	interval = 1,
	chance = 1,
	action = remove_warehouse_liquid,
})

-- Der erste Mapgen-Chunk rund um den vorgesehenen Einstiegspunkt wird beim
-- ersten Serverstart mit dieser Mod ueber die volle Warehouse-Hoehe erzeugt.
local storage = minetest.get_mod_storage()

local function write_origin_slab(y_min, y_max)
	local p1 = {x = ORIGIN_MIN.x, y = y_min, z = ORIGIN_MIN.z}
	local p2 = {x = ORIGIN_MAX.x, y = y_max, z = ORIGIN_MAX.z}
	local vm = VoxelManip()
	local emin, emax = vm:read_from_map(p1, p2)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data = vm:get_data()

	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			local index = area:index(p1.x, y, z)
			for x = p1.x, p2.x do
				if y == FLOOR_Y or y == CEILING_Y then
					data[index] = bedrock_content_id
				else
					data[index] = is_light_position(x, y, z)
						and light_air_content_id or air_content_id
				end
				index = index + 1
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting(p1, p2)
	vm:write_to_map(false)
end

local function initialize_origin_column(y_min)
	if y_min > EMPTY_MAX_Y then
		local floor_node = minetest.get_node({x = 0, y = FLOOR_Y, z = 0}).name
		local room_node = minetest.get_node(PREGENERATE_POS).name
		if floor_node ~= "nextgen_bedrock:bedrock" or
			(room_node ~= "air" and room_node ~= LIGHT_AIR_NAME) then
			minetest.log("warning", ("[marghl_custom_warehouse] Origin migration incomplete; floor=%s, room=%s. Will retry on next start.")
				:format(floor_node, room_node))
			return
		end
		storage:set_int(PREGENERATE_KEY, 1)
		minetest.log("action", ("[marghl_custom_warehouse] Origin column generated; floor=%s, room=%s")
			:format(floor_node, room_node))
		return
	end

	local y_max = math.min(y_min + 79, EMPTY_MAX_Y)
	write_origin_slab(y_min, y_max)
	minetest.after(0, initialize_origin_column, y_max + 1)
end

minetest.register_on_mods_loaded(function()
	if storage:get_int(PREGENERATE_KEY) == 1 and
		storage:get_int(PREGENERATE_CEILING_KEY) == 1 then
		return
	end

	minetest.after(0, function()
		minetest.emerge_area(ORIGIN_MIN, ORIGIN_MAX, function(_, _, remaining)
			if remaining ~= 0 then
				return
			end
			if storage:get_int(PREGENERATE_KEY) ~= 1 then
				initialize_origin_column(FLOOR_Y)
			end
			if storage:get_int(PREGENERATE_CEILING_KEY) ~= 1 then
				write_origin_slab(CEILING_Y, CEILING_Y)
				storage:set_int(PREGENERATE_CEILING_KEY, 1)
				minetest.log("action", "[marghl_custom_warehouse] Origin ceiling generated")
			end
		end)
	end)
end)

local warehouse_sky = {
	priority = 1000,
	sky_data = {
		type = "plain",
		base_color = SKY_COLOR,
		clouds = false,
		sky_color = {
			day_sky = SKY_COLOR,
			day_horizon = SKY_COLOR,
			dawn_sky = SKY_COLOR,
			dawn_horizon = SKY_COLOR,
			night_sky = SKY_COLOR,
			night_horizon = SKY_COLOR,
			indoors = SKY_COLOR,
			fog_tint_type = "custom",
			fog_sun_tint = SKY_COLOR,
			fog_moon_tint = SKY_COLOR,
		},
	},
	cloud_data = {density = 0},
	sun_data = {visible = false, sunrise_visible = false},
	moon_data = {visible = false},
	star_data = {visible = false},
	light_data = {shadow_intensity = 0, saturation = 1},
}

local players_in_warehouse = {}

local function set_warehouse_sky(player)
	local name = player:get_player_name()
	if climate_api and climate_api.skybox then
		climate_api.skybox.add(name, SKY_LAYER_NAME, warehouse_sky)
		climate_api.skybox.update(name)
	else
		player:set_sky({type = "plain", base_color = SKY_COLOR, clouds = false})
		player:set_clouds({density = 0})
		player:set_sun({visible = false, sunrise_visible = false})
		player:set_moon({visible = false})
		player:set_stars({visible = false})
	end
	player:override_day_night_ratio(1)
	if lighting_monoid then
		lighting_monoid:add_change(player, {
			shadows = {intensity = 0},
			exposure = {exposure_correction = 1.5},
		}, LIGHTING_CHANGE_NAME)
	end
	players_in_warehouse[name] = true
end

local function restore_normal_sky(player)
	local name = player:get_player_name()
	if climate_api and climate_api.skybox then
		climate_api.skybox.remove(name, SKY_LAYER_NAME)
		climate_api.skybox.update(name)
	else
		player:set_sky({type = "regular", clouds = true})
		player:set_clouds({density = 0.4})
		player:set_sun({visible = true, sunrise_visible = true})
		player:set_moon({visible = true})
		player:set_stars({visible = true})
	end
	player:override_day_night_ratio(nil)
	if lighting_monoid then
		lighting_monoid:del_change(player, LIGHTING_CHANGE_NAME)
	end
	players_in_warehouse[name] = nil
end

local sky_timer = 0
minetest.register_globalstep(function(dtime)
	sky_timer = sky_timer + dtime
	if sky_timer < 0.5 then
		return
	end
	sky_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local pos = player:get_pos()
		local inside = pos and pos.y >= EMPTY_MIN_Y and pos.y <= EMPTY_MAX_Y
		if inside and not players_in_warehouse[name] then
			set_warehouse_sky(player)
		elseif not inside and players_in_warehouse[name] then
			restore_normal_sky(player)
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	players_in_warehouse[player:get_player_name()] = nil
end)

local function get_mapchunk_bounds(pos)
	local chunk_blocks = tonumber(minetest.get_mapgen_setting("chunksize")) or 5
	local chunk_size = chunk_blocks * 16
	local chunk_offset = math.floor(chunk_blocks / 2) * 16
	local function chunk_min(value)
		return math.floor((value + chunk_offset) / chunk_size) * chunk_size - chunk_offset
	end
	local minp = {
		x = chunk_min(pos.x),
		y = chunk_min(pos.y),
		z = chunk_min(pos.z),
	}
	local maxp = {
		x = minp.x + chunk_size - 1,
		y = minp.y + chunk_size - 1,
		z = minp.z + chunk_size - 1,
	}
	return minp, maxp
end

minetest.register_chatcommand("warehouse_fix_lighting", {
	description = "Erzeugt die zufaellige Warehouse-Beleuchtung im aktuellen Mapgen-Chunk neu",
	privs = {server = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Der Befehl kann nur im Spiel ausgefuehrt werden."
		end
		local minp, maxp = get_mapchunk_bounds(vector.round(player:get_pos()))
		local y_min = math.max(minp.y, EMPTY_MIN_Y)
		local y_max = math.min(maxp.y, EMPTY_MAX_Y)
		if y_min > y_max then
			return false, "Der aktuelle Mapgen-Chunk liegt nicht in der Warehouse-Schicht."
		end

		local p1 = {x = minp.x, y = y_min, z = minp.z}
		local p2 = {x = maxp.x, y = y_max, z = maxp.z}
		local vm = VoxelManip()
		local emin, emax = vm:read_from_map(p1, p2)
		local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
		local data = vm:get_data()

		for z = p1.z, p2.z do
			for y = p1.y, p2.y do
				local index = area:index(p1.x, y, z)
				for x = p1.x, p2.x do
					if data[index] == light_air_content_id then
						data[index] = air_content_id
					end
					if data[index] == air_content_id and is_light_position(x, y, z) then
						data[index] = light_air_content_id
					end
					index = index + 1
				end
			end
		end

		vm:set_data(data)
		vm:calc_lighting(p1, p2)
		vm:write_to_map(false)
		minetest.fix_light(p1, p2)

		return true, ("Zufaellige Beleuchtung (durchschnittlich jeder 6. Luftnode) fuer den Mapgen-Chunk %s bis %s erneuert.")
			:format(minetest.pos_to_string(minp), minetest.pos_to_string(maxp))
	end,
})

minetest.log("action", ("[marghl_custom_warehouse] bedrock_floor=%d, empty=%d..%d, bedrock_ceiling=%d, random_light_chance=1/6, light_level=%d")
	:format(FLOOR_Y, EMPTY_MIN_Y, EMPTY_MAX_Y, CEILING_Y, warehouse_light_level))
