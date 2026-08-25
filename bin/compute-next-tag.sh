#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<OmniTools version>-<release>`, which is what this
# repository has always published (v0.6.0-0, v0.6.0-1):
#
# - if defaults/main.yml points at an OmniTools version that has never been
#   released, the release counter restarts at 0 (`v0.7.0-0`)
# - otherwise the counter is incremented (`v0.7.0-1`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
#
# The commit-message approach this replaced only recognized commits authored by
# renovate[bot] whose subject contained both "docker tag to" and "omni", so
# every other change to the role went unreleased until a Renovate bump came
# along to carry it. It had never fired: both existing tags were pushed by
# hand. It also could not have produced them, because it tagged the version
# string straight out of the commit subject with `-0` appended, and the Docker
# tags this role tracks carry no `v` (`0.6.0`) while every tag here does.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `omnitools_version:` so that neither
# `omnitools_container_image_tag`, which is `{{ omnitools_version }}`, nor
# `omnitools_container_image_self_build_repo_version`, which is a Jinja
# conditional around it, can be mistaken for it. Those derived values are what
# a looser `_version:` match would happily return as `{{`.
version="$(sed -nE 's|^omnitools_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the OmniTools version from $defaults_path"
	exit 1
fi

# OmniTools's version values carry no leading `v` (`0.6.0`) while the tags do
# (`v0.6.0-0`). Stripping any `v` before prepending one keeps this correct
# whichever convention the value follows.
tag_prefix="v${version#v}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
