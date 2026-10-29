-- Keep existing nodes and tools functional, but prevent new ones from being
-- crafted and hide them from creative inventories and compatible craft guides.
local hidden_items = {
	"cottages:anvil",
	"cottages:hammer",
	"jumpdrive:backbone",
	"jumpdrive:fleet_controller",
}

for _, itemname in ipairs(hidden_items) do
	local recipe_removed = core.clear_craft({ output = itemname })

	local definition = core.registered_items[itemname]
	if definition then
		local groups = table.copy(definition.groups or {})
		groups.not_in_creative_inventory = 1
		core.override_item(itemname, { groups = groups })

		local remaining_recipes = core.get_all_craft_recipes(itemname)
		core.log("action", string.format(
			"[marghl_custom_override] %s: hidden, recipe_removed=%s, remaining_recipes=%d",
			itemname,
			tostring(recipe_removed),
			remaining_recipes and #remaining_recipes or 0
		))
	else
		core.log("warning", "[marghl_custom_override] Item not found: " .. itemname)
	end
end
