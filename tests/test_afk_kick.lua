local script = debug.getinfo(1, "S").source:sub(2)
local root = script:match("^(.*)/tests/[^/]+$") or "."

local callbacks = {}
local messages = {}
local kicks = {}
local privileges = {}

minetest = {
	registered_privileges = {},
	settings = {
		get = function()
			return nil
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
	chat_send_player = function(name, message)
		messages[#messages + 1] = {name = name, message = message}
	end,
	kick_player = function(name, reason)
		kicks[#kicks + 1] = {name = name, reason = reason}
	end,
	log = function() end,
}

afk_api = {
	register_on_afk = function(definition)
		callbacks[#callbacks + 1] = definition
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

local player = {}
function player:get_player_name()
	return "alice"
end

dofile(root .. "/marghl_custom/afk_kick.lua")

assert(minetest.registered_privileges.allow_afk, "allow_afk privilege missing")
assert(#callbacks == 2, "warning and kick callbacks expected")
assert(callbacks[1].min_afk_time == 270, "warning threshold must be 270 seconds")
assert(callbacks[2].min_afk_time == 300, "kick threshold must be 300 seconds")

callbacks[1].func(player, 270)
assert(#messages == 1 and messages[1].name == "alice", "warning missing")
callbacks[2].func(player, 300)
assert(#kicks == 1 and kicks[1].name == "alice", "kick missing")

privileges.alice = {allow_afk = true}
callbacks[1].func(player, 270)
callbacks[2].func(player, 300)
assert(#messages == 1, "exempt player was warned")
assert(#kicks == 1, "exempt player was kicked")

print("AFK kick validation passed: thresholds, warning, kick, exemption.")
