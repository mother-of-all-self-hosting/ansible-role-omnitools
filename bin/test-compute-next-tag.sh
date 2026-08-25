#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at OmniTools 0.6.0 which has already seen
# two releases of it (v0.6.0-0 and v0.6.0-1), matching this repository's real
# history.
#
# The defaults file carries the traps this role's real one has: the Renovate
# annotation that has to stay attached to the version, and two further
# variables whose names end in `_version` or `_tag` and whose values are
# derived from it through Jinja. Picking either of those up would produce a
# literal `v{{-0` tag.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# renovate: datasource=docker depName=iib0011/omni-tools versioning=semver
		omnitools_version: 0.6.0

		omnitools_container_image: "{{ omnitools_container_image_registry_prefix }}iib0011/omni-tools:{{ omnitools_container_image_tag }}"
		omnitools_container_image_tag: "{{ omnitools_version }}"
		omnitools_container_image_self_build_repo_version: "{{ 'v' + omnitools_version if omnitools_version != 'latest' else 'main' }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md
	mkdir -p molecule/default
	printf 'placeholder\n' > molecule/default/verify.yml

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v0.6.0-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^omnitools_version: 0.6.0|omnitools_version: 0.7.0|' defaults/main.yml"
revert_version="sed -i 's|^omnitools_version: 0.7.0|omnitools_version: 0.6.0|' defaults/main.yml"
prefixed_version="sed -i 's|^omnitools_version: 0.6.0|omnitools_version: v0.7.0|' defaults/main.yml"
pin_image_tag="sed -i 's|^omnitools_container_image_tag: .*|omnitools_container_image_tag: 9.9.9|' defaults/main.yml"
pin_self_build_version="sed -i 's|^omnitools_container_image_self_build_repo_version: .*|omnitools_container_image_self_build_repo_version: v9.9.9|' defaults/main.yml"
drop_annotation="sed -i '/^# renovate:/d' defaults/main.yml"
edit_meta="printf 'a platform\n' >> meta/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_molecule="printf 'an assert\n' >> molecule/default/verify.yml"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v0.7.0-0 "$(merge "$bump_version")"
expect 'task edit'    v0.7.0-1 "$(merge "$edit_task")"
expect 'template'     v0.7.0-2 "$(merge "$edit_template")"
expect 'meta'         v0.7.0-3 "$(merge "$edit_meta")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v0.6.0-2 "$(merge "$edit_task")"
expect 'version bump' v0.7.0-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''       "$(merge "$edit_readme")"
expect 'Molecule' ''       "$(merge "$edit_molecule")"
expect 'a script' ''       "$(merge "$edit_script")"
expect 'a task'   v0.6.0-2 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v0.6.0-$release_number"
done
expect 'a task' v0.6.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v0.6.0-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v0.6.0-2 "$(merge "$revert_version && $edit_task")"

# OmniTools's version values carry no leading `v` - the Docker tags this role
# tracks are `0.6.0`, not `v0.6.0` - while every tag here does. The tag must
# not gain a second `v` if that convention ever changes.
scenario 'A version value with a leading v does not yield a doubled prefix'
expect 'version bump' v0.7.0-0 "$(merge "$prefixed_version")"

# `omnitools_container_image_tag` is `{{ omnitools_version }}` and
# `omnitools_container_image_self_build_repo_version` is a Jinja conditional
# around it. Pinning either to a literal is the shape of change that a less
# careful match would follow.
scenario 'A pinned image tag is not mistaken for the version'
expect 'pinned tag' v0.6.0-2 "$(merge "$pin_image_tag")"

scenario 'A pinned self-build repository version is not mistaken for the version'
expect 'pinned self-build version' v0.6.0-2 "$(merge "$pin_self_build_version")"

# The Renovate annotation sits directly above the version. Removing it must not
# change which line the version is read from - if it ever did, a refactor that
# moved the annotation would silently change the tags this repository cuts.
scenario 'The Renovate annotation is not what anchors the version'
expect 'annotation removed' v0.6.0-2  "$(merge "$drop_annotation")"
expect 'version bump'       v0.7.0-0 "$(merge "$bump_version")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
