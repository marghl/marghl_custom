local foods = {
	["farming:artichoke"] = {satiates = 4},
	["farming:asparagus"] = {satiates = 1},
	["farming:blackberry"] = {satiates = 1},
	["farming:cactus_juice"] = {satiates = 2, returns = "vessels:drinking_glass"},
	["farming:carrot_juice"] = {satiates = 4, returns = "vessels:drinking_glass"},
	["farming:chapathi"] = {satiates = 3},
	["farming:cheese_vegan"] = {satiates = 2},
	["farming:chili_powder"] = {heals = -1},
	["farming:cinnamon_roll"] = {satiates = 4},
	["farming:coffee_cup"] = {satiates = 2, returns = "vessels:drinking_glass"},
	["farming:croissant"] = {satiates = 3},
	["farming:eggplant"] = {satiates = 3},
	["farming:flan"] = {satiates = 6},
	["farming:ginger"] = {satiates = 1},
	["farming:gingerbread_man"] = {satiates = 2},
	["farming:gulab_jamun"] = {satiates = 3},
	["farming:gyoza"] = {satiates = 4},
	["farming:jerusalem_artichokes"] = {satiates = 11, returns = "farming:bowl"},
	["farming:kitkat"] = {satiates = 5},
	["farming:kiwi"] = {satiates = 2},
	["farming:kiwi_sorbet"] = {satiates = 8, returns = "farming:bowl"},
	["farming:laddu"] = {satiates = 5},
	["farming:mac_and_cheese"] = {satiates = 6, returns = "farming:bowl"},
	["farming:mayonnaise"] = {satiates = 3},
	["farming:mint_tea"] = {satiates = 2, returns = "vessels:drinking_glass"},
	["farming:mochi"] = {satiates = 3},
	["farming:onigiri"] = {satiates = 2},
	["farming:paella"] = {satiates = 8, returns = "farming:bowl"},
	["farming:parsley"] = {satiates = 1},
	["farming:pineapple_juice"] = {satiates = 4, returns = "vessels:drinking_glass"},
	["farming:popcorn"] = {satiates = 4},
	["farming:potato_omelet"] = {satiates = 6, returns = "farming:bowl"},
	["farming:samosa"] = {satiates = 6},
	["farming:smoothie_berry"] = {satiates = 6, returns = "vessels:drinking_glass"},
	["farming:smoothie_raspberry"] = {satiates = 2, returns = "vessels:drinking_glass"},
	["farming:soy_milk"] = {satiates = 2, returns = "vessels:drinking_glass"},
	["farming:spanish_potatoes"] = {satiates = 8, returns = "farming:bowl"},
	["farming:spinach"] = {satiates = 1},
	["farming:sunflower_bread"] = {satiates = 8},
	["farming:sunflower_seeds_toasted"] = {satiates = 1},
	["farming:tofu"] = {satiates = 3},
	["farming:tofu_cooked"] = {satiates = 6},
	["farming:tomato_soup"] = {satiates = 8, returns = "farming:bowl"},
	["farming:tortang_talong"] = {satiates = 10},
}

local added = 0
for item_name, data in pairs(foods) do
	local definition = minetest.registered_items[item_name]
	if definition and definition.on_use and not definition._hunger_ng then
		hunger_ng.add_hunger_data(item_name, data)
		added = added + 1
	else
		minetest.log("warning", "[marghl_custom_food] Could not add hunger data for " .. item_name)
	end
end

minetest.log("action", string.format(
	"[marghl_custom_food] Added Hunger NG data for %d Farming items",
	added
))

