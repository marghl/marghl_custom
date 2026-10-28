local S = core.get_translator(core.get_current_modname())

local horse_taming_duration = 15
local horse_throw_interval = 2
local horse_initial_throw_chance = 15
local horse_attempt_bonus = 3
local horse_minimum_throw_chance = 5
local horse_inventory_size = 16
local horse_inventory_formname = "marghl_custom_mobs:horse_inventory"

local horse_inventory_sessions = {}

local function is_player(player)
	return player and player:is_player()
end

local function is_owner(self, player)
	return self.tamed
		and self.owner == player:get_player_name()
end

local function can_access_horse(self, player)
	local player_name = player:get_player_name()
	return is_owner(self, player)
		or core.check_player_privs(player_name, {protection_bypass = true})
end

local function take_one(player, itemname)
	if core.is_creative_enabled(player:get_player_name()) then
		return
	end
	player:get_inventory():remove_item("main", itemname)
end

local function drop_item(pos, itemname)
	if pos then
		core.add_item(pos, itemname)
	end
end

local function horse_inventory_name(player_name)
	return "marghl_custom_mobs_horse_" .. player_name
end

local function save_horse_inventory(session, inventory)
	if not session or not session.horse then
		return
	end
	local contents = {}
	for index, stack in ipairs(inventory:get_list("main") or {}) do
		contents[index] = stack:to_string()
	end
	session.horse._marghl_horse_inventory = contents
end

local function valid_horse_inventory_session(player_name, inventory_name)
	local session = horse_inventory_sessions[player_name]
	return session
		and session.inventory_name == inventory_name
		and session.horse
		and session.horse.object
		and session.horse.object:get_pos()
		and (session.horse.owner == player_name
			or core.check_player_privs(player_name, {protection_bypass = true}))
		and session.horse._marghl_horse_chest
		and session
end

local function close_horse_inventory(player_name)
	local session = horse_inventory_sessions[player_name]
	if not session then
		return
	end
	local inventory = core.get_inventory({
		type = "detached",
		name = session.inventory_name,
	})
	if inventory then
		save_horse_inventory(session, inventory)
	end
	horse_inventory_sessions[player_name] = nil
	core.remove_detached_inventory(session.inventory_name)
end

local function open_horse_inventory(self, player)
	local player_name = player:get_player_name()
	close_horse_inventory(player_name)

	local inventory_name = horse_inventory_name(player_name)
	local callbacks = {
		allow_move = function(_, _, _, _, _, count, actor)
			return valid_horse_inventory_session(
				actor:get_player_name(), inventory_name) and count or 0
		end,
		allow_put = function(_, _, _, stack, actor)
			return valid_horse_inventory_session(
				actor:get_player_name(), inventory_name) and stack:get_count() or 0
		end,
		allow_take = function(_, _, _, stack, actor)
			return valid_horse_inventory_session(
				actor:get_player_name(), inventory_name) and stack:get_count() or 0
		end,
		on_move = function(inventory)
			save_horse_inventory(horse_inventory_sessions[player_name], inventory)
		end,
		on_put = function(inventory)
			save_horse_inventory(horse_inventory_sessions[player_name], inventory)
		end,
		on_take = function(inventory)
			save_horse_inventory(horse_inventory_sessions[player_name], inventory)
		end,
	}
	local inventory = core.create_detached_inventory(inventory_name, callbacks, player_name)
	inventory:set_size("main", horse_inventory_size)
	for index, itemstring in ipairs(self._marghl_horse_inventory or {}) do
		inventory:set_stack("main", index, ItemStack(itemstring))
	end

	local session = {
		horse = self,
		inventory_name = inventory_name,
	}
	horse_inventory_sessions[player_name] = session

	local escaped_name = core.formspec_escape(inventory_name)
	local formspec = table.concat({
		"formspec_version[4]",
		"size[10.75,10.5]",
		"label[0.5,0.45;", core.formspec_escape(S("Horse inventory")), "]",
		"list[detached:", escaped_name, ";main;3.375,1;4,4;]",
		"label[0.5,5.35;", core.formspec_escape(S("Player inventory")), "]",
		"list[current_player;main;0.5,5.8;8,4;]",
		"listring[detached:", escaped_name, ";main]",
		"listring[current_player;main]",
	})
	core.show_formspec(player_name, horse_inventory_formname, formspec)
end

