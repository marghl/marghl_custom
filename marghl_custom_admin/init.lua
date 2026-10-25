local function count_entries(registry)
	local count = 0
	for _ in pairs(registry) do
		count = count + 1
	end
	return count
end

minetest.register_chatcommand("nodecount", {
	description = "Zeigt die Anzahl der registrierten Nodes und Items",
	privs = {server = true},
	func = function()
		local node_count = count_entries(minetest.registered_nodes)
		local item_count = count_entries(minetest.registered_items)
		return true, string.format(
			"Registriert: %d Nodes, %d Items insgesamt.",
			node_count,
			item_count
		)
	end,
})

local notice_colors = {
	white = "#FFFFFF",
	lightgray = "#C0C0C0",
	lightgrey = "#C0C0C0",
	gray = "#888888",
	grey = "#888888",
	darkgray = "#555555",
	darkgrey = "#555555",
	black = "#000000",
	red = "#FF5555",
	orange = "#FFAA00",
	yellow = "#FFFF55",
	green = "#55FF55",
	cyan = "#55FFFF",
	blue = "#5555FF",
	violet = "#AA55FF",
	purple = "#AA55FF",
	magenta = "#FF55FF",
	pink = "#FFAAAA",
}

local function parse_notice(rest)
	local color_name, colored_message = rest:match("^(%S+)%s+(.+)$")
	if not color_name then
		return rest
	end

	local color = notice_colors[color_name:lower()]
	if not color and color_name:match("^#%x%x%x%x%x%x$") then
		color = color_name
	end
	if color then
		return minetest.colorize(color, colored_message)
	end
	return rest
end

minetest.register_chatcommand("notice", {
	params = "<Spieler> [Farbe|#RRGGBB] <Nachricht>",
	description = "Sendet einem Spieler eine private, optional farbige Nachricht ohne Praefix",
	privs = {server = true},
	func = function(_, param)
		local target, rest = param:match("^(%S+)%s+(.+)$")
		if not target then
			return false, "Verwendung: /notice <Spieler> [Farbe|#RRGGBB] <Nachricht>"
		end

		if not minetest.get_player_by_name(target) then
			return false, "Spieler ist nicht online: " .. target
		end

		minetest.chat_send_player(target, parse_notice(rest))
		return true, "Nachricht an " .. target .. " gesendet."
	end,
})

minetest.register_chatcommand("servermsg", {
	params = "<Nachricht>",
	description = "Sendet eine serverweite Nachricht mit dem Praefix [server]",
	privs = {server = true},
	func = function(_, param)
		if not param:find("%S") then
			return false, "Verwendung: /servermsg <Nachricht>"
		end

		minetest.chat_send_all("[server] " .. param)
		return true, "Serverweite Nachricht gesendet."
	end,
})

local itemsearch_formname = "marghl_custom_admin:itemsearch"
local itemsearch_limit = 300
local itemsearch_state = {}

local function itemsearch_description(def)
	local description = def and def.description or ""
	if minetest.strip_colors then
		description = minetest.strip_colors(description)
	end
	description = description:gsub("[\r\n]+", " "):gsub("%s+", " ")
	return description
end

