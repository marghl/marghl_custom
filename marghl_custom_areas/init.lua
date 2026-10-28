local S = minetest.get_translator(minetest.get_current_modname())

local protection_privileges = {
	protect_streets = "Darf in geschuetzten oeffentlichen Strassen bauen",
	protect_public = "Darf in geschuetzten oeffentlichen Bereichen bauen",
	protect_infra = "Darf an geschuetzter oeffentlicher Infrastruktur bauen",
}

for name, description in pairs(protection_privileges) do
	minetest.register_privilege(name, {
		description = description,
		give_to_singleplayer = false,
		give_to_admin = true,
	})
end

local original_can_interact = areas.canInteract
local last_safe_meta_key = "marghl_custom_areas:last_safe_position"
local last_blocked_area = {}

local function get_relevant_areas(pos)
	if areas.config.use_smallest_area_precedence then
		local area = areas:getSmallestAreaAtPos(pos)
		return area and {area} or {}
	end
	return areas:getAreasAtPos(pos)
end

local function has_privilege_access(area, name)
	for privilege in pairs(area.privs_open or {}) do
		if minetest.check_player_privs(name, {[privilege] = true}) then
			return true
		end
	end
	return false
end

-- Erweiterung aus OgelGames' Areas-Fork, angepasst an die aktuelle Areas-API.
-- Eine Freigabe bedeutet, dass das Privileg alternativ zum Besitzerzugang gilt.
function areas:canInteract(pos, name)
	if original_can_interact(self, pos, name) then
		return true
	end

	for _, area in pairs(get_relevant_areas(pos)) do
		if has_privilege_access(area, name) then
			return true
		end
	end
	return false
end

local function get_blocking_area(pos, name)
	for id, area in pairs(areas:getAreasAtPos(pos)) do
		if area.denied_players
				and area.denied_players[name]
				and not areas:isAreaOwner(id, name) then
			return id, area
		end
	end
end

local function position_is_in_area(pos, area)
	return pos.x >= area.pos1.x and pos.x <= area.pos2.x
		and pos.y >= area.pos1.y and pos.y <= area.pos2.y
		and pos.z >= area.pos1.z and pos.z <= area.pos2.z
end

local function nearest_outside_position(pos, area)
	local margin = 1.5
	local candidates = {
		{x = area.pos1.x - margin, y = pos.y, z = pos.z},
		{x = area.pos2.x + margin, y = pos.y, z = pos.z},
		{x = pos.x, y = pos.y, z = area.pos1.z - margin},
		{x = pos.x, y = pos.y, z = area.pos2.z + margin},
	}
	local nearest = candidates[1]
	local nearest_distance = vector.distance(pos, nearest)
	for index = 2, #candidates do
		local distance = vector.distance(pos, candidates[index])
		if distance < nearest_distance then
			nearest = candidates[index]
			nearest_distance = distance
		end
	end
	return nearest
end

local function eject_player(player, id, area)
	local name = player:get_player_name()
	local current_pos = player:get_pos()
	local saved_pos = minetest.string_to_pos(
		player:get_meta():get_string(last_safe_meta_key)
	)

	if not saved_pos
			or position_is_in_area(saved_pos, area)
			or get_blocking_area(saved_pos, name) then
		saved_pos = nearest_outside_position(current_pos, area)
	end

	player:set_pos(saved_pos)
	if last_blocked_area[name] ~= id then
		minetest.chat_send_player(name,
			S("Du darfst Area @1 nicht betreten.", id))
	end
	last_blocked_area[name] = id
end

local entry_timer = 0
minetest.register_globalstep(function(dtime)
	entry_timer = entry_timer + dtime
	if entry_timer < 0.2 then
		return
	end
	entry_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local pos = player:get_pos()
		local id, area = get_blocking_area(pos, name)
		if area then
			eject_player(player, id, area)
		else
			player:get_meta():set_string(last_safe_meta_key,
				minetest.pos_to_string(pos))
			last_blocked_area[name] = nil
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	last_blocked_area[player:get_player_name()] = nil
end)

minetest.register_chatcommand("area_priv_open", {
	params = "<ID> <Privileg>",
	description = "Schaltet eine Area fuer Spieler mit einem Privileg frei oder wieder geschlossen",
	func = function(name, param)
		local id_text, privilege = param:match("^(%d+)%s+(%S+)%s*$")
		local id = tonumber(id_text)
		if not id then
			return false, "Verwendung: /area_priv_open <ID> <Privileg>"
		end
		if not minetest.registered_privileges[privilege] then
			return false, "Unbekanntes Privileg: " .. privilege
		end
		if not areas:isAreaOwner(id, name) then
			return false, "Area " .. id .. " existiert nicht oder gehoert dir nicht."
		end

		local area = areas.areas[id]
		local privileges = area.privs_open or {}
		local enabled = not privileges[privilege]
		privileges[privilege] = enabled or nil
		area.privs_open = next(privileges) and privileges or nil
		areas:save()

		minetest.log("action", string.format(
			"[marghl_custom_areas] %s %s privilege %s for area %d",
			name,
			enabled and "enabled" or "disabled",
			privilege,
			id
		))
		if enabled then
			return true, S("Area @1 ist jetzt fuer das Privileg '@2' freigegeben.", id, privilege)
		end
		return true, S("Freigabe des Privilegs '@1' fuer Area @2 entfernt.", privilege, id)
	end,
})

