#!/usr/bin/env bash
# Works out which release, if any, a commit gets.
#
# Image versions follow Squid: the first release on a Squid version is tagged
# v<SQUID_VERSION> (v6.14); every later release on the same Squid version
# (a Debian bump, a fix to the image itself) is tagged v<SQUID_VERSION>-N
# (v6.14-1, v6.14-2, ...). The Dockerfile spells the version 6_14 to match
# upstream's SQUID_6_14 tags; tags use a dot.
#
# Usage:
#   compute-version.sh          Push to main: tag the next release when Squid
#                               changed or the image changed since the last
#                               release on this Squid version.
#   compute-version.sh <tag>    A tag made by hand: check it matches the
#                               SQUID_VERSION in its own Dockerfile.
#
# Prints key=value lines (release, tag, previous_tag, squid_version, is_latest)
# and appends them to $GITHUB_OUTPUT when set.
set -euo pipefail

# Everything that ends up in the image. A change to any of these earns a
# release; docs and CI changes do not.
IMAGE_PATHS=(
    Dockerfile
    docker-entrypoint.sh
)
TAG_RE='^v([0-9]+\.[0-9]+(\.[0-9]+)?)(-([0-9]+))?$'

die() {
    echo "::error::$*" >&2
    exit 1
}

# SQUID_VERSION from the Dockerfile at a ref, as a dotted version (6_14 -> 6.14).
squid_version_at() {
    git show "$1:Dockerfile" | sed -n 's/^ARG SQUID_VERSION=//p' | head -n1 | tr _ .
}

# All release tags, oldest first. Older tag styles don't match TAG_RE and are
# ignored.
release_tags() {
    git tag --list 'v*' | grep -E "${TAG_RE}" | sort -V || true
}

# Release tags for one Squid version, oldest first.
tags_for_squid() {
    grep -E "^v${1//./\\.}(-[0-9]+)?$" || true
}

# The release tag sorting just before $1 (empty if none).
previous_of() {
    { release_tags; echo "$1"; } | sort -uV | awk -v t="$1" '$0 == t { print p; exit } { p = $0 }'
}

newest_with() {
    { release_tags; echo "$1"; } | sort -uV | tail -n1
}

release=false
tag=""

if [ $# -ge 1 ] && [ -n "$1" ]; then
    tag="$1"
    [[ "${tag}" =~ ${TAG_RE} ]] || die "Release tag must be vX.Y or vX.Y-N, got ${tag}"
    base="${BASH_REMATCH[1]}"
    git rev-parse -q --verify "refs/tags/${tag}" >/dev/null || die "Tag ${tag} does not exist"
    squid="$(squid_version_at "refs/tags/${tag}")"
    [ -n "${squid}" ] || die "No ARG SQUID_VERSION in the Dockerfile at ${tag}"
    [ "${base}" = "${squid}" ] ||
        die "Tag ${tag} does not match SQUID_VERSION=${squid} in its Dockerfile; use v${squid} or v${squid}-N"
    release=true
else
    squid="$(squid_version_at HEAD)"
    [ -n "${squid}" ] || die "No ARG SQUID_VERSION in the Dockerfile"
    # A re-run after a failed build: HEAD already carries this release's tag.
    head_tag="$(git tag --points-at HEAD | tags_for_squid "${squid}" | sort -V | tail -n1)"
    last="$(release_tags | tags_for_squid "${squid}" | tail -n1)"
    if [ -n "${head_tag}" ]; then
        tag="${head_tag}"
        release=true
    elif [ -z "${last}" ]; then
        tag="v${squid}"
        release=true
    elif ! git diff --quiet "${last}" HEAD -- "${IMAGE_PATHS[@]}"; then
        rev="${last#"v${squid}"}"
        rev="${rev#-}"
        tag="v${squid}-$((${rev:-0} + 1))"
        release=true
    else
        echo "No image changes since ${last}; nothing to release." >&2
    fi
    if [ "${release}" = true ] && [ "$(newest_with "${tag}")" != "${tag}" ]; then
        die "${tag} would be older than the newest release $(release_tags | tail -n1); SQUID_VERSION=${squid} went backwards. Tag a release by hand if this is intended."
    fi
fi

previous_tag=""
is_latest=false
if [ "${release}" = true ]; then
    previous_tag="$(previous_of "${tag}")"
    [ "$(newest_with "${tag}")" = "${tag}" ] && is_latest=true
fi

out="release=${release}
tag=${tag}
previous_tag=${previous_tag}
squid_version=${squid}
is_latest=${is_latest}"
echo "${out}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "${out}" >>"${GITHUB_OUTPUT}"
fi
