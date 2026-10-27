#!/usr/bin/env bash
set -eu

mods_root=${1:-/srv/luanti/mods}

if [ ! -d "$mods_root" ]; then
	printf 'Mod directory not found: %s\n' "$mods_root" >&2
	exit 1
fi

printf 'STATUS\tMOD\tPATH\n'

find "$mods_root" -type f -name mod.conf -print0 |
while IFS= read -r -d '' mod_conf; do
	mod_dir=${mod_conf%/mod.conf}
	mod_name=$(sed -n 's/^name[[:space:]]*=[[:space:]]*//p' "$mod_conf" |
		head -n 1 | tr -d '\r')
	[ -n "$mod_name" ] || mod_name=${mod_dir##*/}
	locale_dir=$mod_dir/locale
	status=not_prepared

	if [ -d "$locale_dir" ] &&
		find "$locale_dir" -maxdepth 1 -type f \
			\( -name '*.de.po' -o -name '*.de.tr' \) -print -quit |
		grep -q .; then
		status=german_available
	elif [ -d "$locale_dir" ] &&
		find "$locale_dir" -maxdepth 1 -type f -name '*.pot' -print -quit |
		grep -q .; then
		status=po_ready
	elif [ -f "$locale_dir/template.txt" ]; then
		status=tr_ready
	elif find "$mod_dir" -type f -name '*.lua' -exec \
		grep -lE '(minetest|core)\.get_translator[[:space:]]*\(' {} + 2>/dev/null |
		grep -q .; then
		status=translator_without_template
	fi

	printf '%s\t%s\t%s\n' "$status" "$mod_name" "$mod_dir"
done | sort -t "$(printf '\t')" -k1,1 -k2,2
