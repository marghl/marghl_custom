#!/usr/bin/env bash
set -u

mods_root=${1:-/srv/luanti/mods}

if [ ! -d "$mods_root" ]; then
	printf 'Mod directory not found: %s\n' "$mods_root" >&2
	exit 1
fi

for package_dir in "$mods_root"/*; do
	[ -d "$package_dir" ] || continue
	package_name=${package_dir##*/}

	if [ ! -d "$package_dir/.git" ] && [ ! -f "$package_dir/.git" ]; then
		printf 'kein git\t%s\t%s\n' "$package_name" "$package_dir"
		continue
	fi

	if ! GIT_TERMINAL_PROMPT=0 git -C "$package_dir" fetch --quiet --prune; then
		printf 'Git-Abruf fehlgeschlagen: %s (%s)\n' \
			"$package_name" "$package_dir" >&2
		continue
	fi

	upstream=$(git -C "$package_dir" rev-parse \
		--abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)

	if [ -z "$upstream" ]; then
		branch=$(git -C "$package_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
		if [ -n "$branch" ] && git -C "$package_dir" show-ref \
			--verify --quiet "refs/remotes/origin/$branch"; then
			upstream="origin/$branch"
		else
			printf 'Kein Upstream konfiguriert: %s (%s)\n' \
				"$package_name" "$package_dir" >&2
			continue
		fi
	fi

	behind=$(git -C "$package_dir" rev-list --count "HEAD..$upstream" 2>/dev/null || true)
	if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
		printf 'Update\t%s\t%s\t%s Commit(s)\n' \
			"$package_name" "$package_dir" "$behind"
	fi
done
