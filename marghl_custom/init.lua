marghl_custom = rawget(_G, "marghl_custom") or {}
marghl_custom.storage = minetest.get_mod_storage()

dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/tutorial.lua")
