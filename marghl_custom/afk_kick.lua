local S = assert(marghl_custom.S)

local kick_time = math.max(1,
	math.floor(tonumber(minetest.settings:get("marghl_custom_afk_kick_time")) or 300))
local warning_time = math.max(0,
	math.floor(tonumber(minetest.settings:get("marghl_custom_afk_warning_time")) or 30))
warning_time = math.min(warning_time, kick_time - 1)

if not minetest.registered_privileges.allow_afk then
	minetest.register_privilege("allow_afk", {
		description = S("May remain AFK without being disconnected"),
		give_to_singleplayer = true,
		give_to_admin = true,
	})
end

local function may_remain_afk(player)
	return minetest.check_player_privs(player:get_player_name(), {allow_afk = true})
end

if warning_time > 0 then
	afk_api.register_on_afk({
		min_afk_time = kick_time - warning_time,
		func = function(player)
			if may_remain_afk(player) then
				return
			end
			minetest.chat_send_player(player:get_player_name(),
				S("AFK warning: You will be disconnected in @1 seconds.", warning_time))
		end,
	})
end

afk_api.register_on_afk({
	min_afk_time = kick_time,
	func = function(player, afk_time)
		if may_remain_afk(player) then
			return
		end
		local name = player:get_player_name()
		minetest.log("action", "[marghl_custom] AFK kick: " .. name ..
			" after " .. math.floor(afk_time) .. " seconds")
		minetest.kick_player(name,
			S("Disconnected after @1 seconds of inactivity.", kick_time))
	end,
})
