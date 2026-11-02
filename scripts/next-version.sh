#!/bin/sh
# Prints the next semantic version after the latest vX.Y.Z tag.
# Usage: scripts/next-version.sh major|minor|patch
set -eu

bump="${1:?usage: next-version.sh major|minor|patch}"
latest=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)
current="${latest#v}"
current="${current:-0.0.0}"

major=$(echo "$current" | cut -d. -f1)
minor=$(echo "$current" | cut -d. -f2)
patch=$(echo "$current" | cut -d. -f3)

case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
    *) echo "unknown bump '$bump': use major, minor, or patch" >&2; exit 1 ;;
esac
