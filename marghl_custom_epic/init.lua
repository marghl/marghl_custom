local function update_formspec(meta, kind)
	local topic = minetest.formspec_escape(meta:get_string("topic"))
	local save_name = minetest.formspec_escape(meta:get_string("save_name"))
	local title = kind == "check" and "Epic savegame check" or "Epic automatic savegame load"

	meta:set_string("infotext", title .. ": " .. topic .. "/" .. save_name)
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[8,3.4]" ..
		"field[0.4,0.8;7.2,0.7;topic;Topic;" .. topic .. "]" ..
		"field[0.4,1.8;7.2,0.7;save_name;Name;" .. save_name .. "]" ..
		"button_exit[2.5,2.6;3,0.8;save;Save]")
end

local function construct(kind)
	return function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("topic", "Tutorial")
		meta:set_string("save_name", "Fortschritt")
		update_formspec(meta, kind)
	end
end

local function receive_fields(kind)
	return function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end
		if fields.save then
			local meta = minetest.get_meta(pos)
			meta:set_string("topic", fields.topic or "")
			meta:set_string("save_name", fields.save_name or "")
			update_formspec(meta, kind)
		end
	end
end

local function get_save_position(meta, playername)
	local topic = meta:get_string("topic")
	local save_name = meta:get_string("save_name")
	if topic == "" or save_name == "" then
		return nil
	end

	local savegame = epic.savegame.load(playername)
	local topic_data = savegame[topic]
	local pos = topic_data and topic_data[save_name]
	if type(pos) ~= "table" or
		type(pos.x) ~= "number" or type(pos.y) ~= "number" or type(pos.z) ~= "number" then
		return nil
	end
	return vector.new(pos)
end