local function drop_horse_inventory(self, pos)
	for player_name, session in pairs(horse_inventory_sessions) do
		if session.horse == self then
			local inventory = core.get_inventory({
				type = "detached",
				name = session.inventory_name,
			})
			if inventory then
				save_horse_inventory(session, inventory)
			end
			core.close_formspec(player_name, horse_inventory_formname)
			close_horse_inventory(player_name)
		end
	end
	for _, itemstring in ipairs(self._marghl_horse_inventory or {}) do
		local stack = ItemStack(itemstring)
		if not stack:is_empty() then
			core.add_item(pos, stack)
		end
	end
	self._marghl_horse_inventory = nil
	if self._marghl_horse_chest then
		drop_item(pos, "default:chest")
		self._marghl_horse_chest = nil
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == horse_inventory_formname and fields.quit then
		close_horse_inventory(player:get_player_name())
	end
end)

core.register_on_leaveplayer(function(player)
	close_horse_inventory(player:get_player_name())
end)

local function configure_mount(self, values)
	-- Do not overwrite upgrades such as the horse shoes from mob_horse.
	self.max_speed_forward = self.max_speed_forward or values.forward
	self.max_speed_reverse = self.max_speed_reverse or values.reverse
	self.accel = self.accel or values.accel
	self.driver_attach_at = self.driver_attach_at or values.attach
	self.driver_eye_offset = self.driver_eye_offset or values.eye
	self.driver_scale = self.driver_scale or values.scale
	local properties = self.object:get_properties()
	if properties.stepheight ~= values.stepheight then
		self.object:set_properties({stepheight = values.stepheight})
	end
end

local horse_mount = {
	forward = 6,
	reverse = 2,
	accel = 6,
	attach = {x = 0, y = 10, z = -2},
	eye = {x = 0, y = 13, z = 0},
	scale = {x = 0.8, y = 0.8},
	stepheight = 1.2,
}

local livestock = {
	["mobs_animal:cow"] = {
		forward = 3,
		reverse = 1.5,
		accel = 3,
		attach = {x = 0, y = 9, z = -1},
		eye = {x = 0, y = 10, z = 0},
		scale = {x = 0.75, y = 0.75},
		stepheight = 1.1,
	},
	["mobs_animal:pumba"] = {
		forward = 4,
		reverse = 1.5,
		accel = 4,
		attach = {x = 0, y = 7, z = -1},
		eye = {x = 0, y = 8, z = 0},
		scale = {x = 0.65, y = 0.65},
		stepheight = 1.1,
	},
}

local function finish_taming(self, player)
	local name = player:get_player_name()
	self.tamed = true
	self.owner = name
	self.order = "stand"
	self._marghl_taming = nil
	self._marghl_tame_attempts = nil
	mobs.detach(player, {x = 1, y = 0, z = 1})
	self:set_animation("stand")
	core.chat_send_player(name, S("You have successfully broken in the horse."))
end

local function abort_taming(self, player, thrown)
	local name = player and player:get_player_name()
	self._marghl_taming = nil
	if thrown then
		self._marghl_tame_attempts = (self._marghl_tame_attempts or 0) + 1
	end
	if player then
		mobs.detach(player, {x = 1, y = 0, z = 1})
	end
	self:set_animation("stand")
	if name then
		core.chat_send_player(name, thrown
			and S("The horse threw you off. The next attempt will be easier.")
			or S("You stopped breaking in the horse."))
	end
end

local function buck(self)
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	local yaw = (self.object:get_yaw() or 0) + math.rad(math.random(-50, 50))
	local direction = core.yaw_to_dir(yaw)
	local velocity = self.object:get_velocity()
	self.object:set_yaw(yaw)
	self.object:set_velocity({
		x = direction.x * 3.5,
		y = velocity.y,
		z = direction.z * 3.5,
	})
	if math.random(3) == 1 and math.abs(velocity.y) < 0.1 then
		self.object:add_velocity({x = 0, y = 4, z = 0})
	end
	self:set_animation(math.random(3) == 1 and "punch" or "run")
end

local function tame_horse_step(self, dtime)
	local state = self._marghl_taming
	if not state then
		return
	end
	local player = core.get_player_by_name(state.player)
	if not player or self.driver ~= player then
		self._marghl_taming = nil
		return false
	end
	if player:get_player_control().sneak then
		abort_taming(self, player, false)
		return false
	end

	state.elapsed = state.elapsed + dtime
	state.throw_timer = state.throw_timer + dtime
	buck(self)

	if state.elapsed >= horse_taming_duration then
		finish_taming(self, player)
		return false
	end
	if state.throw_timer >= horse_throw_interval then
		state.throw_timer = state.throw_timer - horse_throw_interval
		local attempts = self._marghl_tame_attempts or 0
		local chance = math.max(
			horse_minimum_throw_chance,
			horse_initial_throw_chance - attempts * horse_attempt_bonus
		)
		if math.random(100) <= chance then
			abort_taming(self, player, true)
		end
	end
	return false
