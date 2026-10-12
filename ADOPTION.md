# Optional relink proposal

**Discussion draft; not submitted or endorsed by KDE.** The tested pilot uses
Kdenlive 26.08.1 (`55e16e85`) with the SDK 0.9/ABI 53. Its complete builds pass
with and without PostProject; the document checker and relink tests pass.

## Initial user journey and scope

Save a project while media is available. Move or rename a file, then reopen.
The existing missing-media dialog can offer a unique content-verified candidate
whose Kdenlive hash agrees. No match, duplicates, corrupt/unreadable production
or resolution failure preserve the existing missing state. Confirmation stays
in Kdenlive's normal dialog; the next save records the accepted locator.

Discuss only the optional package toggle, file-backed clip identity/fingerprint
recording, missing-file lookup and their tests. The first four existing patches
form that slice. Proxy jobs/provenance/staleness, shared-production selection
and the thumbnail/QML compatibility fix are separate proposals. The complete
ten-patch pilot is evidence, not one proposed merge request.

PostProject remains an optional installed C ABI/C++17 dependency. Kdenlive does
not invoke Cargo. `-DWITH_POSTPROJECT=OFF` omits its implementation and linkage;
an absent package preserves the ordinary build. Result propagation supports
Kdenlive's `-fno-exceptions`. Saves perform explicit file fingerprint I/O and
atomic sidecar commits; recovery performs bounded searches in the project and
previous media directories. Large-media latency and the best UI scheduling
boundary need maintainer agreement before an upstream feature is selected.

## Current upstream check

On 2026-10-12 KDE Invent `master` was
`a87f694882870666115ab09017e17dc47d935cfc`. Patches 1 and 2 apply there; patch 3
needs two context changes for a new include and saved-path member.
[`review/0003-relink-current-master.patch`](review/0003-relink-current-master.patch)
contains that independently reviewable hook. Apply it after patches 1 and 2;
patch 4 then applies. This draft has an application check, not a full master
build. The pinned pilot retains the full host qualification and reproducible
[build route](README.md#build).

The maintained Kdenlive → Blender → Manager handoff passes shared identity,
render provenance, moved media, explicit competing-write conflicts and stale
content. These prove the larger pilot's behavior, not upstream acceptance.
Report pilot problems through this repository's
[issues](https://github.com/postproject-org/postproject-kdenlive/issues).

## Contributing upstream

The current [upstream README](https://invent.kde.org/multimedia/kdenlive/-/blob/a87f694882870666115ab09017e17dc47d935cfc/README.md)
asks contributors to contact developers before a task and submit code on KDE
Invent. Begin with an issue or `#kdenlive-dev:kde.org`, then use the agreed
target branch. The GitHub repository is a mirror.
[KDE policy](https://community.kde.org/Policies/Commit_Policy) requires the
contributor to understand and maintain submitted code. A maintainer must
review, own and support any submission. The package and patches retain their recorded license notices.