minetest.register_node("marghl_custom_epic:savegame_check", {
	description = "Epic Savegame Check block: succeeds if the configured savegame exists",
	tiles = epic.create_texture("condition", "epic_save.png^epic_question_mark.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,
	on_construct = construct("check"),
	on_receive_fields = receive_fields("check"),

	epic = {
		on_enter = function(_, meta, player, ctx)
			if get_save_position(meta, player:get_player_name()) then
				ctx.next()
			end
		end,
	},
})

minetest.register_node("marghl_custom_epic:savegame_load", {
	description = "Epic Automatic Savegame Load block: loads the configured savegame",
	tiles = epic.create_texture("action", "epic_load.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,
	on_construct = construct("load"),
	on_receive_fields = receive_fields("load"),

	epic = {
		on_enter = function(_, meta, player, ctx)
			local playername = player:get_player_name()
			local save_pos = get_save_position(meta, playername)
			if not save_pos then
				epic.chat_send_player(playername, "Configured savegame not found")
				ctx.next()
				return
			end

			local save_node = epic.get_node(save_pos)
			if not save_node or save_node.name ~= "epic:save" then
				epic.chat_send_player(playername, "The save block no longer exists")
				ctx.next()
				return
			end

			local save_meta = minetest.get_meta(save_pos)
			local relative_pos = minetest.string_to_pos(save_meta:get_string("pos"))
			if not relative_pos then
				epic.chat_send_player(playername, "The savegame has no valid target")
				ctx.next()
				return
			end

			local destination = epic.to_absolute_pos(save_pos, relative_pos)
			local destination_node = epic.get_node(destination)
			if destination_node and destination_node.name == "epic:epic" then
				local destination_meta = minetest.get_meta(destination)
				local main_relative = minetest.string_to_pos(destination_meta:get_string("main_pos"))
				if main_relative then
					ctx.next(epic.to_absolute_pos(destination, main_relative))
					return
				end
			elseif destination_node and epic.is_epic(destination_node) then
				ctx.next(destination)
				return
			end

			player:set_pos(vector.add(destination, {x = 0, y = 0.5, z = 0}))
			ctx.abort("savegame_loaded")
		end,
	},
})

local function update_inventory_check_formspec(meta)
	meta:set_string("infotext", "Epic Inventory Check block")
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[10.4,8.1]" ..
		"label[0.4,0.4;Required items and quantities]" ..
		"list[context;main;0.4,0.8;8,1;]" ..
		"label[0.4,2.2;Player inventory]" ..
		"list[current_player;main;0.4,2.6;8,4;]" ..
		"listring[context;main]" ..
		"listring[current_player;main]")
end

local function may_configure_inventory(pos, player)
	return player and not minetest.is_protected(pos, player:get_player_name())
end

minetest.register_node("marghl_custom_epic:inventory_check", {
	description = "Epic Exact Inventory Check block: checks the complete inventory without consuming it",
	tiles = epic.create_texture("condition", "epic_briefcase.png^epic_question_mark.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:get_inventory():set_size("main", 8)
		update_inventory_check_formspec(meta)
	end,

	allow_metadata_inventory_put = function(pos, _, _, stack, player)
		return may_configure_inventory(pos, player) and stack:get_count() or 0
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		return may_configure_inventory(pos, player) and stack:get_count() or 0
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		return may_configure_inventory(pos, player) and count or 0
	end,

	epic = {
		on_check = function(_, meta, player, ctx)
			local requirements = meta:get_inventory():get_list("main") or {}
			local required_counts = {}
			for _, stack in ipairs(requirements) do
				if not stack:is_empty() then
					local item_name = stack:get_name()
					required_counts[item_name] = (required_counts[item_name] or 0) + stack:get_count()
				end
			end

			local present_counts = {}
			for _, stack in ipairs(player:get_inventory():get_list("main") or {}) do
				if not stack:is_empty() then
					local item_name = stack:get_name()
					present_counts[item_name] = (present_counts[item_name] or 0) + stack:get_count()
				end
			end

			for item_name, required_count in pairs(required_counts) do
				if (present_counts[item_name] or 0) < required_count then
					return
				end
			end
			for item_name, present_count in pairs(present_counts) do
				if (required_counts[item_name] or 0) ~= present_count then
					return
				end
			end

			ctx.next()
		end,
	},
})

-- Erweiterung des originalen Epic-Dialogsystems: Ein Textblock in derselben
-- Branch-Flaeche fuegt der Auswahl-Formspec erklaerenden, nicht anklickbaren
-- Text hinzu. Die Dateien der Epic-Mod bleiben dabei unveraendert.
local DIALOGUE_FORMNAME = "marghl_custom_epic:dialogue"
local active_dialogues = {}

local function get_dialogue(playername)
	local dialogue = active_dialogues[playername]
	if not dialogue then
		dialogue = {
			active = false,
			quit = false,
			selected = nil,
			targets = {},
			texts = {},
			choice_fields = {},
		}
		active_dialogues[playername] = dialogue
	end
	return dialogue
end

local function sorted_dialogue_entries(entries)
	local result = {}
	for pos_str, value in pairs(entries) do
		if type(value) == "table" then
			result[#result + 1] = {
				pos = pos_str,
				text = value.text or "",
				kind = value.kind or "dialogue",
			}
		else
			result[#result + 1] = {pos = pos_str, text = value, kind = "dialogue"}
		end
	end
	table.sort(result, function(a, b)
		return a.pos < b.pos
	end)
	return result
end

local function count_text_lines(value)
	local _, newline_count = value:gsub("\n", "")
	return newline_count + 1
end

local function update_epic_dialogue_formspec(meta)
	local dialogue_text = meta:get_string("text")
	meta:set_string("infotext", "Dialogue block: '" .. dialogue_text .. "'")
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[10,6]" ..
		"textarea[0.4,0.5;9.2,4.4;text;Text;" ..
		minetest.formspec_escape(dialogue_text) .. "]" ..
		"button_exit[3.5,5.1;3,0.7;save;Save]")
end

local function show_dialogue(playername)
	local dialogue = active_dialogues[playername]
	if not dialogue then
		return
	end

	local text_entries = sorted_dialogue_entries(dialogue.texts)
	local target_entries = sorted_dialogue_entries(dialogue.targets)
	dialogue.choice_fields = {}
	local text_parts = {}
	for _, entry in ipairs(text_entries) do
		text_parts[#text_parts + 1] = entry.text
	end

	local choices_y = 0.3
	if #text_parts > 0 then
		choices_y = 2.8
	end
	local choice_layout = {}
	local next_y = choices_y
	for index, entry in ipairs(target_entries) do
		-- Echte Zeilenumbrueche erhalten entsprechend Platz. Textarea sorgt
		-- zusaetzlich fuer automatischen Umbruch langer Zeilen.
		local entry_height = entry.kind == "button" and 0.9
			or math.max(0.9, count_text_lines(entry.text) * 0.55 + 0.25)
		choice_layout[index] = {y = next_y, height = entry_height}
		next_y = next_y + entry_height + 0.15
	end
	local height = math.max(next_y + 0.2, 1.5)
	local formspec = {
		"formspec_version[4]",
		("size[10,%.1f]"):format(height),
	}
	if #text_parts > 0 then
		formspec[#formspec + 1] = "textarea[0.4,0.3;9.2,2.4;;;" ..
			minetest.formspec_escape(table.concat(text_parts, "\n")) .. "]"
	end

	for index, entry in ipairs(target_entries) do
		local layout = choice_layout[index]
		local field_name = "choice_" .. index
		local button_height = 0.7
		local button_y = layout.y
		dialogue.choice_fields[field_name] = entry.pos
		if entry.kind == "button" then
			formspec[#formspec + 1] = ("button_exit[0.4,%.2f;9.2,%.2f;%s;%s]")
				:format(button_y, button_height, field_name,
					minetest.formspec_escape(entry.text))
		else
			formspec[#formspec + 1] = ("button_exit[0.4,%.2f;2,%.2f;%s;Auswaehlen]")
				:format(button_y, button_height, field_name)
			formspec[#formspec + 1] = ("textarea[2.7,%.2f;6.9,%.2f;;;%s]")
				:format(layout.y, layout.height, minetest.formspec_escape(entry.text))
		end
	end

	minetest.show_formspec(playername, DIALOGUE_FORMNAME, table.concat(formspec))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= DIALOGUE_FORMNAME then
		return
	end
	local dialogue = active_dialogues[player:get_player_name()]
	if not dialogue then
		return true
	end
	for field_name, pos_str in pairs(dialogue.choice_fields) do
		if fields[field_name] then
			dialogue.selected = pos_str
			return true
		end
	end
	dialogue.quit = true
	return true
end)

minetest.override_item("epic:dialogue", {
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("text", "Example text")
		update_epic_dialogue_formspec(meta)
	end,
	on_receive_fields = function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end
		if fields.save then
			local meta = minetest.get_meta(pos)
			meta:set_string("text", fields.text or "")
			update_epic_dialogue_formspec(meta)
		end
	end,
	epic = {
		on_enter = function(pos, meta, player)
			local dialogue = get_dialogue(player:get_player_name())
			dialogue.targets[minetest.pos_to_string(pos)] = meta:get_string("text")
		end,
		on_check = function(pos, _, player, ctx)
			local dialogue = active_dialogues[player:get_player_name()]
			if not dialogue then
				return
			end
			if not dialogue.active then
				show_dialogue(player:get_player_name())
				dialogue.active = true
			end
			if dialogue.quit then
				ctx.abort("dialogue-exit")
			elseif dialogue.selected == minetest.pos_to_string(pos) then
				ctx.next()
			end
		end,
		on_exit = function(_, _, player)
			active_dialogues[player:get_player_name()] = nil
		end,
	},
})

-- Bereits gesetzte Dialogbloecke erhalten beim Laden ebenfalls das neue
-- mehrzeilige Bearbeitungsformular.
minetest.register_lbm({
	label = "Update Epic dialogue formspec for multiline text",
	name = "marghl_custom_epic:update_dialogue_formspec",
	nodenames = {"epic:dialogue"},
	run_at_every_load = true,
	action = function(pos)
		update_epic_dialogue_formspec(minetest.get_meta(pos))
	end,
})

local function update_dialogue_text_formspec(meta)
	local display_text = meta:get_string("text")
	meta:set_string("infotext", "Epic Dialogue Text: " .. display_text)
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[10,6]" ..
		"textarea[0.4,0.5;9.2,4.4;text;Text;" ..
		minetest.formspec_escape(display_text) .. "]" ..
		"button_exit[3.5,5.1;3,0.7;save;Save]")
end

minetest.register_node("marghl_custom_epic:dialogue_text", {
	description = "Epic Dialogue Text Condition: adds text and always stays false",
	tiles = epic.create_texture("condition", "epic_bubble.png^epic_question_mark.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("text", "Dialogtext")
		update_dialogue_text_formspec(meta)
	end,
	on_receive_fields = function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end
		if fields.save then
			local meta = minetest.get_meta(pos)
			meta:set_string("text", fields.text or "")
			update_dialogue_text_formspec(meta)
		end
	end,
	epic = {
		on_enter = function(pos, meta, player)
			local dialogue = get_dialogue(player:get_player_name())
			dialogue.texts[minetest.pos_to_string(pos)] = meta:get_string("text")
		end,
		-- Absichtlich eine niemals erfolgreiche Branch-Bedingung. Der Block
		-- liefert nur den Text fuer die gemeinsame Dialog-Formspec.
		on_check = function()
			-- false: ctx.next() wird niemals aufgerufen
		end,
	},
})

minetest.register_on_leaveplayer(function(player)
	active_dialogues[player:get_player_name()] = nil
end)

-- Frei beschriftbare Schaltflaeche fuer das gemeinsame Dialogsystem.
-- Der Klick ist die erfolgreiche Bedingung.

local function update_button_dialogue_formspec(meta)
	local button_text = meta:get_string("button_text")
	meta:set_string("infotext", "Epic Button: " .. button_text)
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[9,2.2]" ..
		"field[0.4,0.8;8.2,0.7;button_text;Schaltflaeche;" ..
		minetest.formspec_escape(button_text) .. "]" ..
		"button_exit[3,1.5;3,0.7;save;Speichern]")
end

minetest.register_node("marghl_custom_epic:button_dialogue", {
	description = "Epic Button: one configurable button",
	tiles = epic.create_texture("condition", "epic_go.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("button_text", "Weiter")
		update_button_dialogue_formspec(meta)
	end,
	on_receive_fields = function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end
		if fields.save then
			local meta = minetest.get_meta(pos)
			meta:set_string("button_text", fields.button_text or "")
			update_button_dialogue_formspec(meta)
		end
	end,
	epic = {
		on_enter = function(pos, meta, player)
			local dialogue = get_dialogue(player:get_player_name())
			dialogue.targets[minetest.pos_to_string(pos)] = {
				kind = "button",
				text = meta:get_string("button_text"),
			}
		end,
		on_check = function(pos, _, player, ctx)
			local dialogue = active_dialogues[player:get_player_name()]
			if not dialogue then
				return
			end
			if not dialogue.active then
				show_dialogue(player:get_player_name())
				dialogue.active = true
			end
			if dialogue.quit then
				ctx.abort("dialogue-exit")
			elseif dialogue.selected == minetest.pos_to_string(pos) then
				ctx.next()
			end
		end,
		on_exit = function(_, _, player)
			active_dialogues[player:get_player_name()] = nil
		end,
	},
})

local default_schematic_path = minetest.get_modpath("default") .. "/schematics/"

local function place_forced_tree(pos, filename, offset, rotation)
	minetest.place_schematic(
		vector.add(pos, offset),
		default_schematic_path .. filename,
		rotation,
		nil,
		true
	)
end

local tree_types = {
	{key = "apple", label = "Apple Tree", grow = function(pos)
		place_forced_tree(pos, "apple_tree_from_sapling.mts", {x = -3, y = -1, z = -3}, "random")
	end},
	{key = "jungle", label = "Jungle Tree", grow = function(pos)
		place_forced_tree(pos, "jungle_tree_from_sapling.mts", {x = -2, y = -1, z = -2}, "random")
	end},
	{key = "emergent_jungle", label = "Emergent Jungle Tree", grow = function(pos)
		place_forced_tree(pos, "emergent_jungle_tree_from_sapling.mts", {x = -3, y = -5, z = -3}, "random")
	end},
	{key = "pine", label = "Pine Tree", grow = function(pos)
		local filename = math.random() > 0.5
			and "pine_tree_from_sapling.mts" or "small_pine_tree_from_sapling.mts"
		place_forced_tree(pos, filename, {x = -2, y = -1, z = -2}, "0")
	end},
	{key = "snowy_pine", label = "Snowy Pine Tree", grow = function(pos)
		local filename = math.random() > 0.5
			and "snowy_pine_tree_from_sapling.mts" or "snowy_small_pine_tree_from_sapling.mts"
		place_forced_tree(pos, filename, {x = -2, y = -1, z = -2}, "random")
	end},
	{key = "acacia", label = "Acacia Tree", grow = function(pos)
		place_forced_tree(pos, "acacia_tree_from_sapling.mts", {x = -4, y = -1, z = -4}, "random")
	end},
	{key = "aspen", label = "Aspen Tree", grow = function(pos)
		place_forced_tree(pos, "aspen_tree_from_sapling.mts", {x = -2, y = -1, z = -2}, "0")
	end},
}

local tree_by_key = {}
local tree_key_by_label = {}
local tree_labels = {}
for index, tree in ipairs(tree_types) do
	tree_by_key[tree.key] = tree
	tree_key_by_label[tree.label] = tree.key
	tree_labels[index] = tree.label
end

local function update_tree_formspec(meta)
	local relative_pos = meta:get_string("pos")
	local selected_key = meta:get_string("tree_type")
	local selected_index = 1
	for index, tree in ipairs(tree_types) do
		if tree.key == selected_key then
			selected_index = index
			break
		end
	end

	meta:set_string("infotext", "Epic Grow Tree block: " ..
		(tree_by_key[selected_key] or tree_types[1]).label .. " at " .. relative_pos)
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[8,3.8]" ..
		"label[0.4,0.4;Tree type]" ..
		"dropdown[0.4,0.8;7.2,0.7;tree_type;" ..
		table.concat(tree_labels, ",") .. ";" .. selected_index .. "]" ..
		"label[0.4,1.8;Tree base: " .. minetest.formspec_escape(relative_pos) .. "]" ..
		"button_exit[0.4,2.2;3.4,0.8;setpos;Set ground position]" ..
		"button_exit[4.2,2.2;3.4,0.8;showpos;Show]" ..
		"button_exit[2.5,3.1;3,0.6;save;Save]")
end

minetest.register_node("marghl_custom_epic:grow_tree", {
	description = "Epic Grow Tree block: immediately grows a selected tree",
	tiles = epic.create_texture("action", "default_sapling.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", minetest.pos_to_string({x = 0, y = 1, z = 0}))
		meta:set_string("tree_type", "apple")
		update_tree_formspec(meta)
	end,

	after_place_node = function(pos, placer)
		if placer then
			minetest.get_meta(pos):set_string("owner", placer:get_player_name())
		end
	end,

	on_receive_fields = function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end

		local meta = minetest.get_meta(pos)
		if fields.tree_type and tree_key_by_label[fields.tree_type] then
			meta:set_string("tree_type", tree_key_by_label[fields.tree_type])
		end

		if fields.setpos then
			local playername = sender:get_player_name()
			epic.chat_send_player(playername, "Please punch the ground where the tree should grow")
			epic.punchnode_callback(sender, {
				timeout = 300,
				check_protection = true,
				callback = function(ground_pos)
					local tree_pos = vector.add(ground_pos, {x = 0, y = 1, z = 0})
					local current_meta = minetest.get_meta(pos)
					current_meta:set_string("pos", minetest.pos_to_string(epic.to_relative_pos(pos, tree_pos)))
					update_tree_formspec(current_meta)
					epic.chat_send_player(playername, "Tree position set to " .. minetest.pos_to_string(tree_pos))
				end,
			})
		elseif fields.showpos then
			local relative_pos = minetest.string_to_pos(meta:get_string("pos"))
			if relative_pos then
				epic.show_waypoint(sender:get_player_name(),
					epic.to_absolute_pos(pos, relative_pos), "Tree position", 3)
			end
		end

		update_tree_formspec(meta)
	end,

	epic = {
		on_enter = function(pos, meta, _, ctx)
			local relative_pos = minetest.string_to_pos(meta:get_string("pos"))
			local tree = tree_by_key[meta:get_string("tree_type")] or tree_types[1]
			if not relative_pos then
				ctx.next()
				return
			end

			local target_pos = epic.to_absolute_pos(pos, relative_pos)
			local owner = meta:get_string("owner")
			if minetest.is_protected(target_pos, owner) then
				minetest.log("warning", "[marghl_custom_epic] Protected tree target at " ..
					minetest.pos_to_string(target_pos))
				ctx.next()
				return
			end

			tree.grow(target_pos)
			minetest.log("action", ("[marghl_custom_epic] Grew %s at %s")
				:format(tree.key, minetest.pos_to_string(target_pos)))
			ctx.next()
		end,
	},
})

-- A branch can poll several dig conditions for the same player at once.
-- Each condition therefore gets its own watcher, keyed by its step_data table.
local dig_watchers = {}

local function update_dig_check_formspec(meta)
	local relative_pos = meta:get_string("pos")
	local node_name = meta:get_string("node_name")
	meta:set_string("infotext", "Epic Dig Check block: " .. node_name .. " at " .. relative_pos)
	meta:set_string("formspec",
		"formspec_version[4]" ..
		"size[8,3.1]" ..
		"label[0.4,0.5;Target: " .. minetest.formspec_escape(relative_pos) .. "]" ..
		"label[0.4,1.0;Node: " .. minetest.formspec_escape(node_name) .. "]" ..
		"button_exit[0.4,1.6;3.4,0.8;setpos;Set target]" ..
		"button_exit[4.2,1.6;3.4,0.8;showpos;Show]")
end

minetest.register_node("marghl_custom_epic:dig_check", {
	description = "Epic Dig Check block: waits until the player digs the selected node",
	tiles = epic.create_texture("condition", "default_tool_steelpick.png^epic_question_mark.png"),
	paramtype2 = "facedir",
	groups = {cracky = 3, oddly_breakable_by_hand = 3, epic = 1},
	on_rotate = epic.on_rotate,

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("pos", minetest.pos_to_string({x = 0, y = 0, z = 0}))
		meta:set_string("node_name", "")
		update_dig_check_formspec(meta)
	end,

	on_receive_fields = function(pos, _, fields, sender)
		if not sender or minetest.is_protected(pos, sender:get_player_name()) then
			return
		end

		local meta = minetest.get_meta(pos)
		if fields.setpos then
			local playername = sender:get_player_name()
			epic.chat_send_player(playername, "Please punch the node whose digging should be monitored")
			epic.punchnode_callback(sender, {
				timeout = 300,
				check_protection = true,
				callback = function(target_pos, target_node)
					local current_meta = minetest.get_meta(pos)
					current_meta:set_string("pos",
						minetest.pos_to_string(epic.to_relative_pos(pos, target_pos)))
					current_meta:set_string("node_name", target_node.name)
					update_dig_check_formspec(current_meta)
					epic.chat_send_player(playername, "Dig target set to " ..
						target_node.name .. " at " .. minetest.pos_to_string(target_pos))
				end,
			})
		elseif fields.showpos then
			local relative_pos = minetest.string_to_pos(meta:get_string("pos"))
			if relative_pos then
				epic.show_waypoint(sender:get_player_name(),
					epic.to_absolute_pos(pos, relative_pos), "Dig target", 3)
			end
		end
	end,

	epic = {
		on_enter = function(pos, meta, player, ctx)
			local relative_pos = minetest.string_to_pos(meta:get_string("pos"))
			local node_name = meta:get_string("node_name")
			if not relative_pos or node_name == "" then
				return
			end

			local playername = player:get_player_name()
			ctx.step_data.dug = false
			local player_watchers = dig_watchers[playername]
			if not player_watchers then
				player_watchers = {}
				dig_watchers[playername] = player_watchers
			end
			player_watchers[ctx.step_data] = {
				pos_hash = minetest.hash_node_position(epic.to_absolute_pos(pos, relative_pos)),
				node_name = node_name,
			}
		end,
		on_check = function(_, _, player, ctx)
			if ctx.step_data.dug then
				ctx.next()
			end
		end,
		on_exit = function(_, _, player, ctx)
			local playername = player:get_player_name()
			local player_watchers = dig_watchers[playername]
			if player_watchers then
				player_watchers[ctx.step_data] = nil
				if next(player_watchers) == nil then
					dig_watchers[playername] = nil
				end
			end
		end,
	},
})

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then
		return
	end
	local player_watchers = dig_watchers[digger:get_player_name()]
	if not player_watchers then
		return
	end
	local pos_hash = minetest.hash_node_position(pos)
	for step_data, watcher in pairs(player_watchers) do
		if watcher.pos_hash == pos_hash and watcher.node_name == oldnode.name then
			step_data.dug = true
		end
	end
end)

minetest.register_on_leaveplayer(function(player)
	dig_watchers[player:get_player_name()] = nil
end)
