#!/bin/sh
# SPDX-FileCopyrightText: 2026 Erich Seifert <dev@erichseifert.de>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
#
# Runs the document-checker tests: upstream's, and the pilot's when built.
#
# Usage: tools/test.sh [build-dir]
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
build=${1:-"$here/build"}
build=$(cd "$build" && pwd)
user=$(mktemp -d)
trap 'rm -rf "$user"' EXIT

export QT_QPA_PLATFORM=offscreen
export QT_PLUGIN_PATH="$build/bin"
export XDG_CONFIG_HOME="$user/config"
export XDG_CACHE_HOME="$user/cache"
ctest --test-dir "$build" --output-on-failure -R '^(documenttest|postprojecttest)$'
