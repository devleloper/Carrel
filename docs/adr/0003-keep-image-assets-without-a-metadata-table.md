# 3. Keep image assets without a metadata table

- Status: accepted
- Date: 2026-11-03

## Context

ADR-07 in [part 3 of the proposal](../proposal/03-architecture.md) stores imported images as immutable HEIC
files in `assets/<sha256>.heic` and gives each page placements that name an asset, with a frame and a rotation.
The data model in section 8.4 also keeps an `ASSET` record per file in `notebook.json`: kind, file extension,
byte count, original name and import date.

Schema version 2 is the first to reference assets. Nothing in the MVP shows an asset's original name or import
date, and everything else in the record can be read from the file itself.

## Decision

- Schema version 2 stores image placements only: `id`, `assetID`, `frame` in page points and `rotation`. There
  is no asset table.
- The file is the asset. Its name is the SHA-256 of its bytes, its extension follows from what references it
  (`.heic` for an image placement) and its size comes from the file system.
- Whether an asset is in use is computed from the placements of every page, including pages in the Trash, when
  expired pages are purged.

## Consequences

A crash cannot leave a record and a file that disagree. The only ordering to keep is that an asset file is on
disk before a placement references it, and an unreferenced file is harmless until the next purge removes it.

The original file name and the import date are not recorded. If sync in 1.0 or a screen that lists a
notebook's images needs them, a later schema version adds the table; its migration step can create a record
for every referenced asset, leaving the fields it cannot know empty.
