local admin_armor = {
	"3d_armor:helmet_admin",
	"3d_armor:chestplate_admin",
	"3d_armor:leggings_admin",
	"3d_armor:boots_admin",
}

-- Verteilt den Strahlenschutz gleichmaessig auf den kompletten Satz.
-- Erst alle vier Teile zusammen erreichen 100 Prozent Schutz.
for _, item_name in ipairs(admin_armor) do
	local definition = minetest.registered_items[item_name]
	if definition then
		local armor_groups = table.copy(definition.armor_groups or {})
		local groups = table.copy(definition.groups or {})
		armor_groups.radiation = 25

		-- Die Werte ergeben ueber alle vier Teile zusammen:
		-- feather 1, fire 5 und jump +0.5.
		groups.armor_feather = (groups.armor_feather or 0) + 0.25
		groups.armor_fire = (groups.armor_fire or 0) + 1.25
		groups.physics_jump = (groups.physics_jump or 0) + 0.125

		minetest.override_item(item_name, {
			armor_groups = armor_groups,
			groups = groups,
		})
	end
end

local function wears_full_admin_armor(player)
	local inventory = player:get_inventory()
	if not inventory or inventory:get_size("armor") == 0 then
		return false
	end

	for _, item_name in ipairs(admin_armor) do
		if not inventory:contains_item("armor", item_name) then
			return false
		end
	end
	return true
end

-- Haelt die Atemluft mit vollstaendiger Adminruestung auf Maximum.
-- Das wirkt sowohl in Wasser als auch im Vakuum.
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 then
		return
	end
	timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		if wears_full_admin_armor(player) and player:get_breath() < 10 then
			player:set_breath(10)
		end
	end
end)
