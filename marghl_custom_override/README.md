# Marghl Custom: Overrides

This mod contains server-specific changes to items and behavior registered by
other mods. Add future overrides to `init.lua` in clearly labelled sections.

## Cottages

- Removes all crafting recipes for `cottages:anvil` and `cottages:hammer`.
- Hides both items from creative inventories and compatible crafting guides.
- Keeps existing anvils and hammers available and functional.

At startup the mod logs whether each recipe was removed and how many recipes
remain. This makes load-order or item-name problems visible in `server.log`.
