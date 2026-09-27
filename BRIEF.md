# Kdenlive per-target brief

Checked on 2026-09-27 against Kdenlive tag `v26.08.1`, commit
`55e16e85cd9a9c6e032cd27a621137b4da881a7c` (committed 2026-09-08). That tag is
also the stable release Flathub builds (`flathub/org.kde.kdenlive` at
`3c38d709`). Line numbers refer to that commit. None of the relink, hash, or
proxy logic cited below differs in substance on `master` at `e4d5b25d`
(2026-09-26).

## Current behavior

**Clip hash.** `ProjectClip::getFileHash()` (`src/bin/projectclip.cpp:1636`)
stores a hex MD5 in the producer property `kdenlive:file_hash`, and for file
clips also the byte size in `kdenlive:file_size` (lines 1674 and 1688). Both are
saved as `<property>` children of the clip's `<producer>` or `<chain>` element
in the `.kdenlive` XML. `ProjectClip::calculateHash()` (line 1692) hashes the
whole file up to 2,000,000 bytes, and above that only the first and last
1,000,000 bytes (line 1704). Slideshows hash their folder listing plus two
sampled files, and title, color, and text clips hash their XML or text. Nothing
else identifies a clip's content. Each bin clip also has a random
`kdenlive:control_uuid` that is stable for the life of the project.

**Opening a project.** `KdenliveDoc` runs `DocumentChecker`
(`src/doc/kdenlivedoc.cpp:253`, `src/doc/documentchecker.cpp:181`). For a
missing clip the only automatic repair is `relocateResource()` (line 616, used
at line 980). It replaces the old project root with the new one, or the longest
common path prefix, when the whole project folder moved. A renamed clip, or one
moved within the project, is reported as missing. For a clip that is present,
the checker recomputes the hash (line 1120) and marks a changed file for reload.

**Relink dialog.** The user opens the dialog, picks a folder, and starts a
recursive search. `DocumentCheckerTreeModel::slotSearchRecursively()`
(`src/doc/documentcheckertreemodel.cpp:61`) calls
`DocumentChecker::searchFileRecursively()` (`documentchecker.cpp:1325`). That
function computes the MD5 of every file with the stored size and returns the
**first** match in directory order, without looking for a second one. It falls
back to a filename search (`searchPathRecursively()`, line 1235) when nothing
matches. The hash therefore takes part only after the user starts a search,
only below the chosen folder, and a duplicate copy is chosen silently. What was
found is written back into the one project file (`fixClip()`, line 1701), and
no other project or application learns of it.

**Proxies.** `KdenliveDoc` names a proxy `<cache>/proxy/<file_hash>.<ext>`
(`src/doc/kdenlivedoc.cpp:1736`). The cache is the project folder, or the global
cache when no project folder is set (`getCacheDir(CacheProxy)`, line 2397).
`ProxyTask` renders it through `melt` or `ffmpeg` as a subprocess
(`src/jobs/proxytask.cpp:203` and `:245`). The clip keeps the proxy path in
`kdenlive:proxy` and the source path in `kdenlive:originalurl`, so the
association lives only in the project file and the file name. When a source is
replaced, the reload path compares hashes only to rebuild audio thumbnails
(`src/bin/projectclip.cpp:469`–`491`). Nothing checks the existing proxy against
the new source content. Recording proxies as managed artifacts would close that gap.

**Build and packaging.** CMake with ECM, KF6 ≥ 6.21, Qt ≥ 6.10, MLT ≥ 7.38,
KDDockWidgets ≥ 2.4, OpenTimelineIO, and FFmpeg (`CMakeLists.txt:41`–`162`).
`kdenliveLib` sets `CXX_STANDARD 14` (`src/CMakeLists.txt:316`), but Qt raises
it to C++17. KDE's compiler settings add `-fno-exceptions` to application code,
and only `tests/` re-enables exceptions. Flatpak: KDE runtime and SDK 6.10, with
dependencies in `packaging/flatpak/org.kde.kdenlive-dependencies.json`. Flathub
builds the release tarball.

## User pain

A clip renamed or moved inside a project, for example graded rushes renamed
`-graded`, makes Kdenlive stop at an error dialog when the project opens. The
user must know to choose a folder and start a search. That search can take a
wrong duplicate without saying so, and has to be repeated in every project and
on every machine that uses the file.

