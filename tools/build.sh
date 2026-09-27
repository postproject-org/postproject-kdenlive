#!/bin/sh
# SPDX-FileCopyrightText: 2026 Erich Seifert <dev@erichseifert.de>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Configures and builds the patched tree with its tests. PREFIX is a PostProject
# install prefix; pass "none" to build without PostProject, which must behave
# exactly as upstream Kdenlive.
#
# Usage: tools/build.sh PREFIX [tree] [build-dir]
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
prefix=${1:?usage: tools/build.sh PREFIX|none [tree] [build-dir]}
tree=${2:-"$here/kdenlive"}
build=${3:-"$here/build"}

if [ "$prefix" = none ]; then
    postproject="-DWITH_POSTPROJECT=OFF"
else
    postproject="-DCMAKE_PREFIX_PATH=$(cd "$prefix" && pwd)"
fi

# Kdenlive's tests use Qt::Test without finding it (the component is commented
# out in its find_package call); find it for them.
cmake -S "$tree" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_TESTING=ON \
    -DCMAKE_PROJECT_INCLUDE="$here/tools/find-qt-test.cmake" \
    "$postproject"
cmake --build "$build" --target kdenlive documenttest
if [ "$prefix" != none ]; then
    grep -q '^#define HAVE_POSTPROJECT 1' "$build/config-kdenlive.h" || {
        echo "error: PostProject was not found under $prefix" >&2
        exit 1
    }
    cmake --build "$build" --target postprojecttest
fi