local function itemsearch_find(query)
	local needle = query:lower()
	local results = {}
	local total = 0

	for item_name, def in pairs(minetest.registered_items) do
		local description = itemsearch_description(def)
		if needle == "" or item_name:lower():find(needle, 1, true)
				or description:lower():find(needle, 1, true) then
			total = total + 1
			results[#results + 1] = {
				name = item_name,
				description = description,
			}
		end
	end

	table.sort(results, function(a, b)
		return a.name < b.name
	end)
	while #results > itemsearch_limit do
		results[#results] = nil
	end
	return results, total
end

local function itemsearch_show(player_name, query, selected)
	local player = minetest.get_player_by_name(player_name)
	if not player or not minetest.check_player_privs(player_name, {give = true}) then
		return
	end

	local state = itemsearch_state[player_name] or {}
	query = query or state.query or ""
	local results, total = itemsearch_find(query)
	selected = math.max(1, math.min(tonumber(selected) or 1, #results))
	state.query = query
	state.results = results
	state.total = total
	state.selected = selected
	itemsearch_state[player_name] = state

	local entries = {}
	for _, result in ipairs(results) do
		local label = result.name
		if result.description ~= "" then
			label = label .. " — " .. result.description
		end
		entries[#entries + 1] = minetest.formspec_escape(label)
	end

	local selected_item = results[selected]
	local status
	if total > #results then
		status = string.format("%d Treffer; die ersten %d werden angezeigt.", total, #results)
	else
		status = string.format("%d Treffer", total)
	end

	local formspec = {
		"formspec_version[4]",
		"size[12,9]",
		"label[0.4,0.35;Item-Suche (einschliesslich versteckter und technischer Items)]",
		"field[0.4,0.75;8.6,0.8;query;Beschreibung oder Itemstring;",
		minetest.formspec_escape(query), "]",
		"button[9.2,0.75;2.4,0.8;search;Suchen]",
		"textlist[0.4,1.75;11.2,5.2;items;",
		table.concat(entries, ","), ";", tostring(selected), ";false]",
		"label[0.4,7.2;", minetest.formspec_escape(status), "]",
	}

	if selected_item then
		formspec[#formspec + 1] = "item_image[0.4,7.55;1,1;" .. selected_item.name .. "]"
		formspec[#formspec + 1] = "label[1.65,7.55;" ..
			minetest.formspec_escape(selected_item.name) .. "]"
		formspec[#formspec + 1] = "button[9.2,7.55;2.4,0.9;give_item;Give]"
	end

	minetest.show_formspec(player_name, itemsearch_formname, table.concat(formspec))
end

minetest.register_chatcommand("itemsearch", {
	params = "[Suchtext]",
	description = "Durchsucht alle registrierten Items und oeffnet eine Give-Oberflaeche",
	privs = {give = true},
	func = function(name, param)
		itemsearch_show(name, param)
		return true
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= itemsearch_formname then
		return
	end

	local name = player:get_player_name()
	if not minetest.check_player_privs(name, {give = true}) then
		itemsearch_state[name] = nil
		return true
	end

	local state = itemsearch_state[name]
	if not state then
		return true
	end

	if fields.quit then
		itemsearch_state[name] = nil
		return true
	end

	if fields.search or fields.key_enter_field == "query" then
		itemsearch_show(name, fields.query or "", 1)
		return true
	end

	if fields.items then
		local event = minetest.explode_textlist_event(fields.items)
		if event.type == "CHG" or event.type == "DCL" then
			itemsearch_show(name, state.query, event.index)
		end
		return true
	end

	if fields.give_item then
		local result = state.results[state.selected]
		if not result or not minetest.registered_items[result.name] then
			minetest.chat_send_player(name, "Das ausgewaehlte Item ist nicht mehr registriert.")
			return true
		end

		local stack = ItemStack(result.name)
		local inventory = player:get_inventory()
		if not inventory:room_for_item("main", stack) then
			minetest.chat_send_player(name, "Kein Platz im Hauptinventar.")
			return true
		end

		inventory:add_item("main", stack)
		minetest.log("action", string.format(
			"[marghl_custom_admin] %s gave themselves %s via itemsearch",
			name,
			result.name
		))
		minetest.chat_send_player(name, "Erhalten: " .. result.name)
		itemsearch_show(name, state.query, state.selected)
		return true
	end

	return true
end)

minetest.register_on_leaveplayer(function(player)
	itemsearch_state[player:get_player_name()] = nil
end)

local function remove_named_item(inventory, listname, item_name, limit)
	local removed = 0
	local size = inventory:get_size(listname)
	for index = 1, size do
		if removed >= limit then
			break
		end

		local stack = inventory:get_stack(listname, index)
		if stack:get_name() == item_name then
			local amount = math.min(stack:get_count(), limit - removed)
			stack:take_item(amount)
			inventory:set_stack(listname, index, stack)
			removed = removed + amount
		end
	end
	return removed
end

minetest.register_chatcommand("takeitem", {
	params = "<Spieler> <Itemstring> [Anzahl|all]",
	description = "Entfernt ein bestimmtes Item aus Hauptinventar und Ruestung eines Spielers",
	privs = {give = true, server = true},
	func = function(caller, param)
		local target_name, item_name, amount_text =
			param:match("^(%S+)%s+(%S+)%s*(%S*)$")
		if not target_name then
			return false, "Verwendung: /takeitem <Spieler> <Itemstring> [Anzahl|all]"
		end

		if not minetest.registered_items[item_name] then
			return false, "Unbekannter Itemstring: " .. item_name
		end

		local limit = 1
		if amount_text ~= "" then
			if amount_text:lower() == "all" then
				limit = math.huge
			else
				limit = tonumber(amount_text)
				if not limit or limit < 1 or limit ~= math.floor(limit) then
					return false, "Die Anzahl muss eine positive ganze Zahl oder 'all' sein."
				end
			end
		end

		local player = minetest.get_player_by_name(target_name)
		if not player then
			return false, "Spieler ist nicht online: " .. target_name
		end

		local inventory = player:get_inventory()
		local removed = remove_named_item(inventory, "main", item_name, limit)
		if removed < limit and inventory:get_size("armor") > 0 then
			removed = removed + remove_named_item(
				inventory,
				"armor",
				item_name,
				limit - removed
			)
		end

		if removed == 0 then
			return false, target_name .. " besitzt dieses Item nicht im Hauptinventar oder in der Ruestung."
		end

		if armor and armor.set_player_armor then
			armor:set_player_armor(player)
		end

		minetest.log("action", string.format(
			"[marghl_custom_admin] %s removed %d x %s from %s",
			caller,
			removed,
			item_name,
			target_name
		))
		return true, string.format(
			"%d x %s von %s entfernt.",
			removed,
			item_name,
			target_name
		)
	end,
})