end

local function start_horse_taming(self, player)
	configure_mount(self, horse_mount)
	self._marghl_taming = {
		player = player:get_player_name(),
		elapsed = 0,
		throw_timer = 0,
	}
	mobs.attach(self, player)
	core.chat_send_player(player:get_player_name(),
		S("Stay on the horse for 15 seconds. Sneak to stop the attempt."))
end

local function override_horse()
	local definition = core.registered_entities["mob_horse:horse"]
	if not definition or definition._marghl_custom_mobs then
		return
	end
	definition._marghl_custom_mobs = true

	local original_do_custom = definition.do_custom
	definition.do_custom = function(self, dtime)
		configure_mount(self, horse_mount)
		if self._marghl_taming then
			return tame_horse_step(self, dtime)
		end
		return original_do_custom and original_do_custom(self, dtime)
	end

	local original_on_rightclick = definition.on_rightclick
	definition.on_rightclick = function(self, clicker)
		if not is_player(clicker) then
			return
		end
		if self._marghl_taming then
			return
		end
		if can_access_horse(self, clicker) and not self.child then
			local itemname = clicker:get_wielded_item():get_name()
			if not self._marghl_horse_chest and itemname == "default:chest" then
				self._marghl_horse_chest = true
				self._marghl_horse_inventory = {}
				take_one(clicker, "default:chest")
				core.chat_send_player(clicker:get_player_name(),
					S("The saddlebags have been fitted."))
				return
			end
			if self._marghl_horse_chest and itemname == ""
			and clicker:get_player_control().sneak then
				open_horse_inventory(self, clicker)
				return
			end
		end
		if not self.tamed and not self.child then
			-- Food still heals wild horses, but no longer tames them.
			if mobs:feed_tame(self, clicker, 10, false, false) then
				return
			end
			if clicker:get_wielded_item():is_empty() then
				start_horse_taming(self, clicker)
				return
			end
		end
		return original_on_rightclick and original_on_rightclick(self, clicker)
	end

	local original_on_die = definition.on_die
	definition.on_die = function(self, pos)
		if self._marghl_horse_chest then
			drop_horse_inventory(self, pos)
		end
		if original_on_die then
			return original_on_die(self, pos)
		end
	end

	core.log("action", "[marghl_custom_mobs] enabled horse taming")
end

local function override_livestock(entity_name, values)
	local definition = core.registered_entities[entity_name]
	if not definition or definition._marghl_custom_mobs then
		return
	end
	definition._marghl_custom_mobs = true

	local original_do_custom = definition.do_custom
	definition.do_custom = function(self, dtime)
		configure_mount(self, values)
		if self.driver then
			mobs.drive(self, "walk", "stand", false, dtime)
			return false
		end
		return original_do_custom and original_do_custom(self, dtime)
	end

	local original_on_rightclick = definition.on_rightclick
	definition.on_rightclick = function(self, clicker)
		if not is_player(clicker) then
			return
		end
		if is_owner(self, clicker) and not self.child then
			local itemname = clicker:get_wielded_item():get_name()
			if self.driver == clicker then
				mobs.detach(clicker, {x = 1, y = 0, z = 1})
				self:set_animation("stand")
				return
			end
			if not self.driver and not self._marghl_saddle
			and itemname == "mobs:saddle" then
				self._marghl_saddle = true
				self.order = "stand"
				take_one(clicker, "mobs:saddle")
				core.chat_send_player(clicker:get_player_name(),
					S("The saddle has been fitted."))
				return
			end
			if not self.driver and self._marghl_saddle
			and (itemname == "" or itemname == "mobs:saddle") then
				configure_mount(self, values)
				mobs.attach(self, clicker)
				return
			end
		end
		return original_on_rightclick and original_on_rightclick(self, clicker)
	end

	local original_on_die = definition.on_die
	definition.on_die = function(self, pos)
		if self.driver then
			mobs.detach(self.driver, {x = 1, y = 0, z = 1})
		end
		if self._marghl_saddle then
			drop_item(pos, "mobs:saddle")
			self._marghl_saddle = nil
		end
		if original_on_die then
			return original_on_die(self, pos)
		end
	end

	core.log("action", "[marghl_custom_mobs] enabled riding for " .. entity_name)
end

core.register_on_mods_loaded(function()
	override_horse()
	for entity_name, values in pairs(livestock) do
		override_livestock(entity_name, values)
	end
end)
