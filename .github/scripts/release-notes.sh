#!/usr/bin/env bash
# Prints the top of a release's notes: the image tag and a table of component
# versions, marking what changed since the previous release. The release
# workflow appends GitHub's generated list of merged pull requests below it.
#
# Usage: release-notes.sh <tag> <ref> [previous_tag]
set -euo pipefail

tag="$1"
ref="$2"
prev="${3:-}"
image="${DOCKER_IMAGE:-ghcr.io/jacobalberty/squid-docker}"

dockerfile_at() {
    git show "$1:Dockerfile" 2>/dev/null || true
}

squid_in() {
    sed -n 's/^ARG SQUID_VERSION=//p' <<<"$1" | head -n1 | tr _ .
}

base_in() {
    sed -n 's/^FROM .* AS builder$//;t;s/^FROM //p' <<<"$1" | head -n1
}

change() {
    local old="$1" new="$2"
    if [ -z "${prev}" ]; then
        echo ""
    elif [ -z "${old}" ]; then
        echo "added"
    elif [ "${old}" != "${new}" ]; then
        echo "updated from ${old}"
    fi
}

cur="$(dockerfile_at "${ref}")"
old=""
[ -z "${prev}" ] || old="$(dockerfile_at "refs/tags/${prev}")"

squid="$(squid_in "${cur}")"
base="$(base_in "${cur}")"
link="https://github.com/squid-cache/squid/releases/tag/SQUID_${squid//./_}"

echo "**Image:** \`${image}:${tag}\` (linux/amd64, linux/arm64)"
echo ""
echo "### Components"
echo ""
echo "| Component | Version | Change |"
echo "| --- | --- | --- |"
echo "| Squid | [${squid}](${link}) | $(change "$(squid_in "${old}")" "${squid}") |"
echo "| Base image | \`${base}\` | $(change "$(base_in "${old}")" "${base}") |"
echo ""
if [ -n "${prev}" ] && [ "$(squid_in "${old}")" != "${squid}" ]; then
    echo "Squid changed in this release; see the [upstream Squid release notes](${link})."
    echo ""
fi
