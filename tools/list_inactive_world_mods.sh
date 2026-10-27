#!/usr/bin/env bash
set -eu

world_config=${1:-/srv/luanti/world/world.mt}
mods_root=${2:-/srv/luanti/mods}

if [ ! -f "$world_config" ]; then
	printf 'World configuration not found: %s\n' "$world_config" >&2
	exit 1
fi

if [ ! -d "$mods_root" ]; then
	printf 'Mod directory not found: %s\n' "$mods_root" >&2
	exit 1
fi

declare -A load_values=()

while IFS=$'\t' read -r mod_name value; do
	[ -n "$mod_name" ] || continue
	load_values["$mod_name"]=$value
done < <(
	awk '
		/^[[:space:]]*load_mod_[^[:space:]=]+[[:space:]]*=/ {
			line = $0
			sub(/^[[:space:]]*load_mod_/, "", line)
			name = line
			sub(/[[:space:]]*=.*/, "", name)
			value = line
			sub(/^[^=]*=[[:space:]]*/, "", value)
			sub(/[[:space:]]*#.*/, "", value)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
			print name "\t" value
		}
	' "$world_config"
)

for package_dir in "$mods_root"/*; do
	[ -d "$package_dir" ] || continue
	found_mod=false
	found_active_mod=false

	while IFS= read -r -d '' mod_conf; do
		found_mod=true
		mod_dir=${mod_conf%/mod.conf}
		mod_name=$(sed -n 's/^name[[:space:]]*=[[:space:]]*//p' "$mod_conf" |
			head -n 1 | tr -d '\r')
		[ -n "$mod_name" ] || mod_name=${mod_dir##*/}

		value=${load_values[$mod_name]-}
		case ${value,,} in
			""|false|no|off|0) ;;
			*) found_active_mod=true ;;
		esac
	done < <(
		find "$package_dir" -type f -name mod.conf \
			-not -path '*/.git/*' -print0
	)

	if [ "$found_mod" = true ] && [ "$found_active_mod" = false ]; then
		printf '%s\n' "$package_dir"
	fi
done | sort -u