minetest.register_chatcommand("area_priv_list", {
	params = "<ID>",
	description = "Zeigt die Privileg-Freigaben einer Area",
	func = function(name, param)
		local id = tonumber(param:match("^%s*(%d+)%s*$"))
		if not id then
			return false, "Verwendung: /area_priv_list <ID>"
		end
		if not areas:isAreaOwner(id, name) then
			return false, "Area " .. id .. " existiert nicht oder gehoert dir nicht."
		end

		local result = {}
		for privilege in pairs(areas.areas[id].privs_open or {}) do
			result[#result + 1] = privilege
		end
		table.sort(result)
		if #result == 0 then
			return true, "Area " .. id .. " hat keine Privileg-Freigaben."
		end
		return true, "Area " .. id .. ": " .. table.concat(result, ", ")
	end,
})

minetest.register_chatcommand("area_deny", {
	params = "<ID> <Spieler>",
	description = "Sperrt einen bestimmten Spieler aus einer Area aus",
	func = function(name, param)
		local id_text, target = param:match("^%s*(%d+)%s+(%S+)%s*$")
		local id = tonumber(id_text)
		if not id then
			return false, "Verwendung: /area_deny <ID> <Spieler>"
		end
		if not areas:isAreaOwner(id, name) then
			return false, "Area " .. id .. " existiert nicht oder gehoert dir nicht."
		end
		if not areas:player_exists(target) then
			return false, "Unbekannter Spieler: " .. target
		end
		if areas:isAreaOwner(id, target) then
			return false, "Besitzer und Areas-Administratoren koennen nicht ausgesperrt werden."
		end

		local area = areas.areas[id]
		area.denied_players = area.denied_players or {}
		if area.denied_players[target] then
			return false, target .. " ist bereits aus Area " .. id .. " ausgesperrt."
		end
		area.denied_players[target] = true
		areas:save()

		local player = minetest.get_player_by_name(target)
		if player and position_is_in_area(player:get_pos(), area) then
			eject_player(player, id, area)
		end
		minetest.log("action", string.format(
			"[marghl_custom_areas] %s denied %s entry to area %d",
			name,
			target,
			id
		))
		return true, target .. " wurde aus Area " .. id .. " ausgesperrt."
	end,
})

minetest.register_chatcommand("area_allow", {
	params = "<ID> <Spieler>",
	description = "Hebt die Zutrittssperre fuer einen Spieler auf",
	func = function(name, param)
		local id_text, target = param:match("^%s*(%d+)%s+(%S+)%s*$")
		local id = tonumber(id_text)
		if not id then
			return false, "Verwendung: /area_allow <ID> <Spieler>"
		end
		if not areas:isAreaOwner(id, name) then
			return false, "Area " .. id .. " existiert nicht oder gehoert dir nicht."
		end

		local area = areas.areas[id]
		if not area.denied_players or not area.denied_players[target] then
			return false, target .. " ist fuer Area " .. id .. " nicht ausgesperrt."
		end
		area.denied_players[target] = nil
		if next(area.denied_players) == nil then
			area.denied_players = nil
		end
		areas:save()
		minetest.log("action", string.format(
			"[marghl_custom_areas] %s allowed %s entry to area %d",
			name,
			target,
			id
		))
		return true, target .. " darf Area " .. id .. " wieder betreten."
	end,
})

minetest.register_chatcommand("area_deny_list", {
	params = "<ID>",
	description = "Zeigt die aus einer Area ausgesperrten Spieler",
	func = function(name, param)
		local id = tonumber(param:match("^%s*(%d+)%s*$"))
		if not id then
			return false, "Verwendung: /area_deny_list <ID>"
		end
		if not areas:isAreaOwner(id, name) then
			return false, "Area " .. id .. " existiert nicht oder gehoert dir nicht."
		end

		local result = {}
		for player_name in pairs(areas.areas[id].denied_players or {}) do
			result[#result + 1] = player_name
		end
		table.sort(result)
		if #result == 0 then
			return true, "Aus Area " .. id .. " ist niemand ausgesperrt."
		end
		return true, "Aus Area " .. id .. " ausgesperrt: "
			.. table.concat(result, ", ")
	end,
})
