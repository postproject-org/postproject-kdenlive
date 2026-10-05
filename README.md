# PostProject Kdenlive pilot

An experimental, maintained integration of [PostProject](https://postproject.org)
into [Kdenlive](https://kdenlive.org). When a project opens and a clip is
missing because it was renamed or moved, Kdenlive asks PostProject to find it
by content. It offers the file in its usual relink dialog only when exactly one
file matches, and only when Kdenlive's own clip hash agrees with that file.
In every other case the dialog behaves as before. Kdenlive also records each
proxy it renders as derived from its clip. A proxy whose source was replaced is
rebuilt when the project opens, where Kdenlive would keep playing it.

This repository is not a Kdenlive fork. It holds a small patch series for one
pinned Kdenlive release (`UPSTREAM`), the scripts that apply and build it, CI,
and the [per-target brief](BRIEF.md) checked against Kdenlive's source. What the
pilot taught PostProject is recorded in PostProject's
[`docs/release-0.4-integration-findings.md`](https://github.com/postproject-org/postproject/blob/main/docs/release-0.4-integration-findings.md).
This is not a KDE project, and nothing here has been proposed to or reviewed by
the Kdenlive maintainers.

## What changes

Kdenlive keeps its project file and behavior. PostProject assists relinking
and keeps track of how each proxy was made.

- On every save, `film.kdenlive` gets a sidecar production `film.pproj` next to
  it. The sidecar records each file-backed bin clip by its
  `kdenlive:control_uuid`, PostProject content fingerprint, Kdenlive's own
  hash, and location. The `.kdenlive` file itself is never changed by the
  pilot.
- Passing `--postproject-production /absolute/path/shared.pproj` selects one
  explicit production instead of the sidecar. This is the pilot's current
  human-facing shared-production control; it does not infer a path from a
  Blender project or directory layout.
- On opening, all missing clips are resolved in one PostProject call under the
  project folder and the clips' former folders. A single match whose Kdenlive
  MD5 equals
  `kdenlive:file_hash` is shown as *Fixed* in the relink dialog. A duplicate,
  no match, an unreadable sidecar, or no sidecar leaves the clip *Missing*.
- Rendering a proxy for a recorded clip runs as a PostProject job with Kdenlive
  as the worker. The finished proxy is recorded with the activity that made it:
  the tool, its arguments, and the content of the source it was made from. A
  failed render records its log. Proxies made before their clip was recorded
  are recorded on save when their name is the clip's present hash.
- On opening, a proxy whose source no longer has that content is reported for
  rebuilding in the relink dialog, and the rebuilt proxy is recorded again.
- Built without PostProject (`-DWITH_POSTPROJECT=OFF`, or no package found),
  none of this code is compiled.

The patches in `patches/` are:

| Patch | Change |
|---|---|
| `0001` | Find PostProject as an optional package |
| `0002` | Record bin clips in a PostProject sidecar on save |
| `0003` | Relink missing clips through the PostProject sidecar |
| `0004` | Test relinking through the PostProject sidecar |
| `0005` | Record proxy renders in the PostProject sidecar |
| `0006` | Rebuild proxies the PostProject sidecar reports as stale |
| `0007` | Test proxies as managed artifacts in the PostProject sidecar |
| `0008` | Select an explicit PostProject production |
| `0009` | Exercise Kdenlive's half of the shared-production workflow |
| `0010` | Carry scoped decision tokens and atomic commit outcomes between hosts |

## Build

You need Kdenlive's usual build dependencies (KF6 ≥ 6.21, Qt ≥ 6.10,
MLT ≥ 7.38, KDDockWidgets ≥ 2.4, OpenTimelineIO, FFmpeg), CMake, and Ninja,
plus an installed PostProject 0.7 development package. Kdenlive links PostProject only through
`find_package(PostProject)`. Cargo is needed only to build PostProject itself:

Resolution option factories and setters now propagate failures immediately
through the existing Result protocol. The build-disabled fallback remains
available; final candidate host qualification is pending.

```sh
git clone https://github.com/postproject-org/postproject
(cd postproject &&
  cargo build --release --locked -p postproject-ffi &&
  cmake -S . -B target/package \
    -DPOSTPROJECT_LIBRARY="$PWD/target/release/libpostproject.so" \
    -DPOSTPROJECT_STATIC_LIBRARY="$PWD/target/release/libpostproject.a" \
    -DCMAKE_INSTALL_PREFIX="$PWD/../install" &&
  cmake --install target/package)

tools/checkout.sh          # pinned Kdenlive + patches in ./kdenlive
tools/build.sh install     # or: tools/build.sh none  (upstream behavior)
tools/test.sh
build/bin/kdenlive
```

To launch the pilot against a production also selected in Blender:

```sh
build/bin/kdenlive --postproject-production /show/edit/shared.pproj film.kdenlive
```

`tools/shared-production.sh` is the CI driver for the installed Kdenlive,
Blender extension, and OpenAssetIO Manager paths. Run it with no arguments in
the repository to see the required paths in its usage comment.

For a Flatpak build, PostProject's integrator documentation has a tested module
for the KDE 6.10 SDK that Kdenlive's manifest uses.

## Working on the patches

`tools/checkout.sh` turns `./kdenlive` into a normal Git tree. Its branch
`postproject-pilot` holds one commit per patch on top of the pinned release.
Edit, commit, or rebase there, then run `tools/export.sh` to regenerate
`patches/` and `patches/series`. Commit the regenerated patches here.

To move to a new Kdenlive release, change all three values in `UPSTREAM`. Then
check out the new tag, rebase `postproject-pilot` onto it, export, and re-check
every file and line cited in `BRIEF.md`. The pin moves deliberately; it does
not follow every upstream commit.

## Continuous integration

`.github/workflows/ci.yml` builds the pinned Kdenlive with the patches against
PostProject `main`, and once more without PostProject. It then runs Kdenlive's
document-checker tests and the pilot's tests. The PostProject build also runs
Kdenlive, Blender, and the OpenAssetIO Manager against one temporary production.
It runs on every push here, on demand, and nightly from PostProject's
`kdenlive-pilot` workflow, which can also be started by hand against any
PostProject revision. A full Kdenlive build is too heavy for PostProject's
per-pull-request checks.

## Removing it

Build Kdenlive without PostProject, or use an upstream Kdenlive build, and
delete the `.pproj` files next to your projects. Your `.kdenlive` projects need
nothing else.

## License

The patches modify Kdenlive and are licensed like it, under
`GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL` (see `LICENSES/`). The scripts
use the same license.
