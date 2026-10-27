-- Cottages: keep existing anvils and hammers functional, but prevent new
-- ones from being crafted and hide them from compatible item lists.
local hidden_cottages_items = {
	"cottages:anvil",
	"cottages:hammer",
}

for _, itemname in ipairs(hidden_cottages_items) do
	core.clear_craft({ output = itemname })

	local definition = core.registered_items[itemname]
	if definition then
		local groups = table.copy(definition.groups or {})
		groups.not_in_creative_inventory = 1
		core.override_item(itemname, { groups = groups })
	else
		core.log("warning", "[marghl_custom_override] Item not found: " .. itemname)
	end
end

