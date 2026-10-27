local storage = assert(marghl_custom.storage)
local S = assert(marghl_custom.S)
local F = minetest.formspec_escape
local state_key = "marghl_custom:tutorial_state"
local pending = "pending"
local completed = "completed"
local default_radius = math.max(1,
	math.floor(tonumber(minetest.settings:get("marghl_custom_tutorial_radius")) or 4))
local maximum_radius = math.max(default_radius,
	math.floor(tonumber(minetest.settings:get("marghl_custom_tutorial_radius_max")) or 32))

local function get_stored_pos(key)
	local value = minetest.deserialize(storage:get_string(key))
	if type(value) ~= "table"
	or type(value.x) ~= "number"
	or type(value.y) ~= "number"
	or type(value.z) ~= "number" then
		return nil
	end
	return vector.new(value)
end

local function set_stored_pos(key, pos)
	storage:set_string(key, minetest.serialize(vector.round(pos)))
end

local function parse_setting_pos(value)
	if not value or value == "" then
		return nil
	end
	local x, y, z = value:match(
		"^%s*%(?%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*%)?%s*$"
	)
	if not x then
		return nil
	end
	return vector.new(tonumber(x), tonumber(y), tonumber(z))
end

local function get_tutorial_pos()
	return get_stored_pos("tutorial_start")
end

local function get_real_spawn_pos()
	return get_stored_pos("tutorial_real_spawn")
		or parse_setting_pos(minetest.settings:get("static_spawnpoint"))
end

local function is_pending(player)
	return player:get_meta():get_string(state_key) == pending
end

local function send_to_tutorial(player)
	local pos = get_tutorial_pos()
	if not pos then
		return false
	end
	player:set_pos(pos)
	return true
end

local function finish_tutorial(player)
	if not is_pending(player) then
		return false
	end
	local destination = get_real_spawn_pos()
	if not destination then
		minetest.log("error", "[marghl_custom] Tutorial cannot finish: real spawn is not configured")
		return false
	end

	player:get_meta():set_string(state_key, completed)
	player:set_pos(destination)
	return true
end

local function update_exit_formspec(pos)
	local meta = minetest.get_meta(pos)
	local radius = meta:get_int("radius")
	if radius < 1 then
		radius = default_radius
		meta:set_int("radius", radius)
	end
	meta:set_string("infotext", S("Tutorial exit (radius: @1)", radius))
	meta:set_string("formspec",
		"formspec_version[4]size[7,3]" ..
		"label[0.5,0.5;" .. F(S("Detection radius")) .. "]" ..
		"field[0.5,1.0;3.0,0.8;radius;" .. F(S("Radius (1-@1)", maximum_radius)) .. ";" .. radius .. "]" ..
		"button_exit[4.5,1.0;2.0,0.8;save;" .. F(S("Save")) .. "]"
	)
end

local function initialize_exit(pos)
	update_exit_formspec(pos)
	minetest.get_node_timer(pos):start(0.25)
end

local function scan_exit(pos)
	local radius = minetest.get_meta(pos):get_int("radius")
	if radius < 1 then
		radius = default_radius
	end
	for _, object in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
		if object:is_player() and is_pending(object) then
			finish_tutorial(object)
		end
	end
	return true
end

minetest.register_node("marghl_custom:tutorial_exit", {
	description = S("Tutorial exit"),
	tiles = {"marghl_custom_tutorial_exit.png"},
	paramtype = "light",
	sunlight_propagates = true,
	walkable = true,
	groups = {cracky = 1, not_in_creative_inventory = 1},
	sounds = default and default.node_sound_metal_defaults() or nil,
	on_construct = initialize_exit,
	on_timer = scan_exit,

	on_receive_fields = function(pos, _, fields, sender)
		if not fields.save or not sender then
			return
		end
		if not minetest.check_player_privs(sender:get_player_name(), {server = true}) then
			return
		end
		local radius = math.floor(tonumber(fields.radius) or default_radius)
		radius = math.max(1, math.min(maximum_radius, radius))
		minetest.get_meta(pos):set_int("radius", radius)
		update_exit_formspec(pos)
	end,

	on_place = function(itemstack, placer, pointed_thing)
		if not placer
		or not minetest.check_player_privs(placer:get_player_name(), {server = true}) then
			return itemstack
		end
		return minetest.item_place(itemstack, placer, pointed_thing)
	end,

	can_dig = function(_, player)
		return player
			and minetest.check_player_privs(player:get_player_name(), {server = true})
	end,
})

minetest.register_lbm({
	name = "marghl_custom:initialize_tutorial_exit",
	nodenames = {"marghl_custom:tutorial_exit"},
	run_at_every_load = true,
	action = initialize_exit,
})

minetest.register_on_newplayer(function(player)
	player:get_meta():set_string(state_key, pending)
	if not get_tutorial_pos() then
		minetest.log("warning", "[marghl_custom] New player tutorial skipped: tutorial start is not configured")
		return
	end
	send_to_tutorial(player)
end)

minetest.register_on_joinplayer(function(player)
	if not is_pending(player) then
		return
	end
	minetest.after(0, function(name)
	local current = minetest.get_player_by_name(name)
		if current and is_pending(current) then
			send_to_tutorial(current)
		end
	end, player:get_player_name())
end)

minetest.register_on_respawnplayer(function(player)
	if is_pending(player) then
		return send_to_tutorial(player)
	end
	return false
end)

minetest.register_chatcommand("tutorial_set_start", {
	description = S("Sets the starting point for new tutorial players"),
	privs = {server = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("Player is not online.")
		end
		local pos = vector.round(player:get_pos())
		set_stored_pos("tutorial_start", pos)
		return true, S("Tutorial start set: @1", minetest.pos_to_string(pos))
	end,
})

minetest.register_chatcommand("tutorial_set_spawn", {
	description = S("Sets the real spawn after completing the tutorial"),
	privs = {server = true},
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("Player is not online.")
		end
		local pos = vector.round(player:get_pos())
		set_stored_pos("tutorial_real_spawn", pos)
		return true, S("Real spawn set: @1", minetest.pos_to_string(pos))
	end,
})

minetest.register_chatcommand("tutorial_reset", {
	description = S("Sends a player through the tutorial again"),
	params = S("<player name>"),
	privs = {server = true},
	func = function(_, param)
		local name = param:match("^%s*(%S+)%s*$")
		if not name or not minetest.player_exists(name) then
			return false, S("Unknown player.")
		end
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("The player must be online to be reset.")
		end
		if not get_tutorial_pos() then
			return false, S("The tutorial start has not been set yet.")
		end
		player:get_meta():set_string(state_key, pending)
		send_to_tutorial(player)
		return true, S("@1 was sent to the tutorial.", name)
	end,
})
