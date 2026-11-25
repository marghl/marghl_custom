local S = assert(marghl_custom.S)

local idle_time = math.max(1,
	math.floor(tonumber(minetest.settings:get("marghl_custom_idle_time")) or 300))
local kick_min_time = math.max(0,
	math.floor(tonumber(minetest.settings:get("marghl_custom_afk_kick_min_time")) or 300))
local occupancy_threshold = tonumber(
	minetest.settings:get("marghl_custom_afk_kick_occupancy")) or 0.75
occupancy_threshold = math.max(0, math.min(1, occupancy_threshold))
local check_interval = math.max(1,
	math.floor(tonumber(minetest.settings:get("marghl_custom_afk_check_interval")) or 5))

if not minetest.registered_privileges.allow_afk then
	minetest.register_privilege("allow_afk", {
		description = S("May remain idle or AFK without being disconnected"),
		give_to_singleplayer = true,
		give_to_admin = true,
	})
end

local states = {}
marghl_custom.player_status = marghl_custom.player_status or {}

local function now()
	return minetest.get_us_time() / 1000000
end

local function set_status(name, status, since)
	states[name] = {
		status = status,
		since = since or now(),
	}
end

local function clear_status(name)
	states[name] = nil
end

function marghl_custom.player_status.get(name)
	local state = states[name]
	if not state then
		return "active"
	end
	return state.status, state.since
end

local function may_remain_afk(name)
	return minetest.check_player_privs(name, {allow_afk = true})
end

minetest.register_chatcommand("afk", {
	description = S("Mark yourself as AFK until your next activity"),
	func = function(name)
		set_status(name, "afk")
		return true, S("You are now AFK. Any activity will clear this status.")
	end,
})

afk_api.register_on_afk({
	min_afk_time = idle_time,
	func = function(player, afk_time)
		local name = player:get_player_name()
		local state = states[name]
		if not state or state.status ~= "afk" then
			set_status(name, "idle", now() - afk_time)
		end
	end,
})

afk_api.register_on_back({
	min_afk_time = 0,
	func = function(player)
		clear_status(player:get_player_name())
	end,
})

minetest.register_on_leaveplayer(function(player)
	clear_status(player:get_player_name())
end)

local function find_kick_candidate(players, status, current_time)
	local candidate
	local longest_time = -1

	for _, player in ipairs(players) do
		local name = player:get_player_name()
		local state = states[name]
		if state and state.status == status and not may_remain_afk(name) then
			local absent_time
			if status == "idle" then
				absent_time = afk_api.get_afk_time(player, current_time) or 0
			else
				absent_time = current_time - state.since
			end

			if absent_time >= kick_min_time and absent_time > longest_time then
				candidate = player
				longest_time = absent_time
			end
		end
	end

	return candidate, longest_time
end

local function check_server_occupancy()
	local players = minetest.get_connected_players()
	local max_users = tonumber(minetest.settings:get("max_users")) or 15
	if max_users < 1 or #players / max_users <= occupancy_threshold then
		return
	end

	local current_time = now()
	local candidate, absent_time = find_kick_candidate(players, "idle", current_time)
	if not candidate then
		candidate, absent_time = find_kick_candidate(players, "afk", current_time)
	end
	if not candidate then
		return
	end

	local name = candidate:get_player_name()
	local status = states[name] and states[name].status or "idle"
	minetest.log("action", string.format(
		"[marghl_custom] Occupancy AFK kick: %s (%s for %d seconds, %d/%d players)",
		name, status, math.floor(absent_time), #players, max_users))
	minetest.kick_player(name, S(
		"The server is busy. You were disconnected after @1 seconds of inactivity.",
		math.floor(absent_time)))
end

local elapsed = 0
minetest.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < check_interval then
		return
	end
	elapsed = 0
	check_server_occupancy()
end)

if minetest.register_can_bypass_userlimit then
	minetest.register_can_bypass_userlimit(function(name)
		return may_remain_afk(name)
	end)
end

minetest.register_on_mods_loaded(function()
	if not beerchat or not beerchat.register_callback then
		return
	end

	beerchat.register_callback("before_send_pm", function(sender, message, target)
		local state = states[target]
		if state and state.status == "afk" then
			return false, S(
				"@1 is currently AFK. Please use the mail system (/mail) instead.", target)
		end
	end, "high")
end)
