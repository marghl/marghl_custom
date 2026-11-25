local script = debug.getinfo(1, "S").source:sub(2)
local root = script:match("^(.*)/tests/[^/]+$") or "."

local afk_callbacks = {}
local back_callbacks = {}
local chatcommands = {}
local globalsteps = {}
local mods_loaded_callbacks = {}
local bypass_callbacks = {}
local beerchat_callbacks = {}
local kicks = {}
local privileges = {}
local afk_times = {}
local clock = 1000

local function make_player(name)
	return {
		get_player_name = function()
			return name
		end,
	}
end

local players = {
	make_player("alice"),
	make_player("bob"),
	make_player("carol"),
	make_player("dave"),
}

local settings = {
	marghl_custom_idle_time = "100",
	marghl_custom_afk_kick_min_time = "120",
	marghl_custom_afk_kick_occupancy = "0.75",
	marghl_custom_afk_check_interval = "5",
	max_users = "4",
}

minetest = {
	registered_privileges = {},
	settings = {
		get = function(_, name)
			return settings[name]
		end,
	},
	register_privilege = function(name, definition)
		minetest.registered_privileges[name] = definition
	end,
	check_player_privs = function(name, required)
		for privilege in pairs(required) do
			if not (privileges[name] and privileges[name][privilege]) then
				return false
			end
		end
		return true
	end,
	register_chatcommand = function(name, definition)
		chatcommands[name] = definition
	end,
	register_on_leaveplayer = function() end,
	register_globalstep = function(callback)
		globalsteps[#globalsteps + 1] = callback
	end,
	register_can_bypass_userlimit = function(callback)
		bypass_callbacks[#bypass_callbacks + 1] = callback
	end,
	register_on_mods_loaded = function(callback)
		mods_loaded_callbacks[#mods_loaded_callbacks + 1] = callback
	end,
	get_connected_players = function()
		return players
	end,
	get_us_time = function()
		return clock * 1000000
	end,
	kick_player = function(name, reason)
		kicks[#kicks + 1] = {name = name, reason = reason}
	end,
	log = function() end,
}

afk_api = {
	register_on_afk = function(definition)
		afk_callbacks[#afk_callbacks + 1] = definition
	end,
	register_on_back = function(definition)
		back_callbacks[#back_callbacks + 1] = definition
	end,
	get_afk_time = function(player)
		return afk_times[player:get_player_name()]
	end,
}

beerchat = {
	register_callback = function(trigger, callback)
		beerchat_callbacks[trigger] = callback
	end,
}

marghl_custom = {
	S = function(text, ...)
		local arguments = {...}
		return (text:gsub("@(%d+)", function(index)
			return tostring(arguments[tonumber(index)] or "")
		end))
	end,
}

dofile(root .. "/marghl_custom/afk_kick.lua")

assert(minetest.registered_privileges.allow_afk, "allow_afk privilege missing")
assert(afk_callbacks[1].min_afk_time == 100, "idle threshold must be configurable")
assert(back_callbacks[1].min_afk_time == 0, "all activity must clear status")
assert(chatcommands.afk, "/afk command missing")
assert(#bypass_callbacks == 1, "user-limit bypass callback missing")

privileges.alice = {allow_afk = true}
assert(bypass_callbacks[1]("alice"), "exempt player must bypass user limit")
assert(not bypass_callbacks[1]("bob"), "regular player must not bypass user limit")

-- Manual AFK blocks PMs until activity is detected.
chatcommands.afk.func("carol")
assert(marghl_custom.player_status.get("carol") == "afk", "manual AFK status missing")
mods_loaded_callbacks[1]()
local allowed, message = beerchat_callbacks.before_send_pm("bob", "hello", "carol")
assert(allowed == false and message:find("/mail", 1, true), "AFK PM must point to mail")
back_callbacks[1].func(players[3])
assert(marghl_custom.player_status.get("carol") == "active", "activity must clear AFK")

-- Above 75%, idle always has priority over AFK, even if AFK is older.
clock = 1300
afk_times.alice = 250
afk_times.bob = 150
afk_callbacks[1].func(players[1], 250)
afk_callbacks[1].func(players[2], 150)
clock = 1000
chatcommands.afk.func("dave")
clock = 1300
globalsteps[1](5)
assert(#kicks == 1 and kicks[1].name == "bob",
	"longest non-exempt idle player must be kicked before AFK")

-- Exactly 75% occupancy does not trigger a kick.
players = {players[1], players[2], players[3]}
globalsteps[1](5)
assert(#kicks == 1, "exactly 75% occupancy must not trigger a kick")

print("AFK status validation passed: idle priority, occupancy, PM block, exemption, bypass.")
