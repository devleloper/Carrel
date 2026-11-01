# Architecture

A one-page map. The reasoning behind each decision is in the
[proposal, part 3](docs/proposal/03-architecture.md) and in [docs/adr](docs/adr).

## Layers

```mermaid
flowchart TB
    App["App target (Carrel)<br/>SwiftUI screens, UIKit writing surface,<br/>PencilKit adapters"]
    Data["NotebookData<br/>stores, file formats, recovery, backup"]
    Domain["NotebookDomain<br/>entities, ordering, autosave policy"]
    App --> Data
    App --> Domain
    Data --> Domain
```

Dependencies point inward. `NotebookDomain` imports only Foundation. `NotebookData` adds CryptoKit and
Apple Archive. Neither knows about UIKit or PencilKit: ink crosses the boundary as `InkData`, opaque bytes
plus the PencilKit content version needed to read them. Both run their tests on the Mac host with `swift test`.

| Where | What |
|---|---|
| `Packages/CarrelKit/Sources/NotebookDomain` | `Notebook`, `Page`, `Folder`, `Paper`, `Cover`, `SortKey`, `Title`, `AutosavePolicy` |
| `Packages/CarrelKit/Sources/NotebookData` | `LibraryStore` (catalog and folders), `NotebookStore` (one notebook), `InkAutosaver`, `SnapshotStore`, `LibraryBackup`, `InkEnvelope`, `VersionedFile` |
| `Carrel/App` | `CarrelApp`, `AppDependencies` (the composition root) |
| `Carrel/Features/Library` | `LibraryModel`, library screens, new notebook sheet |
| `Carrel/Features/Editor` | `EditorSession`, `DrawingCache`, `NotebookCanvasViewController`, `PageStackLayout`, `PencilInteractionHandler`, palettes, page overview |
| `Carrel/Features/Settings` | `BackupModel`, settings screen |
| `Carrel/Features/Shared` | `UserFacingError`, presentation bindings, the share sheet |
| `Carrel/Services` | `InkCodec`, `InkRenderer`, `PaperRenderer`, `PDFExporter`, `BackgroundTask` |
| `Carrel/DesignSystem` | Reading Room `Palette` and `Theme`, ink palette, covers |

## Design rules

- **One reason to change per type.** Storage is split by what it owns: `LibraryStore` the catalog,
  `NotebookStore` one package, `InkAutosaver` when ink is written, `SnapshotStore` and `LibraryBackup` the
  safety nets. In the editor, `EditorSession` owns page structure, `DrawingCache` the live drawings,
  `PageStackLayout` the geometry and `PencilInteractionHandler` the Apple Pencil gestures.
- **Abstractions where they pay for themselves.** Views and models depend on the concrete stores: there is one
  implementation, and tests run them against temporary directories, which exercises the real file handling
  instead of a mock. Volatile inputs are injected instead: time (`now:` parameters), `UserDefaults`, the
  autosave policy and the library location. A protocol is introduced together with a second implementation,
  not before.
- **Logic lives where it can be tested quickly.** Anything that does not need UIKit lives in the package and
  runs with `swift test` on the Mac; app-side logic is pure where possible (`PageStackLayout`) and is covered by
  the `CarrelTests` target.
- **No duplicated knowledge.** Colors come from `Palette`, file generations from `VersionedFile`, title rules
  from `Title`, error wording from `UserFacingError`.

## Data on disk

```text
Application Support/Carrel/
├── Library/                       # everything a backup contains
│   ├── library.json(.previous)    # folders and tags
│   └── Notebooks/<id>.notebook/
│       ├── notebook.json(.previous)
│       └── ink/<pageID>.ink(.previous)
├── Snapshots/<id>/<timestamp>.notebook   # APFS clones taken when a notebook is opened
└── Recovered/                     # damaged files and libraries replaced by a restore; never cleaned
```

- Every write replaces the file atomically and keeps the previous generation. Reads fall back to it.
- An ink file is an envelope with a length and a SHA-256, so damage is detected before PencilKit sees it.
- The manifest records that a page has ink before its ink file first appears; a missing file is then
  recovered, never shown as an empty page.
- Ink written by a newer PencilKit opens read-only and is never rewritten.

## Saving

`DrawingCache` keeps the latest drawing of every edited page. `InkAutosaver` encodes and writes it after 2 s of
rest, at most 5 s after the first unsaved change, and immediately when the scene becomes inactive. If the app
crashes, at most 5 s of continuous writing is lost. Saves run one at a time, so an older drawing can never
overwrite a newer one; the package tests cover this ordering.

## Writing surface

`NotebookCanvasViewController` stacks pages in a zoomable `UIScrollView`. Only pages near the visible area get a
live `PKCanvasView`; the others show a cached image. A canvas belongs to one page for its whole life, so undo
history can never be applied to the wrong page. Drawings never pass through SwiftUI state.

## Concurrency

The app target defaults to `MainActor` isolation. Storage lives in actors (`LibraryStore`, one `NotebookStore`
per notebook) that are the only writers of their files.
