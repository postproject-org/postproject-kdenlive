# Kdenlive and Blender shared-production design

This note defines the host protocol for the PostProject 0.5 integration
scenario. It is intentionally narrower than either application's project-root
conventions: the shared object is one explicitly selected local `.pproj` file.
It is not inferred from directory nesting and is not a network database.

## Selecting the production

The human chooses an existing production, or a path for a new one, explicitly
in each pilot. Kdenlive's current pilot accepts
`--postproject-production /absolute/path/shared.pproj` at launch. The Blender
extension exposes the path in its add-on preferences and a file-browser
operator. Choosing a production never moves media or changes the host project
path.

For convenience, either host may initially suggest its existing sidecar path.
Accepting that suggestion is still an explicit selection. Neither host derives
the shared path from the other host's project, a common parent directory, a
Blender project root, or a Kdenlive project folder.

Automation supplies the path directly:

- Kdenlive's application and test driver receive the path explicitly;
- Blender's background script receives the same absolute path after `--`;
- OpenAssetIO's Manager configuration receives that path through its existing
  entity-reference configuration;
- every process opens the production independently through an installed
  PostProject package.

The command-line switches are pilot test controls, not additions to either
host's public file format.

## Facts written by each host

Kdenlive remains authoritative for its project and writes only facts it has
observed:

- the camera-media asset and its source representation;
- the `org.kde.kdenlive:control_uuid` external identifier;
- source content observations and confirmed source locations;
- Kdenlive proxy representations, their dependency on source content, and the
  activity that generated them;
- revision origin `Kdenlive` plus the application version.

Blender remains authoritative for its `.blend` file and writes:

- an `org.blender:strip_uuid` identifier attached to an asset it explicitly
  adopted, or to a newly imported asset when lookup found none;
- content observations and confirmed locations for media Blender can read;
- completed render representations, their source dependencies, and observed
  render provenance;
- revision origin `Blender` plus the application version.

Blender first queries by locator and content evidence. One unambiguous match
is offered for adoption; adopting attaches Blender's identifier to that asset.
No match creates new media. Several matches require a user choice and never
cause an implicit merge. Neither host overwrites or removes the other host's
external identifier.

Blender does not claim a PostProject job for ordinary renders. Its supported
handlers expose completion and cancellation but no reliable failure terminal,
so it records an existing output after `render_complete` with honest,
incomplete reproducibility facts. Kdenlive's proxy subprocess has a complete
worker lifecycle and continues to use the job protocol.

## Observing the other host

The automated path reads bounded revision pages after each cross-host write and
then reads the affected objects. A future interactive notification surface can
store a revision cursor and use the same sequence on these events:

- immediately after the user selects or opens a production;
- before a PostProject-assisted relink or save decision;
- when its local cross-process waiter reports a newer revision;
- when the user presses **Refresh PostProject**.

Revision origin prevents a host from presenting its own just-committed work as
an external update. Origin does not suppress state reads: both hosts re-read
affected objects from PostProject rather than reconstructing state from event
payloads.

Kdenlive's scenario assertion observes Blender's new render through revisions
and resolves it through the existing representation APIs. The pilot does not
yet add a media-results panel. Blender refreshes or relinks affected paths only
after an explicit operator action. Kdenlive never opens the `.blend` file, and
Blender never opens the `.kdenlive` file.

The cross-process waiter is only a local wake-up optimization. Correctness
comes from reading revisions after the stored cursor, including after process
restart.

## Conflict user experience

Every user or application decision is based on a recorded production revision.
The host begins its transaction with that revision as the base. Additive facts
may commit alongside independent additive facts. A non-mergeable fact that
changed after the base produces a typed conflict and commits nothing.

On conflict, the intended interactive host flow:

1. keeps the host document unchanged;
2. rolls back or resets the PostProject transaction;
3. reads the current value and the revisions named by the conflict;
4. shows the semantic subject and the competing origins;
5. offers **Keep production value**, **Retry my change**, and **Cancel** only
   where the host can express those choices safely.

**Retry my change** starts a new transaction from the newly read revision. It
is always a visible user decision; neither adapter retries automatically.
Locator conflicts show the current confirmed locator set and the host's
proposed set. Unknown conflict kinds fall back to refresh-and-cancel rather
than last-writer-wins.

The current pilots expose structured conflicts to their adapter code but do not
yet add a conflict dialog. In the headless scenario, the losing Kdenlive path
asserts the conflict key and both revisions instead of parsing diagnostic text.

## Automated scenario

The scenario creates media and an empty production in a temporary local
directory, then invokes the maintained integration paths in this order:

```mermaid
sequenceDiagram
    participant K as Kdenlive
    participant P as shared.pproj
    participant B as Blender
    participant O as OpenAssetIO Manager
    K->>P: Record camera source and proxy
    B->>P: Adopt source; record derived render
    K->>P: Read Blender revision and render
    O->>P: Resolve render entity reference
    K->>P: Confirm moved source
    B->>P: Resolve and relink moved source
    B->>P: Commit locator choice from base R
    K-->>P: Competing choice from R
    P-->>K: Structured locator-set conflict
    K->>P: Observe changed source content
    K->>P: Verify proxy and render are stale
```

1. Kdenlive saves a project and records the camera source.
2. Blender opens a fixture `.blend`, looks up the same file, and adopts the
   existing asset rather than creating one.
3. Blender renders a short derived clip and records the completed output.
4. Kdenlive consumes revisions and resolves that representation.
5. The OpenAssetIO Manager resolves the demonstrated representation from the
   same production.
6. The driver moves the source; one host resolves and confirms the new
   location, and the other consumes the resulting revision.
7. Both hosts read one base revision and propose different confirmed locator
   sets. Exactly one commit succeeds; the loser reports the structured
   conflict and performs no partial write.
8. The source bytes change. Kdenlive's proxy and Blender's render both evaluate
   stale where their recorded dependency policy requires it.

Kdenlive runs through its test executable under the CI display environment;
Blender runs with `--background --factory-startup --python`. The driver passes
one absolute production path to both. It does not edit the production directly,
scan for outputs on a host's behalf, or read either application's project file.

Before release, a maintainer also runs the path in both interactive
applications. That check records selection clarity, update visibility, and the
present absence of conflict UI in the main repository's 0.5 integration
findings.