## Smallest PostProject experiment

This is a resolver experiment: Kdenlive keeps its project file and behavior, and
PostProject only assists relinking. On save, Kdenlive records
each file-backed bin clip in a sidecar production next to the project: an asset
with PostProject's content fingerprint, its location, and `kdenlive:control_uuid`
as an application identifier. When a project opens with a missing clip,
Kdenlive asks PostProject to resolve that asset under the project folder and
the clip's former folder, both mapped to where they are now. A single
confirmed candidate appears in the relink dialog as fixed, but only if
Kdenlive's own MD5 of it equals the stored `kdenlive:file_hash`. In every other
case (ambiguous, not found, error, or no sidecar) the dialog shows the clip as
missing, exactly as before.

**Where the stored hash is usable.** PostProject cannot search with it.
Kdenlive's hash is MD5 over head and tail regions of 1,000,000 bytes, while
PostProject fingerprints with sampled BLAKE3 over 64 KiB regions, and a
resolver can only verify candidates against an algorithm it can compute. The
experiment therefore uses the Kdenlive hash as a second, independent check on
PostProject's single candidate. Clips saved before the pilot was installed
have no sidecar entry and keep Kdenlive's behavior.

## Files and modules that change

`CMakeLists.txt`, `config-kdenlive.h.cmake`, `src/CMakeLists.txt`,
`src/doc/CMakeLists.txt`, and `src/doc/documentchecker.cpp` get about 30 lines,
all behind `HAVE_POSTPROJECT`. `src/doc/kdenlivedoc.cpp` gets one call after a
successful save. New files: `src/doc/postprojectsidecar.{h,cpp}` and
`tests/postprojecttest.cpp`, plus one test helper in `tests/test_utils.*`. The
dialog, the models, and the project file format are unchanged.

## Additional dependency cost

The optional build dependency is the installed PostProject CMake package, found
with `find_package(PostProject 0.4 CONFIG)`. At runtime, `libpostproject.so`
(about 4.5 MiB, SQLite included) depends only on libc, libm, and libgcc. No
Rust is needed to build Kdenlive, and no service or daemon runs. The C++17
wrapper reports errors as exceptions, so the one adapter file is compiled with
`kde_source_files_enable_exceptions()`.

## How to remove or revert it

Configure with `-DWITH_POSTPROJECT=OFF`, or build where PostProject is not
installed, and the compiled code is upstream's. Deleting a `.pproj` sidecar
restores the upstream relink behavior for that project. `.kdenlive` files are
never modified by the pilot, so nothing needs migrating back.

## What counts as success

A build from this repository relinks a renamed clip by content. It never picks
between two identical copies. It behaves as upstream when PostProject or the
sidecar is absent. It builds nightly against PostProject `main`, and the Flatpak
module for PostProject builds on the same KDE 6.10 SDK Kdenlive uses.

## Integration questions

- **Identifier persisted by the host:** none. Kdenlive's project file is
  unchanged, and the sidecar stores Kdenlive's `kdenlive:control_uuid` under the
  scheme `https://postproject.org/id/application` with qualifier
  `org.kde.kdenlive:control_uuid`. A host binding (ADR 0011) would be needed
  only once Kdenlive persists PostProject identities itself.
- **Database owner and location:** Kdenlive creates and updates
  `<project>.pproj` next to `<project>.kdenlive` on every save. The project file
  stays authoritative, and the sidecar holds only content identity and
  locations.
- **PostProject or database absent:** a build without PostProject compiles no
  pilot code. A missing or unreadable sidecar yields no answer, so the dialog
  behaves as upstream. A missing sidecar is created at the next save, and an
  unreadable one is logged and left alone.
- **Uninstall:** rebuild without PostProject or install upstream Kdenlive, then
  delete the `.pproj` files. The `.kdenlive` files need nothing.

## Common assumptions this corrects

Kdenlive is often summarized as relinking by a sampled hash and file size before
falling back to the filename. That holds with three qualifications. The sampling
applies only above 2,000,000 bytes. The search runs only on the user's request
and below a folder the user chooses, never on its own when a project opens. It
accepts the first matching file without detecting a duplicate.
