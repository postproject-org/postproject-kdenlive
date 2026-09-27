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

export QT_QPA_PLATFORM=offscreen
ctest --test-dir "$build" --output-on-failure -R '^(documenttest|postprojecttest)$'
