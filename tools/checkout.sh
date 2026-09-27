#!/bin/sh
# SPDX-FileCopyrightText: 2026 Erich Seifert <dev@erichseifert.de>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Checks out the pinned Kdenlive revision and applies the patch series as
# commits on the branch "postproject-pilot".
#
# Usage: tools/checkout.sh [tree]   (default: ./kdenlive)
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/UPSTREAM"
tree=${1:-"$here/kdenlive"}

if [ ! -d "$tree/.git" ]; then
    git init -q "$tree"
elif [ -n "$(git -C "$tree" status --porcelain)" ]; then
    echo "error: $tree has uncommitted changes" >&2
    exit 1
fi

git -C "$tree" fetch -q --depth 1 "$KDENLIVE_URL" "refs/tags/$KDENLIVE_TAG:refs/tags/$KDENLIVE_TAG"
fetched=$(git -C "$tree" rev-parse "refs/tags/$KDENLIVE_TAG^{commit}")
if [ "$fetched" != "$KDENLIVE_COMMIT" ]; then
    echo "error: $KDENLIVE_TAG is $fetched, expected $KDENLIVE_COMMIT" >&2
    exit 1
fi

git -C "$tree" checkout -q -B postproject-pilot "$KDENLIVE_COMMIT"
while read -r patch; do
    case $patch in '' | '#'*) continue ;; esac
    GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-PostProject pilot} \
    GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-pilot@postproject.invalid} \
        git -C "$tree" am -q "$here/patches/$patch"
done < "$here/patches/series"
echo "$tree: postproject-pilot = $KDENLIVE_TAG + $(git -C "$tree" rev-list --count "$KDENLIVE_COMMIT..HEAD") patches"
