#!/bin/sh
# SPDX-FileCopyrightText: 2026 Erich Seifert <dev@erichseifert.de>
# SPDX-License-Identifier: GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
# Run the maintained Kdenlive and Blender paths against one local production.
#
# Usage: tools/shared-production.sh KDENLIVE_BUILD BLENDER BLENDER_PACKAGE \
#   BLENDER_REPO MANAGER_PYTHON MANAGER_REPO POSTPROJECT_LIBRARY
set -eu

build=$(cd "$1" && pwd)
blender=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
package=$(cd "$(dirname "$3")" && pwd)/$(basename "$3")
blender_repo=$(cd "$4" && pwd)
manager_python=$(cd "$(dirname "$5")" && pwd)/$(basename "$5")
manager_repo=$(cd "$6" && pwd)
postproject_library=$(cd "$(dirname "$7")" && pwd)/$(basename "$7")
trace_directory=${POSTPROJECT_ABI_TRACE_DIRECTORY:-}
root=$(mktemp -d)
user=$(mktemp -d)
if [ -n "$trace_directory" ]; then
    mkdir -p "$trace_directory"
    trace_directory=$(cd "$trace_directory" && pwd)
fi
if [ "${POSTPROJECT_KEEP_SHARED_ROOT:-0}" = 1 ]; then
    printf 'Shared production workspace: %s\n' "$root"
    trap 'rm -rf "$user"' EXIT
else
    trap 'rm -rf "$root" "$user"' EXIT
fi

run_kdenlive() {
    trace_file=${trace_directory:+$trace_directory/kdenlive-$1.txt}
    POSTPROJECT_SHARED_ACTION=$1 \
    POSTPROJECT_SHARED_ROOT=$root \
    POSTPROJECT_ABI_TRACE=$trace_file \
    XDG_CONFIG_HOME=$user/kdenlive-config \
    XDG_CACHE_HOME=$user/kdenlive-cache \
    QT_LOGGING_RULES="*.debug=false;*.info=false" \
    QT_QPA_PLATFORM=offscreen \
    QT_PLUGIN_PATH=$build/bin \
        "$build/bin/postprojecttest" \
        "Exercise Kdenlive's shared production path" --reporter compact
}

run_blender() {
    trace_file=${trace_directory:+$trace_directory/blender-$1.txt}
    BLENDER_USER_RESOURCES=$user POSTPROJECT_ABI_TRACE=$trace_file \
        "$blender" --background --factory-startup \
        --python-exit-code 1 --python "$blender_repo/tests/shared_production.py" \
        -- "$package" "$root" "$1"
}

run_manager() {
    POSTPROJECT_ABI_TRACE=${trace_directory:+$trace_directory/openassetio-manager.txt} \
        "$manager_python" "$manager_repo/tests/shared_production.py" \
        "$root/shared.pproj" "$postproject_library"
}

run_kdenlive record
run_blender record-render
run_kdenlive observe-render
run_manager
run_kdenlive relink
run_blender observe-relink
run_kdenlive prepare-conflict
run_blender win-conflict
run_kdenlive lose-conflict
run_kdenlive change-content
run_kdenlive observe-stale

if [ -n "$trace_directory" ]; then
    sort -u "$trace_directory"/kdenlive-*.txt > "$trace_directory/kdenlive-abi.txt"
    sort -u "$trace_directory"/blender-*.txt > "$trace_directory/blender-abi.txt"
fi
