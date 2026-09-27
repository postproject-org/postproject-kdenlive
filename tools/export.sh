#!/bin/sh
# SPDX-FileCopyrightText: 2026 Erich Seifert <dev@erichseifert.de>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Regenerates patches/ from the commits on top of the pinned revision in a
# tree prepared by tools/checkout.sh.
#
# Usage: tools/export.sh [tree]   (default: ./kdenlive)
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/UPSTREAM"
tree=${1:-"$here/kdenlive"}

rm -f "$here"/patches/*.patch
git -C "$tree" format-patch -q --zero-commit --no-signature --no-stat --abbrev=9 \
    -o "$here/patches" "$KDENLIVE_COMMIT..HEAD"
(cd "$here/patches" && ls ./*.patch | sed 's|^\./||') > "$here/patches/series"
cat "$here/patches/series"
